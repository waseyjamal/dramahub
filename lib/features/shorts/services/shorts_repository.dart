import 'package:get/get.dart';

import 'package:drama_hub/features/shorts/models/short_series_model.dart';
import 'package:drama_hub/features/shorts/models/shorts_config_model.dart';
import 'package:drama_hub/features/shorts/services/shorts_data_service.dart';
import 'package:drama_hub/features/shorts/services/shorts_local_store.dart';
import 'package:drama_hub/utils/constants.dart';

/// Single entry point for the Shorts feature state.
///
/// [init] is safe to call many times; only the first call does work.
class ShortsRepository {
  ShortsRepository._();
  static final ShortsRepository instance = ShortsRepository._();

  final ShortsDataService _data = ShortsDataService();
  final Rx<ShortsConfig> config = ShortsConfig.disabled.obs;

  /// True when the admin enabled the feature and this build is new enough.
  final RxBool enabled = false.obs;

  // In-memory copy so re-opening a series is instant; the data service
  // handles the on-disk cache and its expiry.
  final Map<String, (ShortSeries, DateTime)> _seriesCache = {};
  static const Duration _memoryTtl = Duration(minutes: 5);
  Future<void>? _init;

  Future<void> init() => _init ??= _doInit();

  Future<void> _doInit() async {
    await ShortsLocalStore.instance.ensureLoaded();
    _apply(await _data.cachedConfig());
    await refreshConfig();
  }

  Future<void> refreshConfig() async {
    final remote = await _data.fetchConfig();
    if (remote != null) _apply(remote);
  }

  void _apply(ShortsConfig c) {
    config.value = c;
    enabled.value = c.enabled && Constants.currentBuildVersion >= c.minBuild;
  }

  Future<List<ShortFeedEntry>> loadFeed({bool forceRefresh = false}) async {
    if (forceRefresh) await refreshConfig();
    return _data.loadFeed(forceRefresh: forceRefresh);
  }

  Future<ShortSeries> loadSeries(
    String seriesId, {
    bool forceRefresh = false,
  }) async {
    final cached = _seriesCache[seriesId];
    if (cached != null &&
        !forceRefresh &&
        DateTime.now().difference(cached.$2) < _memoryTtl) {
      return cached.$1;
    }
    final series = await _data.loadSeries(
      seriesId,
      forceRefresh: forceRefresh,
    );
    _seriesCache[seriesId] = (series, DateTime.now());
    return series;
  }
}
