import 'package:flutter/material.dart';

import '../services/privacy_policy.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Arrow Puzzle', style: text.headlineSmall),
            const SizedBox(height: 8),
            const Text('Last updated: ${PrivacyPolicy.updated}'),
            const SizedBox(height: 24),
            for (final section in PrivacyPolicy.sections) ...[
              Text(section.heading, style: text.titleMedium),
              const SizedBox(height: 8),
              Text(section.body, style: text.bodyLarge),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
