import 'package:flutter/material.dart';

import 'package:drama_hub/features/shorts/controllers/shorts_playback_controller.dart';
import 'package:drama_hub/features/shorts/widgets/short_video_page.dart';

/// Vertical swipe player. Wires app lifecycle and route visibility into
/// the [ShortsPlaybackController].
class ShortsPlayerView extends StatefulWidget {
  const ShortsPlayerView({
    super.key,
    required this.controller,
    required this.pageController,
    required this.onEpisodesTap,
    this.onOpenSeries,
    this.endPage,
    this.onEndPageVisible,
  });

  final ShortsPlaybackController controller;
  final PageController pageController;
  final void Function(int index) onEpisodesTap;
  final void Function(int index, int episodeNumber)? onOpenSeries;

  /// Optional page shown after the last item (feed "all caught up").
  final Widget? endPage;
  final ValueChanged<bool>? onEndPageVisible;

  @override
  State<ShortsPlayerView> createState() => _ShortsPlayerViewState();
}

class _ShortsPlayerViewState extends State<ShortsPlayerView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.controller.setAppActive(state == AppLifecycleState.resumed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-runs whenever a route/sheet/dialog covers or uncovers this screen.
    widget.controller.setRouteCurrent(ModalRoute.isCurrentOf(context) ?? true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => PageView.builder(
        controller: widget.pageController,
        scrollDirection: Axis.vertical,
        physics: const _ReelsPagePhysics(),
        // Builds the neighbour pages ahead of time → no frame drop on swipe.
        allowImplicitScrolling: true,
        itemCount: c.items.length + (widget.endPage == null ? 0 : 1),
        onPageChanged: (i) {
          final atEnd = i >= c.items.length;
          widget.onEndPageVisible?.call(atEnd);
          if (!atEnd) c.onPageChanged(i);
        },
        itemBuilder: (context, i) => i >= c.items.length
            ? widget.endPage!
            : ShortVideoPage(
          key: ValueKey(c.items[i].key),
          index: i,
          controller: c,
          onEpisodesTap: () => widget.onEpisodesTap(i),
          onOpenSeries: widget.onOpenSeries == null
              ? null
              : (ep) => widget.onOpenSeries!(i, ep),
        ),
      ),
    );
  }
}

/// Slightly snappier settle than the default PageView, like reels apps.
class _ReelsPagePhysics extends PageScrollPhysics {
  const _ReelsPagePhysics({super.parent});

  @override
  _ReelsPagePhysics applyTo(ScrollPhysics? ancestor) =>
      _ReelsPagePhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring =>
      SpringDescription.withDampingRatio(mass: 0.5, stiffness: 160, ratio: 1.0);
}
