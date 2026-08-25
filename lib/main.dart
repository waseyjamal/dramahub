// lib/main.dart
// ✅ Added: MobileAds.initialize() before Future.wait
// ✅ Added: YandexService registered + initEarly() in Future.wait
// ✅ Added: YandexService.instance.refreshAdLoad() on app resume
// ✅ Everything else: zero changes

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yandex_mobileads/mobile_ads.dart';
import 'package:drama_hub/services/ad_config_service.dart';
import 'package:drama_hub/services/yandex_service.dart';
import 'package:get/get.dart';
import 'package:drama_hub/services/download_service.dart';
import 'package:drama_hub/services/ad_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:drama_hub/firebase_options.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:drama_hub/config/app_config_service.dart';
import 'package:drama_hub/security/root_checker.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/routes/app_routes.dart';
import 'package:drama_hub/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {
    if (kDebugMode) debugPrint('Anonymous auth failed: $e');
  }

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // ✅ Yandex SDK must initialize before any ad loads — do it before Future.wait
  try {
    YandexAds.initialize();
    if (kDebugMode) debugPrint('✅ Yandex MobileAds initialized');
  } catch (e) {
    if (kDebugMode) debugPrint('❌ Yandex MobileAds init error: $e');
  }

  // Register services
  Get.put(DownloadService(), permanent: true);
  // ✅ YandexService registered before Future.wait
  Get.put(YandexService(), permanent: true);

  await Future.wait([
    AppConfigService.instance.loadConfig().timeout(
      const Duration(seconds: 3),
      onTimeout: () => false,
    ),
    AdConfigService.instance.initialize(),
    // ✅ Yandex loads ads in parallel during splash
    YandexService.instance.initEarly().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        if (kDebugMode) debugPrint('ℹ️ Yandex pre-load timed out — continuing');
      },
    ),
  ]);

  await DownloadService.instance.init();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  FlutterNativeSplash.remove();
  runApp(const DramaHubAppRunner());

  _initializeInBackground();
}

Future<void> _initializeInBackground() async {
  try {
    await FirebaseMessaging.instance
        .requestPermission(alert: true, badge: true, sound: true)
        .timeout(const Duration(seconds: 10));
  } catch (e) {
    if (kDebugMode) debugPrint('FCM permission request timed out or failed: $e');
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (kDebugMode) debugPrint('FCM foreground: ${message.notification?.title}');
  });
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationTap(message.data);
  });

  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    Future.delayed(const Duration(seconds: 1), () {
      _handleNotificationTap(initialMessage.data);
    });
  }
}

void _handleNotificationTap(Map<String, dynamic> data) {
  final screen = data['screen'] as String? ?? '';
  final dramaId = data['dramaId'] as String? ?? '';

  if (screen == 'episodes' && dramaId.isNotEmpty) {
    try {
      final homeController = Get.find<HomeController>();
      final drama = homeController.allDramas.firstWhereOrNull(
        (d) => d.id == dramaId,
      );
      if (drama != null) {
        Get.toNamed(AppRoutes.episodes, arguments: drama);
      } else {
        Get.toNamed(AppRoutes.main);
      }
    } catch (e) {
      Get.toNamed(AppRoutes.main);
    }
  } else {
    Get.toNamed(AppRoutes.main);
  }
}

class DramaHubAppRunner extends StatefulWidget {
  const DramaHubAppRunner({super.key});

  @override
  State<DramaHubAppRunner> createState() => _DramaHubAppRunnerState();
}

class _DramaHubAppRunnerState extends State<DramaHubAppRunner>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService.instance.showAppOpen();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performStartupChecks();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      YandexService.instance.cancelPendingAppOpen();
    }
    if (state == AppLifecycleState.resumed) {
      YandexService.instance.setReturnedFromBackground();
      AdConfigService.instance.refresh().then((_) {
        YandexService.instance.refreshAdLoad();
        AdService.instance.showAppOpen();
      });
      // ✅ Force config reload on resume — bypasses 5-min throttle
      // This is what makes new episodes visible immediately when user
      // returns to app after you uploaded content
      try {
        final homeController = Get.find<HomeController>();
        homeController.loadDramas(isResume: true);
      } catch (_) {
        // HomeController not ready yet — safe to ignore
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _performStartupChecks() async {
    if (RootChecker.isDeviceRooted()) _showRootWarning();
    _checkVersionUpdate();
  }

  void _showRootWarning() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Security Warning'),
        content: const Text(
          'This device appears to be rooted. App security may be compromised.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _checkVersionUpdate() {
    final config = AppConfigService.instance.config;
    if (config.latestVersion <= Constants.currentBuildVersion) return;
    if (!config.forceUpdate) return;
    _showForceUpdateDialog();
  }

  void _showForceUpdateDialog() {
    final fallback = AppConfigService.instance.config.fallbackUpdate;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.system_update_rounded,
                    color: AppColors.primaryRed, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Update Required',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'A new version of Drama Hub is available. Please update to continue.',
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (fallback.playstoreEnabled || !fallback.hasAtLeastOneOption)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final url = fallback.playstoreUrl;
                      if (!AppUrls.isSafeUrl(url)) return;
                      await launchUrl(Uri.parse(url),
                          mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Update on Play Store',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              if (fallback.telegramEnabled) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (!AppUrls.isSafeUrl(fallback.telegramUrl)) return;
                      await launchUrl(Uri.parse(fallback.telegramUrl),
                          mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.send_rounded,
                        color: Colors.white70, size: 18),
                    label: const Text('Get Update on Telegram',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
              if (fallback.websiteEnabled) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (!AppUrls.isSafeUrl(fallback.websiteUrl)) return;
                      await launchUrl(Uri.parse(fallback.websiteUrl),
                          mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.language_rounded,
                        color: Colors.white70, size: 18),
                    label: const Text('Download from Website',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const DramaHubApp();
  }
}