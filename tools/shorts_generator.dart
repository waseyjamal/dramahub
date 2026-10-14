// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// Generates a Shorts series JSON file from URL patterns.
///
/// Usage (from project root):
///   dart run tools/shorts_generator.dart \
///     --id lost_heiress --title "The Lost Heiress" --episodes 80 --free 10 \
///     --genre Romance --description "..." \
///     --poster https://media.example.com/shorts/lost_heiress/poster.jpg \
///     --hls  "https://media.example.com/shorts/lost_heiress/ep{n}/master.m3u8" \
///     --mp4  "https://media.example.com/shorts/lost_heiress/ep{n}.mp4" \
///     --thumb "https://media.example.com/shorts/lost_heiress/ep{n}.jpg" \
///     --out shorts_cdn/shorts/series
///
/// `{n}` is replaced by the episode number. --mp4 and --thumb are optional.
/// Then upload the output file to `$cdnBase/shorts/series/<id>.json`.
void main(List<String> args) {
  final opts = <String, String>{};
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i].startsWith('--')) opts[args[i].substring(2)] = args[++i];
  }

  final id = opts['id'];
  final episodes = int.tryParse(opts['episodes'] ?? '');
  final hls = opts['hls'] ?? '';
  final mp4 = opts['mp4'] ?? '';
  if (id == null || episodes == null || episodes <= 0 || (hls.isEmpty && mp4.isEmpty)) {
    print('❌ Required: --id, --episodes, and at least one of --hls / --mp4');
    exit(1);
  }

  String fill(String pattern, int n) => pattern.replaceAll('{n}', '$n');

  final series = {
    'id': id,
    'title': opts['title'] ?? id,
    'description': opts['description'] ?? '',
    'poster': opts['poster'] ?? '',
    'genre': opts['genre'] ?? '',
    'tags': (opts['tags'] ?? '')
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList(),
    'totalEpisodes': episodes,
    if (opts['free'] != null) 'freeEpisodes': int.parse(opts['free']!),
    'episodes': [
      for (var n = 1; n <= episodes; n++)
        {
          'n': n,
          'title': 'Episode $n',
          if (hls.isNotEmpty) 'hls': fill(hls, n),
          if (mp4.isNotEmpty) 'mp4': fill(mp4, n),
          if (opts['thumb'] != null) 'thumb': fill(opts['thumb']!, n),
          if (opts['duration'] != null) 'durationSec': int.parse(opts['duration']!),
        },
    ],
  };

  final outDir = Directory(opts['out'] ?? 'shorts_cdn/shorts/series')
    ..createSync(recursive: true);
  final file = File('${outDir.path}/$id.json');
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(series));
  print('✅ Wrote ${file.path} ($episodes episodes)');
  print('   Remember: add "$id" to feed.json and bump data_version in config.json.');
}
