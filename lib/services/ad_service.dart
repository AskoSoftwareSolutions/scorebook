import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// AD SERVICE
// Rewarded Interstitial Video:
//   - Shows on: Match Start, Wicket, Over Complete
//   - Video plays for 5 seconds → Skip button appears
//   - No banner ads
// ═══════════════════════════════════════════════════════════════════════════════

class AdService with WidgetsBindingObserver {
  static final AdService _i = AdService._();
  factory AdService() => _i;
  AdService._();

  // ── flip to false after AdMob approval ───────────────────────────────────
  static const bool _useTestAds = false; // Production ready! false kodutha production

// Test IDs (Google official)
  static const _tRewarded    = 'ca-app-pub-3940256099942544/5354046379';
  static const _tRewardedIos = 'ca-app-pub-3940256099942544/6978759866';

// Your Real IDs ✅
  static const _rRewarded    = 'ca-app-pub-5068572099745859/7663096771';
  static const _rRewardedIos = 'ca-app-pub-5068572099745859/7663096771';

  static String get _rewardedId =>
      _useTestAds ? (Platform.isIOS ? _tRewardedIos : _tRewarded)
          : (Platform.isIOS ? _rRewardedIos  : _rRewarded);

  bool _initialized    = false;
  bool _adsEnabled     = true;

  // ── Rewarded Interstitial state ───────────────────────────────────────────
  RewardedInterstitialAd? _rewardedAd;
  bool _rewardedReady   = false;
  bool _rewardedPending = false;
  bool _isShowing       = false;

  // ── Cooldown — prevent multiple ads back to back ──────────────────────────
  DateTime? _lastShown;
  static const _cooldown = Duration(seconds: 60); // min 60sec between ads

  // ── Initialize ────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        testDeviceIds: ['5204E240A3034C8E3DEDD3F2343A89D9'],
      ),
    );
    print('[AdService] initialized — testAds=$_useTestAds  id=$_rewardedId');
    _loadRewarded();
  }

  // ── Subscription control ──────────────────────────────────────────────────
  void setAdsEnabled(bool enabled) {
    _adsEnabled = enabled;
    if (!enabled) {
      _rewardedAd?.dispose();
      _rewardedAd     = null;
      _rewardedReady  = false;
      _rewardedPending = false;
    } else {
      _loadRewarded();
    }
  }

  bool get adsEnabled => _adsEnabled;

  // No banner
  Widget buildBanner() => const SizedBox.shrink();

  // ── Cooldown check ────────────────────────────────────────────────────────
  bool get _canShow {
    if (_lastShown == null) return true;
    return DateTime.now().difference(_lastShown!) >= _cooldown;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOAD
  // ══════════════════════════════════════════════════════════════════════════
  void _loadRewarded() {
    if (!_adsEnabled || !_initialized) return;
    if (_rewardedAd != null) return;

    print('[AdService] loading rewarded interstitial...');

    RewardedInterstitialAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          print('[AdService] rewarded LOADED ✅');
          _rewardedAd   = ad;
          _rewardedReady = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (_) {
              _isShowing  = true;
              _lastShown  = DateTime.now();
              print('[AdService] rewarded SHOWING 🎬');
            },
            onAdDismissedFullScreenContent: (ad) {
              print('[AdService] rewarded dismissed — reloading');
              _isShowing    = false;
              ad.dispose();
              _rewardedAd   = null;
              _rewardedReady = false;
              _loadRewarded(); // preload next
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              print('[AdService] rewarded show FAILED: $err');
              _isShowing    = false;
              ad.dispose();
              _rewardedAd   = null;
              _rewardedReady = false;
              _loadRewarded();
            },
          );

          // If pending show was requested before load completed
          if (_rewardedPending) {
            _rewardedPending = false;
            _showAd();
          }
        },
        onAdFailedToLoad: (err) {
          print('[AdService] rewarded load FAILED: $err');
          _rewardedAd      = null;
          _rewardedReady   = false;
          _rewardedPending = false;
          Future.delayed(const Duration(seconds: 30), _loadRewarded);
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHOW
  // ══════════════════════════════════════════════════════════════════════════
  void _showAd() {
    if (!_adsEnabled || _isShowing) return;
    if (_rewardedReady && _rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (_, reward) {
          print('[AdService] reward earned ✅');
        },
      );
    }
  }

  /// Call this on: Match Start, Wicket, Over Complete
  void showRewardedVideo() {
    if (!_adsEnabled) return;
    print('[AdService] showRewardedVideo — ready=$_rewardedReady  canShow=$_canShow');

    if (!_canShow) {
      print('[AdService] cooldown active — skipping');
      return;
    }

    if (_rewardedReady && _rewardedAd != null) {
      _showAd();
    } else {
      // Ad not ready — mark pending, load now, show when loaded
      _rewardedPending = true;
      _loadRewarded();
    }
  }

  // Keep showInterstitial as alias for compatibility
  void showInterstitial() => showRewardedVideo();
}