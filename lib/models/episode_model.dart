class EpisodeModel {
  final String id;
  final String dramaId;
  final int episodeNumber;
  final String title;
  final String description;
  final String videoId;
  final String videoUrl;
  final String watchUrl;
  final String downloadUrl;
  final String thumbnailUrl;
  final String thumbnailImage;
  final int durationMinutes;
  final DateTime releaseDate;
  final bool isPremium;
  final String playerType;
  final String streamUrl;

  // ✅ NEW — direct MP4 URL for streaming and in-app download
  final String mp4Url;

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
    this.mp4Url = '',
  }) : videoUrl = videoId.isNotEmpty
           ? 'https://www.youtube.com/embed/$videoId?autoplay=0&rel=0&modestbranding=1&playsinline=1'
           : '',
       watchUrl = videoId.isNotEmpty
           ? 'https://www.youtube.com/watch?v=$videoId'
           : '',
       thumbnailImage = thumbnailImage ?? thumbnailUrl;

  bool get isUpcoming => DateTime.now().isBefore(releaseDate);
  bool get isReleased => !isUpcoming;
  bool get isCustomPlayer => playerType == 'custom';

  // ✅ True when mp4Url is available — controls download button visibility
  bool get hasDownload => mp4Url.isNotEmpty;

  // ✅ MP4 takes priority over HLS when both exist
  bool get usesMp4 => mp4Url.isNotEmpty;

  bool get isNew {
    final difference = DateTime.now().difference(releaseDate);
    return difference.inHours >= 0 && difference.inHours <= 24;
  }

  factory EpisodeModel.fromJson(Map<String, dynamic> json) {
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
      mp4Url: json['mp4Url'] ?? '',
    );
  }

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
      'mp4Url': mp4Url,
    };
  }
}
