import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drama_hub/utils/constants.dart';

class HistoryController extends GetxController {
  String get _historyKey => StorageKeys.watchHistory;
  static const int _maxItems = 10;

  static const int _schemaVersion = 1;
  static const String _schemaVersionKey = 'watch_history_schema_version';

  final RxList<Map<String, dynamic>> historyItems =
      <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadHistory();
  }

  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ 8.13 — Schema version check: clear history if schema changed
      // Prevents NullPointerException when old entries lack new required fields
      final savedVersion = prefs.getInt(_schemaVersionKey) ?? 0;
      if (savedVersion < _schemaVersion) {
        debugPrint(
          'History schema migrated v$savedVersion→v$_schemaVersion — clearing',
        );
        await prefs.remove(StorageKeys.watchHistory);
        await prefs.setInt(_schemaVersionKey, _schemaVersion);
        historyItems.clear();
        return;
      }

      final raw = prefs.getString(StorageKeys.watchHistory);
      if (raw != null) {
        final List<dynamic> decoded = jsonDecode(raw);
        historyItems.assignAll(
          decoded.map((e) => Map<String, dynamic>.from(e)).toList(),
        );
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  Future<void> addToHistory({
    required String dramaId,
    required String dramaTitle,
    required String dramaBanner,
    required int episodeNumber,
    required String episodeTitle,
  }) async {
    try {
      final newItem = {
        'dramaId': dramaId,
        'dramaTitle': dramaTitle,
        'dramaBanner': dramaBanner,
        'episodeNumber': episodeNumber,
        'episodeTitle': episodeTitle,
        'watchedAt': DateTime.now().toIso8601String(),
      };

      // Remove duplicate if same episode already exists
      historyItems.removeWhere(
        (item) =>
            item['dramaId'] == dramaId &&
            item['episodeNumber'] == episodeNumber,
      );

      // Add to top
      historyItems.insert(0, newItem);

      // Keep max 10 items
      if (historyItems.length > _maxItems) {
        historyItems.removeRange(_maxItems, historyItems.length);
      }

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_historyKey, jsonEncode(historyItems.toList()));
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }

  Future<void> clearHistory() async {
    try {
      historyItems.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      debugPrint('Error clearing history: $e');
    }
  }
}
