/// Model for a downloaded episode stored locally
class DownloadedEpisode {
  final String episodeId;
  final String dramaId;
  final String episodeTitle;
  final String dramaTitle;
  final int episodeNumber;
  final String thumbnailUrl;
  final String filePath;
  final int fileSizeBytes;
  final DateTime downloadedAt;
  final bool isComplete;
  final String? playbackPath;

  DownloadedEpisode({
    required this.episodeId,
    required this.dramaId,
    required this.episodeTitle,
    required this.dramaTitle,
    required this.episodeNumber,
    required this.thumbnailUrl,
    required this.filePath,
    required this.fileSizeBytes,
    required this.downloadedAt,
    required this.isComplete,
    this.playbackPath,
  });

  String get displayName => '$dramaTitle • EP $episodeNumber';

  String get sizeText {
    final mb = fileSizeBytes / 1024 / 1024;
    return '${mb.toStringAsFixed(0)} MB';
  }

  bool isAdMature(int maturityMinutes) {
    final elapsed = DateTime.now().difference(downloadedAt);
    return elapsed.inMinutes >= maturityMinutes;
  }

  Map<String, dynamic> toJson() => {
    'episodeId': episodeId,
    'dramaId': dramaId,
    'episodeTitle': episodeTitle,
    'dramaTitle': dramaTitle,
    'episodeNumber': episodeNumber,
    'thumbnailUrl': thumbnailUrl,
    'filePath': filePath,
    'fileSizeBytes': fileSizeBytes,
    'downloadedAt': downloadedAt.toIso8601String(),
    'isComplete': isComplete,
    'playbackPath': playbackPath,
  };

  factory DownloadedEpisode.fromJson(Map<String, dynamic> json) =>
      DownloadedEpisode(
        episodeId: json['episodeId'] ?? '',
        dramaId: json['dramaId'] ?? '',
        episodeTitle: json['episodeTitle'] ?? '',
        dramaTitle: json['dramaTitle'] ?? '',
        episodeNumber: json['episodeNumber'] ?? 0,
        thumbnailUrl: json['thumbnailUrl'] ?? '',
        filePath: json['filePath'] ?? '',
        fileSizeBytes: json['fileSizeBytes'] ?? 0,
        downloadedAt: DateTime.parse(
            json['downloadedAt'] ?? DateTime.now().toIso8601String()),
        isComplete: json['isComplete'] ?? false,
        playbackPath: json['playbackPath'] as String?,
      );
}

/// Active download task state
class ActiveDownload {
  final String episodeId;
  final String episodeTitle;
  final String dramaTitle;
  final int episodeNumber;
  double progress;
  DownloadStatus status;

  // ✅ NEW — MB progress tracking (added, nothing else changed)
  int downloadedBytes;
  int totalBytes;

  ActiveDownload({
    required this.episodeId,
    required this.episodeTitle,
    required this.dramaTitle,
    required this.episodeNumber,
    this.progress = 0.0,
    this.status = DownloadStatus.downloading,
    // ✅ NEW — default 0 so existing code creating ActiveDownload() still compiles
    this.downloadedBytes = 0,
    this.totalBytes = 0,
  });

  // ✅ NEW — helper getter for display "45 MB / 312 MB"
  String get mbProgressText {
    if (totalBytes <= 0) {
      // Total not yet known — show only downloaded
      final dlMb = downloadedBytes / 1024 / 1024;
      return '${dlMb.toStringAsFixed(0)} MB';
    }
    final dlMb = downloadedBytes / 1024 / 1024;
    final totalMb = totalBytes / 1024 / 1024;
    return '${dlMb.toStringAsFixed(0)} MB / ${totalMb.toStringAsFixed(0)} MB';
  }
}

enum DownloadStatus { downloading, paused, failed, complete }