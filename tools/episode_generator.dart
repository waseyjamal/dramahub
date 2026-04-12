import 'dart:io';
import 'dart:convert';
import 'dart:math';

void main() {
  // CONFIGURATION
  // We target the main episodes file as 'arafta_episodes.json' does not exist in the current structure.
  const String filePath = 'assets/data/episodes.json';
  const String targetDramaId = 'arafta';

  final file = File(filePath);

  // 1. Validation: JSON file exists
  if (!file.existsSync()) {
    print('❌ Error: JSON file not found at $filePath');
    exit(1);
  }

  try {
    // 2. Read File
    final String jsonString = file.readAsStringSync();
    final List<dynamic> jsonList = jsonDecode(jsonString);
    final List<Map<String, dynamic>> episodes = List<Map<String, dynamic>>.from(
      jsonList,
    );

    print('\n--- EPISODE GENERATOR (${targetDramaId.toUpperCase()}) ---');
    print('Loaded ${episodes.length} episodes.');

    // 3. Prompt User
    // Episode Number
    stdout.write('Enter Episode Number (int): ');
    final String? numInput = stdin.readLineSync();
    if (numInput == null || int.tryParse(numInput) == null) {
      print('❌ Invalid number.');
      exit(1);
    }
    final int newEpisodeNumber = int.parse(numInput);

    // Check Duplicate
    final bool exists = episodes.any(
      (e) =>
          e['dramaId'] == targetDramaId &&
          e['episodeNumber'] == newEpisodeNumber,
    );
    if (exists) {
      print(
        '❌ Error: Episode $newEpisodeNumber already exists for $targetDramaId.',
      );
      exit(1);
    }

    // Video ID
    stdout.write('Enter Video ID (YouTube ID string): ');
    final String? videoIdInput = stdin.readLineSync();
    if (videoIdInput == null || videoIdInput.trim().isEmpty) {
      print('❌ Invalid Video ID.');
      exit(1);
    }
    final String videoId = videoIdInput.trim();

    // Release Date
    stdout.write('Enter Release Date (YYYY-MM-DDTHH:MM:SS): ');
    final String? dateInput = stdin.readLineSync();
    if (dateInput == null || DateTime.tryParse(dateInput) == null) {
      print('❌ Invalid Date format. Use ISO 8601 (e.g., 2026-02-20T18:30:00).');
      exit(1);
    }
    final DateTime releaseDate = DateTime.parse(dateInput);

    // 4. Auto-generate ID
    // Find max ID for this drama
    int maxIdNum = 0;
    for (var e in episodes) {
      if (e['dramaId'] == targetDramaId) {
        final String id = e['id'] as String;
        // Expected format: arafta_ep_X
        final parts = id.split('_');
        if (parts.length >= 3) {
          final int? num = int.tryParse(parts.last);
          if (num != null) {
            maxIdNum = max(maxIdNum, num);
          }
        }
      }
    }
    final int newIdNum = maxIdNum + 1;
    final String newId = '${targetDramaId}_ep_$newIdNum';

    // 5. Build New Object
    final Map<String, dynamic> newEpisode = {
      "id": newId,
      "dramaId": targetDramaId,
      "episodeNumber": newEpisodeNumber,
      "title": "Episode $newEpisodeNumber",
      "videoUrl": "https://www.youtube.com/embed/$videoId",
      "downloadUrl": "",
      "durationMinutes": 45, // Default
      "releaseDate": releaseDate.toUtc().toIso8601String(), // Ensure UTC format
      "isPremium": false,
    };

    // 6. Append
    episodes.add(newEpisode);

    // 7. Sort
    // Sort by dramaId (to keep grouped) then episodeNumber
    episodes.sort((a, b) {
      final String dramaA = a['dramaId'] ?? '';
      final String dramaB = b['dramaId'] ?? '';
      int cmp = dramaA.compareTo(dramaB);
      if (cmp != 0) return cmp;

      final int epA = a['episodeNumber'] ?? 0;
      final int epB = b['episodeNumber'] ?? 0;
      return epA.compareTo(epB);
    });

    // 8. Save
    final String jsonOutput = const JsonEncoder.withIndent(
      '  ',
    ).convert(episodes);
    file.writeAsStringSync(jsonOutput);

    // 9. Report
    print('\n✅ Episode Added Successfully');
    print('Episode Number: $newEpisodeNumber');
    print('Release Date: ${newEpisode['releaseDate']}');
    print('Video ID: $videoId (Url: ${newEpisode['videoUrl']})');
    print('Generated ID: $newId');
  } catch (e) {
    print('❌ Unexpected Error: $e');
    exit(1);
  }
}
