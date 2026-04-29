import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/constants/app_routes.dart';
import '../../services/ad_service.dart';
import '../../core/theme/app_theme.dart';
import '../../services/join_scorer_service.dart';
import '../../services/session_service.dart';
import '../../services/match_cloud_pull_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../repositories/match_repository.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/app_widgets.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  ActiveMatchInfo? _active;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    // Check active scoring match
    final info = await SessionService().getActiveMatch();
    if (info != null && mounted) {
      setState(() => _active = info);
    }

    // ── Stale-resume guard: if this match was already finished elsewhere
    //    (another scorer device completed innings 2 + closed the match),
    //    silently clear the local resume pointer so we don't offer a
    //    Resume button that would let the user re-score innings 2.
    if (info != null) {
      // ignore: unawaited_futures
      _verifyActiveStillInProgress(info.matchId);
    }

    // ── Auto-rejoin watch live if session exists ─────────────────────────────
    final watchInfo = await SessionService().getWatchLive();
    if (watchInfo != null && mounted) {
      // Small delay so home page renders first
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          Get.toNamed(
            AppRoutes.liveViewer,
            arguments: {
              'matchCode':     watchInfo.matchCode,
              'authenticated': true,
            },
          );
        }
      });
    }
  }

  /// Best-effort cloud check — if the cloud says this match is completed
  /// (because another device finished innings 2), pull the final state into
  /// local SQLite, mark local as completed, and clear the resume pointer.
  /// Errors are swallowed; offline users still see the Resume button.
  Future<void> _verifyActiveStillInProgress(int localId) async {
    try {
      final cloud = MatchCloudPullService();
      final code = await cloud.cloudCodeFor(localId);
      if (code == null || code.isEmpty) return;
      final data = await FirebaseSyncService().getMatchData(code);
      final status = (data?['status'] as String?) ?? '';
      if (status != 'completed') return;

      // Pull the final cloud snapshot into local DB so summary/history are
      // correct, then mark local match completed and clear the resume.
      await cloud.pullIntoLocal(code);
      try {
        final repo = Get.isRegistered<MatchRepository>()
            ? Get.find<MatchRepository>()
            : MatchRepository();
        final m = await repo.getMatch(localId);
        if (m != null && m.status != AppConstants.matchStatusCompleted) {
          await repo.updateMatch(m.copyWith(
            status: AppConstants.matchStatusCompleted,
            result: (data?['result'] as String?) ?? m.result,
          ));
        }
      } catch (_) {}
      await SessionService().clearActiveMatch();
      if (mounted) setState(() => _active = null);
    } catch (_) {/* offline — leave Resume visible */}
  }

  void _resume() {
    if (_active == null) return;
    Get.toNamed(AppRoutes.liveScoring, arguments: _active!.matchId);
  }

  Future<void> _dismissResume() async {
    await SessionService().clearActiveMatch();
    if (mounted) setState(() => _active = null);
  }

  Future<bool> _confirmExitApp(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app_rounded,
                color: AppTheme.warning, size: 22),
            SizedBox(width: 10),
            Text('Exit App?',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
          'Close Cricket Scorer?',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Exit',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final exit = await _confirmExitApp(context);
        if (exit) SystemNavigator.pop();
      },
      child: SafeArea(
      top: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.bgDark, AppTheme.bgCard],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            top: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ────────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppTheme.greenGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            "assets/logo/app_icon.png",
                            width: 45,
                            height: 45,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ScoreBook',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const Text('Offline Scoring App',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.settings_rounded,
                            color: AppTheme.textSecondary, size: 22),
                        onPressed: () => Get.toNamed(AppRoutes.settings),
                        tooltip: 'Settings',
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Resume banner ─────────────────────────────────────
                  if (_active != null) ...[
                    _ResumeBanner(
                      info: _active!,
                      onResume: _resume,
                      onDismiss: _dismissResume,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Hero new-match card ───────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppTheme.greenGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🏆 Ready to Score?',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        const Text(
                          'Start a new match and track every ball with live scoring, player stats, and auto PDF reports.',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => Get.toNamed(AppRoutes.createMatch),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_circle_outline,
                                    color: Colors.black87, size: 20),
                                SizedBox(width: 8),
                                Text('New Match',
                                    style: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Watch Live card ───────────────────────────────────
                  const _WatchLiveCard(),
                  const SizedBox(height: 12),
                  const _JoinMatchCard(),

                  const SizedBox(height: 20),

                  // ── Quick actions ─────────────────────────────────────
                  const SectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: 14),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _ActionCard(
                        icon: Icons.add_circle_outline,
                        label: 'New Match',
                        subtitle: 'Start scoring',
                        color: AppTheme.primary,
                        onTap: () => Get.toNamed(AppRoutes.createMatch),
                      ),
                      _ActionCard(
                        icon: Icons.history,
                        label: 'Match History',
                        subtitle: 'Past matches',
                        color: const Color(0xFF1565C0),
                        onTap: () => Get.toNamed(AppRoutes.matchHistory),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),
                  // ── Tournament card ─────────────────────────────────────────
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Get.toNamed(AppRoutes.tournamentList),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppTheme.accent.withOpacity(0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Row(children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.emoji_events_rounded,
                              color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tournaments',
                                  style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800)),
                              SizedBox(height: 3),
                              Text('Host multi-team tournaments with auto-scheduling',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.arrow_forward_ios_rounded,
                              color: AppTheme.accent, size: 14),
                        ),
                      ]),
                    ),
                  ),
                  // ── Features ──────────────────────────────────────────
                  const SectionHeader(title: 'Features'),
                  const SizedBox(height: 14),
                  _feat('⚡', 'Live Ball-by-Ball Scoring', 'All run types, extras & wickets'),
                  _feat('📊', 'Player Statistics', 'Batting & bowling stats in real-time'),
                  _feat('📄', 'PDF Match Report', 'Professional scorecard PDF'),
                  _feat('📤', 'WhatsApp Share', 'Share results instantly'),
                  _feat('🌐', 'Watch Live Anywhere', 'Code + password → live scoreboard'),
                  _feat('💾', '100% Offline', 'No internet required, SQLite storage'),
                  _feat('↩️', 'Undo Ball', 'Correct scoring mistakes easily'),
                  _feat('🔄', 'Auto Resume', 'Match resumes even after app is killed'),

                  const SizedBox(height: 16),
                  // ── Banner Ad ─────────────────────────────────────────
                  Center(child: AdService().buildBanner()),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _feat(String emoji, String title, String sub) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.bgCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.borderColor),
    ),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 24)),
      const SizedBox(width: 14),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            Text(sub,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ])),
    ]),
  );
}

