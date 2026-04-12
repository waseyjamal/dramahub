# DRAMA HUB FLUTTER ANDROID APP
## COMPLETE PRODUCTION-READY BLUEPRINT

---

# SECTION 1: SYSTEM ARCHITECTURE OVERVIEW

## 1.1 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           PRESENTATION LAYER                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  HomeScreen │  │EpisodeScreen│  │ VideoScreen │  │ PremiumInfoScreen   │ │
│  │  (Grid UI)  │  │ (List/Grid) │  │ (WebView)   │  │ (Telegram CTA)      │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘ │
│         │                │                │                    │            │
│  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────────▼──────────┐ │
│  │HomeController│  │EpisodeController│ │VideoController│ │PremiumController│ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           BUSINESS LOGIC LAYER                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  AdService  │  │ DataService │  │VideoService │  │ NavigationService   │ │
│  │(Monetization)│  │(JSON Local) │  │(YouTube WV) │  │ (GetX Routes)       │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DATA LAYER                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  dramas.json│  │episodes.json│  │  App Config │  │   Local Assets      │ │
│  │ (Drama List)│  │(Episode Map)│  │ (Settings)  │  │  (Images/Icons)     │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 1.2 Tech Stack Specification

| Component | Technology | Version |
|-----------|------------|---------|
| Framework | Flutter | 3.19.0+ |
| Language | Dart | 3.3.0+ |
| State Management | GetX | ^4.6.6 |
| Video Player | webview_flutter | ^4.7.0 |
| Ads | google_mobile_ads | ^5.0.0 |
| Images | cached_network_image | ^3.3.1 |
| Launcher | url_launcher | ^6.2.5 |
| Security | flutter_windowmanager | ^0.2.0 |
| Root Check | root_checker | ^0.0.3 |

## 1.3 Core Principles

1. **Single Responsibility**: Each controller handles one feature
2. **Reactive State**: All UI updates via Obx/Rx variables
3. **Lazy Loading**: Images and data loaded on-demand
4. **Ad Modularity**: Ad logic centralized in AdService
5. **No Backend**: All data from local JSON files
6. **Minimal Dependencies**: Only essential packages

---

# SECTION 2: FOLDER & FILE STRUCTURE

## 2.1 Complete Project Structure

```
drama_hub/
├── android/
│   ├── app/
│   │   ├── build.gradle              # AdMob App ID config
│   │   └── src/main/
│   │       ├── AndroidManifest.xml   # FLAG_SECURE config
│   │       └── kotlin/.../MainActivity.kt
│   └── build.gradle
├── assets/
│   ├── data/
│   │   ├── dramas.json               # Drama list data
│   │   └── episodes/                 # Episode data per drama
│   │       ├── arafta_episodes.json
│   │       └── my_left_side_episodes.json
│   ├── images/
│   │   ├── posters/                  # Drama poster images
│   │   ├── icons/                    # App icons
│   │   └── placeholders/             # Loading placeholders
│   └── config/
│       └── app_config.json           # Ad IDs, Telegram links
├── lib/
│   ├── main.dart                     # App entry point
│   ├── app.dart                      # GetMaterialApp config
│   ├── bindings/
│   │   ├── home_binding.dart
│   │   ├── episode_binding.dart
│   │   ├── video_binding.dart
│   │   └── premium_binding.dart
│   ├── controllers/
│   │   ├── home_controller.dart
│   │   ├── episode_controller.dart
│   │   ├── video_controller.dart
│   │   ├── premium_controller.dart
│   │   └── splash_controller.dart
│   ├── models/
│   │   ├── drama_model.dart
│   │   └── episode_model.dart
│   ├── services/
│   │   ├── ad_service.dart           # Centralized ad logic
│   │   ├── data_service.dart         # JSON data loading
│   │   └── video_service.dart        # WebView video handling
│   ├── routes/
│   │   ├── app_pages.dart            # Route definitions
│   │   └── app_routes.dart           # Route names
│   ├── screens/
│   │   ├── splash_screen.dart
│   │   ├── home_screen.dart
│   │   ├── episode_screen.dart
│   │   ├── video_screen.dart
│   │   ├── premium_info_screen.dart
│   │   └── widgets/
│   │       ├── drama_card.dart
│   │       ├── episode_card.dart
│   │       ├── badge_widget.dart
│   │       ├── search_bar.dart
│   │       ├── loading_shimmer.dart
│   │       └── premium_lock_overlay.dart
│   ├── theme/
│   │   ├── app_colors.dart           # Color palette
│   │   ├── app_text_styles.dart      # Typography
│   │   └── app_theme.dart            # ThemeData
│   └── utils/
│       ├── constants.dart
│       ├── helpers.dart
│       └── extensions.dart
├── pubspec.yaml
└── README.md
```

## 2.2 File Templates

### pubspec.yaml
```yaml
name: drama_hub
description: Turkish Drama Streaming App
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  get: ^4.6.6
  google_mobile_ads: ^5.0.0
  webview_flutter: ^4.7.0
  cached_network_image: ^3.3.1
  url_launcher: ^6.2.5
  flutter_windowmanager: ^0.2.0
  shimmer: ^3.0.0
  share_plus: ^7.2.2

flutter:
  uses-material-design: true
  assets:
    - assets/data/
    - assets/data/episodes/
    - assets/images/
    - assets/config/
```

