import 'package:flutter/material.dart';
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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  // ✅ 8.15 — stored as field, not looked up in build() on every frame
  late final WatchlistController _watchlistController;

  @override
  void initState() {
    super.initState();

    // ✅ 8.15 — single Get.find() call here, reused in build()
    _watchlistController = Get.find<WatchlistController>();

    _screens = [
      const HomeScreen(),
      WatchlistScreen(onBrowseTapped: () => setState(() => _currentIndex = 0)),
      const HistoryScreen(),
      const ProfileScreen(),
    ];

    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(StorageKeys.onboardingDone) ?? false;
    // ✅ W-5 — mounted check after async gap
    // Previously: could navigate after widget disposed during await
    if (!done && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.toNamed(AppRoutes.onboarding);
      });
    }
  }

  void _onTabTapped(int index) {
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.secondaryDark,
          border: Border(
            top: BorderSide(
              color: AppColors.primaryRed.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        // ✅ Removed const from BottomNavigationBar because
        // Watchlist item uses Obx which cannot be const
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          backgroundColor: AppColors.secondaryDark,
          selectedItemColor: AppColors.primaryRed,
          unselectedItemColor: Colors.white38,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            // ✅ #7 — Watchlist badge showing count
            BottomNavigationBarItem(
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
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
