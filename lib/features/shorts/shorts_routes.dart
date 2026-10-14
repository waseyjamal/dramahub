import 'package:get/get.dart';

import 'package:drama_hub/features/shorts/screens/shorts_my_list_screen.dart';
import 'package:drama_hub/features/shorts/screens/shorts_series_screen.dart';

class ShortsRoutes {
  ShortsRoutes._();

  static const series = '/shorts/series';
  static const myList = '/shorts/my-list';

  static final pages = [
    GetPage(
      name: series,
      page: () => const ShortsSeriesScreen(),
      transition: Transition.downToUp,
    ),
    GetPage(name: myList, page: () => const ShortsMyListScreen()),
  ];

  static Future<void> openSeries(String seriesId, {int episode = 1}) async {
    await Get.toNamed(
      series,
      arguments: ShortsSeriesArgs(seriesId: seriesId, episode: episode),
    );
  }
}