---

# SECTION 3: SCREEN-BY-SCREEN FUNCTIONAL BLUEPRINT

## 3.1 Color Palette (Extracted from Website)

```dart
// lib/theme/app_colors.dart

class AppColors {
  // Background Colors
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceLight = Color(0xFF2A2A2A);
  
  // Primary Colors
  static const Color primary = Color(0xFFE50914);      // Netflix Red
  static const Color primaryDark = Color(0xFFB20710);
  
  // Accent Colors
  static const Color accentGreen = Color(0xFF00C853);  // NEW badge
  static const Color accentOrange = Color(0xFFFF6D00); // HOT badge
  static const Color accentGold = Color(0xFFFFD700);   // PREMIUM badge
  static const Color accentBlue = Color(0xFF2962FF);   // UPCOMING badge
  
  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF666666);
  
  // Status Colors
  static const Color success = Color(0xFF00C853);
  static const Color error = Color(0xFFE50914);
  static const Color warning = Color(0xFFFFA000);
  
  // Overlay
  static const Color overlay = Color(0xCC000000);
  static const Color gradientStart = Color(0x00000000);
  static const Color gradientEnd = Color(0xCC000000);
}
```

## 3.2 Typography System

```dart
// lib/theme/app_text_styles.dart

class AppTextStyles {
  // Headings
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle heading3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textMuted,
  );
  
  // Badges
  static const TextStyle badge = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );
  
  // Buttons
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
}
```

## 3.3 Screen 1: Splash Screen

### Purpose
- Preload ads
- Initialize app
- Show loading state

### UI Structure
```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│         🎬 DRAMA HUB               │
│                                     │
│     Turkish Dramas Hindi Subtitles  │
│                                     │
│                                     │
│         [Loading Indicator]         │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

### Controller Logic
```dart
// lib/controllers/splash_controller.dart

class SplashController extends GetxController {
  final AdService _adService = Get.find<AdService>();
  final DataService _dataService = Get.find<DataService>();
  
  RxBool isLoading = true.obs;
  RxString loadingText = 'Initializing...'.obs;
  
  @override
  void onInit() {
    super.onInit();
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    // Step 1: Preload interstitial
    loadingText.value = 'Loading ads...';
    await _adService.preloadInterstitial();
    
    // Step 2: Load drama data
    loadingText.value = 'Loading content...';
    await _dataService.loadDramas();
    
    // Step 3: Navigate to home
    await Future.delayed(const Duration(milliseconds: 500));
    Get.offAllNamed(Routes.HOME);
  }
}
```

---

## 3.4 Screen 2: Home Screen

### Purpose
- Display drama grid
- Search functionality
- Navigation to episodes
- Telegram CTA

### UI Structure
```
┌─────────────────────────────────────┐
│ ≡    DRAMA HUB              [🔍]   │  ← AppBar
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │  🎬 Drama Hub               │   │  ← Hero Section
│  │  Watch Turkish dramas...    │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🔍 Search drama name...     │   │  ← Search Bar
│  └─────────────────────────────┘   │
│                                     │
│  ┌───────────┐  ┌───────────┐      │
│  │ [HOT]     │  │ [NEW]     │      │  ← Drama Grid
│  │ ┌───────┐ │  │ ┌───────┐ │      │     (2 columns)
│  │ │Poster │ │  │ │Poster │ │      │
│  │ └───────┘ │  │ └───────┘ │      │
│  │ Arafta    │  │ My Left   │      │
│  │ Hindi Sub │  │ Side      │      │
│  └───────────┘  └───────────┘      │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  📲 Join Telegram Updates   │   │  ← Telegram CTA
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

### Widget: DramaCard
```dart
// lib/screens/widgets/drama_card.dart

class DramaCard extends StatelessWidget {
  final DramaModel drama;
  final VoidCallback onTap;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster with badge overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: drama.posterUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const LoadingShimmer(),
                  ),
                ),
                // Badge positioning
                if (drama.badge != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: BadgeWidget(type: drama.badge!),
                  ),
              ],
            ),
            // Title section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drama.title,
                    style: AppTextStyles.heading3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    drama.subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.accentGold,
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
}
```

### Widget: BadgeWidget
```dart
// lib/screens/widgets/badge_widget.dart

class BadgeWidget extends StatelessWidget {
  final BadgeType type;
  
  Color get backgroundColor {
    switch (type) {
      case BadgeType.hot:
        return AppColors.primary;
      case BadgeType.new:
        return AppColors.accentGreen;
      case BadgeType.premium:
        return AppColors.accentGold;
      case BadgeType.upcoming:
        return AppColors.accentBlue;
    }
  }
  
  String get label {
    switch (type) {
      case BadgeType.hot:
        return 'HOT';
      case BadgeType.new:
        return 'NEW';
      case BadgeType.premium:
        return 'PREMIUM';
      case BadgeType.upcoming:
        return 'UPCOMING';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTextStyles.badge,
      ),
    );
  }
}
```

