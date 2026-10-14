import 'package:flutter/material.dart';

import 'package:drama_hub/features/shorts/models/short_series_model.dart';
import 'package:drama_hub/ui_system/colors.dart';

/// Bottom sheet with an episode grid grouped in ranges of 30.
/// Pops with the selected episode number.
class EpisodePickerSheet extends StatefulWidget {
  const EpisodePickerSheet({
    super.key,
    required this.series,
    required this.currentEpisode,
    required this.maxWatched,
    required this.isLocked,
  });

  final ShortSeries series;
  final int currentEpisode;
  final int maxWatched;
  final bool Function(ShortEpisode) isLocked;

  static Future<int?> show(
    BuildContext context, {
    required ShortSeries series,
    required int currentEpisode,
    required int maxWatched,
    required bool Function(ShortEpisode) isLocked,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.secondaryDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EpisodePickerSheet(
        series: series,
        currentEpisode: currentEpisode,
        maxWatched: maxWatched,
        isLocked: isLocked,
      ),
    );
  }

  @override
  State<EpisodePickerSheet> createState() => _EpisodePickerSheetState();
}

class _EpisodePickerSheetState extends State<EpisodePickerSheet> {
  static const int _rangeSize = 30;
  late int _range;

  List<ShortEpisode> get _episodes => widget.series.episodes;

  @override
  void initState() {
    super.initState();
    final idx = _episodes.indexWhere((e) => e.number == widget.currentEpisode);
    _range = idx < 0 ? 0 : idx ~/ _rangeSize;
  }

  @override
  Widget build(BuildContext context) {
    final rangeCount = (_episodes.length / _rangeSize).ceil();
    final start = _range * _rangeSize;
    final visible = _episodes.sublist(
      start,
      (start + _rangeSize).clamp(0, _episodes.length),
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.series.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${_episodes.length} episodes',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              if (rangeCount > 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: rangeCount,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final from = _episodes[i * _rangeSize].number;
                      final to = _episodes[((i + 1) * _rangeSize - 1).clamp(
                        0,
                        _episodes.length - 1,
                      )].number;
                      final selected = i == _range;
                      return ChoiceChip(
                        label: Text('$from-$to'),
                        selected: selected,
                        onSelected: (_) => setState(() => _range = i),
                        selectedColor: AppColors.primaryRed,
                        backgroundColor: AppColors.cardBackground,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 12,
                        ),
                        side: BorderSide.none,
                        showCheckmark: false,
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (_, i) => _cell(visible[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(ShortEpisode ep) {
    final isCurrent = ep.number == widget.currentEpisode;
    final watched = ep.number <= widget.maxWatched;
    final locked = widget.isLocked(ep);
    return Material(
      color: isCurrent
          ? AppColors.primaryRed
          : AppColors.cardBackground,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).pop(ep.number),
        child: Stack(
          children: [
            Center(
              child: Text(
                '${ep.number}',
                style: TextStyle(
                  color: isCurrent || !watched ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (locked)
              const Positioned(
                top: 3,
                right: 3,
                child: Icon(Icons.lock_rounded, size: 11, color: AppColors.goldAccent),
              ),
          ],
        ),
      ),
    );
  }
}
