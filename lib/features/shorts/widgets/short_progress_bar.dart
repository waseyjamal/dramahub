import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

import 'package:drama_hub/ui_system/colors.dart';

/// Thin reels-style progress bar with drag-to-seek.
///
/// video_player only reports position about twice a second, so the bar
/// interpolates between reports with a [Ticker] for 60/120 fps smooth
/// movement. Only the current page's bar runs its ticker.
class ShortProgressBar extends StatefulWidget {
  const ShortProgressBar({
    super.key,
    required this.controller,
    required this.active,
    required this.onSeek,
  });

  final VideoPlayerController controller;
  final bool active;
  final ValueChanged<Duration> onSeek;

  @override
  State<ShortProgressBar> createState() => _ShortProgressBarState();
}

class _ShortProgressBarState extends State<ShortProgressBar>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<double> _fraction = ValueNotifier(0);

  Duration _basePosition = Duration.zero;
  DateTime _baseTime = DateTime.now();
  double? _dragFraction;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onValue);
    _onValue();
    _updateTicker();
  }

  @override
  void didUpdateWidget(ShortProgressBar old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      old.controller.removeListener(_onValue);
      widget.controller.addListener(_onValue);
      _onValue();
    }
    _updateTicker();
  }

  void _updateTicker() {
    final shouldRun = widget.active && widget.controller.value.isPlaying;
    if (shouldRun && !_ticker.isActive) _ticker.start();
    if (!shouldRun && _ticker.isActive) _ticker.stop();
  }

  void _onValue() {
    final v = widget.controller.value;
    if (v.position != _basePosition) {
      _basePosition = v.position;
      _baseTime = DateTime.now();
    }
    _updateTicker();
    if (!_ticker.isActive) _paint();
  }

  void _onTick(Duration _) => _paint();

  void _paint() {
    if (_dragFraction != null) return;
    final v = widget.controller.value;
    final total = v.duration.inMilliseconds;
    if (total <= 0) {
      _fraction.value = 0;
      return;
    }
    var ms = _basePosition.inMilliseconds;
    if (v.isPlaying && !v.isBuffering) {
      final elapsed = DateTime.now().difference(_baseTime).inMilliseconds;
      ms += (elapsed * v.playbackSpeed).round();
    }
    _fraction.value = (ms / total).clamp(0.0, 1.0);
  }

  void _dragTo(double dx, double width) {
    setState(() => _dragFraction = (dx / width).clamp(0.0, 1.0));
    _fraction.value = _dragFraction!;
  }

  void _endDrag() {
    final f = _dragFraction;
    if (f == null) return;
    final target = widget.controller.value.duration * f;
    _basePosition = target;
    _baseTime = DateTime.now();
    setState(() => _dragFraction = null);
    widget.onSeek(target);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onValue);
    _ticker.dispose();
    _fraction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dragging = _dragFraction != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dragging) _TimeBubble(controller: widget.controller, fraction: _dragFraction!),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) => _dragTo(d.localPosition.dx, width),
              onHorizontalDragUpdate: (d) => _dragTo(d.localPosition.dx, width),
              onHorizontalDragEnd: (_) => _endDrag(),
              onHorizontalDragCancel: _endDrag,
              onTapUp: (d) {
                _dragTo(d.localPosition.dx, width);
                _endDrag();
              },
              child: SizedBox(
                height: 24,
                width: width,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: RepaintBoundary(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _fraction,
                      builder: (_, f, _) => CustomPaint(
                        size: Size(width, dragging ? 6 : 2.5),
                        painter: _BarPainter(f, dragging),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.fraction, this.dragging);
  final double fraction;
  final bool dragging;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, r),
      Paint()..color = Colors.white24,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width * fraction, size.height),
        r,
      ),
      Paint()..color = dragging ? AppColors.primaryRed : Colors.white,
    );
    if (dragging) {
      canvas.drawCircle(
        Offset(size.width * fraction, size.height / 2),
        8,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.fraction != fraction || old.dragging != dragging;
}

class _TimeBubble extends StatelessWidget {
  const _TimeBubble({required this.controller, required this.fraction});
  final VideoPlayerController controller;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final total = controller.value.duration;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        '${formatShortDuration(total * fraction)} / ${formatShortDuration(total)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          shadows: [Shadow(blurRadius: 8)],
        ),
      ),
    );
  }
}

String formatShortDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
