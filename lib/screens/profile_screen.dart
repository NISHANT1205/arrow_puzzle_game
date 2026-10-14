import 'package:flutter/material.dart';
import '../services/player_profile_service.dart';
import '../widgets/player_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  int _avatar = 0;
  bool _busy = true;
  String? _error;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await PlayerProfileService.instance.ensureProfile();
      if (!mounted) return;
      _name.text = p.username;
      _avatar = p.avatarId % avatarNames.length;
      _loaded = true;
    } catch (e) {
      if (mounted) _error = '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await PlayerProfileService.instance
          .saveProfile(username: _name.text, avatarId: _avatar);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile saved')));
      }
    } catch (e) {
      if (mounted) _error = '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Player profile')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const Text(
              'Your guest profile is created automatically when online.'),
          const SizedBox(height: 20),
          Center(child: PlayerAvatar(avatarId: _avatar, size: 100)),
          const SizedBox(height: 20),
          TextField(
              controller: _name,
              enabled: _loaded && !_busy,
              maxLength: 20,
              decoration: const InputDecoration(
                  labelText: 'Username',
                  helperText: '4–20 letters, numbers or underscores')),
          const SizedBox(height: 12),
          Text('Choose your avatar',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 80,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10),
            itemCount: avatarNames.length,
            itemBuilder: (context, i) => Semantics(
              selected: _avatar == i,
              button: true,
              child: Tooltip(
                message: avatarNames[i],
                child: InkWell(
                  borderRadius: BorderRadius.circular(40),
                  onTap: _loaded && !_busy
                      ? () => setState(() => _avatar = i)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            width: 3,
                            color: _avatar == i
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent)),
                    child:
                        FittedBox(child: PlayerAvatar(avatarId: i, size: 56)),
                  ),
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 16),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else
            FilledButton(
                onPressed: _loaded ? _save : _load,
                child: Text(_loaded ? 'Save profile' : 'Try again')),
        ]),
      );
}
