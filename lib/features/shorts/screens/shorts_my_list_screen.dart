import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:drama_hub/features/shorts/services/shorts_local_store.dart';
import 'package:drama_hub/features/shorts/shorts_routes.dart';
import 'package:drama_hub/ui_system/colors.dart';

/// Series the user saved from Shorts (stored on device only).
class ShortsMyListScreen extends StatelessWidget {
  const ShortsMyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ShortsLocalStore.instance;
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(title: const Text('My List'), centerTitle: true),
      body: Obx(() {
        final saved = store.saved.toList();
        if (saved.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Tap ♥ or double-tap a video to save a series here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.56,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
          ),
          itemCount: saved.length,
          itemBuilder: (_, i) {
            final s = saved[i];
            final watched = store.maxWatched(s.id);
            return GestureDetector(
              onTap: () => ShortsRoutes.openSeries(
                s.id,
                episode: watched > 0 ? watched : 1,
              ),
              onLongPress: () => store.toggleSaved(s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          s.posterUrl.isEmpty
                              ? const ColoredBox(color: AppColors.cardBackground)
                              : CachedNetworkImage(
                                  imageUrl: s.posterUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => const ColoredBox(
                                    color: AppColors.cardBackground,
                                  ),
                                ),
                          if (watched > 0)
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  s.totalEpisodes > 0
                                      ? 'EP $watched/${s.totalEpisodes}'
                                      : 'EP $watched',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}
