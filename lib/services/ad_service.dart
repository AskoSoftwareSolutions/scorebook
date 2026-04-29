import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// AD SERVICE
//
// Only ONE ad unit is configured in AdMob console:
//   match_end_interstitial → ca-app-pub-5068572099745859/9112745906 (Interstitial)
//
// No banner. No rewarded. Just this single Interstitial.
// Public API (showRewardedVideo / showInterstitial / buildBanner) is preserved
// so existing call sites continue to compile — but only the Interstitial runs.
// ═══════════════════════════════════════════════════════════════════════════════

class AdService with WidgetsBindingObserver {
  static final AdService _i = AdService._();
  factory AdService() => _i;
  AdService._();

  // ── flip to true during dev to force test creatives ──────────────────────
  static const bool _useTestAds = false;

  // Google official test IDs (used only when _useTestAds = true)
  static const _tInterstitial    = 'ca-app-pub-3940256099942544/1033173712';
  static const _tInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';

  // Production Interstitial ID (match_end_interstitial)
  static const _rInterstitial = 'ca-app-pub-5068572099745859/9112745906';

  static String get _interstitialId => _useTestAds
      ? (Platform.isIOS ? _tInterstitialIos : _tInterstitial)
      : _rInterstitial;

  bool _initialized = false;
  bool _adsEnabled  = true;

  // ── Interstitial state ───────────────────────────────────────────────────
  InterstitialAd? _interstitialAd;
  bool _interstitialReady   = false;
  bool _interstitialPending = false;
  bool _isShowing           = false;

  // ── Cooldown — prevent multiple ads back to back ─────────────────────────
  DateTime? _lastShown;
  static const _cooldown = Duration(seconds: 60); // min 60s between ads

  // ══════════════════════════════════════════════════════════════════════════
  // INITIALIZE
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        testDeviceIds: ['5204E240A3034C8E3DEDD3F2343A89D9'],
      ),
    );
    debugPrint(
      '[AdService] initialized — testAds=$_useTestAds  interstitial=$_interstitialId',
    );
    _loadInterstitial();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SUBSCRIPTION CONTROL
  // ══════════════════════════════════════════════════════════════════════════
  void setAdsEnabled(bool enabled) {
    _adsEnabled = enabled;
    if (!enabled) {
      _interstitialAd?.dispose();
      _interstitialAd      = null;
      _interstitialReady   = false;
      _interstitialPending = false;
    } else {
      _loadInterstitial();
    }
  }

  bool get adsEnabled => _adsEnabled;

  // No banner ads — return empty widget so existing call sites stay safe.
  Widget buildBanner({AdSize size = AdSize.banner}) =>
      const SizedBox.shrink();

  // ── Cooldown check ───────────────────────────────────────────────────────
  bool get _canShow {
    if (_lastShown == null) return true;
    return DateTime.now().difference(_lastShown!) >= _cooldown;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOAD INTERSTITIAL
  // ══════════════════════════════════════════════════════════════════════════
  void _loadInterstitial() {
    if (!_adsEnabled || !_initialized) return;
    if (_interstitialAd != null) return;

    debugPrint('[AdService] loading interstitial...');

    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[AdService] interstitial LOADED');
          _interstitialAd    = ad;
          _interstitialReady = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (_) {
              _isShowing = true;
              _lastShown = DateTime.now();
              debugPrint('[AdService] interstitial SHOWING');
            },
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('[AdService] interstitial dismissed — reloading');
              _isShowing = false;
              ad.dispose();
              _interstitialAd    = null;
              _interstitialReady = false;
              _loadInterstitial(); // preload next
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              debugPrint('[AdService] interstitial show FAILED: $err');
              _isShowing = false;
              ad.dispose();
              _interstitialAd    = null;
              _interstitialReady = false;
              _loadInterstitial();
            },
          );

          // If a show was requested before load completed
          if (_interstitialPending) {
            _interstitialPending = false;
            _showAd();
          }
        },
        onAdFailedToLoad: (err) {
          debugPrint('[AdService] interstitial load FAILED: $err');
          _interstitialAd      = null;
          _interstitialReady   = false;
          _interstitialPending = false;
          Future.delayed(const Duration(seconds: 30), _loadInterstitial);
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHOW
  // ══════════════════════════════════════════════════════════════════════════
  void _showAd() {
    if (!_adsEnabled || _isShowing) return;
    if (_interstitialReady && _interstitialAd != null) {
      _interstitialAd!.show();
    }
  }

  /// Show the interstitial. Silently preloads if not ready.
  void showInterstitial() {
    if (!_adsEnabled) return;
    debugPrint(
      '[AdService] showInterstitial — ready=$_interstitialReady  canShow=$_canShow',
    );

    if (!_canShow) {
      final secs = _lastShown == null
          ? 0
          : DateTime.now().difference(_lastShown!).inSeconds;
      debugPrint('[AdService] cooldown ($secs/${_cooldown.inSeconds}s) — skipping');
      return;
    }

    if (_interstitialReady && _interstitialAd != null) {
      _showAd();
    } else {
      // Ad not ready — mark pending, load now, show when loaded
      _interstitialPending = true;
      _loadInterstitial();
    }
  }

  /// Backwards-compat alias. There is no rewarded ad anymore — this just
  /// shows the standard Interstitial so existing call sites keep working.
  void showRewardedVideo() => showInterstitial();
}
