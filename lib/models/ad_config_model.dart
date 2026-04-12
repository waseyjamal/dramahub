class AdConfigModel {
  final bool adsEnabled;
  final AppOpenAdConfig appOpen;
  final InterstitialAdConfig interstitial;
  final RewardedAdConfig rewarded;
  final NativeAdConfig native;

  AdConfigModel({
    required this.adsEnabled,
    required this.appOpen,
    required this.interstitial,
    required this.rewarded,
    required this.native,
  });

  factory AdConfigModel.fromJson(Map<String, dynamic> json) {
    return AdConfigModel(
      adsEnabled: json['ads_enabled'] ?? true,
      appOpen: AppOpenAdConfig.fromJson(json['app_open'] ?? {}),
      interstitial: InterstitialAdConfig.fromJson(json['interstitial'] ?? {}),
      rewarded: RewardedAdConfig.fromJson(json['rewarded'] ?? {}),
      native: NativeAdConfig.fromJson(json['native'] ?? {}),
    );
  }

  /// Safe fallback defaults if GitHub fetch fails
  factory AdConfigModel.defaults() {
    return AdConfigModel(
      adsEnabled: true,
      appOpen: AppOpenAdConfig.defaults(),
      interstitial: InterstitialAdConfig.defaults(),
      rewarded: RewardedAdConfig.defaults(),
      native: NativeAdConfig.defaults(),
    );
  }

  Map<String, dynamic> toJson() => {
    'ads_enabled': adsEnabled,
    'app_open': appOpen.toJson(),
    'interstitial': interstitial.toJson(),
    'rewarded': rewarded.toJson(),
    'native': native.toJson(),
  };
}

class AppOpenAdConfig {
  final bool enabled;
  final int cooldownHours;
  final String adUnitId;

  AppOpenAdConfig({
    required this.enabled,
    required this.cooldownHours,
    required this.adUnitId,
  });

  factory AppOpenAdConfig.fromJson(Map<String, dynamic> json) {
    return AppOpenAdConfig(
      enabled: json['enabled'] ?? true,
      cooldownHours: json['cooldown_hours'] ?? 4,
      adUnitId: json['ad_unit_id'] ?? AppOpenAdConfig.defaults().adUnitId,
    );
  }

  factory AppOpenAdConfig.defaults() => AppOpenAdConfig(
    enabled: false, // ✅ 6.5 — disabled when no config loaded
    cooldownHours: 4,
    adUnitId: '', // ✅ 6.5 — empty string, not test ID
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'cooldown_hours': cooldownHours,
    'ad_unit_id': adUnitId,
  };
}

class InterstitialAdConfig {
  final bool enabled;
  final int cooldownSeconds;
  final int maxPerSession;
  final String adUnitId;
  final Map<String, bool> screens;

  InterstitialAdConfig({
    required this.enabled,
    required this.cooldownSeconds,
    required this.maxPerSession,
    required this.adUnitId,
    required this.screens,
  });

  factory InterstitialAdConfig.fromJson(Map<String, dynamic> json) {
    final screensJson = json['screens'] as Map<String, dynamic>? ?? {};
    return InterstitialAdConfig(
      enabled: json['enabled'] ?? true,
      cooldownSeconds: json['cooldown_seconds'] ?? 30,
      maxPerSession: json['max_per_session'] ?? 3,
      adUnitId: json['ad_unit_id'] ?? InterstitialAdConfig.defaults().adUnitId,
      screens: screensJson.map((k, v) => MapEntry(k, v as bool? ?? false)),
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
  };
}

class RewardedAdConfig {
  final bool enabled;
  final String adUnitId;
  final Map<String, bool> screens;

  RewardedAdConfig({
    required this.enabled,
    required this.adUnitId,
    required this.screens,
  });

  factory RewardedAdConfig.fromJson(Map<String, dynamic> json) {
    final screensJson = json['screens'] as Map<String, dynamic>? ?? {};
    return RewardedAdConfig(
      enabled: json['enabled'] ?? true,
      adUnitId: json['ad_unit_id'] ?? RewardedAdConfig.defaults().adUnitId,
      screens: screensJson.map((k, v) => MapEntry(k, v as bool? ?? false)),
    );
  }

  factory RewardedAdConfig.defaults() => RewardedAdConfig(
    enabled: false, // ✅ 6.5 — disabled when no config loaded
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
  );

  bool isEnabledForScreen(String screenKey) {
    if (!enabled) return false;
    return screens[screenKey] ?? false;
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'ad_unit_id': adUnitId,
    'screens': screens,
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
