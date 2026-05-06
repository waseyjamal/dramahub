/// Model class for Episode
class EpisodeModel {
  final String id;
  final String dramaId;
  final int episodeNumber;
  final String title;
  final String description;

  /// Raw YouTube video ID (e.g. iu7akrHmEsk)
  final String videoId;

  /// Embed URL built internally from videoId — used by WebView player
  final String videoUrl;

  /// Watch URL built internally from videoId — used for Snaptube download
  final String watchUrl;

  final String downloadUrl;
  final String thumbnailUrl;
  final String thumbnailImage;
  final int durationMinutes;
  final DateTime releaseDate;
  final bool isPremium;

  /// Player type: 'youtube' or 'custom' — defaults to 'youtube' if missing
  final String playerType;

  /// HLS stream URL for custom player (e.g. from B2/Cloudflare)
  final String streamUrl;

  EpisodeModel({
    required this.id,
    required this.dramaId,
    required this.episodeNumber,
    required this.title,
    required this.description,
    required this.videoId,
    required this.downloadUrl,
    required this.thumbnailUrl,
    String? thumbnailImage,
    required this.durationMinutes,
    required this.releaseDate,
    this.isPremium = false,
    this.playerType = 'youtube',
    this.streamUrl = '',
  }) : videoUrl = videoId.isNotEmpty
           ? 'https://www.youtube.com/embed/$videoId?autoplay=0&rel=0&modestbranding=1&playsinline=1'
           : '',
       watchUrl = videoId.isNotEmpty
           ? 'https://www.youtube.com/watch?v=$videoId'
           : '',
       thumbnailImage = thumbnailImage ?? thumbnailUrl;

  /// Computed getter: Episode is upcoming if release date is in the future
  bool get isUpcoming => DateTime.now().isBefore(releaseDate);

  /// Computed getter: Episode is released if not upcoming
  bool get isReleased => !isUpcoming;

  /// True if this episode uses the custom HLS player
  bool get isCustomPlayer => playerType == 'custom';

  /// Computed getter: Episode is new if released within last 24 hours
  bool get isNew {
    final difference = DateTime.now().difference(releaseDate);
    return difference.inHours >= 0 && difference.inHours <= 24;
  }

  /// Convert from JSON
  factory EpisodeModel.fromJson(Map<String, dynamic> json) {
    // ✅ D-1 — DateTime.parse wrapped in try-catch
    // Previously: one malformed date string crashed entire episode list parse
    DateTime parsedReleaseDate;
    try {
      parsedReleaseDate = json['releaseDate'] != null
          ? DateTime.parse(json['releaseDate']).toLocal()
          : DateTime.now().subtract(const Duration(days: 1));
    } catch (_) {
      parsedReleaseDate = DateTime.now().subtract(const Duration(days: 1));
    }

    return EpisodeModel(
      id: json['id'] ?? '',
      dramaId: json['dramaId'] ?? '',
      episodeNumber: json['episodeNumber'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      videoId: json['videoId'] ?? '',
      downloadUrl: json['downloadUrl'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      thumbnailImage: json['thumbnailImage'],
      durationMinutes: json['durationMinutes'] ?? 0,
      releaseDate: parsedReleaseDate,
      isPremium: json['isPremium'] ?? false,
      playerType: json['playerType'] ?? 'youtube',
      streamUrl: json['streamUrl'] ?? '',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dramaId': dramaId,
      'episodeNumber': episodeNumber,
      'title': title,
      'description': description,
      'videoId': videoId,
      'downloadUrl': downloadUrl,
      'thumbnailUrl': thumbnailUrl,
      'thumbnailImage': thumbnailImage,
      'durationMinutes': durationMinutes,
      'releaseDate': releaseDate.toIso8601String(),
      'isPremium': isPremium,
      'playerType': playerType,
      'streamUrl': streamUrl,
    };
  }
}
