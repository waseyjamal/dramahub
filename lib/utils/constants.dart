import 'package:drama_hub/config/app_config_service.dart';

class Constants {
  // App info
  static const String appName = 'Drama Hub';
  static const String appVersion = '1.0.0';

  // API (placeholder for future use)
  static const String baseUrl = '';

  // Shared preferences keys
  static const String keyTheme = 'theme';
  static const String keyLanguage = 'language';

  // Default values
  static const int defaultTimeout = 30;
  static const int itemsPerPage = 20;
}

/// Centralized SharedPreferences keys
/// Use these instead of raw strings anywhere in the app
class StorageKeys {
  // Onboarding
  static const String onboardingDone = 'onboarding_done';

  // Last watched
  static const String lastDramaId = 'last_drama_id';
  static const String lastDramaTitle = 'last_drama_title';
  static const String lastDramaBanner = 'last_drama_banner';
  static const String lastEpisodeNumber = 'last_episode_number';
  static const String lastEpisodeTitle = 'last_episode_title';

  // Watchlist
  static const String watchlist = 'watchlist_dramas';

  // ✅ 8.6 — Added: previously magic strings scattered in controllers
  static const String watchHistory = 'watch_history';
  static const String cachedDramas = 'cached_dramas';
  static const String cachedDramasTime = 'cached_dramas_time';
  static const String episodesCache = 'episodes_cache_';
  static const String episodesCacheTime = 'episodes_cache_time_';

  // ✅ Version system — cache invalidation
  static const String dataVersion = 'data_version';
}

class AppConstants {
  // ✅ 8.7 — premium drama ID centralized
  // Change this if the premium drama ever changes
  static const String premiumDramaId = 'arafta';
}

/// ✅ All social/external URLs controlled from admin panel via app_config.json
/// Change any URL from admin — no new APK needed.
class AppUrls {
  // ── Dynamic (admin-controlled) ───────────────────────────────────────────
  static String get telegram =>
      AppConfigService.instance.config.telegramUrl;
  static String get instagram =>
      AppConfigService.instance.config.instagramUrl;
  static String get website =>
      AppConfigService.instance.config.websiteUrl;

  // ── Static (rarely changes, not worth admin overhead) ────────────────────
  static const String playStore =
      'https://play.google.com/store/apps/details?id=com.dramahub.drama_hub';
  static const String githubDataBase =
      'https://dramahub-data.waseyjamal000.workers.dev';

  static bool isSafeUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && ['https', 'http', 'tg'].contains(uri.scheme);
  }
}
