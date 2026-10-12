import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drama_hub/services/ad_config_service.dart';
import 'package:drama_hub/services/ad_service.dart';
import 'package:get/get.dart';
import 'package:drama_hub/services/download_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drama_hub/firebase_options.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:drama_hub/config/app_config_service.dart';
import 'package:drama_hub/services/force_update_service.dart';
import 'package:drama_hub/security/root_checker.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/routes/app_routes.dart';
import 'app.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    await FirebaseAuth.instance
        .signInAnonymously()
        .timeout(const Duration(seconds: 3));
  } catch (e) {
    if (kDebugMode) debugPrint('Anonymous auth failed: $e');
  }

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Register services
  Get.put(DownloadService(), permanent: true);
  Get.put(AdService(), permanent: true);

  // Restore a saved force-update block first — works offline and before the
  // config fetch, so an old build is never usable even for a moment.
  await ForceUpdateService.instance.init();

  await Future.wait([
    AppConfigService.instance.loadConfig().timeout(
      const Duration(seconds: 3),
      onTimeout: () => false,
    ),
    AdConfigService.instance.initialize(),
    // LevelPlay init during splash — ads start loading before first screen
    AdService.instance.initLevelPlayEarly().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        if (kDebugMode) debugPrint('ℹ️ LevelPlay pre-init timed out — continuing');
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
    if (state == AppLifecycleState.resumed) {
      AdConfigService.instance.refresh().then((_) {
        AdService.instance.refreshAdLoad();
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

  static const String _rootWarningDismissedKey = 'root_warning_dismissed';

  Future<void> _performStartupChecks() async {
    if (RootChecker.isDeviceRooted()) await _maybeShowRootWarning();
  }

  Future<void> _maybeShowRootWarning() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_rootWarningDismissedKey) ?? false) return;
    } catch (_) {}
    if (!mounted) return;
    _showRootWarning();
  }

  Future<void> _markRootWarningDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_rootWarningDismissedKey, true);
    } catch (_) {}
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
    ).then((_) => _markRootWarningDismissed());
  }

  @override
  Widget build(BuildContext context) {
    return const DramaHubApp();
  }
}