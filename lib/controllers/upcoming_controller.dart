import 'dart:async';
import 'package:get/get.dart';
import 'package:drama_hub/models/episode_model.dart';
import 'package:drama_hub/routes/app_routes.dart';

/// Controller for Upcoming Episode screen
///
/// Manages countdown timer and auto-navigation when release time is reached
class UpcomingController extends GetxController {
  // Episode passed from previous screen
  late EpisodeModel episode;

  // Countdown values
  final RxInt days = 0.obs;
  final RxInt hours = 0.obs;
  final RxInt minutes = 0.obs;
  final RxInt seconds = 0.obs;

  // Timer instance
  Timer? _countdownTimer;

  @override
  void onInit() {
    super.onInit();

    // ✅ 3.3 — Safe cast with null check (was hard cast — crashed if arguments null)
    final args = Get.arguments;
    if (args == null || args is! EpisodeModel) {
      Future.microtask(() => Get.back());
      return;
    }
    episode = args;

    _startCountdown();
  }

  /// Starts the countdown timer
  void _startCountdown() {
    // ✅ 3.7 — Check if release date already passed BEFORE starting timer
    // Previously: timer would start, immediately hit zero, and navigate
    // Now: handle past dates gracefully
    final now = DateTime.now();
    final difference = episode.releaseDate.difference(now);

    if (difference.isNegative || difference.inSeconds <= 0) {
      // Release date already passed — navigate immediately to video
      // Use microtask to avoid navigating during GetX controller init
      Future.microtask(() => Get.offNamed(AppRoutes.video, arguments: episode));
      return;
    }

    // Date is in the future — safe to start countdown
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdown();
    });
  }

  /// Updates countdown values and checks if release time is reached
  void _updateCountdown() {
    final now = DateTime.now();
    final difference = episode.releaseDate.difference(now);

    if (difference.isNegative || difference.inSeconds <= 0) {
      _countdownTimer?.cancel();
      Get.offNamed(AppRoutes.video, arguments: episode);
      return;
    }

    days.value = difference.inDays;
    hours.value = difference.inHours % 24;
    minutes.value = difference.inMinutes % 60;
    seconds.value = difference.inSeconds % 60;
  }

  @override
  void onClose() {
    _countdownTimer?.cancel();
    super.onClose();
  }
}
