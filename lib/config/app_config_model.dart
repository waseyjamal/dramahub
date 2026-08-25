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
  final int dataVersion;
  final String cdnBase;
  final String instagramUrl;
  final String websiteUrl;
  final String telegramBotToken;
  final String telegramChatId;
  final FallbackUpdateConfig fallbackUpdate;

  // ── Signing API (for secure video URL signing via Deno Deploy) ──
  final String signingApi;
  final String signingApiFallback;
  final bool useSignedUrls;

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
    required this.dataVersion,
    required this.cdnBase,
    required this.instagramUrl,
    required this.websiteUrl,
    required this.telegramBotToken,
    required this.telegramChatId,
    required this.fallbackUpdate,
    required this.signingApi,
    required this.signingApiFallback,
    required this.useSignedUrls,
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
      dataVersion: json['data_version'] ?? 1,
      cdnBase: (json['cdn_base'] as String?)?.trim().isNotEmpty == true
          ? (json['cdn_base'] as String).trim().replaceAll(RegExp(r'/$'), '')
          : 'https://dramahub-data.pages.dev',
      instagramUrl:
          json['instagram_url'] ?? 'https://instagram.com/dramas_hubs',
      websiteUrl: json['website_url'] ?? 'https://dramahubs.stream/',
      telegramBotToken: json['telegram_bot_token'] ?? '',
      telegramChatId: json['telegram_chat_id'] ?? '',
      fallbackUpdate: FallbackUpdateConfig.fromJson(
        json['fallback_update'] as Map<String, dynamic>? ?? {},
      ),
      // ── Signing API — safe defaults if missing from old config ──
      signingApi: (json['signing_api'] as String?)?.trim() ?? '',
      signingApiFallback:
          (json['signing_api_fallback'] as String?)?.trim() ?? '',
      useSignedUrls: json['use_signed_urls'] ?? false,
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
      dataVersion: 1,
      cdnBase: 'https://dramahub-data.pages.dev',
      instagramUrl: 'https://instagram.com/dramas_hubs',
      websiteUrl: 'https://dramahubs.stream/',
      telegramBotToken: '',
      telegramChatId: '',
      fallbackUpdate: FallbackUpdateConfig.defaults(),
      signingApi: '',
      signingApiFallback: '',
      useSignedUrls: false,
    );
  }
}

/// Fallback update delivery config — controlled remotely via admin panel
class FallbackUpdateConfig {
  final bool playstoreEnabled;
  final String playstoreUrl;
  final bool telegramEnabled;
  final String telegramUrl;
  final bool websiteEnabled;
  final String websiteUrl;

  FallbackUpdateConfig({
    required this.playstoreEnabled,
    required this.playstoreUrl,
    required this.telegramEnabled,
    required this.telegramUrl,
    required this.websiteEnabled,
    required this.websiteUrl,
  });

  bool get hasAtLeastOneOption =>
      playstoreEnabled || telegramEnabled || websiteEnabled;

  factory FallbackUpdateConfig.fromJson(Map<String, dynamic> json) {
    return FallbackUpdateConfig(
      playstoreEnabled: json['playstore_enabled'] ?? true,
      playstoreUrl:
          json['playstore_url'] ??
          'https://play.google.com/store/apps/details?id=com.dramahub.drama_hub',
      telegramEnabled: json['telegram_enabled'] ?? false,
      telegramUrl: json['telegram_url'] ?? 'https://t.me/araftahindisub',
      websiteEnabled: json['website_enabled'] ?? false,
      websiteUrl:
          json['website_url'] ?? 'https://dramahubs.stream/p/app-download.html',
    );
  }

  factory FallbackUpdateConfig.defaults() => FallbackUpdateConfig(
    playstoreEnabled: true,
    playstoreUrl:
        'https://play.google.com/store/apps/details?id=com.dramahub.drama_hub',
    telegramEnabled: false,
    telegramUrl: 'https://t.me/araftahindisub',
    websiteEnabled: false,
    websiteUrl: 'https://dramahubs.stream/p/app-download.html',
  );
}
