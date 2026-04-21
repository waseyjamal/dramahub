import 'package:drama_hub/services/ad_config_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:drama_hub/firebase_options.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:drama_hub/config/app_config_service.dart';
import 'package:drama_hub/security/root_checker.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:get/get.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/routes/app_routes.dart';
import 'package:drama_hub/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app.dart';

/// Current app version
const int currentAppVersion = 4;

/// Main entry point for Drama Hub app
Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Firebase MUST be first — everything else depends on it
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {
    debugPrint('Anonymous auth failed: $e');
  }

  // Crashlytics setup — sync, fast, must be right after Firebase
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // ✅ Only load config before first frame — fastest possible startup
  // Config needed immediately for version check and ad config
  await AppConfigService.instance.loadConfig().timeout(
    const Duration(seconds: 3),
    onTimeout: () => false,
  );

  // ✅ Remove splash — app is ready to show
  FlutterNativeSplash.remove();
  runApp(const DramaHubAppRunner());

  // ✅ Everything else runs AFTER app is visible
  // User never waits for ads, FCM, or analytics
  _initializeInBackground();
}

/// Runs after first frame — user already sees the app
/// Nothing here blocks the UI
Future<void> _initializeInBackground() async {
  // Initialize ads and FCM permission in parallel
  await Future.wait([
    AdConfigService.instance.initialize(),
    FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    ),
  ]).timeout(const Duration(seconds: 10), onTimeout: () => []);

  // FCM listeners — set up after permission granted
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('FCM foreground: ${message.notification?.title}');
  });
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationTap(message.data);
  });

  // Check initial notification (app opened from notification)
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    Future.delayed(const Duration(seconds: 1), () {
      _handleNotificationTap(initialMessage.data);
    });
  }

  // ✅ FCM token — commented out, enable when needed for push campaigns
  // FirebaseMessaging.instance.getToken().then((token) {
  //   debugPrint('FCM Token: $token');
  // }).catchError((e) {
  //   debugPrint('FCM token error: $e');
  // });
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

/// Wrapper to handle startup checks before showing main app
class DramaHubAppRunner extends StatefulWidget {
  const DramaHubAppRunner({super.key});

  @override
  State<DramaHubAppRunner> createState() => _DramaHubAppRunnerState();
}

class _DramaHubAppRunnerState extends State<DramaHubAppRunner> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performStartupChecks();
    });
  }

  Future<void> _performStartupChecks() async {
    if (RootChecker.isDeviceRooted()) {
      _showRootWarning();
    }
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
    if (config.latestVersion > currentAppVersion) {
      if (config.forceUpdate) {
        _showForceUpdateDialog();
      } else {
        _showOptionalUpdateDialog();
      }
    }
  }

  // ✅ P-4 — AppUrls.telegram instead of hardcoded string
  Future<void> _launchTelegram() async {
    await launchUrl(
      Uri.parse(AppUrls.telegram),
      mode: LaunchMode.externalApplication,
    );
  }

  void _showForceUpdateDialog() {
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
                child: const Icon(
                  Icons.system_update_rounded,
                  color: AppColors.primaryRed,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Update Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A new version of Drama Hub is available. Please update to continue.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _launchTelegram,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text(
                    'Get Update on Telegram',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptionalUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
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
                  color: AppColors.goldAccent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.new_releases_rounded,
                  color: AppColors.goldAccent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Update Available',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A new version of Drama Hub is available with new features and improvements.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Later',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _launchTelegram();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Update',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
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
