import 'package:url_launcher/url_launcher.dart';

class AppLinks {
  static final privacyPolicy = Uri.parse(
    'https://nisharc.in/privacy-policy/arrow-puzzle',
  );
  static final playStore = Uri.https('play.google.com', '/store/apps/details', {
    'id': 'com.nisharc.arrowpuzzle',
  });

  static Future<bool> open(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
