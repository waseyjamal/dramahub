import 'package:flutter/material.dart';
import 'package:drama_hub/services/ad_service.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:drama_hub/ui_system/colors.dart';
import 'package:drama_hub/screens/home_screen.dart';
import 'package:drama_hub/screens/watchlist_screen.dart';
import 'package:drama_hub/screens/history_screen.dart';
import 'package:drama_hub/screens/profile_screen.dart';
import 'package:drama_hub/controllers/watchlist_controller.dart';
import 'package:drama_hub/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drama_hub/routes/app_routes.dart';
import 'package:drama_hub/screens/downloads_screen.dart';
import 'package:drama_hub/services/download_service.dart';
import 'package:drama_hub/features/shorts/screens/shorts_feed_screen.dart';
import 'package:drama_hub/features/shorts/services/shorts_repository.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

// Tab identity is by id, not position — positions change when the
// Shorts tab is switched on/off from the admin config.
enum _TabId { home, shorts, watchlist, downloads, history, profile }

class _MainScreenState extends State<MainScreen> {
  _TabId _currentTab = _TabId.home;

  late final List<Widget> _screens;

  // Stack order of _screens — never changes, so every screen keeps its state.
  static const List<_TabId> _stackOrder = [
    _TabId.home,
    _TabId.watchlist,
    _TabId.downloads,
    _TabId.history,
    _TabId.profile,
    _TabId.shorts,
  ];

  // ✅ 8.15 — stored as field, not looked up in build() on every frame
  late final WatchlistController _watchlistController;

  // True while the Shorts tab is selected — the feed loads/plays only then.
  final ValueNotifier<bool> _shortsActive = ValueNotifier(false);
  final ShortsRepository _shorts = ShortsRepository.instance;
  Worker? _shortsWorker;

  @override
  void initState() {
    super.initState();

    // ✅ 8.15 — single Get.find() call here, reused in build()
    _watchlistController = Get.find<WatchlistController>();

    _screens = [
      const HomeScreen(),
      WatchlistScreen(onBrowseTapped: () => _selectTab(_TabId.home)),
      const DownloadsScreen(),
      const HistoryScreen(),
      const ProfileScreen(),
      ShortsFeedScreen(active: _shortsActive),
    ];

    _shorts.init();
    // If the open tab disappears from the bar (Shorts toggled from admin
    // config mid-session), fall back to Home.
    _shortsWorker = ever<bool>(_shorts.enabled, (_) {
      if (!mounted) return;
      if (!_visibleTabs.contains(_currentTab)) {
        _selectTab(_TabId.home);
      } else {
        setState(() {});
      }
    });

    _checkOnboarding();
  }

  @override
  void dispose() {
    _shortsWorker?.dispose();
    _shortsActive.dispose();
    super.dispose();
  }

  /// With Shorts on, Downloads moves into Profile to keep 5 tabs.
  /// With Shorts off, the bar is exactly the original one.
  List<_TabId> get _visibleTabs => _shorts.enabled.value
      ? const [
          _TabId.home,
          _TabId.shorts,
          _TabId.watchlist,
          _TabId.history,
          _TabId.profile,
        ]
      : const [
          _TabId.home,
          _TabId.watchlist,
          _TabId.downloads,
          _TabId.history,
          _TabId.profile,
        ];

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(StorageKeys.onboardingDone) ?? false;
    // ✅ W-5 — mounted check after async gap
    if (!done && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.toNamed(AppRoutes.onboarding);
      });
    }
  }

  void _selectTab(_TabId tab) {
    setState(() => _currentTab = tab);
    _shortsActive.value = tab == _TabId.shorts;
  }

  void _onTabTapped(int index) {
    HapticFeedback.lightImpact();
    final tab = _visibleTabs[index];
    _selectTab(tab);
    _triggerTabAd(tab);
  }

  void _triggerTabAd(_TabId tab) {
    switch (tab) {
      case _TabId.watchlist:
        Future.delayed(const Duration(seconds: 1), () {
          AdService.instance.showInterstitialForScreen('watchlist_screen');
        });
        break;
      case _TabId.history:
        Future.delayed(const Duration(seconds: 1), () {
          AdService.instance.showInterstitialForScreen('history_screen');
        });
        break;
      default:
        break;
    }
  }

  BottomNavigationBarItem _item(_TabId tab) {
    switch (tab) {
      case _TabId.home:
        return const BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded),
          label: 'Home',
        );
      case _TabId.shorts:
        return const BottomNavigationBarItem(
          icon: Icon(Icons.slow_motion_video_rounded),
          label: 'Shorts',
        );
      case _TabId.watchlist:
        return BottomNavigationBarItem(
          icon: Obx(() {
            final count = _watchlistController.watchlist.length;
            return Badge(
              label: Text('$count'),
              isLabelVisible: count > 0,
              backgroundColor: AppColors.primaryRed,
              child: const Icon(Icons.favorite_rounded),
            );
          }),
          label: 'Watchlist',
        );
      case _TabId.downloads:
        return BottomNavigationBarItem(
          icon: Obx(() {
            final count = DownloadService.instance.downloadCount.value;
            return Badge(
              label: Text('$count'),
              isLabelVisible: count > 0,
              // ✅ FIX — was Colors.green, now matches app brand color
              backgroundColor: AppColors.primaryRed,
              child: const Icon(Icons.download_for_offline_rounded),
            );
          }),
          label: 'Downloads',
        );
      case _TabId.history:
        return const BottomNavigationBarItem(
          icon: Icon(Icons.history_rounded),
          label: 'History',
        );
      case _TabId.profile:
        return const BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'Profile',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _visibleTabs;
    var navIndex = tabs.indexOf(_currentTab);
    if (navIndex < 0) navIndex = 0;
    final onShorts = _currentTab == _TabId.shorts;

    return Scaffold(
      body: IndexedStack(
        index: _stackOrder.indexOf(_currentTab),
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: onShorts ? Colors.black : AppColors.secondaryDark,
          border: Border(
            top: BorderSide(
              color: onShorts
                  ? Colors.white12
                  : AppColors.primaryRed.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: navIndex,
          onTap: _onTabTapped,
          backgroundColor: onShorts ? Colors.black : AppColors.secondaryDark,
          selectedItemColor: AppColors.primaryRed,
          unselectedItemColor: Colors.white38,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          items: tabs.map(_item).toList(),
        ),
      ),
    );
  }
}
