import 'package:drama_hub/models/vast_ad_config_model.dart';

class AdConfigModel {
  final bool adsEnabled;
  final AppOpenAdConfig appOpen;
  final InterstitialAdConfig interstitial;
  final RewardedAdConfig rewarded;
  final DownloadAdConfig download;
  final NativeAdConfig native;
  final VastAdConfig vast;
  final AdNetworksConfig adNetworks;
  final OfflineAdConfig offlineAds;

  AdConfigModel({
    required this.adsEnabled,
    required this.appOpen,
    required this.interstitial,
    required this.rewarded,
    required this.download,
    required this.native,
    required this.vast,
    required this.adNetworks,
    required this.offlineAds,
  });

  factory AdConfigModel.fromJson(Map<String, dynamic> json) {
    return AdConfigModel(
      adsEnabled: json['ads_enabled'] ?? true,
      appOpen: AppOpenAdConfig.fromJson(json['app_open'] ?? {}),
      interstitial: InterstitialAdConfig.fromJson(json['interstitial'] ?? {}),
      rewarded: RewardedAdConfig.fromJson(json['rewarded'] ?? {}),
      download: DownloadAdConfig.fromJson(json['download'] ?? {}),
      native: NativeAdConfig.fromJson(json['native'] ?? {}),
      vast: VastAdConfig.fromJson(json['vast'] ?? {}),
      adNetworks: AdNetworksConfig.fromJson(json['ad_networks'] ?? {}),
      offlineAds: OfflineAdConfig.fromJson(json['offline_ads'] ?? {}),
    );
  }

  /// Safe fallback defaults if GitHub fetch fails
  factory AdConfigModel.defaults() {
    return AdConfigModel(
      adsEnabled: true,
      appOpen: AppOpenAdConfig.defaults(),
      interstitial: InterstitialAdConfig.defaults(),
      rewarded: RewardedAdConfig.defaults(),
      download: DownloadAdConfig.defaults(),
      native: NativeAdConfig.defaults(),
      vast: VastAdConfig.defaults(),
      adNetworks: AdNetworksConfig.defaults(),
      offlineAds: OfflineAdConfig.defaults(),
    );
  }

  Map<String, dynamic> toJson() => {
    'ads_enabled': adsEnabled,
    'app_open': appOpen.toJson(),
    'interstitial': interstitial.toJson(),
    'rewarded': rewarded.toJson(),
    'download': download.toJson(),
    'native': native.toJson(),
    'vast': vast.toJson(),
    'ad_networks': adNetworks.toJson(),
    'offline_ads': offlineAds.toJson(),
  };
}

class AdNetworksConfig {
  final bool appodealEnabled;
  final bool casEnabled;
  AdNetworksConfig({required this.appodealEnabled, required this.casEnabled});
  factory AdNetworksConfig.fromJson(Map<String, dynamic> json) => AdNetworksConfig(
    appodealEnabled: json['appodeal_enabled'] ?? true,
    casEnabled: json['cas_enabled'] ?? true,
  );
  factory AdNetworksConfig.defaults() => AdNetworksConfig(appodealEnabled: true, casEnabled: true);
  Map<String, dynamic> toJson() => {'appodeal_enabled': appodealEnabled, 'cas_enabled': casEnabled};
}

class AppOpenAdConfig {
  final bool enabled;
  final int cooldownHours;
  final String adUnitId;
  final String provider;

  AppOpenAdConfig({
    required this.enabled,
    required this.cooldownHours,
    required this.adUnitId,
    required this.provider,
  });

  factory AppOpenAdConfig.fromJson(Map<String, dynamic> json) {
    return AppOpenAdConfig(
      enabled: json['enabled'] ?? true,
      cooldownHours: json['cooldown_hours'] ?? 4,
      adUnitId: json['ad_unit_id'] ?? AppOpenAdConfig.defaults().adUnitId,
      provider: json['provider'] ?? 'cas',
    );
  }

  factory AppOpenAdConfig.defaults() => AppOpenAdConfig(
    enabled: false, // ✅ 6.5 — disabled when no config loaded
    cooldownHours: 4,
    adUnitId: '', // ✅ 6.5 — empty string, not test ID
    provider: 'cas',
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'cooldown_hours': cooldownHours,
    'ad_unit_id': adUnitId,
    'provider': provider,
  };
}

class InterstitialAdConfig {
  final bool enabled;
  final int cooldownSeconds;
  final int maxPerSession;
  final String adUnitId;
  final Map<String, bool> screens;
  final String priority1;
  final bool priority1Enabled;
  final String priority2;
  final bool priority2Enabled;

  InterstitialAdConfig({
    required this.enabled,
    required this.cooldownSeconds,
    required this.maxPerSession,
    required this.adUnitId,
    required this.screens,
    required this.priority1,
    required this.priority1Enabled,
    required this.priority2,
    required this.priority2Enabled,
  });