### Controller Logic
```dart
// lib/controllers/home_controller.dart

class HomeController extends GetxController {
  final AdService _adService = Get.find<AdService>();
  final DataService _dataService = Get.find<DataService>();
  
  RxList<DramaModel> dramas = <DramaModel>[].obs;
  RxList<DramaModel> filteredDramas = <DramaModel>[].obs;
  RxBool isSearching = false.obs;
  RxString searchQuery = ''.obs;
  
  // Ad cooldown tracking
  DateTime? _lastInterstitialShown;
  static const interstitialCooldown = Duration(minutes: 2);
  
  @override
  void onInit() {
    super.onInit();
    dramas.value = _dataService.dramas;
    filteredDramas.value = dramas;
  }
  
  void onSearch(String query) {
    searchQuery.value = query;
    if (query.isEmpty) {
      filteredDramas.value = dramas;
    } else {
      filteredDramas.value = dramas.where((d) =>
        d.title.toLowerCase().contains(query.toLowerCase())
      ).toList();
    }
  }
  
  Future<void> onDramaTap(DramaModel drama) async {
    // Check cooldown before showing interstitial
    if (_canShowInterstitial()) {
      await _adService.showInterstitial();
      _lastInterstitialShown = DateTime.now();
    }
    
    Get.toNamed(
      Routes.EPISODES,
      arguments: {'drama': drama},
    );
  }
  
  bool _canShowInterstitial() {
    if (_lastInterstitialShown == null) return true;
    return DateTime.now().difference(_lastInterstitialShown!) > 
           interstitialCooldown;
  }
  
  void onTelegramTap() {
    launchUrl(Uri.parse(AppConstants.telegramUrl));
  }
}
```

---

## 3.5 Screen 3: Episode Screen

### Purpose
- Show drama info banner
- Display episode grid
- Handle premium locking
- Episode search

### UI Structure
```
┌─────────────────────────────────────┐
│ ←    Arafta                        │  ← AppBar
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │        [Hero Banner Image]      │ │  ← Drama Banner
│ │   Arafta (Bound by Fate)        │ │
│ │   Turkish Drama Hindi Subtitles │ │
│ └─────────────────────────────────┘ │
│                                     │
│ 📅 New Episodes: Fri & Mon 6:30 PM │
│ 🎬 Language: Turkish (Hindi Sub)   │
│ 📥 Format: Full Episode Download   │
│                                     │
│ ┌─────────────────────────────┐    │
│ │ 🔍 Search episode...        │    │  ← Search Bar
│ └─────────────────────────────┘    │
│                                     │
│ ┌─────────────────────────────────┐│
│ │ 🔒 MEMBERSHIP ACCESS            ││  ← Premium Banner
│ │ Episodes 56, 57, 58...          ││
│ └─────────────────────────────────┘│
│                                     │
│ ┌───────────┐  ┌───────────┐       │
│ │ [RELEASED]│  │ [RELEASED]│       │  ← Episode Grid
│ │ Episode 60│  │ Episode 59│       │     (2 columns)
│ │ Hindi Sub │  │ Hindi Sub │       │
│ └───────────┘  └───────────┘       │
│ ┌───────────┐  ┌───────────┐       │
│ │ [RELEASED]│  │ [🔒 LOCK] │       │
│ │ Episode 58│  │ Episode 57│       │
│ │ Hindi Sub │  │ Premium   │       │
│ └───────────┘  └───────────┘       │
│                                     │
│ [Banner Ad - Optional]              │
└─────────────────────────────────────┘
```

### Widget: EpisodeCard
```dart
// lib/screens/widgets/episode_card.dart

class EpisodeCard extends StatelessWidget {
  final EpisodeModel episode;
  final VoidCallback onTap;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.surface,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail with status badge
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: episode.thumbnailUrl,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Status badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: episode.isReleased 
                            ? AppColors.accentGreen 
                            : AppColors.accentBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          episode.isReleased ? 'RELEASED' : 'UPCOMING',
                          style: AppTextStyles.badge.copyWith(fontSize: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                // Episode info
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode.title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hindi Subtitles',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Premium lock overlay
            if (episode.isPremium)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.overlay,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock,
                      color: AppColors.accentGold,
                      size: 32,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

### Controller Logic
```dart
// lib/controllers/episode_controller.dart

class EpisodeController extends GetxController {
  final AdService _adService = Get.find<AdService>();
  final DataService _dataService = Get.find<DataService>();
  
  late DramaModel drama;
  RxList<EpisodeModel> episodes = <EpisodeModel>[].obs;
  RxList<EpisodeModel> filteredEpisodes = <EpisodeModel>[].obs;
  
  // Ad tracking
  DateTime? _lastInterstitialShown;
  static const interstitialCooldown = Duration(minutes: 3);
  RxInt sessionEpisodeOpens = 0.obs;
  static const maxInterstitialsPerSession = 5;
  
  @override
  void onInit() {
    super.onInit();
    drama = Get.arguments['drama'];
    _loadEpisodes();
  }
  
  Future<void> _loadEpisodes() async {
    episodes.value = await _dataService.loadEpisodes(drama.id);
    filteredEpisodes.value = episodes;
  }
  
  void onSearch(String query) {
    if (query.isEmpty) {
      filteredEpisodes.value = episodes;
    } else {
      filteredEpisodes.value = episodes.where((e) =>
        e.title.toLowerCase().contains(query.toLowerCase()) ||
        e.episodeNumber.toString().contains(query)
      ).toList();
    }
  }
  
