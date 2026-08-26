You are a senior mobile ads monetization engineer with 10+ years of experience. Do a complete diagnosis of the ads system in this Flutter project and save the report to `ads_diagnosis.md` in the project root.

## What to analyze:

### 1. Ad Service Architecture
- How ads are initialized
- How interstitial, rewarded, app open ads are managed
- Ad loading and caching strategy
- Error handling and fallback logic

### 2. Yandex Integration
- SDK initialization correctness
- Ad unit IDs configuration
- Mediation networks setup in build.gradle
- Ad request lifecycle

### 3. Fill Rate Analysis
- List every mediation network configured
- For each network estimate fill rate contribution
- Calculate approximate total fill rate percentage
- Identify gaps or missing high-fill networks

### 4. Ad Trigger Points
- Where exactly ads are shown in the app (which screens, which user actions)
- Are trigger points correct and optimally placed
- Any missing ad opportunities
- Any over-aggressive ad placements that could hurt retention

### 5. Revenue Optimization
- Are ad formats used correctly (interstitial vs rewarded vs banner vs app open)
- Any format missing that could add revenue
- Frequency capping analysis
- eCPM optimization opportunities

### 6. Configuration Audit
- app_config.json ad settings
- Ad unit ID audit (duplicates, missing, incorrect)
- Remote ad config correctness

### 7. Issues & Bugs
- Any ad loading bugs
- Memory leaks in ad lifecycle
- Missing dispose calls
- Thread safety issues

### 8. Preload & Caching Strategy (CRITICAL — Top Priority)
- Is ad preloading implemented correctly?
- Are ads preloaded before they are needed (not on-demand)?
- Is there an ad ready to show instantly when triggered?
- What happens if preloaded ad expires or fails — is there auto-reload?
- Is there a retry mechanism with backoff?
- Are multiple ad formats preloaded simultaneously?
- Compare this preload strategy against top 1% monetized apps industry standard:
  * Top 1% apps preload next ad immediately after current ad is shown
  * Top 1% apps maintain a ready ad in memory at all times
  * Top 1% apps have 3-layer fallback: preloaded → reload → skip
  * Top 1% apps never show loading spinner before an ad
  * Top 1% apps preload on app launch before user reaches any screen
- Rate this app's preload system against top 1% standard
- Give exact code-level fixes if preload system is not top 1%

## Files to analyze:
- lib/services/ad_service.dart
- lib/services/yandex_service.dart
- lib/services/ad_config_service.dart
- lib/models/ad_config_model.dart
- lib/widgets/yandex_banner_ad_widget.dart
- android/app/build.gradle (mediation networks)
- assets/data/app_config.json (if exists)

## Output format for ads_diagnosis.md:

# Drama Hub — Ads System Diagnosis Report
Generated: [date]

## Executive Summary
[Overall ads health score /100]
[Estimated fill rate: X%]
[Estimated revenue efficiency: X%]

## Ad Architecture Analysis
[Full analysis]

## Mediation Networks Analysis
| Network | Status | Estimated Fill Rate | Notes |
[Table of all networks]

## Fill Rate Calculation
[Detailed breakdown of how fill rate is calculated]
[Final estimated fill rate percentage]

## Ad Trigger Points Audit
[Every place ads are shown with assessment]

## Issues Found
[Critical/Warning/Info]

## Revenue Optimization Recommendations
[Specific actionable recommendations]

## Final Verdict
[Ready for monetization / Needs fixes]