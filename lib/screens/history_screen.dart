import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drama_hub/controllers/history_controller.dart';
import 'package:drama_hub/controllers/home_controller.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/ui_system/spacing.dart';
import 'package:drama_hub/ui_system/radius.dart';
import 'package:drama_hub/ui_system/shadows.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HistoryController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch History'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          Obx(
            () => controller.historyItems.isNotEmpty
                ? TextButton(
                    onPressed: () => _showClearDialog(context, controller),
                    child: const Text(
                      'Clear All',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.historyItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 80,
                  color: Colors.white12,
                ),
                const SizedBox(height: 24),
                const Text(
                  'No Watch History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Episodes you watch will appear here',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          itemCount: controller.historyItems.length,

          itemBuilder: (context, index) {
            final item = controller.historyItems[index];
            return _HistoryCard(
              item: item,
              onTap: () {
                final homeController = Get.find<HomeController>();
                final drama = homeController.allDramas.firstWhereOrNull(
                  (d) => d.id == item['dramaId'],
                );
                if (drama != null) {
                  homeController.goToEpisodes(drama);
                }
              },
            );
          },
        );
      }),
    );
  }

  void _showClearDialog(BuildContext context, HistoryController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Clear History',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to clear all watch history?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              controller.clearHistory();
              Navigator.pop(context);
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _HistoryCard({required this.item, required this.onTap});

  String _timeAgo(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.large),
          boxShadow: AppShadows.cardShadow,
          border: Border.all(
            color: AppColors.primaryRed.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: CachedNetworkImage(
                imageUrl: item['dramaBanner'] ?? '',
                width: 110,
                height: 75,
                fit: BoxFit.cover,
                memCacheWidth: 200,
                memCacheHeight: 140,
                fadeInDuration: Duration.zero,
                errorWidget: (c, u, e) => Container(
                  width: 110,
                  height: 75,
                  color: AppColors.secondaryDark,
                  child: const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['dramaTitle'] ?? '',
                      style: const TextStyle(
                        color: AppColors.primaryRed,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Episode ${item['episodeNumber']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['episodeTitle'] ?? '',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeAgo(item['watchedAt'] ?? ''),
                      style: TextStyle(
                        color: AppColors.goldAccent,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
