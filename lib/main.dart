import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:scoring_count/services/fcm_service.dart';
import 'package:scoring_count/services/firebase_purge_service.dart';
import 'package:scoring_count/services/session_service.dart';
import 'package:scoring_count/views/tournament/tournament_poster_view.dart';
import 'firebase_options.dart'; // ✅ FlutterFire generated — run `flutterfire configure`
import 'core/constants/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'repositories/match_repository.dart';
import 'repositories/tournament_repository.dart';              // ← NEW (line 10)
import 'services/deep_link_service.dart';
import 'services/network_service.dart';
import 'views/splash/splash_view.dart';
import 'views/home/home_view.dart';
import 'views/create_match/create_match_view.dart';
import 'views/live_scoring/live_scoring_view.dart';
import 'views/live_scoring/confirm_roster_view.dart';
import 'views/match_summary/match_summary_view.dart';
import 'views/match_history/match_history_view.dart';
import 'views/live_viewer/live_viewer_page.dart';
import 'views/watch_live/watch_live_page.dart';
import 'views/settings/settings_page.dart';
import 'views/login/login_page.dart';
import 'views/subscription/subscription_page.dart';
import 'services/ad_service.dart';
import 'services/subscription_service.dart';
import 'views/tournament/tournament_list_view.dart';
import 'views/tournament/tournament_create_view.dart';
import 'views/tournament/tournament_teams_view.dart';
import 'views/tournament/tournament_schedule_view.dart';
import 'views/tournament/tournament_detail_view.dart';
import 'views/tournament/tournament_toss_view.dart';
import 'views/celebration/celebration_share_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase Init ─────────────────────────────────────────────────────────
  // Firebase.initializeApp itself only reads local config — safe offline.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('[main] Firebase init failed/timed out: $e — continuing offline');
  }

  // ── Load cached user phone from SharedPreferences (local only) ───────────
  try {
    await SessionService().loadCachedPhone();
  } catch (e) {
    debugPrint('[main] Session load failed: $e');
  }

  // ── Connectivity monitor — start BEFORE the network-dependent services
  //    so it can already report offline if Firebase websocket fails.
  // ignore: unawaited_futures
  NetworkService().start();

  // ── FCM, Ads, Subscription — every one of these can hang for minutes
  //    on a stalled network. We give each a generous-but-bounded timeout
  //    so the splash screen never gets stuck. Fire-and-forget for the
  //    services that don't need to be ready before the first screen.
  // ── DEBUG: Print current auth state ───────────────────────────
  final user = FirebaseAuth.instance.currentUser;
  print('🔐 AUTH DEBUG → User: ${user?.uid}');
  print('🔐 AUTH DEBUG → Phone: ${user?.phoneNumber}');
  print('🔐 AUTH DEBUG → Anonymous: ${user?.isAnonymous}');

  // FCM — non-blocking. Token registration happens in the background;
  // missing it on a cold offline launch isn't fatal (token refresh
  // listener will kick in once the network returns).
  // ignore: unawaited_futures
  FcmService().initialize().timeout(
    const Duration(seconds: 6),
    onTimeout: () =>
        debugPrint('[main] FCM init timed out — continuing without push'),
  ).catchError((e) =>
      debugPrint('[main] FCM init failed: $e — continuing without push'));

  // Ads — initialize() makes a network call to fetch the SDK config but
  // is generally quick. Bound it anyway so a flaky network can't stall
  // the splash.
  try {
    await AdService().initialize().timeout(const Duration(seconds: 6));
  } catch (e) {
    debugPrint('[main] Ads init failed/timed out: $e — continuing without ads');
  }

  // Subscription — pure Firestore read. Falls back to "no subscription"
  // (= ads enabled) on any error/timeout, which matches the not-logged-in
  // default. Never block the launch on this.
  try {
    await SubscriptionService().loadSubscription().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('[main] Subscription load timed out — continuing offline');
        return null;
      },
    );
  } catch (e) {
    debugPrint('[main] Subscription load failed: $e');
  }

  // ── Portrait only ─────────────────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Edge-to-edge immersive (game-like fullscreen) ────────────────────────
  // Status bar stays visible but transparent so the app theme colour shows
  // through, and the navigation bar blends with the content. Incoming calls
  // / notifications no longer clip the UI — Android keeps overlaying them.
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ── Global dependencies ───────────────────────────────────────────────────
  Get.put<MatchRepository>(MatchRepository(), permanent: true);
  Get.put<TournamentRepository>(TournamentRepository(), permanent: true);  // ← NEW

  // ── Handle cold-start deep link ───────────────────────────────────────────
  try {
    await DeepLinkService()
        .handleInitialLink()
        .timeout(const Duration(seconds: 4));
  } catch (e) {
    debugPrint('[main] Deep link handler failed/timed out: $e');
  }

  // ── Best-effort 14-day Firebase retention sweep (fire-and-forget).
  //    Authoritative cleanup runs in the `purgeOldMatches` Cloud Function;
  //    this client sweep keeps the user's own footprint trim between cron
  //    runs. Never awaited — must never delay app launch.
  // ignore: unawaited_futures
  FirebasePurgeService().sweepIfNeeded();

  runApp(const CricketScorerApp());
}

class CricketScorerApp extends StatelessWidget {
  const CricketScorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'ScoreBook',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      initialRoute: AppRoutes.splash,
      // Wrap every route in a Stack so the offline banner can overlay
      // the top of any screen without each view having to opt in.
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GlobalOfflineBanner(),
            ),
          ],
        );
      },
      getPages: [
        GetPage(name: AppRoutes.splash,       page: () => const SplashView()),
        GetPage(name: AppRoutes.home,         page: () => const HomeView()),
        GetPage(name: AppRoutes.createMatch,  page: () => const CreateMatchView()),
        GetPage(name: AppRoutes.liveScoring,  page: () => const LiveScoringView()),
        GetPage(name: AppRoutes.matchSummary, page: () => const MatchSummaryView()),
        GetPage(name: AppRoutes.matchHistory, page: () => const MatchHistoryView()),
        GetPage(name: AppRoutes.liveViewer,   page: () => const LiveViewerPage()),
        GetPage(name: AppRoutes.watchLive,    page: () => const WatchLivePage()),
        GetPage(name: AppRoutes.confirmRoster, page: () => const ConfirmRosterView()),
        GetPage(name: AppRoutes.settings,     page: () => const SettingsPage()),
        GetPage(name: AppRoutes.login,        page: () => const LoginPage()),
        GetPage(name: AppRoutes.subscription, page: () => const SubscriptionPage()),
        GetPage(name: AppRoutes.tournamentList,     page: () => const TournamentListView()),
        GetPage(name: AppRoutes.tournamentCreate,   page: () => const TournamentCreateView()),
        GetPage(name: AppRoutes.tournamentTeams,    page: () => const TournamentTeamsView()),
        GetPage(name: AppRoutes.tournamentSchedule, page: () => const TournamentScheduleView()),
        GetPage(name: AppRoutes.tournamentDetail,   page: () => const TournamentDetailView()),
        GetPage(name: AppRoutes.tournamentToss, page: () => const TournamentTossView()),
        GetPage(name: AppRoutes.tournamentPoster, page: () => const TournamentPosterView()),
        GetPage(name: AppRoutes.celebration, page: () => const CelebrationShareView()),
      ],
    );
  }
}