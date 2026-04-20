import 'package:app_links/app_links.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants/app_routes.dart';

/// Handles deep link generation, incoming link detection, and WhatsApp sharing.
///
/// Deep link format:
///   cricketscorer://live/{matchCode}
///
/// Universal / fallback web link (Play Store redirect):
///   https://play.google.com/store/apps/details?id=com.yourcompany.cricket_scorer
///
/// For WhatsApp sharing we use a custom scheme that works on devices with the app
/// installed (Android intent filter catches it) and falls back to Play Store for
/// devices without the app.
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._();
  factory DeepLinkService() => _instance;
  DeepLinkService._();

  final _appLinks = AppLinks();

  // ── IMPORTANT: Replace with your actual Play Store package ID ─────────────
  static const String packageId = 'com.asko.score_book';
  static const String scheme = 'scorebook';

  // ── Generate share link ───────────────────────────────────────────────────

  /// Returns the deep link URI string for a match code
  String buildDeepLink(String matchCode) {
    return '$scheme://live/$matchCode';
  }

  /// Returns a Play Store fallback link (used in WhatsApp message body)
  String buildPlayStoreLink() {
    return 'https://play.google.com/store/apps/details?id=$packageId';
  }

  // ── Share via WhatsApp ────────────────────────────────────────────────────

  Future<void> shareToWhatsApp({
    required String matchCode,
    required String password,
    required String teamA,
    required String teamB,
  }) async {
    final deepLink = buildDeepLink(matchCode);
    final playStoreLink = buildPlayStoreLink();

    final message = '''🏏 *LIVE CRICKET SCORE*

*$teamA* vs *$teamB*

📲 Watch live score:
$deepLink

🔐 Password: *$password*

_(No app? Install here: $playStoreLink)_
Match Code: *$matchCode*''';

    await Share.share(message, subject: 'Live Cricket Score - $teamA vs $teamB');
  }

  // ── Listen for incoming deep links (app already open) ────────────────────

  void startListening() {
    // Handle links when app is in foreground
    _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingLink(uri);
    }, onError: (_) {});
  }

  /// Called from splash/main — handles cold-start deep link
  Future<void> handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleIncomingLink(uri);
      }
    } catch (_) {}
  }

  void _handleIncomingLink(Uri uri) {
    // cricketscorer://live/{matchCode}
    if (uri.scheme == scheme && uri.host == 'live') {
      final matchCode = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (matchCode != null && matchCode.isNotEmpty) {
        // Navigate to viewer page
        Get.toNamed(AppRoutes.liveViewer, arguments: matchCode);
      }
    }
  }
}