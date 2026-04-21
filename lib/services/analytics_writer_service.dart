import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// Writes analytics events to Firestore via REST API
/// Called from EpisodesController when episode is opened
class AnalyticsWriterService {
  static final AnalyticsWriterService instance = AnalyticsWriterService._();
  AnalyticsWriterService._();

  static const String _projectId = 'dramahub-81508';
  static const String _baseUrl =
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

  Future<void> logEpisodeWatch({
    required String dramaId,
    required String dramaTitle,
    required String episodeId,
    required String episodeTitle,
    required int episodeNumber,
  }) async {
    // ✅ Silent fail — never crash the app for analytics
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // Run all 4 writes in parallel — no need to wait for each
      await Future.wait([
        _writeDocument('analytics/views/events', null, {
          'drama_id': _str(dramaId),
          'drama_title': _str(dramaTitle),
          'episode_id': _str(episodeId),
          'episode_title': _str(episodeTitle),
          'episode_number': _int(episodeNumber),
          'timestamp': _timestamp(now),
        }),
        _incrementDocument('analytics/dramas/counts/$dramaId', {
          'title': _str(dramaTitle),
          'last_watched': _timestamp(now),
        }, incrementField: 'views'),
        _incrementDocument(
          'analytics/episodes/counts/${dramaId}_ep$episodeNumber',
          {
            'title': _str(episodeTitle),
            'drama_title': _str(dramaTitle),
            'drama_id': _str(dramaId),
            'episode_number': _int(episodeNumber),
            'last_watched': _timestamp(now),
          },
          incrementField: 'views',
        ),
        _incrementDocument(
          'analytics/summary',
          {},
          incrementField: 'total_views',
        ),
      ]);
    } catch (e) {
      debugPrint('AnalyticsWriter error: $e');
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    try {
      var user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await FirebaseAuth.instance.signInAnonymously();
        user = FirebaseAuth.instance.currentUser;
      }
      final token = await user!.getIdToken();
      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
    } catch (e) {
      return {'Content-Type': 'application/json'};
    }
  }

  /// POST to create a new document (auto-ID)
  Future<void> _writeDocument(
    String collection,
    String? docId,
    Map<String, dynamic> fields,
  ) async {
    final url = docId != null
        ? '$_baseUrl/$collection/$docId'
        : '$_baseUrl/$collection';

    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: jsonEncode({'fields': fields}),
    );

    // ✅ B-1 fix — log failures instead of silently swallowing them
    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint(
        'AnalyticsWriter _writeDocument failed: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// ✅ B-2 fix — uses Firestore commit API with fieldTransforms for real atomic increment
  /// The old _patchDocument was setting views=0 every time, never actually incrementing
  Future<void> _incrementDocument(
    String path,
    Map<String, dynamic> fields, {
    required String incrementField,
  }) async {
    final commitUrl =
        'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents:commit';

    final body = {
      'writes': [
        {
          'update': {
            'name': 'projects/$_projectId/databases/(default)/documents/$path',
            'fields': fields,
          },
          'updateMask': {'fieldPaths': fields.keys.toList()},
        },
        {
          'transform': {
            'document':
                'projects/$_projectId/databases/(default)/documents/$path',
            'fieldTransforms': [
              {
                'fieldPath': incrementField,
                'increment': {'integerValue': '1'}, // ✅ real atomic +1
              },
            ],
          },
        },
      ],
    };

    final response = await http.post(
      Uri.parse(commitUrl),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint(
        'AnalyticsWriter _incrementDocument failed: ${response.statusCode} ${response.body}',
      );
    }
  }

  // Firestore REST API field type helpers
  Map<String, dynamic> _str(String v) => {'stringValue': v};
  Map<String, dynamic> _int(int v) => {'integerValue': '$v'};
  Map<String, dynamic> _timestamp(String iso) => {'timestampValue': iso};
}
