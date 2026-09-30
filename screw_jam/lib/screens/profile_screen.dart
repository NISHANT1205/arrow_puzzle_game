import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../widgets/palette.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final user = app.user;
    if (user == null) return const SizedBox.shrink();
    final p = app.progress;
    final threeStar = p.stars.values.where((s) => s == 3).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: GameBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Avatar(index: user.avatar, size: 96)),
            const SizedBox(height: 12),
            Center(
              child: Text(
                user.displayName,
                style: const TextStyle(
                  color: Palette.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (user.isGuest)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Playing as guest. Sign up to keep a named profile.',
                    style: TextStyle(color: Palette.inkSoft),
                  ),
                ),
              ),
            if (!user.isGuest) ...[
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < Palette.avatars.length; i++)
                    GestureDetector(
                      onTap: () => app.setAvatar(i),
                      child: Opacity(
                        opacity: user.avatar == i ? 1 : 0.5,
                        child: Avatar(index: i, size: 40),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.8,
              children: [
                _Stat(
                  'Levels done',
                  '${p.stars.length}/${app.levels.count}',
                  Icons.flag_rounded,
                ),
                _Stat('Stars', '${p.totalStars}', Icons.star_rounded),
                _Stat('Perfect (3★)', '$threeStar', Icons.emoji_events_rounded),
                _Stat('Coins', '${p.coins}', Icons.monetization_on_rounded),
                _Stat(
                  'Games played',
                  '${p.plays}',
                  Icons.sports_esports_rounded,
                ),
                _Stat('Wins', '${p.wins}', Icons.check_circle_rounded),
              ],
            ),
            const SizedBox(height: 28),
            GameButton(
              key: const Key('logout'),
              label: user.isGuest ? 'SIGN IN / SIGN UP' : 'LOG OUT',
              icon: Icons.logout_rounded,
              color: const Color(0xFFE53935),
              onPressed: () async {
                await app.logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _Stat(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.card,
        border: Border.all(color: Palette.cardBorder),
        boxShadow: Palette.softShadow(0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Palette.accent, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Palette.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Palette.inkSoft, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
