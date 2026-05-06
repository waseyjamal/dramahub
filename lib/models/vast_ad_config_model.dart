class VastWaterfallEntry {
  final String network;
  final String url;
  final int priority;
  final bool enabled;

  VastWaterfallEntry({
    required this.network,
    required this.url,
    required this.priority,
    required this.enabled,
  });

  factory VastWaterfallEntry.fromJson(Map<String, dynamic> json) {
    return VastWaterfallEntry(
      network: json['network'] ?? '',
      url: json['url'] ?? '',
      priority: json['priority'] ?? 1,
      enabled: json['enabled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'network': network,
    'url': url,
    'priority': priority,
    'enabled': enabled,
  };
}

class VastAdConfig {
  final bool enabled;
  final int skipAfterSeconds;
  final int maxPerSession;
  final int gapBetweenAdsMinutes;
  final List<VastWaterfallEntry> waterfall;

  VastAdConfig({
    required this.enabled,
    required this.skipAfterSeconds,
    required this.maxPerSession,
    required this.gapBetweenAdsMinutes,
    required this.waterfall,
  });

  /// Returns enabled waterfall entries sorted by priority ascending
  List<VastWaterfallEntry> get activeWaterfall {
    final active = waterfall.where((e) => e.enabled && e.url.isNotEmpty).toList();
    active.sort((a, b) => a.priority.compareTo(b.priority));
    return active;
  }

  factory VastAdConfig.fromJson(Map<String, dynamic> json) {
    final waterfallJson = json['waterfall'] as List<dynamic>? ?? [];
    return VastAdConfig(
      enabled: json['enabled'] ?? false,
      skipAfterSeconds: json['skip_after_seconds'] ?? 5,
      maxPerSession: json['max_per_session'] ?? 3,
      gapBetweenAdsMinutes: json['gap_between_ads_minutes'] ?? 10,
      waterfall: waterfallJson
          .map((e) => VastWaterfallEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  factory VastAdConfig.defaults() => VastAdConfig(
    enabled: false,
    skipAfterSeconds: 5,
    maxPerSession: 3,
    gapBetweenAdsMinutes: 10,
    waterfall: [],
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'skip_after_seconds': skipAfterSeconds,
    'max_per_session': maxPerSession,
    'gap_between_ads_minutes': gapBetweenAdsMinutes,
    'waterfall': waterfall.map((e) => e.toJson()).toList(),
  };
}