// ── Resume Banner ─────────────────────────────────────────────────────────────
class _ResumeBanner extends StatelessWidget {
  final ActiveMatchInfo info;
  final VoidCallback onResume;
  final VoidCallback onDismiss;

  const _ResumeBanner(
      {required this.info, required this.onResume, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warning.withOpacity(0.55), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: badge + dismiss
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(children: [
                Icon(Icons.radio_button_checked,
                    color: AppTheme.warning, size: 10),
                SizedBox(width: 4),
                Text('LIVE MATCH',
                    style: TextStyle(
                        color: AppTheme.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1)),
              ]),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close,
                  color: AppTheme.textSecondary, size: 18),
            ),
          ]),

          const SizedBox(height: 10),

          // Teams
          Text('${info.teamA}  vs  ${info.teamB}',
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text('${info.totalOvers} overs  •  In Progress',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),

          const SizedBox(height: 12),

          // Resume button
          GestureDetector(
            onTap: onResume,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: AppTheme.greenGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 6),
                  Text('Resume Match',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Action Card ─────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard(
      {required this.icon,
        required this.label,
        required this.subtitle,
        required this.color,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const Spacer(),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          Text(subtitle,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
        ]),
      ),
    );
  }
}

// ── Watch Live Score Card ─────────────────────────────────────────────────────

