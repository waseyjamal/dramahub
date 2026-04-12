import 'dart:convert';
import 'package:firebase_analytics/firebase_analytics.dart'; // ✅ #13
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drama_hub/models/drama_model.dart';
import 'package:drama_hub/utils/constants.dart'; // ✅ StorageKeys
import 'package:drama_hub/utils/app_snackbar.dart';

class WatchlistController extends GetxController {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance; // ✅ #13

  static const int _maxWatchlist = 20;

  final RxList<DramaModel> watchlist = <DramaModel>[].obs;
  final RxBool hasLoadError = false.obs; // ✅ #3 — error state

  @override
  void onInit() {
    super.onInit();
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    try {
      hasLoadError.value = false;
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(StorageKeys.watchlist) ?? [];
      final dramas = jsonList
          .map((e) => DramaModel.fromJson(jsonDecode(e)))
          .toList();
      watchlist.assignAll(dramas);
    } catch (e) {
      // ✅ #3 — set error state instead of silent fail
      debugPrint('Error loading watchlist: $e');
      hasLoadError.value = true;
    }
  }

  Future<void> _saveWatchlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = watchlist.map((d) => jsonEncode(d.toJson())).toList();
      await prefs.setStringList(StorageKeys.watchlist, jsonList);
    } catch (e) {
      debugPrint('Error saving watchlist: $e');
    }
  }

  bool isInWatchlist(String dramaId) {
    return watchlist.any((d) => d.id == dramaId);
  }

  Future<void> toggleWatchlist(DramaModel drama) async {
    if (isInWatchlist(drama.id)) {
      watchlist.removeWhere((d) => d.id == drama.id);

      // ✅ #13 — analytics on remove
      _analytics.logEvent(
        name: 'watchlist_removed',
        parameters: {'drama_id': drama.id, 'drama_title': drama.title},
      );

      AppSnackbar.info('Removed', '${drama.title} removed from watchlist');
    } else {
      if (watchlist.length >= _maxWatchlist) {
        AppSnackbar.warning(
          'Watchlist Full',
          'Maximum 20 dramas allowed. Remove one to add more.',
        );
        return;
      }
      watchlist.add(drama);

      // ✅ #13 — analytics on add
      _analytics.logEvent(
        name: 'watchlist_added',
        parameters: {'drama_id': drama.id, 'drama_title': drama.title},
      );

      AppSnackbar.success('Added!', '${drama.title} added to watchlist ❤️');
    }
    await _saveWatchlist();
  }
}
