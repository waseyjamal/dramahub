import 'package:get/get.dart';
import 'package:drama_hub/routes/app_routes.dart';
import 'package:drama_hub/screens/home_screen.dart';
import 'package:drama_hub/screens/episodes_screen.dart';
import 'package:drama_hub/screens/video_screen.dart';
import 'package:drama_hub/screens/premium_screen.dart';
import 'package:drama_hub/screens/download_screen.dart';
import 'package:drama_hub/screens/upcoming_screen.dart';
import 'package:drama_hub/screens/about_screen.dart';
import 'package:drama_hub/screens/privacy_policy_screen.dart';
import 'package:drama_hub/controllers/episodes_controller.dart';
import 'package:drama_hub/controllers/video_controller.dart';
import 'package:drama_hub/screens/main_screen.dart';
import 'package:drama_hub/screens/history_screen.dart';
import 'package:drama_hub/screens/profile_screen.dart';
import 'package:drama_hub/screens/onboarding_screen.dart';
import 'package:drama_hub/screens/watchlist_screen.dart';
import 'package:drama_hub/screens/report_problem_screen.dart';
import 'package:drama_hub/screens/suggest_drama_screen.dart';
import 'package:drama_hub/controllers/upcoming_controller.dart';

/// Application pages configuration
///
/// Defines GetX page routes and their associated screens
class AppPages {
  // Prevent instantiation
  AppPages._();

  /// List of all application routes
  static final routes = [
    GetPage(name: AppRoutes.onboarding, page: () => const OnboardingScreen()),

    GetPage(name: AppRoutes.home, page: () => const HomeScreen()),
    GetPage(name: AppRoutes.main, page: () => const MainScreen()),
    GetPage(name: AppRoutes.history, page: () => const HistoryScreen()),
    GetPage(name: AppRoutes.profile, page: () => const ProfileScreen()),
    GetPage(
      name: AppRoutes.episodes,
      page: () => const EpisodesScreen(),
      binding: BindingsBuilder(() {
        // ✅ 4.2 — Added fenix: true
        Get.lazyPut<EpisodesController>(
          () => EpisodesController(),
          fenix: true,
        );
      }),
    ),
    GetPage(
      name: AppRoutes.video,
      page: () => const VideoScreen(),
      binding: BindingsBuilder(() {
        // ✅ 4.2 — Added fenix: true
        Get.lazyPut<VideoController>(() => VideoController(), fenix: true);
      }),
    ),
    GetPage(name: AppRoutes.watchlist, page: () => const WatchlistScreen()),
    GetPage(name: AppRoutes.premium, page: () => const PremiumScreen()),
    GetPage(name: AppRoutes.download, page: () => const DownloadScreen()),
    GetPage(
      name: AppRoutes.upcoming,
      page: () => const UpcomingScreen(),
      binding: BindingsBuilder(() {
        // ✅ 8.16 — UpcomingController registered for route
        // Previously missing — Get.find<UpcomingController>() in screen would throw
        Get.lazyPut<UpcomingController>(
          () => UpcomingController(),
          fenix: true,
        );
      }),
    ),
    GetPage(name: AppRoutes.about, page: () => const AboutScreen()),
    GetPage(
      name: AppRoutes.privacyPolicy,
      page: () => const PrivacyPolicyScreen(),
    ),

    GetPage(
      name: AppRoutes.reportProblem,
      page: () => const ReportProblemScreen(),
    ),
    GetPage(
      name: AppRoutes.suggestDrama,
      page: () => const SuggestDramaScreen(),
    ),
  ];
}
