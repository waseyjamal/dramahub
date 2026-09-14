/// Announcement data model — parsed from app_config.json "announcement" block.
/// Every field except [id] and [enabled] is optional.
/// Missing or blank fields are treated as null — the UI hides those elements.
class AnnouncementModel {
  final String id;
  final bool enabled;
  final AnnouncementType type;
  final String? title;
  final String? message;
  final String? imageUrl;
  final String? actionLabel;
  final String? actionDramaId;
  final int? actionEpisodeNumber;
  final bool showOnce;

  const AnnouncementModel({
    required this.id,
    required this.enabled,
    required this.type,
    this.title,
    this.message,
    this.imageUrl,
    this.actionLabel,
    this.actionDramaId,
    this.actionEpisodeNumber,
    required this.showOnce,
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasTitle => title != null && title!.trim().isNotEmpty;
  bool get hasMessage => message != null && message!.trim().isNotEmpty;
  bool get hasAction =>
      actionDramaId != null && actionDramaId!.isNotEmpty ||
      actionLabel != null && actionLabel!.isNotEmpty;
  bool get hasActionLabel => actionLabel != null && actionLabel!.trim().isNotEmpty;
  bool get navigatesToDrama =>
      actionDramaId != null && actionDramaId!.isNotEmpty;

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] as String?)?.trim().toLowerCase() ?? '';
    final type = AnnouncementType.fromString(rawType);

    final rawImage = (json['image_url'] as String?)?.trim();
    final imageUrl =
        (rawImage != null && rawImage.isNotEmpty) ? rawImage : null;

    final rawDramaId = (json['action_drama_id'] as String?)?.trim();
    final actionDramaId =
        (rawDramaId != null && rawDramaId.isNotEmpty) ? rawDramaId : null;

    final rawActionLabel = (json['action_label'] as String?)?.trim();
    final actionLabel =
        (rawActionLabel != null && rawActionLabel.isNotEmpty)
            ? rawActionLabel
            : null;

    final rawTitle = (json['title'] as String?)?.trim();
    final title = (rawTitle != null && rawTitle.isNotEmpty) ? rawTitle : null;

    final rawMessage = (json['message'] as String?)?.trim();
    final message =
        (rawMessage != null && rawMessage.isNotEmpty) ? rawMessage : null;

    return AnnouncementModel(
      id: (json['id'] as String?)?.trim() ?? '',
      enabled: json['enabled'] as bool? ?? false,
      type: type,
      title: title,
      message: message,
      imageUrl: imageUrl,
      actionLabel: actionLabel,
      actionDramaId: actionDramaId,
      actionEpisodeNumber: json['action_episode_number'] as int?,
      showOnce: json['show_once'] as bool? ?? true,
    );
  }
}

enum AnnouncementType {
  general,
  newDrama,
  newEpisode;

  static AnnouncementType fromString(String value) {
    switch (value) {
      case 'new_drama':
        return AnnouncementType.newDrama;
      case 'new_episode':
        return AnnouncementType.newEpisode;
      default:
        return AnnouncementType.general;
    }
  }
}
