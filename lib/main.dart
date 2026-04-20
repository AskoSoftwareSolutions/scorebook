import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:scoring_count/services/fcm_service.dart';
import 'package:scoring_count/services/session_service.dart';
import 'package:scoring_count/views/tournament/tournament_poster_view.dart';
import 'firebase_options.dart'; // ✅ FlutterFire generated — run `flutterfire configure`
import 'core/constants/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'repositories/match_repository.dart';
import 'repositories/tournament_repository.dart';              // ← NEW (line 10)
import 'services/deep_link_service.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase Init ─────────────────────────────────────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // ── Load cached user phone from SharedPreferences ────────────────────
  await SessionService().loadCachedPhone();
  // FCM
  await FcmService().initialize();
// ── DEBUG: Print current auth state ───────────────────────────
  final user = FirebaseAuth.instance.currentUser;
  print('🔐 AUTH DEBUG → User: ${user?.uid}');
  print('🔐 AUTH DEBUG → Phone: ${user?.phoneNumber}');
  print('🔐 AUTH DEBUG → Anonymous: ${user?.isAnonymous}');
  // ── Ads & Subscription ───────────────────────────────────────────────────
  await AdService().initialize();
  await SubscriptionService().loadSubscription();

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
  await DeepLinkService().handleInitialLink();

  runApp(const CricketScorerApp());
}

class CricketScorerApp extends StatelessWidget {
  const CricketScorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Cricket Scorer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      initialRoute: AppRoutes.splash,
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
      ],
    );
  }
}