class _WatchLiveCard extends StatelessWidget {
  const _WatchLiveCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.watchLive),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.primaryLight.withOpacity(0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryLight.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryLight.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.cell_tower_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text(
                      'Watch Live Score',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: Colors.red.withOpacity(0.3)),
                      ),
                      child: const Text('LIVE',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          )),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  const Text(
                    'Enter match code + password to watch',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Arrow
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppTheme.primaryLight, size: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinMatchCard extends StatelessWidget {
  const _JoinMatchCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showJoinSheet(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.accent.withOpacity(0.35),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.group_add_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Join Existing Match',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 3),
                  Text('Enter match code and score together',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12)),
                ],
              ),
            ),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppTheme.accent, size: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinSheet(BuildContext context) {
    final codeCtrl = TextEditingController();
    final pwCtrl   = TextEditingController();
    bool loading   = false;
    bool obscure   = true;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.group_add_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Join Match',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      Text('Enter match code & password',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                    ],
                  ),
                ]),

                const SizedBox(height: 20),

                // Match Code
                const Text('MATCH CODE',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
                const SizedBox(height: 8),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. CS-CHMU-4821',
                    hintStyle: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.4),
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        letterSpacing: 1),
                    filled: true,
                    fillColor: AppTheme.bgSurface,
                    prefixIcon: const Icon(Icons.tag_rounded,
                        color: AppTheme.primary, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primary, width: 1.5),
                    ),
                  ),
                  onChanged: (_) => setState(() => error = null),
                ),

                const SizedBox(height: 14),

                // Password
                const Text('PASSWORD',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
                const SizedBox(height: 8),
                TextField(
                  controller: pwCtrl,
                  obscureText: obscure,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    letterSpacing: 3,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••',
                    filled: true,
                    fillColor: AppTheme.bgSurface,
                    prefixIcon: const Icon(Icons.lock_rounded,
                        color: AppTheme.textSecondary, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: AppTheme.textSecondary, size: 20,
                      ),
                      onPressed: () =>
                          setState(() => obscure = !obscure),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primary, width: 1.5),
                    ),
                  ),
                  onChanged: (_) => setState(() => error = null),
                ),

                // Error
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.error.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(error!,
                            style: const TextStyle(
                                color: AppTheme.error,
                                fontSize: 12)),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 20),

                // Buttons
                Row(children: [
                  // Watch only
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppTheme.borderColor),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: loading ? null : () {
                        final code = codeCtrl.text
                            .trim().toUpperCase();
                        if (code.isEmpty) {
                          setState(() =>
                          error = 'Enter match code');
                          return;
                        }
                        Navigator.pop(ctx);
                        Get.toNamed(
                          AppRoutes.liveViewer,
                          arguments: {
                            'matchCode': code,
                            'authenticated': true,
                          },
                        );
                      },
                      icon: const Icon(Icons.visibility_rounded,
                          size: 16),
                      label: const Text('Watch',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Score
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: loading ? null : () async {
                        final code = codeCtrl.text
                            .trim().toUpperCase();
                        final pw = pwCtrl.text.trim();

                        if (code.isEmpty) {
                          setState(() =>
                          error = 'Enter match code');
                          return;
                        }
                        if (pw.isEmpty) {
                          setState(() =>
                          error = 'Enter password');
                          return;
                        }

                        setState(() {
                          loading = true;
                          error = null;
                        });

                        final err = await JoinScorerService()
                            .joinAsScorer(code, pw);

                        if (err != null) {
                          setState(() {
                            loading = false;
                            error = err;
                          });
                        }
                      },
                      icon: loading
                          ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white),
                      )
                          : const Icon(
                          Icons.sports_cricket_rounded,
                          color: Colors.white, size: 18),
                      label: Text(
                        loading ? 'Loading...' : 'Start Scoring',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}