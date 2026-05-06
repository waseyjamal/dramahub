import 'package:flutter/scheduler.dart';
import 'package:drama_hub/services/vast_ad_service.dart';
import 'package:get/get.dart';
import 'package:drama_hub/services/data_service.dart';
import 'package:drama_hub/services/ad_service.dart';
import 'package:drama_hub/services/video_service.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/controllers/watchlist_controller.dart';
import 'package:drama_hub/controllers/history_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // DataService — permanent, needed immediately by HomeController
    Get.put(DataService(), permanent: true);

    // ✅ 5.5 — VideoService moved from permanent to lazyPut
    // Was initializing at startup even though only needed on VideoScreen
    Get.lazyPut<VideoService>(() => VideoService(), fenix: true);

    // ✅ 5.6 — AdService delayed to after first frame
    // AdMob SDK warm-up costs 200-400ms — no need to block first paint
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Get.put(AdService(), permanent: true);
      Get.put(VastAdService(), permanent: true);
    });

    // Controllers — all with fenix:true (from fix 4.2)
    Get.lazyPut<HomeController>(() => HomeController(), fenix: true);
    Get.lazyPut<WatchlistController>(() => WatchlistController(), fenix: true);
    Get.lazyPut<HistoryController>(() => HistoryController(), fenix: true);
  }
}