  factory InterstitialAdConfig.fromJson(Map<String, dynamic> json) {
    final screensJson = json['screens'] as Map<String, dynamic>? ?? {};
    return InterstitialAdConfig(
      enabled: json['enabled'] ?? true,
      cooldownSeconds: json['cooldown_seconds'] ?? 30,
      maxPerSession: json['max_per_session'] ?? 3,
      adUnitId: json['ad_unit_id'] ?? InterstitialAdConfig.defaults().adUnitId,
      screens: screensJson.map((k, v) => MapEntry(k, v as bool? ?? false)),
      priority1: json['priority_1'] ?? 'appodeal',
      priority1Enabled: json['priority_1_enabled'] ?? true,
      priority2: json['priority_2'] ?? 'cas',
      priority2Enabled: json['priority_2_enabled'] ?? false,
    );
  }

  factory InterstitialAdConfig.defaults() => InterstitialAdConfig(
    enabled: false, // ✅ 6.5 — disabled when no config loaded
    cooldownSeconds: 30,
    maxPerSession: 3,
    adUnitId: '', // ✅ 6.5 — empty string, not test ID
    screens: {
      'home_screen': false,
      'episodes_screen': false,
      'video_screen': false,
      'upcoming_screen': false,
      'watchlist_screen': false,
      'history_screen': false,
      'download_screen': false,
      'profile_screen': false,
      'premium_screen': false,
      'suggest_drama_screen': false,
      'rate_app_screen': false,
      'report_problem_screen': false,
    },
    priority1: 'appodeal',
    priority1Enabled: true,
    priority2: 'cas',
    priority2Enabled: false,
  );

  bool isEnabledForScreen(String screenKey) {
    if (!enabled) return false;
    return screens[screenKey] ?? false;
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'cooldown_seconds': cooldownSeconds,
    'max_per_session': maxPerSession,
    'ad_unit_id': adUnitId,
    'screens': screens,
    'priority_1': priority1,
    'priority_1_enabled': priority1Enabled,
    'priority_2': priority2,
    'priority_2_enabled': priority2Enabled,
  };
}

class RewardedAdConfig {
  final bool enabled;
  final int cooldownSeconds;
  final int maxPerSession;
  final String adUnitId;
  final Map<String, bool> screens;
  final String priority1;
  final bool priority1Enabled;
  final String priority2;
  final bool priority2Enabled;

  RewardedAdConfig({
    required this.enabled,
    required this.cooldownSeconds,
    required this.maxPerSession,
    required this.adUnitId,
    required this.screens,
    required this.priority1,
    required this.priority1Enabled,
    required this.priority2,
    required this.priority2Enabled,
  });

  factory RewardedAdConfig.fromJson(Map<String, dynamic> json) {
    final screensJson = json['screens'] as Map<String, dynamic>? ?? {};
    return RewardedAdConfig(
      enabled: json['enabled'] ?? true,
      cooldownSeconds: json['cooldown_seconds'] ?? 30,
      maxPerSession: json['max_per_session'] ?? 5,
      adUnitId: json['ad_unit_id'] ?? RewardedAdConfig.defaults().adUnitId,
      screens: screensJson.map((k, v) => MapEntry(k, v as bool? ?? false)),
      priority1: json['priority_1'] ?? 'appodeal',
      priority1Enabled: json['priority_1_enabled'] ?? true,
      priority2: json['priority_2'] ?? 'cas',
      priority2Enabled: json['priority_2_enabled'] ?? false,
    );
  }

  factory RewardedAdConfig.defaults() => RewardedAdConfig(
    enabled: false,
    cooldownSeconds: 30,
    maxPerSession: 5,
    adUnitId: '',
    screens: {
      'home_screen': false,
      'episodes_screen': false,
      'video_screen': false,
      'upcoming_screen': false,
      'watchlist_screen': false,
      'history_screen': false,
      'download_screen': false,
      'profile_screen': false,
      'premium_screen': false,
      'suggest_drama_screen': false,
      'rate_app_screen': false,
      'report_problem_screen': false,
    },
    priority1: 'appodeal',
    priority1Enabled: true,
    priority2: 'cas',
    priority2Enabled: false,
  );

  bool isEnabledForScreen(String screenKey) {
    if (!enabled) return false;
    return screens[screenKey] ?? false;
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'cooldown_seconds': cooldownSeconds,
    'max_per_session': maxPerSession,
    'ad_unit_id': adUnitId,
    'screens': screens,
    'priority_1': priority1,
    'priority_1_enabled': priority1Enabled,
    'priority_2': priority2,
    'priority_2_enabled': priority2Enabled,
  };
}

class DownloadAdConfig {
  final bool enabled;
  final int cooldownSeconds;
  final int maxPerSession;
  final String priority1;
  final bool priority1Enabled;
  final String priority2;
  final bool priority2Enabled;