  Future<void> onEpisodeTap(EpisodeModel episode) async {
    // Premium check
    if (episode.isPremium) {
      Get.toNamed(Routes.PREMIUM_INFO);
      return;
    }
    
    // Upcoming check
    if (!episode.isReleased) {
      Get.snackbar(
        'Coming Soon',
        'This episode will be released soon!',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    
    // Show interstitial with frequency cap
    if (_canShowInterstitial()) {
      await _adService.showInterstitial();
      _lastInterstitialShown = DateTime.now();
      sessionEpisodeOpens.value++;
    }
    
    Get.toNamed(
      Routes.VIDEO,
      arguments: {
        'episode': episode,
        'drama': drama,
      },
    );
  }
  
  bool _canShowInterstitial() {
    // Session cap check
    if (sessionEpisodeOpens.value >= maxInterstitialsPerSession) {
      return false;
    }
    
    // Cooldown check
    if (_lastInterstitialShown == null) return true;
    return DateTime.now().difference(_lastInterstitialShown!) > 
           interstitialCooldown;
  }
}
```

---

## 3.6 Screen 4: Video Screen

### Purpose
- Show interstitial before video
- Load YouTube in WebView
- Download button with rewarded ad
- Security (FLAG_SECURE)

### UI Structure
```
┌─────────────────────────────────────┐
│ ←    Episode 60 - Arafta           │  ← AppBar
├─────────────────────────────────────┤
│                                     │
│                                     │
│                                     │
│    ┌─────────────────────────┐     │
│    │                         │     │
│    │     [YouTube Player]    │     │  ← WebView
│    │                         │     │     (YouTube Embed)
│    │                         │     │
│    └─────────────────────────┘     │
│                                     │
│                                     │
│                                     │
├─────────────────────────────────────┤
│  Episode 60 - Hindi Subtitles      │
│  Arafta (Bound by Fate)            │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │  ⬇️ Download Episode        │   │  ← Download Button
│  │     (Watch Ad to Unlock)    │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  📲 Join Telegram Premium   │   │  ← Telegram CTA
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

### Controller Logic
```dart
// lib/controllers/video_controller.dart

class VideoController extends GetxController {
  final AdService _adService = Get.find<AdService>();
  
  late EpisodeModel episode;
  late DramaModel drama;
  late WebViewController webViewController;
  
  RxBool isVideoLoaded = false.obs;
  RxBool isRewardedAdLoading = false.obs;
  RxBool isDownloadUnlocked = false.obs;
  
  @override
  void onInit() {
    super.onInit();
    episode = Get.arguments['episode'];
    drama = Get.arguments['drama'];
    _initializeWebView();
    _enableSecurity();
  }
  
  Future<void> _enableSecurity() async {
    // Enable FLAG_SECURE - prevents screenshots/screen recording
    await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
  }
  
  void _initializeWebView() {
    webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            isVideoLoaded.value = true;
          },
        ),
      )
      ..loadRequest(Uri.parse(_buildYouTubeUrl()));
  }
  
  String _buildYouTubeUrl() {
    // Use YouTube embed URL with parameters to hide controls
    final videoId = _extractVideoId(episode.videoUrl);
    return 'https://www.youtube.com/embed/$videoId?'
        'autoplay=1&'
        'controls=1&'
        'modestbranding=1&'
        'rel=0&'
        'showinfo=0';
  }
  
  String _extractVideoId(String url) {
    // Extract video ID from various YouTube URL formats
    final regExp = RegExp(
      r'^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*',
    );
    final match = regExp.firstMatch(url);
    return match?.group(2) ?? '';
  }
  
  Future<void> onDownloadTap() async {
    if (isDownloadUnlocked.value) {
      // Already unlocked, open download URL
      _openDownloadUrl();
      return;
    }
    
    // Show rewarded ad
    isRewardedAdLoading.value = true;
    
    final rewarded = await _adService.showRewardedAd(
      onRewarded: (reward) {
        isDownloadUnlocked.value = true;
        Get.snackbar(
          'Download Unlocked!',
          'You can now download this episode.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.accentGreen,
          colorText: AppColors.textPrimary,
        );
      },
    );
    
    isRewardedAdLoading.value = false;
    
    if (!rewarded) {
      Get.snackbar(
        'Ad Not Available',
        'Please try again later.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  
  void _openDownloadUrl() {
    launchUrl(
      Uri.parse(episode.downloadUrl),
      mode: LaunchMode.externalApplication,
    );
  }
  
  @override
  void onClose() {
    // Clear FLAG_SECURE when leaving video screen
    FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    super.onClose();
  }
}
```

### WebView Security Configuration
```dart
// lib/services/video_service.dart

class VideoService {
  static WebViewController createSecureWebView(String videoUrl) {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // Block external navigation attempts
            if (request.url.contains('youtube.com') || 
                request.url.contains('youtu.be')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      // Inject JavaScript to disable right-click/long-press
      ..runJavaScript('''
        document.addEventListener('contextmenu', event => event.preventDefault());
        document.addEventListener('selectstart', event => event.preventDefault());
        document.addEventListener('dragstart', event => event.preventDefault());
      ''');
  }
}
```

---

## 3.7 Screen 5: Premium Info Screen

### Purpose
- Explain premium benefits
- Show Telegram join CTA
- Manual membership flow

### UI Structure
```
┌─────────────────────────────────────┐
│ ←    Premium Access                │  ← AppBar
├─────────────────────────────────────┤
│                                     │
│         👑                          │
│                                     │
│    Premium Membership               │
│                                     │
│  Unlock exclusive benefits:         │
│                                     │
│  ✓ Early access to new episodes     │
│  ✓ Ad-free streaming experience     │
│  ✓ Direct download links            │
│  ✓ HD quality videos                │
│  ✓ Priority support                 │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  💎 Join Premium - ₹99/mo   │   │  ← CTA Button
│  └─────────────────────────────┘   │
│                                     │
│  ─────────── OR ───────────        │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  📲 Join via Telegram       │   │  ← Telegram CTA
│  └─────────────────────────────┘   │
│                                     │
│  Contact @admin for manual payment  │
│                                     │
└─────────────────────────────────────┘
```

### Controller Logic
```dart
// lib/controllers/premium_controller.dart

class PremiumController extends GetxController {
  final String telegramPremiumUrl = AppConstants.telegramPremiumUrl;
  final String telegramAdminUrl = AppConstants.telegramAdminUrl;
  
  void onJoinPremiumTap() {
    // Open Telegram private channel link
    _launchTelegram(telegramPremiumUrl);
  }
  
  void onContactAdminTap() {
    _launchTelegram(telegramAdminUrl);
  }
  
  void _launchTelegram(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar(
        'Error',
        'Could not open Telegram. Please install Telegram app.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
```

---

# SECTION 4: MONETIZATION FLOW LOGIC

## 4.1 Ad Service Architecture

```dart
// lib/services/ad_service.dart

class AdService extends GetxService {
  // Ad Unit IDs (replace with your actual IDs)
  static const String interstitialId = 'ca-app-pub-xxx/xxx';
  static const String rewardedId = 'ca-app-pub-xxx/xxx';
  static const String bannerId = 'ca-app-pub-xxx/xxx';
  
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  
  // Frequency cap configuration
  static const int maxInterstitialsPerSession = 5;
  static const Duration interstitialCooldown = Duration(minutes: 2);
  static const Duration rewardedCooldown = Duration(minutes: 1);
  
  // Session tracking
  int _sessionInterstitialCount = 0;
  DateTime? _lastInterstitialTime;
  DateTime? _lastRewardedTime;
  
  RxBool isInterstitialReady = false.obs;
  RxBool isRewardedReady = false.obs;
  
  @override
  void onInit() {
    super.onInit();
    _initializeAds();
  }
  
  Future<void> _initializeAds() async {
    await MobileAds.instance.initialize();
    await preloadInterstitial();
    await preloadRewarded();
  }
  
  // ==================== INTERSTITIAL ADS ====================
  
  Future<void> preloadInterstitial() async {
    await InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          isInterstitialReady.value = true;
          _setupInterstitialCallbacks(ad);
        },
        onAdFailedToLoad: (error) {
          isInterstitialReady.value = false;
          debugPrint('Interstitial failed to load: $error');
        },
      ),
    );
  }
  
  void _setupInterstitialCallbacks(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        isInterstitialReady.value = false;
        preloadInterstitial(); // Preload next
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        isInterstitialReady.value = false;
        preloadInterstitial();
      },
    );
  }
  
  Future<bool> showInterstitial() async {
    // Frequency cap checks
    if (_sessionInterstitialCount >= maxInterstitialsPerSession) {
      debugPrint('Interstitial cap reached for session');
      return false;
    }
    
    if (_lastInterstitialTime != null) {
      final timeSince = DateTime.now().difference(_lastInterstitialTime!);
      if (timeSince < interstitialCooldown) {
        debugPrint('Interstitial cooldown active');
        return false;
      }
    }
    
    if (_interstitialAd == null) {
      await preloadInterstitial();
      return false;
    }
    
    await _interstitialAd!.show();
    _sessionInterstitialCount++;
    _lastInterstitialTime = DateTime.now();
    return true;
  }
  
  // ==================== REWARDED ADS ====================
  
  Future<void> preloadRewarded() async {
    await RewardedAd.load(
      adUnitId: rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          isRewardedReady.value = true;
          _setupRewardedCallbacks(ad);
        },
        onAdFailedToLoad: (error) {
          isRewardedReady.value = false;
          debugPrint('Rewarded failed to load: $error');
        },
      ),
    );
  }
  
  void _setupRewardedCallbacks(RewardedAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        isRewardedReady.value = false;
        preloadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        isRewardedReady.value = false;
        preloadRewarded();
      },
    );
  }
  
  Future<bool> showRewardedAd({
    required Function(RewardItem) onRewarded,
  }) async {
    if (_rewardedAd == null) {
      await preloadRewarded();
      return false;
    }
    
    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        onRewarded(reward);
        _lastRewardedTime = DateTime.now();
      },
    );
    return true;
  }
  
  // ==================== BANNER AD ====================
  
  Widget buildBannerAd() {
    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: 60,
      child: AdWidget(
        ad: BannerAd(
          adUnitId: bannerId,
          size: AdSize.banner,
          request: const AdRequest(),
          listener: BannerAdListener(),
        )..load(),
      ),
    );
  }
}
```

## 4.2 Monetization Event Flow Chart

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        USER SESSION FLOW                                    │
└─────────────────────────────────────────────────────────────────────────────┘

[APP LAUNCH]
     │
     ▼
┌─────────────┐
│ Splash Screen│ ──► Preload Interstitial + Rewarded
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ Home Screen  │
└──────┬──────┘
       │
       ├──► User taps Drama Card
       │         │
       │         ├──► Check Cooldown (2 min)
       │         │         │
       │         │         ├──► Pass ──► Show Interstitial
       │         │         │                    │
       │         │         │                    ▼
       │         │         │            Navigate to Episode Screen
       │         │         │
       │         │         └──► Fail ──► Navigate directly
       │         │
       │         └──► Update LastShown timestamp
       │
       ▼
┌─────────────────┐
│ Episode Screen   │
└────────┬────────┘
         │
         ├──► User taps Episode
         │         │
         │         ├──► Premium? ──► YES ──► Show Premium Info Screen
         │         │                       └──► Telegram CTA
         │         │
         │         ├──► Upcoming? ──► YES ──► Show "Coming Soon" toast
         │         │
         │         └──► Released? ──► YES
         │                              │
         │                              ├──► Check Session Cap (5 max)
         │                              │         │
         │                              │         ├──► Pass ──► Show Interstitial
         │                              │         │                    │
         │                              │         │                    ▼
         │                              │         │            Navigate to Video Screen
         │                              │         │
         │                              │         └──► Fail ──► Navigate directly
         │                              │
         │                              └──► Increment counter
         │
         ▼
┌─────────────────┐
│  Video Screen    │
└────────┬────────┘
         │
         ├──► WebView loads YouTube embed
         │         │
         │         └──► FLAG_SECURE enabled
         │
         ├──► User taps Download
         │         │
         │         ├──► Already unlocked? ──► YES ──► Open external browser
         │         │
         │         └──► Locked? ──► YES
         │                        │
         │                        ├──► Show Rewarded Ad (mandatory)
         │                        │         │
         │                        │         ├──► User completes ──► Unlock download
         │                        │         │                              │
         │                        │         │                              ▼
         │                        │         │                     Open external browser
         │                        │         │
         │                        │         └──► User skips ──► Stay locked
         │                        │
         │                        └──► No ad available ──► Show error toast
         │
         └──► Optional: Banner ad at bottom (light usage)
```

## 4.3 Revenue Trigger Map

| User Action | Ad Type | Frequency | Revenue Potential |
|-------------|---------|-----------|-------------------|
| Drama Selection | Interstitial | 1 per 2 min cooldown | Medium |
| Episode Open | Interstitial | Max 5/session | Medium |
| Download Request | Rewarded | On-demand | High |
| Video Screen | Banner | Always visible | Low |
| Session Duration | Interstitial | Controlled | Medium |

## 4.4 Frequency Cap Configuration

```dart
// lib/utils/constants.dart

class AdConfig {
  // Interstitial Settings
  static const int maxInterstitialsPerSession = 5;
  static const Duration interstitialCooldown = Duration(minutes: 2);
  static const bool showInterstitialOnDramaTap = true;
  static const bool showInterstitialOnEpisodeTap = true;
  
  // Rewarded Settings
  static const bool rewardedMandatoryForDownload = true;
  static const Duration rewardedCooldown = Duration(minutes: 1);
  
  // Banner Settings
  static const bool showBannerOnEpisodeScreen = true;
  static const bool showBannerOnVideoScreen = false; // Disabled for video
  
  // Session Settings
  static const Duration sessionTimeout = Duration(hours: 4);
}
```

---

# SECTION 5: IMPLEMENTATION COMMAND GUIDE

## 5.1 Project Initialization

```bash
# Step 1: Create Flutter project
flutter create drama_hub --org com.dramahub

# Step 2: Navigate to project
cd drama_hub

# Step 3: Add dependencies
cat > dependencies.txt << 'EOF'
get: ^4.6.6
google_mobile_ads: ^5.0.0
webview_flutter: ^4.7.0
cached_network_image: ^3.3.1
url_launcher: ^6.2.5
flutter_windowmanager: ^0.2.0
shimmer: ^3.0.0
share_plus: ^7.2.2
EOF

# Step 4: Add to pubspec.yaml
flutter pub add get google_mobile_ads webview_flutter cached_network_image url_launcher flutter_windowmanager shimmer share_plus

# Step 5: Get packages
flutter pub get
```

## 5.2 Android Configuration

### AndroidManifest.xml
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    
    <application
        android:label="Drama Hub"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme"/>
            
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <!-- AdMob App ID -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy"/>
        
        <meta-data
            android:name="flutterEmbedding"
            android:value="2"/>
    </application>
</manifest>
```

### build.gradle (App Level)
```gradle
// android/app/build.gradle

android {
    namespace = "com.dramahub"
    compileSdk = 34
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    defaultConfig {
        applicationId = "com.dramahub"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.debug
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

## 5.3 Core File Implementation Order

### Phase 1: Foundation (Files 1-5)
```bash
# Create folder structure
mkdir -p lib/{bindings,controllers,models,services,routes,screens/widgets,theme,utils}
mkdir -p assets/{data/episodes,images/{posters,icons,placeholders},config}
```

**File 1: lib/theme/app_colors.dart**
**File 2: lib/theme/app_text_styles.dart**
**File 3: lib/theme/app_theme.dart**
**File 4: lib/utils/constants.dart**
**File 5: lib/models/drama_model.dart + episode_model.dart**

### Phase 2: Services (Files 6-8)
**File 6: lib/services/ad_service.dart**
**File 7: lib/services/data_service.dart**
**File 8: lib/services/video_service.dart**

### Phase 3: Routes & Bindings (Files 9-11)
**File 9: lib/routes/app_routes.dart**
**File 10: lib/routes/app_pages.dart**
**File 11: lib/bindings/*.dart (all bindings)**

### Phase 4: Controllers (Files 12-16)
**File 12: lib/controllers/splash_controller.dart**
**File 13: lib/controllers/home_controller.dart**
**File 14: lib/controllers/episode_controller.dart**
**File 15: lib/controllers/video_controller.dart**
**File 16: lib/controllers/premium_controller.dart**

### Phase 5: Widgets (Files 17-22)
**File 17: lib/screens/widgets/drama_card.dart**
**File 18: lib/screens/widgets/episode_card.dart**
**File 19: lib/screens/widgets/badge_widget.dart**
**File 20: lib/screens/widgets/search_bar.dart**
**File 21: lib/screens/widgets/loading_shimmer.dart**
**File 22: lib/screens/widgets/premium_lock_overlay.dart**

### Phase 6: Screens (Files 23-28)
**File 23: lib/screens/splash_screen.dart**
**File 24: lib/screens/home_screen.dart**
**File 25: lib/screens/episode_screen.dart**
**File 26: lib/screens/video_screen.dart**
**File 27: lib/screens/premium_info_screen.dart**

### Phase 7: Entry Points (Files 28-29)
**File 28: lib/app.dart**
**File 29: lib/main.dart**

## 5.4 Data JSON Structure

### assets/data/dramas.json
```json
{
  "dramas": [
    {
      "id": "arafta",
      "title": "Arafta",
      "subtitle": "Hindi Subtitles",
      "fullTitle": "Arafta (Bound by Fate)",
      "description": "Turkish Drama with Hindi Subtitles. Download all episodes in high quality with smooth playback.",
      "posterUrl": "https://example.com/arafta-poster.jpg",
      "bannerUrl": "https://example.com/arafta-banner.jpg",
      "badge": "hot",
      "schedule": "New Free Episodes: Friday & Monday (6:30 PM)",
      "language": "Turkish (Hindi Subtitles)",
      "format": "Full Episode Download",
      "episodeCount": 60,
      "premiumEpisodeStart": 56
    },
    {
      "id": "my_left_side",
      "title": "My Left Side",
      "subtitle": "Hindi Subtitles",
      "fullTitle": "My Left Side (Sol Yanım)",
      "description": "Turkish Drama with Hindi Subtitles.",
      "posterUrl": "https://example.com/my-left-side-poster.jpg",
      "bannerUrl": "https://example.com/my-left-side-banner.jpg",
      "badge": "new",
      "schedule": "New Episodes: Daily",
      "language": "Turkish (Hindi Subtitles)",
      "format": "Full Episode Download",
      "episodeCount": 30,
      "premiumEpisodeStart": 25
    }
  ]
}
```

### assets/data/episodes/arafta_episodes.json
```json
{
  "dramaId": "arafta",
  "episodes": [
    {
      "id": "arafta_60",
      "episodeNumber": 60,
      "title": "Episode 60",
      "subtitle": "Hindi Subtitles",
      "thumbnailUrl": "https://example.com/arafta-ep60-thumb.jpg",
      "videoUrl": "https://youtube.com/watch?v=VIDEO_ID_60",
      "downloadUrl": "https://example.com/download/arafta-ep60",
      "isPremium": false,
      "isNew": true,
      "isUpcoming": false,
      "isReleased": true,
      "releaseDate": "2026-02-14"
    },
    {
      "id": "arafta_57",
      "episodeNumber": 57,
      "title": "Episode 57",
      "subtitle": "Hindi Subtitles",
      "thumbnailUrl": "https://example.com/arafta-ep57-thumb.jpg",
      "videoUrl": "https://youtube.com/watch?v=VIDEO_ID_57",
      "downloadUrl": "https://example.com/download/arafta-ep57",
      "isPremium": true,
      "isNew": false,
      "isUpcoming": false,
      "isReleased": true,
      "releaseDate": "2026-02-10"
    },
    {
      "id": "arafta_61",
      "episodeNumber": 61,
      "title": "Episode 61",
      "subtitle": "Hindi Subtitles",
      "thumbnailUrl": "https://example.com/arafta-ep61-thumb.jpg",
      "videoUrl": "",
      "downloadUrl": "",
      "isPremium": false,
      "isNew": false,
      "isUpcoming": true,
      "isReleased": false,
      "releaseDate": "2026-02-17"
    }
  ]
}
```

### assets/config/app_config.json
```json
{
  "appName": "Drama Hub",
  "version": "1.0.0",
  "telegram": {
    "channelUrl": "https://t.me/araftahindisub",
    "premiumUrl": "https://t.me/+XXXXXXXXXXXX",
    "adminUrl": "https://t.me/dramahub_admin"
  },
  "ads": {
    "enabled": true,
    "testMode": false,
    "interstitialId": "ca-app-pub-3940256099942544/1033173712",
    "rewardedId": "ca-app-pub-3940256099942544/5224354917",
    "bannerId": "ca-app-pub-3940256099942544/6300978111"
  },
  "features": {
    "flagSecure": true,
    "rootDetection": false,
    "screenshotBlock": true
  }
}
```

## 5.5 Build Commands

```bash
# Development build
flutter run

# Release APK build
flutter build apk --release

# App Bundle for distribution
flutter build appbundle --release

# Obfuscate for security
flutter build apk --release --obfuscate --split-debug-info=symbols/

# Analyze code
flutter analyze

# Format code
flutter format lib/
```

## 5.6 Antigravity Execution Instructions

### For AI Code Generation System:

1. **Parse this blueprint** into structured components
2. **Generate files in order** specified in Section 5.3
3. **Follow exact naming conventions** for classes and files
4. **Use GetX patterns** as specified - no Provider/Bloc/Riverpod
5. **Implement ad service first** before any UI that uses ads
6. **Create JSON data files** before controllers that load them
7. **Test each phase** before proceeding to next

### Critical Implementation Notes:

```
⚠️ MANDATORY REQUIREMENTS:
─────────────────────────────────────
✓ Use GetX for ALL state management
✓ No Firebase dependencies
✓ No backend API calls
✓ Local JSON data only
✓ YouTube embed via WebView
✓ FLAG_SECURE on video screen
✓ Ad frequency caps implemented
✓ Premium flow → Telegram only
✓ No in-app purchases
✓ No authentication
─────────────────────────────────────
```

### Quality Checklist:

- [ ] All screens use Obx for reactive updates
- [ ] AdService is singleton via GetX dependency injection
- [ ] Interstitial has 2-minute cooldown
- [ ] Max 5 interstitials per session
- [ ] Rewarded ad mandatory before download
- [ ] Premium episodes show lock overlay
- [ ] WebView disables context menu
- [ ] FLAG_SECURE enabled on video screen
- [ ] All images use CachedNetworkImage
- [ ] Loading states with shimmer effect
- [ ] Error handling for ad failures
- [ ] Telegram links open externally

---

# APPENDIX: COMPLETE MODEL CLASSES

## drama_model.dart
```dart
class DramaModel {
  final String id;
  final String title;
  final String subtitle;
  final String fullTitle;
  final String description;
  final String posterUrl;
  final String bannerUrl;
  final String? badge;
  final String schedule;
  final String language;
  final String format;
  final int episodeCount;
  final int premiumEpisodeStart;

  DramaModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.fullTitle,
    required this.description,
    required this.posterUrl,
    required this.bannerUrl,
    this.badge,
    required this.schedule,
    required this.language,
    required this.format,
    required this.episodeCount,
    required this.premiumEpisodeStart,
  });

