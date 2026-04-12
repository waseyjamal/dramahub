import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drama_hub/routes/app_routes.dart';
import 'package:drama_hub/utils/constants.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/shadows.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = 'Version ${info.version} (${info.buildNumber})';
      });
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),

                // App Logo + Info
                Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
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
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Drama Hub',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _version,
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                // Connect Section
                _SectionLabel(label: 'Connect With Us'),
                // ✅ P-2 — AppUrls.telegram instead of hardcoded string
                _ProfileTile(
                  icon: Icons.send_rounded,
                  iconColor: const Color(0xFF0088CC),
                  title: 'Join Telegram',
                  subtitle: '@araftahindisub',
                  onTap: () => _launch(AppUrls.telegram),
                ),
                _ProfileTile(
                  icon: Icons.camera_alt_rounded,
                  iconColor: const Color(0xFFE1306C),
                  title: 'Instagram',
                  subtitle: '@arafta_hindi',
                  onTap: () => _launch('https://instagram.com/arafta_hindi'),
                ),
                _ProfileTile(
                  icon: Icons.language_rounded,
                  iconColor: AppColors.primaryRed,
                  title: 'Website',
                  subtitle: 'drama-hubs.blogspot.com',
                  onTap: () => _launch('https://drama-hubs.blogspot.com'),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Feedback Section
                _SectionLabel(label: 'Feedback'),

                // Rate App → custom in-app rating screen
                _ProfileTile(
                  icon: Icons.star_rounded,
                  iconColor: AppColors.goldAccent,
                  title: 'Rate the App',
                  subtitle: 'Enjoying Drama Hub? Rate us!',
                  onTap: () => _launch(
                    'https://play.google.com/store/apps/details?id=com.dramahub.drama_hub',
                  ),
                ),

                // Report a Problem → Google Form WebView
                _ProfileTile(
                  icon: Icons.bug_report_rounded,
                  iconColor: Colors.orangeAccent,
                  title: 'Report a Problem',
                  subtitle: 'Tell us what went wrong',
                  onTap: () => Get.toNamed(AppRoutes.reportProblem),
                ),

                // Suggest a Drama → Google Form WebView
                _ProfileTile(
                  icon: Icons.movie_rounded,
                  iconColor: Colors.purpleAccent,
                  title: 'Suggest a Drama',
                  subtitle: 'Want to see a drama here?',
                  onTap: () => Get.toNamed(AppRoutes.suggestDrama),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Legal Section
                _SectionLabel(label: 'Legal'),
                _ProfileTile(
                  icon: Icons.privacy_tip_rounded,
                  iconColor: Colors.tealAccent,
                  title: 'Privacy Policy',
                  subtitle: 'Read our privacy policy',
                  onTap: () => Get.toNamed(AppRoutes.privacyPolicy),
                ),
                _ProfileTile(
                  icon: Icons.info_rounded,
                  iconColor: Colors.blueAccent,
                  title: 'About Us',
                  subtitle: 'Learn more about Drama Hub',
                  onTap: () => Get.toNamed(AppRoutes.about),
                ),

                const SizedBox(height: AppSpacing.xl),

                Text(
                  'Made with ❤️ by Dramahub',
                  style: TextStyle(color: Colors.white24, fontSize: 12),
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

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          boxShadow: AppShadows.cardShadow,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}
