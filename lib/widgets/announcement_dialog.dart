import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:drama_hub/models/announcement_model.dart';
import 'package:drama_hub/ui_system/colors.dart';

class AnnouncementDialog extends StatelessWidget {
  final AnnouncementModel announcement;

  /// Called when the user taps the action button.
  /// Dismiss logic is handled inside the dialog; the caller handles navigation.
  final VoidCallback? onAction;

  const AnnouncementDialog({
    super.key,
    required this.announcement,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image banner (hidden if imageUrl is null/empty) ──────────────
            if (announcement.hasImage) _buildImageBanner(),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Type badge ────────────────────────────────────────────
                  _TypeBadge(type: announcement.type),
                  const SizedBox(height: 12),

                  // ── Title (hidden if null/empty) ──────────────────────────
                  if (announcement.hasTitle) ...[
                    Text(
                      announcement.title!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ── Message (hidden if null/empty) ────────────────────────
                  if (announcement.hasMessage) ...[
                    Text(
                      announcement.message!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else
                    const SizedBox(height: 8),

                  // ── Action button (hidden if no action configured) ─────────
                  if (announcement.hasAction) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onAction?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          announcement.hasActionLabel
                              ? announcement.actionLabel!
                              : _defaultActionLabel(announcement.type),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // ── Dismiss ────────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Maybe Later',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageBanner() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: CachedNetworkImage(
          imageUrl: announcement.imageUrl!,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: const Color(0xFF0D0D0D),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white24,
                ),
              ),
            ),
          ),
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  String _defaultActionLabel(AnnouncementType type) {
    switch (type) {
      case AnnouncementType.newDrama:
      case AnnouncementType.newEpisode:
        return 'Watch Now';
      case AnnouncementType.general:
        return 'Learn More';
    }
  }
}

class _TypeBadge extends StatelessWidget {
  final AnnouncementType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (type) {
      AnnouncementType.newDrama => (
          Icons.movie_creation_rounded,
          'New Drama',
          AppColors.primaryRed,
        ),
      AnnouncementType.newEpisode => (
          Icons.fiber_new_rounded,
          'New Episode',
          const Color(0xFF1565C0),
        ),
      AnnouncementType.general => (
          Icons.campaign_rounded,
          'Announcement',
          const Color(0xFF6A1B9A),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
