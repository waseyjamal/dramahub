import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/shadows.dart';
import 'package:drama_hub/ui_system/typography.dart';
import 'package:drama_hub/utils/constants.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    // ✅ W-4 — dynamic version from PackageInfo instead of hardcoded string
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Us'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxl),

                // Logo + App Name
                Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryRed.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(
                            Icons.play_circle_filled,
                            color: AppColors.primaryRed,
                            size: 60,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'Drama Hub',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    // ✅ W-4 — dynamic version, never goes stale
                    Text(
                      _version.isNotEmpty ? 'Version $_version' : '',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.softGrey,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Description Card
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    boxShadow: AppShadows.cardShadow,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Drama Hub is your ultimate destination for Turkish dramas with Hindi subtitles. '
                    'Watch, download, and enjoy the best Turkish content — completely free!',
                    style: AppTypography.body.copyWith(
                      color: AppColors.softGrey,
                      fontSize: 14,
                      height: 1.7,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Connect With Us
                Text(
                  'Connect With Us',
                  style: AppTypography.title.copyWith(
                    fontSize: 16,
                    color: AppColors.softGrey,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.lg),

                // ✅ P-3 — AppUrls.telegram instead of hardcoded string
                _SocialButton(
                  icon: Icons.send_rounded,
                  label: 'Telegram Channel',
                  subtitle: '@araftahindisub',
                  color: const Color(0xFF0088CC),
                  onTap: () => _launch(AppUrls.telegram),
                ),
                const SizedBox(height: AppSpacing.md),
                _SocialButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Instagram',
                  subtitle: '@arafta_hindi',
                  color: const Color(0xFFE1306C),
                  onTap: () => _launch(AppUrls.instagram),
                ),
                const SizedBox(height: AppSpacing.md),
                _SocialButton(
                  icon: Icons.language_rounded,
                  label: 'Website',
                  subtitle: 'drama-hubs.blogspot.com',
                  color: AppColors.primaryRed,
                  onTap: () => _launch(AppUrls.website),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Footer
                Text(
                  'Made with ❤️ by Dramahub',
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

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.large),
          boxShadow: AppShadows.cardShadow,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.title.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.softGrey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
