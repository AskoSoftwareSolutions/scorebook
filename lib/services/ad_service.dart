import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// AD SERVICE
//
// AdMob units (production):
//   Banner       → ca-app-pub-5068572099745859/5786908322 (scorebook_ads)
//   Interstitial → ca-app-pub-5068572099745859/7680087268 (score_book_interstitial)
//   Rewarded     → ca-app-pub-5068572099745859/7663096771 (score_book_reward)
//
// NOTE: If "Partner bidding" checkbox is ticked in AdMob console for any of
//       these units, standard AdMob demand will NOT fill them. Uncheck it
//       unless you're using a third-party mediation platform.
// ═══════════════════════════════════════════════════════════════════════════════

class AdService with WidgetsBindingObserver {
  static final AdService _i = AdService._();
  factory AdService() => _i;
  AdService._();

  // ── flip to true during dev to force test creatives ──────────────────────
  static const bool _useTestAds = false;

  // Google official test IDs
  static const _tBanner        = 'ca-app-pub-3940256099942544/6300978111';
  static const _tBannerIos     = 'ca-app-pub-3940256099942544/2934735716';
  static const _tInterstitial  = 'ca-app-pub-3940256099942544/1033173712';
  static const _tInterstitialI = 'ca-app-pub-3940256099942544/4411468910';
  static const _tRewarded      = 'ca-app-pub-3940256099942544/5224354917';
  static const _tRewardedIos   = 'ca-app-pub-3940256099942544/1712485313';

  // Production IDs
  static const _rBanner       = 'ca-app-pub-5068572099745859/5786908322';
  static const _rInterstitial = 'ca-app-pub-5068572099745859/7680087268';
  static const _rRewarded     = 'ca-app-pub-5068572099745859/7663096771';

  static String get _bannerId => _useTestAds
      ? (Platform.isIOS ? _tBannerIos : _tBanner)
      : _rBanner;
  static String get _interstitialId => _useTestAds
      ? (Platform.isIOS ? _tInterstitialI : _tInterstitial)
      : _rInterstitial;
  static String get _rewardedId => _useTestAds
      ? (Platform.isIOS ? _tRewardedIos : _tRewarded)
      : _rRewarded;

  bool _initialized = false;
  bool _adsEnabled  = true;

  // ── Interstitial ──────────────────────────────────────────────────────────
  InterstitialAd? _interstitialAd;
  bool _interstitialReady   = false;
  bool _interstitialPending = false;

  // ── Rewarded ──────────────────────────────────────────────────────────────
  RewardedAd? _rewardedAd;
  bool _rewardedReady   = false;
  bool _rewardedPending = false;

  bool _isShowing = false;

