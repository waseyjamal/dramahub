/// Model for app configuration
class AppConfigModel {
  final String appName;
  final String telegramUrl;
  final bool showHeroSection;
  final bool showTelegramCTA;
  final bool showMembershipPromo;
  final bool enablePremiumBadge;
  final int latestVersion;
  final bool forceUpdate;
  final List<String> heroSliderDramaIds;
  final int dataVersion; // ✅ version system — cache invalidation

  AppConfigModel({
    required this.appName,
    required this.telegramUrl,
    required this.showHeroSection,
    required this.showTelegramCTA,
    required this.showMembershipPromo,
    required this.enablePremiumBadge,
    required this.latestVersion,
    required this.forceUpdate,
    required this.heroSliderDramaIds,
    required this.dataVersion, // ✅
  });

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    List<String> heroIds = [];
    if (json['hero_slider_dramas'] != null) {
      heroIds = List<String>.from(
        (json['hero_slider_dramas'] as List)
            .where((e) => e != null && e.toString().isNotEmpty)
            .map((e) => e.toString()),
      );
    }

    return AppConfigModel(
      appName: json['appName'] ?? 'Drama Hub',
      telegramUrl: json['telegramUrl'] ?? 'https://t.me/araftahindisub',
      showHeroSection: json['showHeroSection'] ?? true,
      showTelegramCTA: json['showTelegramCTA'] ?? true,
      showMembershipPromo: json['showMembershipPromo'] ?? true,
      enablePremiumBadge: json['enablePremiumBadge'] ?? true,
      latestVersion: json['latestVersion'] ?? 1,
      forceUpdate: json['forceUpdate'] ?? false,
      heroSliderDramaIds: heroIds,
      dataVersion: json['data_version'] ?? 1, // ✅
    );
  }

  factory AppConfigModel.defaultConfig() {
    return AppConfigModel(
      appName: 'Drama Hub',
      telegramUrl: 'https://t.me/araftahindisub',
      showHeroSection: true,
      showTelegramCTA: true,
      showMembershipPromo: true,
      enablePremiumBadge: true,
      latestVersion: 1,
      forceUpdate: false,
      heroSliderDramaIds: [],
      dataVersion: 1, // ✅
    );
  }
}