  DownloadAdConfig({
    required this.enabled,
    required this.cooldownSeconds,
    required this.maxPerSession,
    required this.priority1,
    required this.priority1Enabled,
    required this.priority2,
    required this.priority2Enabled,
  });

  factory DownloadAdConfig.fromJson(Map<String, dynamic> json) {
    return DownloadAdConfig(
      enabled: json['enabled'] ?? true,
      cooldownSeconds: json['cooldown_seconds'] ?? 120,
      maxPerSession: json['max_per_session'] ?? 3,
      priority1: json['priority_1'] ?? 'cas',
      priority1Enabled: json['priority_1_enabled'] ?? true,
      priority2: json['priority_2'] ?? 'appodeal',
      priority2Enabled: json['priority_2_enabled'] ?? true,
    );
  }

  factory DownloadAdConfig.defaults() => DownloadAdConfig(
    enabled: false,
    cooldownSeconds: 120,
    maxPerSession: 3,
    priority1: 'cas',
    priority1Enabled: true,
    priority2: 'appodeal',
    priority2Enabled: true,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'cooldown_seconds': cooldownSeconds,
    'max_per_session': maxPerSession,
    'priority_1': priority1,
    'priority_1_enabled': priority1Enabled,
    'priority_2': priority2,
    'priority_2_enabled': priority2Enabled,
  };
}

class NativeAdConfig {
  final bool enabled;
  final int everyNthCard;
  final String adUnitId;
  final Map<String, bool> screens; // ADD THIS

  NativeAdConfig({
    required this.enabled,
    required this.everyNthCard,
    required this.adUnitId,
    required this.screens, // ADD THIS
  });

  factory NativeAdConfig.fromJson(Map<String, dynamic> json) {
    final screensJson = json['screens'] as Map<String, dynamic>? ?? {};
    return NativeAdConfig(
      enabled: json['enabled'] ?? false,
      everyNthCard: json['every_nth_card'] ?? 5,
      adUnitId: json['ad_unit_id'] ?? NativeAdConfig.defaults().adUnitId,
      screens: screensJson.map(
        (k, v) => MapEntry(k, v as bool? ?? false),
      ), // ADD THIS
    );
  }

  factory NativeAdConfig.defaults() => NativeAdConfig(
    enabled: false, // ✅ 6.5 — disabled when no config loaded
    everyNthCard: 5,
    adUnitId: '', // ✅ 6.5 — empty string, not test ID
    screens: {
      'home_screen': false,
      'episodes_screen': false,
      'watchlist_screen': false,
      'history_screen': false,
      'download_screen': false,
    },
  );

  bool isEnabledForScreen(String screenKey) {
    if (!enabled) return false;
    return screens[screenKey] ?? false;
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'every_nth_card': everyNthCard,
    'ad_unit_id': adUnitId,
    'screens': screens, // ADD THIS
  };
}

class OfflineAdConfig {
  final bool enabled;
  final String adType; // 'interstitial' or 'rewarded'
  final int maturityMinutes;
  final int sessionCoolMinutes;
  final int maxPerSession;
  final String priority1;
  final bool priority1Enabled;
  final String priority2;
  final bool priority2Enabled;

  OfflineAdConfig({
    required this.enabled,
    required this.adType,
    required this.maturityMinutes,
    required this.sessionCoolMinutes,
    required this.maxPerSession,
    required this.priority1,
    required this.priority1Enabled,
    required this.priority2,
    required this.priority2Enabled,
  });

  factory OfflineAdConfig.fromJson(Map<String, dynamic> json) {
    return OfflineAdConfig(
      enabled: json['enabled'] ?? false,
      adType: json['ad_type'] ?? 'interstitial',
      maturityMinutes: json['maturity_minutes'] ?? 5,
      sessionCoolMinutes: json['session_cool_minutes'] ?? 5,
      maxPerSession: json['max_per_session'] ?? 3,
      priority1: json['priority_1'] ?? 'cas',
      priority1Enabled: json['priority_1_enabled'] ?? true,
      priority2: json['priority_2'] ?? 'appodeal',
      priority2Enabled: json['priority_2_enabled'] ?? true,
    );
  }

  factory OfflineAdConfig.defaults() => OfflineAdConfig(
    enabled: false,
    adType: 'interstitial',
    maturityMinutes: 5,
    sessionCoolMinutes: 5,
    maxPerSession: 3,
    priority1: 'cas',
    priority1Enabled: true,
    priority2: 'appodeal',
    priority2Enabled: true,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'ad_type': adType,
    'maturity_minutes': maturityMinutes,
    'session_cool_minutes': sessionCoolMinutes,
    'max_per_session': maxPerSession,
    'priority_1': priority1,
    'priority_1_enabled': priority1Enabled,
    'priority_2': priority2,
    'priority_2_enabled': priority2Enabled,
  };
}

