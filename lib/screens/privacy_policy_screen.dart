import 'package:flutter/material.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/shadows.dart';
import 'package:drama_hub/ui_system/typography.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),

                // Header
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    boxShadow: AppShadows.cardShadow,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.privacy_tip_rounded,
                        color: AppColors.primaryRed,
                        size: 48,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Last updated: February 2026',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.softGrey,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                _PolicySection(
                  title: '1. Information We Collect',
                  content:
                      'Drama Hub collects minimal information to provide the best experience. '
                      'We collect anonymous usage data such as dramas viewed, episodes watched, '
                      'and app interactions through Firebase Analytics. '
                      'We do not collect any personally identifiable information.',
                ),

                _PolicySection(
                  title: '2. How We Use Information',
                  content:
                      'The information we collect is used solely to improve app performance, '
                      'understand user preferences, and provide better content recommendations. '
                      'We never sell or share your data with third parties for marketing purposes.',
                ),

                _PolicySection(
                  title: '3. Advertisements',
                  content:
                      'Drama Hub displays ads through Google AdMob to support free content. '
                      'AdMob may collect device information to show relevant ads. '
                      'You can opt out of personalized ads through your device settings.',
                ),

                _PolicySection(
                  title: '4. Third Party Services',
                  content:
                      'We use the following third party services:\n\n'
                      '• Firebase Analytics — usage tracking\n'
                      '• Firebase Crashlytics — crash reporting\n'
                      '• Google AdMob — advertisements\n'
                      '• YouTube — video playback\n\n'
                      'Each service has its own privacy policy.',
                ),

                _PolicySection(
                  title: '5. Data Security',
                  content:
                      'We take data security seriously. All data transmission is encrypted. '
                      'We do not store any personal information on our servers. '
                      'Anonymous analytics data is stored securely on Firebase servers.',
                ),

                _PolicySection(
                  title: '6. Children\'s Privacy',
                  content:
                      'Drama Hub is not directed to children under 13. '
                      'We do not knowingly collect personal information from children. '
                      'If you believe a child has provided us information, please contact us.',
                ),

                _PolicySection(
                  title: '7. Changes to Policy',
                  content:
                      'We may update this privacy policy from time to time. '
                      'Any changes will be reflected in the app with an updated date. '
                      'Continued use of the app after changes means you accept the new policy.',
                ),

                _PolicySection(
                  title: '8. Contact Us',
                  content:
                      'If you have any questions about this privacy policy, '
                      'please contact us through our Telegram channel or website:\n\n'
                      '📱 Telegram: t.me/araftahindisub\n'
                      '🌐 Website: drama-hubs.blogspot.com',
                ),

                const SizedBox(height: AppSpacing.xl),

                // Footer
                Text(
                  '© 2026 Drama Hub. All rights reserved.',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String content;

  const _PolicySection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppShadows.cardShadow,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.title.copyWith(
              fontSize: 15,
              color: AppColors.primaryRed,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            content,
            style: AppTypography.body.copyWith(
              color: AppColors.softGrey,
              fontSize: 13,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
