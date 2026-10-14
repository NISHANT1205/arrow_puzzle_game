import 'dart:convert';
import 'dart:io';

import 'package:arrow_puzzle/services/privacy_policy.dart';

/// Regenerate copy and the public privacy-policy document without credentials.
void main() {
  const root = 'output/play-store/listing';
  const locale = '$root/en-US';
  Directory('$locale/changelogs').createSync(recursive: true);
  final levels =
      (jsonDecode(File('assets/levels/levels.json').readAsStringSync())
          as Map<String, dynamic>)['levels'] as List<dynamic>;
  final count = levels.length;
  const title = 'Arrow Puzzle: Tap & Escape';
  const short =
      'Tap arrows to escape! Solve offline logic puzzles, clear boards and explore 3D.';
  final description =
      '''Find the clear path. Tap the right arrow. Clear the board.

Arrow Puzzle: Tap & Escape is an offline logic puzzle game where every arrow needs a way out. Follow each arrow's direction, spot what is blocking its path, and choose the right order to remove them.

The rules are easy to learn, but winding arrows and crowded boards make every move worth thinking about. A clear arrow slides away. A blocked arrow crashes and costs you a heart. Can you clear the whole board before your hearts run out?

$count levels to explore
Discover a curated collection of arrow puzzles, from smaller boards to larger layouts with long paths and tricky blockers. Replay completed levels and try to clear them without a mistake.

A new dimension with 3D cube puzzles
Selected levels take the challenge onto a 3D cube. Rotate the cube to inspect different sides and discover how arrows on one face can block arrows on another. Look beyond the front of the board to find your next move.

How to play
• Follow the direction of an arrow's head.
• Check whether its escape path is clear.
• Tap to send the arrow off the board.
• Remove blocking arrows in the right order.
• Clear every arrow to complete the level.

Think before you tap
Begin each level with three hearts. Tapping a blocked arrow costs one heart, so inspect the board and plan your moves. If you need help, use a hint to highlight an arrow that can escape.

Play at your own pace
There is no countdown pushing you to rush. Take your time tracing paths, untangling the board, and finding a clear route.

Features
• $count bundled logic puzzle levels.
• Flat arrow boards and selected 3D cube challenges.
• Offline gameplay with no account required.
• Hints to help you find a safe move.
• Zoom and pan to inspect larger boards.
• Rotate 3D cubes to explore hidden sides.
• Replay completed levels.
• Saved progress on your device.
• Dark mode and adjustable sound and vibration settings.

Whether you enjoy tap puzzles, arrow escape games, or untangling tricky logic boards, Arrow Puzzle gives you a simple goal with plenty to figure out.

Take a closer look, choose your next arrow, and clear the way.''';
  final notes = '''Welcome to Arrow Puzzle!

• Explore $count arrow puzzle levels.
• Discover 3D cube challenges.
• Use hints to find a clear escape path.
• Play offline and save your progress.
• Customize dark mode, sound and vibration.''';
  if (title.length > 30 ||
      short.length > 80 ||
      description.length > 4000 ||
      notes.length > 500) {
    throw StateError('Listing copy exceeds a Play Console character limit.');
  }
  for (final entry in {
    'title.txt': title,
    'short_description.txt': short,
    'full_description.txt': description,
    'changelogs/1.txt': notes,
  }.entries) {
    File('$locale/${entry.key}').writeAsStringSync(entry.value);
  }

  const escape = HtmlEscape();
  final sections = PrivacyPolicy.sections
      .map((section) => '<h2>${escape.convert(section.heading)}</h2>'
          '<p>${escape.convert(section.body)}</p>')
      .join('\n');
  File('$root/privacy-policy.html').writeAsStringSync('''<!doctype html>
<html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Arrow Puzzle — Privacy Policy</title>
<style>body{max-width:760px;margin:48px auto;padding:0 24px;font:17px/1.7 system-ui;color:#101b43;background:#fff}h1{line-height:1.2}h2{font-size:21px;margin-top:32px}</style>
<main><h1>Arrow Puzzle Privacy Policy</h1>
<p>Last updated: ${PrivacyPolicy.updated}</p>
$sections
</main></html>''');

  final settingsFile = File('$root/store-settings.json');
  final previous = settingsFile.existsSync()
      ? jsonDecode(settingsFile.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};
  final settings = {
    'package_name': 'com.nisharc.arrowpuzzle',
    'version_name': '1.0.0',
    'version_code': 1,
    'default_language': 'en-US',
    'app_type': 'Game',
    'category': 'Puzzle',
    'contains_ads': false,
    'in_app_purchases': false,
    'requires_login': false,
    'data_safety_draft': {
      'collects_user_data': false,
      'shares_user_data': false,
      'basis':
          'Reviewed dependencies and release app code: no ads, analytics, accounts or network data collection; preferences stay on device.',
      'note':
          'Confirm the final Play Console questionnaire before submission. Device-managed backup preferences are disclosed in the policy.',
    },
    'developer_name': previous['developer_name'],
    'support_email': previous['support_email'],
    'privacy_policy_url': previous['privacy_policy_url'],
    'website_url': previous['website_url'],
    'pricing': previous['pricing'],
    'target_countries': previous['target_countries'],
    'target_age_groups': previous['target_age_groups'],
    'content_rating':
        'Complete the Play Console content-rating questionnaire; no rating is preassigned.',
    'keyword_themes': [
      'arrow puzzle',
      'arrow escape',
      'logic puzzle',
      'tap puzzle',
      'offline puzzle game',
      '3D cube puzzle'
    ],
    'keyword_research':
        'Relevance-based copy; keyword search volumes and ranking outcomes have not been measured.',
    'assets': {
      'icon': 'graphics/store-icon-512.png',
      'feature_graphic': 'graphics/feature-graphic-1024x500.png',
      'phone_screenshots': '../edited/',
      'screenshot_dimensions': '1080x1920',
      'recommended_screenshot_order': [
        '02-gameplay',
        '04-cube',
        '03-levels',
        '05-hint',
        '06-dark-mode',
        '01-home',
        '07-level-complete',
        '09-settings'
      ],
    },
    'character_counts': {
      'title': title.length,
      'short_description': short.length,
      'full_description': description.length,
      'release_notes': notes.length,
    },
    'pending_console_fields': [
      for (final field in [
        'developer_name',
        'support_email',
        'privacy_policy_url',
        'pricing',
        'target_countries',
        'target_age_groups',
      ])
        if (previous[field] == null) field,
      'content_rating_questionnaire',
    ],
    'policy_sources': [
      'https://support.google.com/googleplay/android-developer/answer/9859152?hl=en',
      'https://support.google.com/googleplay/android-developer/answer/10144311',
      'https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-sg',
    ],
  };
  File('$root/store-settings.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(settings)}\n');
  stdout.writeln('Listing generated: title ${title.length}/30, short '
      '${short.length}/80, full ${description.length}/4000, '
      'release notes ${notes.length}/500.');
}
