"""Inspect a signed Play release without exposing signing credentials."""

import argparse
import hashlib
import json
import struct
import subprocess
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path


def run(command):
    result = subprocess.run(command, text=True, capture_output=True, check=True)
    return result.stdout.strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--bundletool", type=Path, required=True)
    parser.add_argument("--java-home", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    java = str(args.java_home / "bin/java")
    command = [java, "-jar", str(args.bundletool)]
    bundle_flag = f"--bundle={args.bundle.resolve()}"
    run(command + ["validate", bundle_flag])
    manifest_text = run(command + ["dump", "manifest", bundle_flag, "--module=base"])
    (args.output / "android-manifest.xml").write_text(manifest_text + "\n")
    config_text = run(command + ["dump", "config", bundle_flag])
    (args.output / "bundle-config.json").write_text(config_text + "\n")
    config = json.loads(config_text)
    native_packaging = config["optimizations"]["uncompressNativeLibraries"]
    assert native_packaging["enabled"]
    assert native_packaging["alignment"] == "PAGE_ALIGNMENT_16K"
    manifest = ET.fromstring(manifest_text)
    android = "{http://schemas.android.com/apk/res/android}"
    sdk = manifest.find("uses-sdk")
    app = manifest.find("application")
    assert sdk is not None and app is not None
    assert manifest.attrib["package"] == "com.nisharc.arrowpuzzle"
    assert manifest.attrib[android + "versionName"] == "1.0.0"
    assert manifest.attrib[android + "versionCode"] == "1"
    assert int(sdk.attrib[android + "targetSdkVersion"]) >= 36
    assert app.attrib.get(android + "debuggable", "false") == "false"
    activities = [item.attrib[android + "name"] for item in app.findall("activity")]
    assert "com.nisharc.arrowpuzzle.MainActivity" in activities

    verification = run([
        str(args.java_home / "bin/jarsigner"), "-verify", "-certs", str(args.bundle)
    ])
    (args.output / "signature-verification.txt").write_text(verification + "\n")
    assert "jar verified." in verification

    libraries = []
    with zipfile.ZipFile(args.bundle) as archive:
        assert archive.testzip() is None
        signatures = [name for name in archive.namelist()
                      if name.startswith("META-INF/") and name.endswith(".RSA")]
        assert signatures, "No RSA signature found"
        signature_file = args.output / "upload-signature.p7b"
        signature_file.write_bytes(archive.read(signatures[0]))
        certificates = run([
            "openssl", "pkcs7", "-inform", "DER", "-in", str(signature_file),
            "-print_certs"
        ])
        assert "Android Debug" not in certificates, "Bundle uses a debug certificate"
        certificate_start = certificates.index("-----BEGIN CERTIFICATE-----")
        certificate_end = certificates.index("-----END CERTIFICATE-----") + len(
            "-----END CERTIFICATE-----")
        certificate_file = args.output / "bundle-upload-certificate.pem"
        certificate_file.write_text(certificates[certificate_start:certificate_end] + "\n")
        bundle_certificate = run([
            "openssl", "x509", "-in", str(certificate_file), "-noout", "-fingerprint", "-sha256"
        ])
        expected_certificate = run([
            "openssl", "x509", "-in", str(args.output / "upload-certificate.pem"),
            "-noout", "-fingerprint", "-sha256"
        ])
        assert bundle_certificate == expected_certificate, "Unexpected upload certificate"

        for name in sorted(archive.namelist()):
            if not name.startswith("base/lib/") or not name.endswith(".so"):
                continue
            data = archive.read(name)
            assert data[:4] == b"\x7fELF", name
            is_64 = data[4] == 2
            endian = "<" if data[5] == 1 else ">"
            if is_64:
                table = struct.unpack_from(endian + "Q", data, 32)[0]
                entry_size, entries = struct.unpack_from(endian + "HH", data, 54)
            else:
                table = struct.unpack_from(endian + "I", data, 28)[0]
                entry_size, entries = struct.unpack_from(endian + "HH", data, 42)
            alignments = []
            for index in range(entries):
                offset = table + index * entry_size
                kind = struct.unpack_from(endian + "I", data, offset)[0]
                if kind == 1:
                    alignment = struct.unpack_from(
                        endian + ("Q" if is_64 else "I"), data, offset + (48 if is_64 else 28)
                    )[0]
                    alignments.append(alignment)
            assert alignments, name
            if is_64:
                assert min(alignments) >= 16384, f"16 KB alignment missing: {name}"
            libraries.append({
                "path": name, "bits": 64 if is_64 else 32,
                "load_segment_alignments": alignments,
                "supports_16kb_elf_alignment": min(alignments) >= 16384,
            })

    report = {
        "package_name": manifest.attrib["package"],
        "version_name": manifest.attrib[android + "versionName"],
        "version_code": int(manifest.attrib[android + "versionCode"]),
        "min_sdk": int(sdk.attrib[android + "minSdkVersion"]),
        "target_sdk": int(sdk.attrib[android + "targetSdkVersion"]),
        "debuggable": False,
        "label": app.attrib.get(android + "label"),
        "permissions": [element.attrib[android + "name"]
                        for element in manifest.findall("uses-permission")],
        "bundle_bytes": args.bundle.stat().st_size,
        "sha256": hashlib.sha256(args.bundle.read_bytes()).hexdigest(),
        "bundletool_validation": "passed",
        "jar_signature_verification": "passed",
        "upload_certificate_sha256": bundle_certificate.split("=", 1)[1],
        "native_libraries": libraries,
        "native_library_packaging_alignment": native_packaging["alignment"],
        "checks": "Package, activity, version, target API, non-debug release, upload certificate, archive integrity and 64-bit ELF alignment checked.",
        "runtime_smoke_test": "Not run: no Android device or emulator was connected.",
    }
    (args.output / "build-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Verified {report['package_name']} {report['version_name']} "
          f"({report['version_code']}), target API {report['target_sdk']}, "
          f"{len(libraries)} native libraries, signed release bundle.")


if __name__ == "__main__":
    main()
