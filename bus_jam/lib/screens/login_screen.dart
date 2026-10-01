import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/common.dart';
import '../widgets/palette.dart';
import 'home_screen.dart';
import 'splash_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _signUp = false;
  bool _hide = true;
  bool _busy = false;
  int _avatar = 0;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final app = AppScope.read(context);
    try {
      if (_signUp) {
        await app.signUp(_user.text, _pass.text, _avatar);
      } else {
        await app.login(_user.text, _pass.text);
      }
      _goHome();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _guest() async {
    await AppScope.read(context).continueAsGuest();
    _goHome();
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  InputDecoration _deco(String label, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: Palette.field,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const Logo(size: 40),
                    const SizedBox(height: 6),
                    const Text(
                      'Park. Board. Go!',
                      style: TextStyle(color: Palette.inkSoft),
                    ),
                    const SizedBox(height: 24),
                    _card(),
                    const SizedBox(height: 18),
                    TextButton.icon(
                      key: const Key('guest'),
                      onPressed: _busy ? null : _guest,
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Play as Guest'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Palette.card,
        boxShadow: Palette.softShadow(1.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Palette.cardBorder),
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Login'),
                  icon: Icon(Icons.login),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Sign Up'),
                  icon: Icon(Icons.person_add),
                ),
              ],
              selected: {_signUp},
              onSelectionChanged: (s) => setState(() {
                _signUp = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 18),
            if (_signUp) ...[
              const Text(
                'Pick an avatar',
                style: TextStyle(color: Palette.inkSoft),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < Palette.avatars.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _avatar = i),
                      child: AnimatedScale(
                        scale: _avatar == i ? 1.15 : 0.9,
                        duration: const Duration(milliseconds: 150),
                        child: Opacity(
                          opacity: _avatar == i ? 1 : 0.55,
                          child: Avatar(index: i, size: 42),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              key: const Key('username'),
              controller: _user,
              textInputAction: TextInputAction.next,
              decoration: _deco('Username', Icons.person),
              validator: AuthService.validateUsername,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('password'),
              controller: _pass,
              obscureText: _hide,
              textInputAction: _signUp
                  ? TextInputAction.next
                  : TextInputAction.done,
              onFieldSubmitted: (_) => _signUp ? null : _submit(),
              decoration: _deco(
                'Password',
                Icons.lock,
                suffix: IconButton(
                  icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
              validator: AuthService.validatePassword,
            ),
            if (_signUp) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('confirm'),
                controller: _confirm,
                obscureText: _hide,
                onFieldSubmitted: (_) => _submit(),
                decoration: _deco('Confirm password', Icons.lock_outline),
                validator: (v) =>
                    v != _pass.text ? 'Passwords do not match' : null,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('auth-error'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 20),
            GameButton(
              key: const Key('submit'),
              label: _signUp ? 'CREATE ACCOUNT' : 'LOGIN',
              icon: _signUp ? Icons.rocket_launch : Icons.play_arrow_rounded,
              onPressed: _busy ? null : _submit,
            ),
            const SizedBox(height: 10),
            const Text(
              'Accounts are saved on this device only.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Palette.inkSoft, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
