import 'package:get/get.dart';
import 'package:drama_hub/services/data_service.dart';
import 'package:drama_hub/services/ad_service.dart';
import 'package:drama_hub/services/video_service.dart';
import 'package:drama_hub/services/signing_service.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/controllers/watchlist_controller.dart';
import 'package:drama_hub/controllers/history_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // DataService — permanent, needed immediately by HomeController
    Get.put(DataService(), permanent: true);

    // VideoService — lazy, only needed on VideoScreen
    Get.lazyPut<VideoService>(() => VideoService(), fenix: true);

    // SigningService — singleton, handles secure video URL signing
    Get.put(SigningService.instance, permanent: true);

    // Ad services
    Get.put(AdService(), permanent: true);

    // Controllers
    Get.lazyPut<HomeController>(() => HomeController(), fenix: true);
    Get.lazyPut<WatchlistController>(() => WatchlistController(), fenix: true);
    Get.lazyPut<HistoryController>(() => HistoryController(), fenix: true);
  }
}