  // ── Cooldown ──────────────────────────────────────────────────────────────
  DateTime? _lastShown;
  static const _cooldown = Duration(seconds: 45);

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
        '[AdService] initialized — testAds=$_useTestAds  '
        'banner=$_bannerId  interstitial=$_interstitialId  rewarded=$_rewardedId');
    _loadInterstitial();
    _loadRewarded();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SUBSCRIPTION CONTROL
  // ══════════════════════════════════════════════════════════════════════════
  void setAdsEnabled(bool enabled) {
    _adsEnabled = enabled;
    if (!enabled) {
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _interstitialReady = false;
      _interstitialPending = false;

      _rewardedAd?.dispose();
      _rewardedAd = null;
      _rewardedReady = false;
      _rewardedPending = false;
    } else {
      _loadInterstitial();
      _loadRewarded();
    }
  }

  bool get adsEnabled => _adsEnabled;

  bool get _canShow {
    if (_lastShown == null) return true;
    return DateTime.now().difference(_lastShown!) >= _cooldown;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BANNER — real AdMob banner widget
  // ══════════════════════════════════════════════════════════════════════════
  Widget buildBanner({AdSize size = AdSize.banner}) {
    if (!_adsEnabled) return const SizedBox.shrink();
    return _BannerAdWidget(adUnitId: _bannerId, size: size);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERSTITIAL
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
          _interstitialAd = ad;
          _interstitialReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (_) {
              _isShowing = true;
              _lastShown = DateTime.now();
            },
            onAdDismissedFullScreenContent: (ad) {
              _isShowing = false;
              ad.dispose();
              _interstitialAd = null;
              _interstitialReady = false;
              _loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              debugPrint('[AdService] interstitial show FAILED: $err');
              _isShowing = false;
              ad.dispose();
              _interstitialAd = null;
              _interstitialReady = false;
              _loadInterstitial();
            },
          );
          if (_interstitialPending) {
            _interstitialPending = false;
            _showInterstitial();
          }
        },
        onAdFailedToLoad: (err) {
          debugPrint('[AdService] interstitial load FAILED: $err');
          _interstitialAd = null;
          _interstitialReady = false;
          _interstitialPending = false;
          Future.delayed(const Duration(seconds: 30), _loadInterstitial);
        },
      ),
    );
  }

  void _showInterstitial() {
    if (!_adsEnabled || _isShowing) return;
    if (_interstitialReady && _interstitialAd != null) {
      _interstitialAd!.show();
    }
  }

  /// Fire-and-forget interstitial. Silently preloads if not ready.
  void showInterstitial() {
    if (!_adsEnabled) return;
    if (!_canShow) {
      debugPrint('[AdService] cooldown — skipping interstitial');
      return;
    }
    if (_interstitialReady && _interstitialAd != null) {
      _showInterstitial();
    } else {
      _interstitialPending = true;
      _loadInterstitial();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REWARDED
  // ══════════════════════════════════════════════════════════════════════════
  void _loadRewarded() {
    if (!_adsEnabled || !_initialized) return;
    if (_rewardedAd != null) return;
    debugPrint('[AdService] loading rewarded...');
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[AdService] rewarded LOADED');
          _rewardedAd = ad;
          _rewardedReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (_) {
              _isShowing = true;
              _lastShown = DateTime.now();
            },
            onAdDismissedFullScreenContent: (ad) {
              _isShowing = false;
              ad.dispose();
              _rewardedAd = null;
              _rewardedReady = false;
              _loadRewarded();
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              debugPrint('[AdService] rewarded show FAILED: $err');
              _isShowing = false;
              ad.dispose();
              _rewardedAd = null;
              _rewardedReady = false;
              _loadRewarded();
            },
          );
          if (_rewardedPending) {
            _rewardedPending = false;
            _showRewarded();
          }
        },
        onAdFailedToLoad: (err) {
          debugPrint('[AdService] rewarded load FAILED: $err');
          _rewardedAd = null;
          _rewardedReady = false;
          _rewardedPending = false;
          Future.delayed(const Duration(seconds: 30), _loadRewarded);
        },
      ),
    );
  }

  void _showRewarded() {
    if (!_adsEnabled || _isShowing) return;
    if (_rewardedReady && _rewardedAd != null) {
      _rewardedAd!.show(onUserEarnedReward: (_, __) {});
    }
  }

  /// Show rewarded; falls back to interstitial if rewarded not available.
  void showRewardedVideo() {
    if (!_adsEnabled) return;
    if (!_canShow) {
      debugPrint('[AdService] cooldown — skipping rewarded');
      return;
    }
    if (_rewardedReady && _rewardedAd != null) {
      _showRewarded();
    } else if (_interstitialReady && _interstitialAd != null) {
      debugPrint('[AdService] rewarded not ready → interstitial fallback');
      _showInterstitial();
    } else {
      _rewardedPending = true;
      _loadRewarded();
      _loadInterstitial();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BANNER WIDGET
// ═══════════════════════════════════════════════════════════════════════════════
class _BannerAdWidget extends StatefulWidget {
  final String adUnitId;
  final AdSize size;
  const _BannerAdWidget({required this.adUnitId, required this.size});

  @override
  State<_BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<_BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: widget.size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('[AdService] banner load FAILED: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox(height: 0);
    return SizedBox(
      width: widget.size.width.toDouble(),
      height: widget.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
