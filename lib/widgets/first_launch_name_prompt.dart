import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/player_profile_service.dart';

/// Opens after the first frame, independently of network/profile startup.
class FirstLaunchNamePrompt extends StatefulWidget {
  const FirstLaunchNamePrompt(
      {super.key, required this.child, this.profiles, this.preferences});
  final Widget child;
  final PlayerProfileService? profiles;
  final Future<SharedPreferences>? preferences;
  static const completedKey = 'arrow_name_prompt_completed_v1';

  @override
  State<FirstLaunchNamePrompt> createState() => _FirstLaunchNamePromptState();
}

class _FirstLaunchNamePromptState extends State<FirstLaunchNamePrompt> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_show()));
  }

  Future<void> _show() async {
    final prefs = await (widget.preferences ?? SharedPreferences.getInstance());
    if (!mounted || prefs.getBool(FirstLaunchNamePrompt.completedKey) == true) {
      return;
    }
    final profiles = widget.profiles ?? PlayerProfileService.instance;
    await profiles.loadCachedProfile();
    if (!mounted) return;
    // Persist before displaying, so force-closing the first launch cannot repeat it.
    await prefs.setBool(FirstLaunchNamePrompt.completedKey, true);
    if (!mounted) return;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _NameDialog(profiles: profiles));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.profiles});
  final PlayerProfileService profiles;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  bool _edited = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
        text: widget.profiles.profile.value?.username ??
            'guest${10000000 + Random.secure().nextInt(90000000)}');
    widget.profiles.profile.addListener(_profileChanged);
    // Populate the actual unique server-assigned guest name when connected.
    unawaited(
        widget.profiles.ensureProfile().then((_) {}, onError: (Object _) {}));
  }

  void _profileChanged() {
    final player = widget.profiles.profile.value;
    if (!_edited && player != null && mounted) _name.text = player.username;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final requestedName = _name.text.trim();
    final edited = _edited;
    try {
      final player = await widget.profiles.ensureProfile();
      await widget.profiles.saveProfile(
        username: edited ? requestedName : player.username,
        avatarId: player.avatarId,
      );
      if (mounted) Navigator.of(context).pop();
    } on PlayerProfileException catch (e) {
      if (mounted) {
        setState(() => _error = e.statusCode == 409
            ? 'That username is taken. Try another one.'
            : e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not save your name. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    widget.profiles.profile.removeListener(_profileChanged);
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PopScope(
        canPop: !_saving,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          content: SingleChildScrollView(
              child: Form(
                  key: _form,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                            controller: _name,
                            enabled: !_saving,
                            maxLength: 20,
                            textInputAction: TextInputAction.done,
                            autocorrect: false,
                            enableSuggestions: false,
                            onChanged: (_) {
                              _edited = true;
                              if (_error != null) setState(() => _error = null);
                            },
                            onFieldSubmitted: (_) => _save(),
                            validator: (v) => RegExp(r'^[a-zA-Z0-9_]{4,20}$')
                                    .hasMatch(v?.trim() ?? '')
                                ? null
                                : 'Use 4–20 letters, numbers or underscores.',
                            decoration: InputDecoration(
                              labelText: 'Name',
                              counterText: '',
                              filled: true,
                              fillColor: colors.primaryContainer
                                  .withValues(alpha: .25),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            )),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(_error!,
                                  style: TextStyle(color: colors.error))),
                      ]))),
          actions: [
            SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: colors.primary))
                        : const Text('Save'))),
            SizedBox(
                width: double.infinity,
                child: TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Not now'))),
          ],
        ));
  }
}
