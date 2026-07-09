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
import 'package:drama_hub/config/app_config_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _version = 'Loading...';
  bool _isUpToDate = true;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    final currentBuild = int.tryParse(info.buildNumber) ?? 1;
    final latestVersion = AppConfigService.instance.config.latestVersion;
    setState(() {
      _version = 'Version ${info.version} (${info.buildNumber})';
      _isUpToDate = currentBuild >= latestVersion;
    });
  }

  Future<void> _launch(String url) async {
    if (!AppUrls.isSafeUrl(url)) return;
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
                const SizedBox(height: AppSpacing.lg),

                // ── HERO CARD ──────────────────────────────
                _HeroCard(version: _version, isUpToDate: _isUpToDate),

                const SizedBox(height: AppSpacing.xl),

                // ── CONNECT SECTION ────────────────────────
                const _SectionLabel(label: 'Connect With Us'),
                _TileGroup(
                  tiles: [
                    _TileData(
                      icon: Icons.send_rounded,
                      iconColor: const Color(0xFF0088CC),
                      title: 'Join Telegram',
                      subtitle: 'Join our community',
                      onTap: () => _launch(AppUrls.telegram),
                    ),
                    _TileData(
                      icon: Icons.camera_alt_rounded,
                      iconColor: const Color(0xFFE1306C),
                      title: 'Instagram',
                      subtitle: 'Follow us for daily updates',
                      onTap: () => _launch(AppUrls.instagram),
                    ),
                    _TileData(
                      icon: Icons.language_rounded,
                      iconColor: AppColors.primaryRed,
                      title: 'Website',
                      subtitle: 'Browse dramas on the web',
                      onTap: () => _launch(AppUrls.website),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── FEEDBACK SECTION ───────────────────────
                const _SectionLabel(label: 'Feedback'),
                _TileGroup(
                  tiles: [
                    _TileData(
                      icon: Icons.star_rounded,
                      iconColor: AppColors.goldAccent,
                      title: 'Rate the App',
                      subtitle: 'Enjoying Drama Hub? Rate us!',
                      onTap: () => _launch(
                        'https://play.google.com/store/apps/details?id=com.dramahub.drama_hub',
                      ),
                    ),
                    _TileData(
                      icon: Icons.bug_report_rounded,
                      iconColor: Colors.orangeAccent,
                      title: 'Report a Problem',
                      subtitle: 'Tell us what went wrong',
                      onTap: () => Get.toNamed(AppRoutes.reportProblem),
                    ),
                    _TileData(
                      icon: Icons.movie_rounded,
                      iconColor: Colors.purpleAccent,
                      title: 'Suggest a Drama',
                      subtitle: 'Want to see a drama here?',
                      onTap: () => Get.toNamed(AppRoutes.suggestDrama),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── LEGAL SECTION ──────────────────────────
                const _SectionLabel(label: 'Legal'),
                _TileGroup(
                  tiles: [
                    _TileData(
                      icon: Icons.privacy_tip_rounded,
                      iconColor: Colors.tealAccent,
                      title: 'Privacy Policy',
                      subtitle: 'Read our privacy policy',
                      onTap: () => Get.toNamed(AppRoutes.privacyPolicy),
                    ),
                    _TileData(
                      icon: Icons.info_rounded,
                      iconColor: Colors.blueAccent,
                      title: 'About Us',
                      subtitle: 'Learn more about Drama Hub',
                      onTap: () => Get.toNamed(AppRoutes.about),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                const Text(
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

// ── HERO CARD ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final String version;
  final bool isUpToDate;

  const _HeroCard({required this.version, required this.isUpToDate});

  @override
  Widget build(BuildContext context) {
    final badgeColor = isUpToDate
        ? const Color(0xFF26C6DA)
        : const Color(0xFFFFC107);
    final badgeText = isUpToDate ? 'UP TO DATE' : 'UPDATE AVAILABLE';
    final badgeDotColor = isUpToDate
        ? const Color(0xFF26C6DA)
        : const Color(0xFFFFC107);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(
          color: AppColors.primaryRed.withValues(alpha: 0.18),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryRed.withValues(alpha: 0.22),
            AppColors.primaryRed.withValues(alpha: 0.06),
          ],
        ),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(
                color: AppColors.primaryRed.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.medium - 1.5),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Icon(
                  Icons.play_circle_filled,
                  color: AppColors.primaryRed,
                  size: 36,
                ),
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Drama Hub',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  version,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: badgeDotColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: badgeDotColor.withValues(alpha: 0.7),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── SECTION LABEL ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── TILE DATA MODEL ───────────────────────────────────────────────────────────

class _TileData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _TileData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });
}

// ── TILE GROUP (iOS-style grouped list) ──────────────────────────────────────

class _TileGroup extends StatelessWidget {
  final List<_TileData> tiles;
  const _TileGroup({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.055),
          width: 1,
        ),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        children: List.generate(tiles.length, (index) {
          final tile = tiles[index];
          final isLast = index == tiles.length - 1;
          return _GroupedTile(
            data: tile,
            isFirst: index == 0,
            isLast: isLast,
            showDivider: !isLast,
          );
        }),
      ),
    );
  }
}

// ── GROUPED TILE ──────────────────────────────────────────────────────────────

class _GroupedTile extends StatelessWidget {
  final _TileData data;
  final bool isFirst;
  final bool isLast;
  final bool showDivider;

  const _GroupedTile({
    required this.data,
    required this.isFirst,
    required this.isLast,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: data.onTap,
            borderRadius: BorderRadius.vertical(
              top: isFirst ? Radius.circular(AppRadius.large) : Radius.zero,
              bottom: isLast ? Radius.circular(AppRadius.large) : Radius.zero,
            ),
            splashColor: data.iconColor.withValues(alpha: 0.08),
            highlightColor: data.iconColor.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: data.iconColor.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Icon(data.icon, color: data.iconColor, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          data.subtitle,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Optional NEW badge
                  if (data.badge != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        data.badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white24,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 58 + AppSpacing.md),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
      ],
    );
  }
}