  factory DramaModel.fromJson(Map<String, dynamic> json) {
    return DramaModel(
      id: json['id'],
      title: json['title'],
      subtitle: json['subtitle'],
      fullTitle: json['fullTitle'],
      description: json['description'],
      posterUrl: json['posterUrl'],
      bannerUrl: json['bannerUrl'],
      badge: json['badge'],
      schedule: json['schedule'],
      language: json['language'],
      format: json['format'],
      episodeCount: json['episodeCount'],
      premiumEpisodeStart: json['premiumEpisodeStart'],
    );
  }
}
```

## episode_model.dart
```dart
class EpisodeModel {
  final String id;
  final int episodeNumber;
  final String title;
  final String subtitle;
  final String thumbnailUrl;
  final String videoUrl;
  final String downloadUrl;
  final bool isPremium;
  final bool isNew;
  final bool isUpcoming;
  final bool isReleased;
  final String releaseDate;

  EpisodeModel({
    required this.id,
    required this.episodeNumber,
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.downloadUrl,
    required this.isPremium,
    required this.isNew,
    required this.isUpcoming,
    required this.isReleased,
    required this.releaseDate,
  });

  factory EpisodeModel.fromJson(Map<String, dynamic> json) {
    return EpisodeModel(
      id: json['id'],
      episodeNumber: json['episodeNumber'],
      title: json['title'],
      subtitle: json['subtitle'],
      thumbnailUrl: json['thumbnailUrl'],
      videoUrl: json['videoUrl'],
      downloadUrl: json['downloadUrl'],
      isPremium: json['isPremium'],
      isNew: json['isNew'],
      isUpcoming: json['isUpcoming'],
      isReleased: json['isReleased'],
      releaseDate: json['releaseDate'],
    );
  }
}

enum BadgeType { hot, new, premium, upcoming }
```

---

**END OF BLUEPRINT**

*This blueprint is designed for direct implementation by AI code generation systems. All architectural decisions prioritize monetization efficiency, short-term ROI, and clean GetX-based Flutter architecture.*
