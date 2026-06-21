import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

/// Fully custom, YouTube-style video player overlay.
///
/// This widget does NOT manage the [VideoPlayerController] lifecycle.
/// The parent screen creates, initializes, and disposes the controller.
/// This widget only renders UI and gestures on top of it.
class CustomVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;
  final VoidCallback? onBack;

  /// Called whenever fullscreen is entered/exited, with the new value.
  final ValueChanged<bool>? onFullscreenChanged;

  /// Called once when playback reaches the end.
  final VoidCallback? onPlaybackEnded;

  /// Optional widget shown when [controller] reports an error.
  /// If null, a default error UI with retry is shown.
  final Widget? errorWidget;

  /// Optional retry callback for the default error UI.
  final VoidCallback? onRetry;

  const CustomVideoPlayer({
    super.key,
    required this.controller,
    required this.title,
    this.onBack,
    this.onFullscreenChanged,
    this.onPlaybackEnded,
    this.errorWidget,
    this.onRetry,
  });

  @override
  State<CustomVideoPlayer> createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer>
    with TickerProviderStateMixin {
  // ── Controls visibility ──
  bool _showControls = true;
  Timer? _hideTimer;

  // ── Playback state mirrors ──
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _hasEnded = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffered = Duration.zero;
  double _playbackSpeed = 1.0;

  Timer? _progressTimer;
  bool _endedFired = false;

  // ── Seek animation ──
  late AnimationController _leftSeekController;
  late AnimationController _rightSeekController;
  late Animation<double> _leftSeekScale;
  late Animation<double> _rightSeekScale;
  late Animation<double> _leftSeekOpacity;
  late Animation<double> _rightSeekOpacity;
  int _leftSeekAccum = 0;
  int _rightSeekAccum = 0;
  Timer? _leftSeekHideTimer;
  Timer? _rightSeekHideTimer;

  // ── Progress bar dragging ──
  bool _isDraggingProgress = false;
  double _dragProgressValue = 0.0; // 0..1

  // ── Fullscreen ──
  bool _isFullscreen = false;

  // ── Volume / brightness swipe ──
  bool _isAdjustingBrightness = false;
  bool _isAdjustingVolume = false;
  double _brightnessValue = 0.5; // 0..1
  double _volumeValue = 0.5; // 0..1
  double? _dragStartY;
  double _dragStartBrightness = 0.5;
  double _dragStartVolume = 0.5;
  Timer? _brightnessIndicatorTimer;
  Timer? _volumeIndicatorTimer;
  StreamSubscription<double>? _volumeButtonSubscription;

  static const List<double> _speedOptions = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  @override
  void initState() {
    super.initState();

    _leftSeekController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _rightSeekController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _leftSeekScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.5,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 20),
    ]).animate(_leftSeekController);

    _rightSeekScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.5,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 20),
    ]).animate(_rightSeekController);

    _leftSeekOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_leftSeekController);

    _rightSeekOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_rightSeekController);

    _leftSeekController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _leftSeekAccum = 0;
      }
    });
    _rightSeekController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _rightSeekAccum = 0;
      }
    });

    _initFromController();
    widget.controller.addListener(_onControllerUpdate);
    _startProgressTimer();
    _initBrightnessAndVolume();
    _startHideTimer();
  }

  void _initFromController() {
    final value = widget.controller.value;
    _isPlaying = value.isPlaying;
    _isBuffering = value.isBuffering;
    _duration = value.duration;
    _position = value.position;
    _playbackSpeed = value.playbackSpeed == 0 ? 1.0 : value.playbackSpeed;
    if (value.buffered.isNotEmpty) {
      _buffered = value.buffered.last.end;
    }
  }

  Future<void> _initBrightnessAndVolume() async {
    try {
      final b = await ScreenBrightness().application;
      if (mounted) setState(() => _brightnessValue = b.clamp(0.0, 1.0));
    } catch (_) {}
    try {
      // Suppress system volume bar while player is active
      VolumeController.instance.showSystemUI = false;
      final v = await VolumeController.instance.getVolume();
      if (mounted) {
        setState(() => _volumeValue = v.clamp(0.0, 1.0));
      }
    } catch (_) {}

    // Listen for volume changes from physical buttons
    // fetchInitialVolume: false — already read above, no double-trigger
    _volumeButtonSubscription = VolumeController.instance.addListener(
      (newVolume) {
        if (!mounted) return;
        setState(() {
          _volumeValue = newVolume.clamp(0.0, 1.0);
          _isAdjustingVolume = true;
        });
        _volumeIndicatorTimer?.cancel();
        _volumeIndicatorTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _isAdjustingVolume = false);
        });
      },
      fetchInitialVolume: false,
    );
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final value = widget.controller.value;

    final isBuffering = value.isBuffering;
    final isPlaying = value.isPlaying;
    final duration = value.duration;
    Duration buffered = _buffered;
    if (value.buffered.isNotEmpty) {
      buffered = value.buffered.last.end;
    }

    if (value.hasError) {
      setState(() {
        _isBuffering = false;
      });
      return;
    }

    // Detect end of playback
    if (duration.inMilliseconds > 0 &&
        value.position >= duration &&
        !_endedFired) {
      _endedFired = true;
      setState(() {
        _hasEnded = true;
        _isPlaying = false;
        _showControls = true;
      });
      _hideTimer?.cancel();
      widget.onPlaybackEnded?.call();
      return;
    }

    if (isBuffering != _isBuffering ||
        isPlaying != _isPlaying ||
        duration != _duration ||
        buffered != _buffered) {
      setState(() {
        _isBuffering = isBuffering;
        _isPlaying = isPlaying;
        _duration = duration;
        _buffered = buffered;
        if (isPlaying && _hasEnded) {
          _hasEnded = false;
          _endedFired = false;
        }
      });
    }
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (_isDraggingProgress) return;
      final pos = widget.controller.value.position;
      if (pos != _position) {
        setState(() => _position = pos);
      }
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (!_isPlaying || _hasEnded) return; // don't auto-hide when paused/ended
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_isDraggingProgress) return;
      setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _togglePlayPause() {
    if (_hasEnded) {
      widget.controller.seekTo(Duration.zero);
      widget.controller.play();
      setState(() {
        _hasEnded = false;
        _endedFired = false;
        _isPlaying = true;
        _showControls = true;
      });
      _startHideTimer();
      return;
    }

    if (_isPlaying) {
      widget.controller.pause();
      setState(() {
        _isPlaying = false;
        _showControls = true;
      });
      _hideTimer?.cancel();
    } else {
      widget.controller.play();
      setState(() {
        _isPlaying = true;
      });
      _startHideTimer();
    }
  }

  void _seekRelative(int seconds) {
    final newPos = _position + Duration(seconds: seconds);
    Duration target = newPos;
    if (target < Duration.zero) target = Duration.zero;
    if (_duration > Duration.zero && target > _duration) target = _duration;
    widget.controller.seekTo(target);
    setState(() => _position = target);
  }

  void _onDoubleTapLeft() {
    HapticFeedback.lightImpact();
    _seekRelative(-10);
    _leftSeekAccum += 10;
    _rightSeekHideTimer?.cancel();
    setState(() {});
    if (_leftSeekController.status == AnimationStatus.forward) {
      // Already animating — just restart to extend.
      _leftSeekController.forward(from: 0.15);
    } else {
      _leftSeekController.forward(from: 0);
    }
  }

  void _onDoubleTapRight() {
    HapticFeedback.lightImpact();
    _seekRelative(10);
    _rightSeekAccum += 10;
    setState(() {});
    if (_rightSeekController.status == AnimationStatus.forward) {
      _rightSeekController.forward(from: 0.15);
    } else {
      _rightSeekController.forward(from: 0);
    }
  }

  void _onDoubleTapCenter() {
    HapticFeedback.lightImpact();
    _togglePlayPause();
  }

  // ── Progress bar ──
  double get _progressFraction {
    if (_duration.inMilliseconds <= 0) return 0.0;
    if (_isDraggingProgress) return _dragProgressValue;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  double get _bufferedFraction {
    if (_duration.inMilliseconds <= 0) return 0.0;
    return (_buffered.inMilliseconds / _duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  void _onProgressDragStart() {
    _isDraggingProgress = true;
    _hideTimer?.cancel();
    setState(() {
      _dragProgressValue = _progressFraction;
      _showControls = true;
    });
  }

  void _onProgressDragUpdate(double fraction) {
    setState(() {
      _dragProgressValue = fraction.clamp(0.0, 1.0);
    });
  }

  void _onProgressDragEnd() {
    if (_duration.inMilliseconds > 0) {
      final target = Duration(
        milliseconds: (_dragProgressValue * _duration.inMilliseconds).round(),
      );
      widget.controller.seekTo(target);
      setState(() {
        _position = target;
        _isDraggingProgress = false;
        if (_isPlaying) {
          _endedFired = false;
          _hasEnded = false;
        }
      });
    } else {
      setState(() => _isDraggingProgress = false);
    }
    _startHideTimer();
  }

  // ── Time formatting ──
  String _formatDuration(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ── Speed sheet ──
  Future<void> _showSpeedSheet() async {
    _hideTimer?.cancel();
    final selected = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Playback speed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              for (final speed in _speedOptions)
                ListTile(
                  title: Text(
                    speed == 1.0 ? 'Normal' : '${speed}x',
                    style: TextStyle(
                      color: speed == _playbackSpeed
                          ? const Color(0xFFFF0000)
                          : Colors.white,
                      fontWeight: speed == _playbackSpeed
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: speed == _playbackSpeed
                      ? const Icon(Icons.check, color: Color(0xFFFF0000))
                      : null,
                  onTap: () => Navigator.of(context).pop(speed),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != _playbackSpeed) {
      await widget.controller.setPlaybackSpeed(selected);
      setState(() => _playbackSpeed = selected);
    }
    if (_isPlaying) _startHideTimer();
  }

  // ── Fullscreen ──
  Future<void> _toggleFullscreen() async {
    if (_isFullscreen) return;
    setState(() => _isFullscreen = true);
    widget.onFullscreenChanged?.call(true);

    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _FullscreenPlayerRoute(
          controller: widget.controller,
          title: widget.title,
        ),
        transitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (__, animation, ___, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );

    // Returned from fullscreen
    setState(() => _isFullscreen = false);
    widget.onFullscreenChanged?.call(false);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // ── Brightness / Volume swipe ──
  void _onVerticalDragStart(DragStartDetails details, double screenWidth) {
    _dragStartY = details.globalPosition.dy;
    _dragStartBrightness = _brightnessValue;
    _dragStartVolume = _volumeValue;

    final isLeftSide = details.globalPosition.dx < screenWidth / 2;
    if (isLeftSide) {
      _isAdjustingBrightness = true;
    } else {
      _isAdjustingVolume = true;
    }
    setState(() {});
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, double screenHeight) {
    if (_dragStartY == null) return;
    final delta = _dragStartY! - details.globalPosition.dy;
    // Full screen height drag = full 0..1 range
    final changeFraction = delta / screenHeight;

    if (_isAdjustingBrightness) {
      final newValue = (_dragStartBrightness + changeFraction).clamp(0.0, 1.0);
      setState(() => _brightnessValue = newValue);
      ScreenBrightness().setApplicationScreenBrightness(newValue).catchError((_) {});
      _brightnessIndicatorTimer?.cancel();
    } else if (_isAdjustingVolume) {
      final newValue = (_dragStartVolume + changeFraction).clamp(0.0, 1.0);
      setState(() => _volumeValue = newValue);
      VolumeController.instance.setVolume(newValue);
      _volumeIndicatorTimer?.cancel();
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _dragStartY = null;
    if (_isAdjustingBrightness) {
      _brightnessIndicatorTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _isAdjustingBrightness = false);
      });
    }
    if (_isAdjustingVolume) {
      _volumeIndicatorTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _isAdjustingVolume = false);
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _leftSeekHideTimer?.cancel();
    _rightSeekHideTimer?.cancel();
    _brightnessIndicatorTimer?.cancel();
    _volumeIndicatorTimer?.cancel();
    _leftSeekController.dispose();
    _rightSeekController.dispose();
    widget.controller.removeListener(_onControllerUpdate);
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _volumeButtonSubscription?.cancel();
    VolumeController.instance.showSystemUI = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;

    if (value.hasError) {
      return widget.errorWidget ?? _buildDefaultError();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          onVerticalDragStart: (d) => _onVerticalDragStart(d, width),
          onVerticalDragUpdate: (d) => _onVerticalDragUpdate(d, height),
          onVerticalDragEnd: _onVerticalDragEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video
              Center(
                child: AspectRatio(
                  aspectRatio: value.aspectRatio == 0
                      ? 16 / 9
                      : value.aspectRatio,
                  child: VideoPlayer(widget.controller),
                ),
              ),

              // Double-tap zones (left / center / right)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleControls,
                      onDoubleTap: _onDoubleTapLeft,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleControls,
                      onDoubleTap: _onDoubleTapCenter,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleControls,
                      onDoubleTap: _onDoubleTapRight,
                    ),
                  ),
                ],
              ),

              // Seek animations
              _buildSeekOverlay(
                alignment: Alignment.centerLeft,
                scale: _leftSeekScale,
                opacity: _leftSeekOpacity,
                icon: Icons.replay_10_rounded,
                seconds: _leftSeekAccum,
              ),
              _buildSeekOverlay(
                alignment: Alignment.centerRight,
                scale: _rightSeekScale,
                opacity: _rightSeekOpacity,
                icon: Icons.forward_10_rounded,
                seconds: _rightSeekAccum,
              ),

              // Buffering indicator
              if (_isBuffering && !_hasEnded)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF0000)),
                ),

              // Brightness indicator
              if (_isAdjustingBrightness)
                _buildSideIndicator(
                  alignment: Alignment.centerLeft,
                  icon: _brightnessValue > 0.5
                      ? Icons.brightness_high_rounded
                      : Icons.brightness_low_rounded,
                  value: _brightnessValue,
                ),

              // Volume indicator
              if (_isAdjustingVolume)
                _buildSideIndicator(
                  alignment: Alignment.centerRight,
                  icon: _volumeValue == 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  value: _volumeValue,
                ),

              // Controls overlay
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: _buildControlsOverlay(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDefaultError() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Something went wrong',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            if (widget.onRetry != null)
              ElevatedButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekOverlay({
    required Alignment alignment,
    required Animation<double> scale,
    required Animation<double> opacity,
    required IconData icon,
    required int seconds,
  }) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: FadeTransition(
          opacity: opacity,
          child: ScaleTransition(
            scale: scale,
            child: Icon(icon, color: Colors.white, size: 40),
          ),
        ),
      ),
    );
  }

  Widget _buildSideIndicator({
    required Alignment alignment,
    required IconData icon,
    required double value,
  }) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              width: 4,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  FractionallySizedBox(
                    heightFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(value * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Stack(
      children: [
        // Top gradient + bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  if (widget.onBack != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: widget.onBack,
                    ),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Center play / replay button
        if (!_isPlaying)
          Center(
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _hasEnded ? Icons.replay_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),

        // Bottom gradient + bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 24, 8, 4),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildProgressBar(),
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      Text(
                        '${_formatDuration(_isDraggingProgress ? Duration(milliseconds: (_dragProgressValue * _duration.inMilliseconds).round()) : _position)} / ${_formatDuration(_duration)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _showSpeedSheet,
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          _playbackSpeed == 1.0 ? '1x' : '${_playbackSpeed}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _hasEnded
                              ? Icons.replay_rounded
                              : (_isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded),
                          color: Colors.white,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                      IconButton(
                        icon: Icon(
                          _isFullscreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          color: Colors.white,
                        ),
                        onPressed: _toggleFullscreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        void handleTapOrDrag(double dx) {
          final fraction = (dx / width).clamp(0.0, 1.0);
          _onProgressDragUpdate(fraction);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            _onProgressDragStart();
            handleTapOrDrag(details.localPosition.dx);
            _onProgressDragEnd();
          },
          onHorizontalDragStart: (details) {
            _onProgressDragStart();
            handleTapOrDrag(details.localPosition.dx);
          },
          onHorizontalDragUpdate: (details) {
            handleTapOrDrag(details.localPosition.dx);
          },
          onHorizontalDragEnd: (_) => _onProgressDragEnd(),
          child: SizedBox(
            height: 24,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Background track
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Buffered track
                FractionallySizedBox(
                  widthFactor: _bufferedFraction,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Played track
                FractionallySizedBox(
                  widthFactor: _progressFraction,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Thumb
                Align(
                  alignment: Alignment((_progressFraction * 2) - 1, 0),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF0000),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Drag tooltip
                if (_isDraggingProgress)
                  Align(
                    alignment: Alignment((_progressFraction * 2) - 1, 0),
                    child: FractionalTranslation(
                      translation: const Offset(0, -1.8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(
                            Duration(
                              milliseconds:
                                  (_dragProgressValue *
                                          _duration.inMilliseconds)
                                      .round(),
                            ),
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Dedicated fullscreen route — owns orientation/UI chrome only.
/// The [VideoPlayerController] is passed in from the parent and is
/// NOT disposed here — the parent screen owns its lifecycle.
class _FullscreenPlayerRoute extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;

  const _FullscreenPlayerRoute({
    required this.controller,
    required this.title,
  });

  @override
  State<_FullscreenPlayerRoute> createState() => _FullscreenPlayerRouteState();
}

class _FullscreenPlayerRouteState extends State<_FullscreenPlayerRoute> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Orientation restored by _toggleFullscreen() after Navigator.pop
    // so we don't restore here — avoids flicker during the pop animation.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: _FullscreenControls(
          controller: widget.controller,
          title: widget.title,
          onExitFullscreen: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

/// Renders the video + full custom controls in fullscreen mode.
/// Stateful so it can manage its own controls-visibility timer
/// independently from the portrait player instance.
class _FullscreenControls extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;
  final VoidCallback onExitFullscreen;

  const _FullscreenControls({
    required this.controller,
    required this.title,
    required this.onExitFullscreen,
  });

  @override
  State<_FullscreenControls> createState() => _FullscreenControlsState();
}

class _FullscreenControlsState extends State<_FullscreenControls>
    with TickerProviderStateMixin {
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _hasEnded = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffered = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _isDraggingProgress = false;
  double _dragProgressValue = 0.0;
  bool _endedFired = false;

  // Seek animations
  late AnimationController _leftSeekController;
  late AnimationController _rightSeekController;
  late Animation<double> _leftSeekScale;
  late Animation<double> _rightSeekScale;
  late Animation<double> _leftSeekOpacity;
  late Animation<double> _rightSeekOpacity;
  int _leftSeekAccum = 0;
  int _rightSeekAccum = 0;

  Timer? _progressTimer;

  bool _isAdjustingBrightness = false;
  bool _isAdjustingVolume = false;
  double _brightnessValue = 0.5;
  double _volumeValue = 0.5;
  double? _dragStartY;
  double _dragStartBrightness = 0.5;
  double _dragStartVolume = 0.5;
  Timer? _brightnessIndicatorTimer;
  Timer? _volumeIndicatorTimer;
  StreamSubscription<double>? _volumeButtonSubscription;

  static const List<double> _speedOptions = [
    0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0,
  ];

  @override
  void initState() {
    super.initState();
    _initSeekAnimations();
    _syncFromController();
    widget.controller.addListener(_onControllerUpdate);
    _startProgressTimer();
    _startHideTimer();
    _initBrightnessAndVolume();
  }

  void _initSeekAnimations() {
    _leftSeekController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _rightSeekController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _leftSeekScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 20),
    ]).animate(_leftSeekController);
    _rightSeekScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 20),
    ]).animate(_rightSeekController);
    _leftSeekOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_leftSeekController);
    _rightSeekOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_rightSeekController);
  }

  void _syncFromController() {
    final value = widget.controller.value;
    _isPlaying = value.isPlaying;
    _isBuffering = value.isBuffering;
    _duration = value.duration;
    _position = value.position;
    _playbackSpeed =
        value.playbackSpeed == 0 ? 1.0 : value.playbackSpeed;
    if (value.buffered.isNotEmpty) {
      _buffered = value.buffered.last.end;
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final value = widget.controller.value;
    Duration buffered = _buffered;
    if (value.buffered.isNotEmpty) {
      buffered = value.buffered.last.end;
    }
    if (value.duration.inMilliseconds > 0 &&
        value.position >= value.duration &&
        !_endedFired) {
      _endedFired = true;
      setState(() {
        _hasEnded = true;
        _isPlaying = false;
        _showControls = true;
      });
      _hideTimer?.cancel();
      return;
    }
    setState(() {
      _isBuffering = value.isBuffering;
      _isPlaying = value.isPlaying;
      _duration = value.duration;
      _buffered = buffered;
      if (value.isPlaying && _hasEnded) {
        _hasEnded = false;
        _endedFired = false;
      }
    });
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(
      const Duration(milliseconds: 250), (_) {
      if (!mounted || _isDraggingProgress) return;
      final pos = widget.controller.value.position;
      if (pos != _position) setState(() => _position = pos);
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (!_isPlaying || _hasEnded) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isDraggingProgress) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _togglePlayPause() {
    if (_hasEnded) {
      widget.controller.seekTo(Duration.zero);
      widget.controller.play();
      setState(() {
        _hasEnded = false;
        _endedFired = false;
        _isPlaying = true;
        _showControls = true;
      });
      _startHideTimer();
      return;
    }
    if (_isPlaying) {
      widget.controller.pause();
      setState(() { _isPlaying = false; _showControls = true; });
      _hideTimer?.cancel();
    } else {
      widget.controller.play();
      setState(() => _isPlaying = true);
      _startHideTimer();
    }
  }

  void _seekRelative(int seconds) {
    final raw = _position + Duration(seconds: seconds);
    final target = raw < Duration.zero
        ? Duration.zero
        : (raw > _duration ? _duration : raw);
    widget.controller.seekTo(target);
    setState(() => _position = target);
  }

  void _onDoubleTapLeft() {
    HapticFeedback.lightImpact();
    _seekRelative(-10);
    _leftSeekAccum += 10;
    setState(() {});
    if (_leftSeekController.status == AnimationStatus.forward) {
      _leftSeekController.forward(from: 0.15);
    } else {
      _leftSeekController.forward(from: 0);
    }
  }

  void _onDoubleTapRight() {
    HapticFeedback.lightImpact();
    _seekRelative(10);
    _rightSeekAccum += 10;
    setState(() {});
    if (_rightSeekController.status == AnimationStatus.forward) {
      _rightSeekController.forward(from: 0.15);
    } else {
      _rightSeekController.forward(from: 0);
    }
  }

  double get _progressFraction {
    if (_duration.inMilliseconds <= 0) return 0.0;
    if (_isDraggingProgress) return _dragProgressValue;
    return (_position.inMilliseconds / _duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  double get _bufferedFraction {
    if (_duration.inMilliseconds <= 0) return 0.0;
    return (_buffered.inMilliseconds / _duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  Future<void> _showSpeedSheet() async {
    _hideTimer?.cancel();
    final selected = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Playback speed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            for (final speed in _speedOptions)
              ListTile(
                title: Text(
                  speed == 1.0 ? 'Normal' : '${speed}x',
                  style: TextStyle(
                    color: speed == _playbackSpeed
                        ? const Color(0xFFFF0000)
                        : Colors.white,
                    fontWeight: speed == _playbackSpeed
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
                trailing: speed == _playbackSpeed
                    ? const Icon(Icons.check, color: Color(0xFFFF0000))
                    : null,
                onTap: () => Navigator.of(context).pop(speed),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && selected != _playbackSpeed) {
      await widget.controller.setPlaybackSpeed(selected);
      setState(() => _playbackSpeed = selected);
    }
    if (_isPlaying) _startHideTimer();
  }

  Future<void> _initBrightnessAndVolume() async {
    try {
      final b = await ScreenBrightness().application;
      if (mounted) setState(() => _brightnessValue = b.clamp(0.0, 1.0));
    } catch (_) {}
    try {
      // Suppress system volume bar while player is active
      VolumeController.instance.showSystemUI = false;
      final v = await VolumeController.instance.getVolume();
      if (mounted) {
        setState(() => _volumeValue = v.clamp(0.0, 1.0));
      }
    } catch (_) {}

    // Listen for volume changes from physical buttons
    // fetchInitialVolume: false — already read above, no double-trigger
    _volumeButtonSubscription = VolumeController.instance.addListener(
      (newVolume) {
        if (!mounted) return;
        setState(() {
          _volumeValue = newVolume.clamp(0.0, 1.0);
          _isAdjustingVolume = true;
        });
        _volumeIndicatorTimer?.cancel();
        _volumeIndicatorTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _isAdjustingVolume = false);
        });
      },
      fetchInitialVolume: false,
    );
  }

  void _onVerticalDragStart(DragStartDetails details, double screenWidth) {
    _dragStartY = details.globalPosition.dy;
    _dragStartBrightness = _brightnessValue;
    _dragStartVolume = _volumeValue;
    final isLeftSide = details.globalPosition.dx < screenWidth / 2;
    if (isLeftSide) {
      _isAdjustingBrightness = true;
    } else {
      _isAdjustingVolume = true;
    }
    setState(() {});
  }

  void _onVerticalDragUpdate(
      DragUpdateDetails details, double screenHeight) {
    if (_dragStartY == null) return;
    final delta = _dragStartY! - details.globalPosition.dy;
    final changeFraction = delta / screenHeight;
    if (_isAdjustingBrightness) {
      final newValue =
          (_dragStartBrightness + changeFraction).clamp(0.0, 1.0);
      setState(() => _brightnessValue = newValue);
      ScreenBrightness()
          .setApplicationScreenBrightness(newValue)
          .catchError((_) {});
      _brightnessIndicatorTimer?.cancel();
    } else if (_isAdjustingVolume) {
      final newValue =
          (_dragStartVolume + changeFraction).clamp(0.0, 1.0);
      setState(() => _volumeValue = newValue);
      VolumeController.instance.setVolume(newValue);
      _volumeIndicatorTimer?.cancel();
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _dragStartY = null;
    if (_isAdjustingBrightness) {
      _brightnessIndicatorTimer =
          Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _isAdjustingBrightness = false);
      });
    }
    if (_isAdjustingVolume) {
      _volumeIndicatorTimer =
          Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _isAdjustingVolume = false);
      });
    }
  }

  Widget _buildSideIndicator({
    required Alignment alignment,
    required IconData icon,
    required double value,
  }) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              width: 4,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  FractionallySizedBox(
                    heightFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(value * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _brightnessIndicatorTimer?.cancel();
    _volumeIndicatorTimer?.cancel();
    _leftSeekController.dispose();
    _rightSeekController.dispose();
    widget.controller.removeListener(_onControllerUpdate);
    _volumeButtonSubscription?.cancel();
    VolumeController.instance.showSystemUI = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          onVerticalDragStart: (d) => _onVerticalDragStart(d, width),
          onVerticalDragUpdate: (d) => _onVerticalDragUpdate(d, height),
          onVerticalDragEnd: _onVerticalDragEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video
              Center(
                child: AspectRatio(
                  aspectRatio: widget.controller.value.aspectRatio == 0
                      ? 16 / 9
                      : widget.controller.value.aspectRatio,
                  child: VideoPlayer(widget.controller),
                ),
              ),

              // Double-tap zones
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleControls,
                      onDoubleTap: _onDoubleTapLeft,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleControls,
                      onDoubleTap: _togglePlayPause,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleControls,
                      onDoubleTap: _onDoubleTapRight,
                    ),
                  ),
                ],
              ),

              // Seek animations
              _buildSeekOverlay(
                alignment: Alignment.centerLeft,
                scale: _leftSeekScale,
                opacity: _leftSeekOpacity,
                icon: Icons.replay_10_rounded,
                seconds: _leftSeekAccum,
              ),
              _buildSeekOverlay(
                alignment: Alignment.centerRight,
                scale: _rightSeekScale,
                opacity: _rightSeekOpacity,
                icon: Icons.forward_10_rounded,
                seconds: _rightSeekAccum,
              ),

              // Buffering
              if (_isBuffering && !_hasEnded)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF0000)),
                ),

              // Brightness indicator
              if (_isAdjustingBrightness)
                _buildSideIndicator(
                  alignment: Alignment.centerLeft,
                  icon: _brightnessValue > 0.5
                      ? Icons.brightness_high_rounded
                      : Icons.brightness_low_rounded,
                  value: _brightnessValue,
                ),

              // Volume indicator
              if (_isAdjustingVolume)
                _buildSideIndicator(
                  alignment: Alignment.centerRight,
                  icon: _volumeValue == 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  value: _volumeValue,
                ),

              // Controls
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: _buildControlsOverlay(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeekOverlay({
    required Alignment alignment,
    required Animation<double> scale,
    required Animation<double> opacity,
    required IconData icon,
    required int seconds,
  }) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: FadeTransition(
          opacity: opacity,
          child: ScaleTransition(
            scale: scale,
            child: Icon(icon, color: Colors.white, size: 40),
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Stack(
      children: [
        // Top bar
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                    ),
                    onPressed: widget.onExitFullscreen,
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Center play/replay
        if (!_isPlaying)
          Center(
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _hasEnded
                      ? Icons.replay_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),

        // Bottom bar
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 24, 8, 4),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildProgressBar(),
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      Text(
                        '${_formatDuration(_isDraggingProgress ? Duration(milliseconds: (_dragProgressValue * _duration.inMilliseconds).round()) : _position)} / ${_formatDuration(_duration)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _showSpeedSheet,
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          _playbackSpeed == 1.0 ? '1x' : '${_playbackSpeed}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _hasEnded
                              ? Icons.replay_rounded
                              : (_isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded),
                          color: Colors.white,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.fullscreen_exit_rounded,
                          color: Colors.white,
                        ),
                        onPressed: widget.onExitFullscreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void handleDrag(double dx) {
          final fraction = (dx / width).clamp(0.0, 1.0);
          setState(() => _dragProgressValue = fraction);
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            setState(() {
              _isDraggingProgress = true;
              _dragProgressValue =
                  (d.localPosition.dx / width).clamp(0.0, 1.0);
            });
            _onProgressDragEnd();
          },
          onHorizontalDragStart: (d) {
            setState(() {
              _isDraggingProgress = true;
              _dragProgressValue =
                  (d.localPosition.dx / width).clamp(0.0, 1.0);
            });
          },
          onHorizontalDragUpdate: (d) => handleDrag(d.localPosition.dx),
          onHorizontalDragEnd: (_) => _onProgressDragEnd(),
          child: SizedBox(
            height: 24,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: _bufferedFraction,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: _progressFraction,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment((_progressFraction * 2) - 1, 0),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF0000),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                if (_isDraggingProgress)
                  Align(
                    alignment: Alignment((_progressFraction * 2) - 1, 0),
                    child: FractionalTranslation(
                      translation: const Offset(0, -1.8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(Duration(
                            milliseconds: (_dragProgressValue *
                                    _duration.inMilliseconds)
                                .round(),
                          )),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onProgressDragEnd() {
    if (_duration.inMilliseconds > 0) {
      final target = Duration(
        milliseconds:
            (_dragProgressValue * _duration.inMilliseconds).round(),
      );
      widget.controller.seekTo(target);
      setState(() {
        _position = target;
        _isDraggingProgress = false;
        if (_isPlaying) {
          _endedFired = false;
          _hasEnded = false;
        }
      });
    } else {
      setState(() => _isDraggingProgress = false);
    }
    _startHideTimer();
  }
}
