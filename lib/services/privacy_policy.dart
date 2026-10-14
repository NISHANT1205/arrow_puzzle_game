/// Shared copy for the in-app policy and the public policy document.
class PrivacyPolicy {
  static const updated = '14 October 2026';
  static const sections = <({String heading, String body})>[
    (
      heading: 'About this policy',
      body: 'This policy applies to Arrow Puzzle '
          '(Android package com.nisharc.arrowpuzzle).',
    ),
    (
      heading: 'Data collection and sharing',
      body: 'When online, Arrow Puzzle creates a guest player profile with '
          'NishArc Studios and sends your player name, avatar, highest completed '
          'level, number of attempts, progress, settings and gameplay events '
          '(moves, hints, mistakes, results, restarts and revives) to its backend. '
          'Session activity records menu, playing, paused and background states '
          'and active/playing time. Gameplay remains available offline.',
    ),
    (
      heading: 'Progress and settings',
      body:
          'Progress, preferences, a random registration secret and a player access token are stored on your '
          'device. Unsent gameplay updates are queued locally and retried when '
          'online. The token identifies your guest profile; clearing app data '
          'or uninstalling removes it. A username alone cannot recover a profile. '
          'Backend records remain after clearing local data. Device backups may '
          'include app preferences according to your backup settings.',
    ),
    (
      heading: 'Your choices',
      body: 'Use Settings > Reset progress to reset your unlocked level and '
          'completion count on this device and sync that reset when online. '
          'Sound, vibration and theme can be changed '
          'individually in Settings. To remove all stored preferences, clear '
          'the app data in Android settings. Device backups are managed through '
          'your device backup settings.',
    ),
    (
      heading: 'Children and personal information',
      body: 'The game does not request your real name, email address, location '
          'or contacts. Use a nickname for your player profile.',
    ),
    (
      heading: 'Contact and changes',
      body: 'For questions about this policy, use the developer contact email '
          'shown on the Arrow Puzzle Google Play listing. If you contact the '
          'developer by email, your email address and message are used to '
          'respond to your request. If the game\'s data practices change, this '
          'policy will be updated.',
    ),
  ];
}
