import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/tournament_models.dart';
import '../../repositories/tournament_repository.dart';
import '../../services/firebase_sync_service.dart';
import '../../services/ad_service.dart';
import '../../services/session_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// LIVE VIEWER PAGE — Premium Redesign
// Deep link: cricketscorer://live/{matchCode}
// ═══════════════════════════════════════════════════════════════════════════════

class LiveViewerPage extends StatefulWidget {
  const LiveViewerPage({super.key});
  @override
  State<LiveViewerPage> createState() => _LiveViewerPageState();
}

class _LiveViewerPageState extends State<LiveViewerPage>
    with TickerProviderStateMixin {
  // Arguments can be:
  //   String         → matchCode (from deep link, needs password gate)
  //   Map            → {'matchCode': '...', 'authenticated': true} (from WatchLivePage)
  late final String matchCode;
  late final bool   _preAuthenticated;

  final _sync = FirebaseSyncService();

  late TabController _tabController;
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _pulse;
  late Animation<double> _fadeIn;

  // State machine
  bool _loadingMeta   = true;
  bool _notFound      = false;
  bool _authenticated = false;
  bool _authChecking  = false;
  Map<String, dynamic>? _data;
  DateTime? _lastUpdated;
  String? _authError;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();

    // Parse arguments
    final args = Get.arguments;
    if (args is Map) {
      matchCode         = (args['matchCode'] as String?) ?? '';
      _preAuthenticated = (args['authenticated'] as bool?) ?? false;
    } else {
      matchCode         = args as String? ?? '';
      _preAuthenticated = false;
    }

    _tabController = TabController(length: 4, vsync: this);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _checkMatch();
  }

  // ── Leave confirmation dialog (used by AppBar + system back) ───────────────
  Future<void> _handleLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Match?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text(
            'Do you want to leave? You can rejoin anytime with the same code.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Stay',
              style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Leave',
              style: TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
    );
    if (leave == true) {
      await SessionService().clearWatchLive();
      // We may have been pushed here via Get.offAllNamed (e.g. lock-stolen
      // auto-redirect from live scoring). In that case the nav stack only
      // has us on it, so Get.back() has nowhere to go and the page locks.
      // Always route home explicitly so both deep-link entry and takeover
      // entry exit cleanly.
      Get.offAllNamed(AppRoutes.home);
    }
  }

  Future<void> _checkMatch() async {
    final exists = await _sync.matchExists(matchCode);
    if (!mounted) return;
    if (!exists) {
      setState(() { _loadingMeta = false; _notFound = true; });
      return;
    }
    setState(() => _loadingMeta = false);

    // ── No password required — authenticate directly ──────────────────────
    setState(() => _authenticated = true);
    _startListening();
  }

  Future<void> _submitPassword(String input) async {
    setState(() { _authChecking = true; _authError = null; });
    final ok = await _sync.verifyPassword(matchCode, input.trim());
    if (!mounted) return;
    if (ok) {
      setState(() { _authChecking = false; _authenticated = true; });
      _startListening();
    } else {
      HapticFeedback.heavyImpact();
      setState(() { _authChecking = false; _authError = 'Incorrect password'; });
    }
  }

  // Track previous values to detect changes
  int _prevWickets    = -1;
  int _prevBalls      = -1;
  int _prevInnings    = -1;

  void _startListening() {
    _sub = _sync.liveStream(matchCode).listen((event) {
      if (!mounted) return;
      if (event.snapshot.value != null) {
        final wasNull = _data == null;
        final newData = Map<String, dynamic>.from(event.snapshot.value as Map);

        // ── Detect milestones for ad triggers ────────────────────────────
        if (!wasNull && _data != null) {
          final newWickets = (newData['wickets']        as int?) ?? 0;
          final newBalls   = (newData['totalBalls']     as int?) ?? 0;
          final newInnings = (newData['currentInnings'] as int?) ?? 1;

          // Innings flip resets cloud counters from (e.g.) 119/8 to 0/0.
          // Without this branch, `newWickets > _prevWickets` would be false
          // for the entire innings 2, suppressing ads. Re-baseline first.
          if (_prevInnings != -1 && newInnings != _prevInnings) {
            debugPrint('[LiveViewer] innings flip $_prevInnings→$newInnings — re-baselining ad counters');
            _prevWickets = newWickets;
            _prevBalls   = newBalls;
            _prevInnings = newInnings;
          } else {
            // Wicket fell
            final wicketFell =
                _prevWickets >= 0 && newWickets > _prevWickets;
            // Over crossed: compare completed-over count rather than
            // exact `newBalls % 6 == 0`, since Firebase can batch
            // multiple balls into a single snapshot (e.g. 5 → 7) and
            // skip the modulo check entirely.
            final overCrossed = _prevBalls >= 0 &&
                newBalls > _prevBalls &&
                (newBalls ~/ 6) > (_prevBalls ~/ 6);

            if (wicketFell) {
              debugPrint('[LiveViewer] WICKET ($_prevWickets → $newWickets) — requesting ad');
              AdService().showRewardedVideo();
            } else if (overCrossed) {
              debugPrint('[LiveViewer] OVER COMPLETE ($_prevBalls → $newBalls) — requesting ad');
              AdService().showRewardedVideo();
            }
            _prevWickets = newWickets;
            _prevBalls   = newBalls;
            _prevInnings = newInnings;
          }
        } else if (wasNull) {
          // Init values on first load. We deliberately DO NOT fire an
          // initial "welcome" ad here anymore — it used to start the
          // 18 s cooldown immediately and swallow the very next wicket
          // or over, which is exactly when viewers expect the ad to play.
          _prevWickets = (newData['wickets']        as int?) ?? 0;
          _prevBalls   = (newData['totalBalls']     as int?) ?? 0;
          _prevInnings = (newData['currentInnings'] as int?) ?? 1;
          debugPrint('[LiveViewer] baseline set — wickets=$_prevWickets balls=$_prevBalls inn=$_prevInnings');
        }

        setState(() {
          _data        = newData;
          _lastUpdated = DateTime.now();
        });
        if (wasNull) _fadeCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingMeta) return const _FullScreenLoader();
    if (_notFound)    return _NotFoundScreen(matchCode: matchCode);

    if (!_authenticated || _data == null) {
      return _PasswordGatePage(
        matchCode: matchCode,
        onSubmit: _submitPassword,
        isLoading: _authChecking,
        error: _authError,
      );
    }

    return FadeTransition(
      opacity: _fadeIn,
      child: _LiveScoreboardPage(
        data: _data!,
        matchCode: matchCode,
        lastUpdated: _lastUpdated,
        tabController: _tabController,
        pulse: _pulse,
        onLeave: _handleLeave,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PASSWORD GATE PAGE
// ═══════════════════════════════════════════════════════════════════════════════

class _PasswordGatePage extends StatefulWidget {
  final String matchCode;
  final Future<void> Function(String) onSubmit;
  final bool isLoading;
  final String? error;
  const _PasswordGatePage({
    required this.matchCode, required this.onSubmit,
    required this.isLoading, this.error,
  });
  @override
  State<_PasswordGatePage> createState() => _PasswordGatePageState();
}

class _PasswordGatePageState extends State<_PasswordGatePage>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  bool _obscure = true;
  late AnimationController _shakeCtrl;
  late Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shake = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_PasswordGatePage old) {
    super.didUpdateWidget(old);
    if (widget.error != null && old.error != widget.error) {
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Cricket icon ─────────────────────────────────────────────
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E7D32).withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.sports_cricket,
                        color: Colors.white, size: 36),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Live Score',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Match code pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Text(
                      widget.matchCode,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Password card ─────────────────────────────────────────────
                  AnimatedBuilder(
                    animation: _shake,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(_shake.value, 0),
                      child: child,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: widget.error != null
                              ? AppTheme.error.withOpacity(0.5)
                              : AppTheme.borderColor,
                          width: widget.error != null ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: const [
                            Icon(Icons.lock_rounded,
                                color: AppTheme.textSecondary, size: 15),
                            SizedBox(width: 7),
                            Text('ENTER PASSWORD',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                )),
                          ]),
                          const SizedBox(height: 14),

                          // Password field
                          TextField(
                            controller: _ctrl,
                            obscureText: _obscure,
                            autofocus: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => widget.onSubmit(_ctrl.text),
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: InputDecoration(
                              hintText: '••••',
                              hintStyle: TextStyle(
                                color: AppTheme.textSecondary.withOpacity(0.4),
                                letterSpacing: 6,
                                fontSize: 16,
                              ),
                              filled: true,
                              fillColor: AppTheme.bgSurface,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: AppTheme.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),

                          // Error
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            child: widget.error != null
                                ? Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(children: [
                                const Icon(Icons.error_rounded,
                                    color: AppTheme.error, size: 14),
                                const SizedBox(width: 6),
                                Text(widget.error!,
                                    style: const TextStyle(
                                        color: AppTheme.error,
                                        fontSize: 12)),
                              ]),
                            )
                                : const SizedBox.shrink(),
                          ),

                          const SizedBox(height: 18),

                          // Submit button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1B5E20),
                                    Color(0xFF2E7D32),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2E7D32)
                                        .withOpacity(0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: widget.isLoading
                                    ? null
                                    : () => widget.onSubmit(_ctrl.text),
                                child: widget.isLoading
                                    ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                    : const Text(
                                  'Watch Live',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'Ask the scorer for the password',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN SCOREBOARD
// ═══════════════════════════════════════════════════════════════════════════════

class _LiveScoreboardPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final String matchCode;
  final DateTime? lastUpdated;
  final TabController tabController;
  final Animation<double> pulse;
  final VoidCallback onLeave;

  const _LiveScoreboardPage({
    required this.data, required this.matchCode,
    required this.lastUpdated, required this.tabController,
    required this.pulse, required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = (data['status'] ?? '') != 'completed';
    final teamA  = data['teamA'] ?? '';
    final teamB  = data['teamB'] ?? '';

    return PopScope(
      canPop: false, // prevent default back — we handle it
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onLeave();
      },
      child: SafeArea(
        top: false,
        child: Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: NestedScrollView(
            headerSliverBuilder: (ctx, _) => [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppTheme.bgCard,
                elevation: 0,
                expandedHeight: 64,
                titleSpacing: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: AppTheme.textPrimary),
                  onPressed: onLeave,
                ),
                title: Row(children: [
                  // Live / Ended badge
                  AnimatedBuilder(
                    animation: pulse,
                    builder: (_, __) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isLive
                            ? Colors.red.withOpacity(0.15 + 0.10 * pulse.value)
                            : Colors.grey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isLive
                              ? Colors.red.withOpacity(0.4)
                              : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      child: Row(children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isLive
                                ? Colors.red.withOpacity(
                                0.6 + 0.4 * pulse.value)
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isLive ? 'LIVE' : 'ENDED',
                          style: TextStyle(
                            color: isLive ? Colors.red : Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      '$teamA vs $teamB',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                actions: [
                  if (lastUpdated != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.sync_rounded,
                              color: AppTheme.success, size: 13),
                          const SizedBox(height: 1),
                          Text(
                            DateFormat('HH:mm:ss').format(lastUpdated!),
                            style: const TextStyle(
                                color: AppTheme.success, fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                ],
                bottom: TabBar(
                  controller: tabController,
                  indicatorColor: AppTheme.primaryLight,
                  indicatorWeight: 2.5,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: AppTheme.primaryLight,
                  unselectedLabelColor: AppTheme.textSecondary,
                  labelStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      letterSpacing: 0.8),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'SCORE'),
                    Tab(text: 'BATTING'),
                    Tab(text: 'BOWLING'),
                    Tab(text: 'LOG'),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              controller: tabController,
              children: [
                _ScoreTab(data: data, pulse: pulse),
                _BattingTab(data: data),
                _BowlingTab(data: data),
                _BallLogTab(data: data),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — SCORE
// ═══════════════════════════════════════════════════════════════════════════════

class _ScoreTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final Animation<double> pulse;
  const _ScoreTab({required this.data, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final teamA       = data['teamA'] ?? '';
    final teamB       = data['teamB'] ?? '';
    final battingTeam = data['battingTeam'] ?? '';
    final score       = data['score'] ?? 0;
    final wickets     = data['wickets'] ?? 0;
    final totalBalls  = data['totalBalls'] ?? 0;
    final totalOvers  = data['totalOvers'] ?? 0;
    final currentOver = data['currentOver'] ?? 0;
    final ballsInOver = data['ballsInOver'] ?? 0;
    final innings     = data['currentInnings'] ?? 1;
    final striker     = data['striker'] ?? '';
    final nonStriker  = data['nonStriker'] ?? '';
    final bowler      = data['bowler'] ?? '';
    final crr    = (data['crr'] as num?)?.toDouble() ?? 0.0;
    final rrr    = (data['rrr'] as num?)?.toDouble() ?? 0.0;
    final target      = data['target'] ?? 0;
    final runsNeeded  = data['runsNeeded'] ?? 0;
    final ballsLeft   = data['ballsLeft'] ?? 0;
    final inn1Score   = data['inn1Score'] ?? 0;
    final inn1Wkts    = data['inn1Wickets'] ?? 0;
    final wides       = data['wides'] ?? 0;
    final noBalls     = data['noBalls'] ?? 0;
    final byes        = data['byes'] ?? 0;
    final legByes     = data['legByes'] ?? 0;
    final partnerRuns = data['partnerRuns'] ?? 0;
    final partnerBalls = data['partnerBalls'] ?? 0;
    final status      = data['status'] ?? '';
    final isCompleted = status == 'completed';

    final overs = '${totalBalls ~/ 6}.${totalBalls % 6}';

    final currentOverBalls = ((data['currentOverBalls'] as List?) ?? [])
        .map((b) => Map<String, dynamic>.from(b as Map))
        .toList();

    final tournamentId      = data['tournamentId']      as String? ?? '';
    final tournamentMatchId = data['tournamentMatchId'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── Next-match banner (only if this live match is part of a
          //    tournament — helps viewers plan which game to watch next) ──
          if (tournamentId.isNotEmpty)
            _NextMatchBanner(
              tournamentId: tournamentId,
              currentMatchId: tournamentMatchId,
            ),

          // ── Target banner (2nd innings) ─────────────────────────────────
          if (innings == 2)
            _LabelBanner(
              icon: Icons.flag_rounded,
              text:
              '${battingTeam == teamA ? teamB : teamA} scored  $inn1Score/$inn1Wkts  ·  Target: $target',
              color: AppTheme.warning,
            ),

          if (innings == 2) const SizedBox(height: 10),

          // ── Big score card ─────────────────────────────────────────────
          _GlassCard(
            child: Column(children: [
              // Teams
              Row(children: [
                _TeamChip(name: teamA, active: battingTeam == teamA),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('vs',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                ),
                _TeamChip(name: teamB, active: battingTeam == teamB),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Text('INN $innings',
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ),
              ]),

              const SizedBox(height: 20),

              // Score
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$score',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: -2,
                      )),
                  Text('/$wickets',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        height: 1.6,
                      )),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$overs / $totalOvers ov',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          )),
                      Text('Ov ${currentOver + 1}, Ball $ballsInOver',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          )),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const _Divider(),
              const SizedBox(height: 14),

              // Rates
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _RateBox(label: 'CRR', value: crr.toStringAsFixed(2)),
                  if (innings == 2 && !isCompleted) ...[
                    Container(width: 1, height: 28, color: AppTheme.borderColor),
                    _RateBox(
                      label: 'Need',
                      value: '$runsNeeded off $ballsLeft',
                      valueColor: AppTheme.warning,
                    ),
                    Container(width: 1, height: 28, color: AppTheme.borderColor),
                    _RateBox(
                      label: 'RRR',
                      value: rrr.toStringAsFixed(2),
                      valueColor: rrr > 12 ? AppTheme.error : AppTheme.warning,
                    ),
                  ],
                ],
              ),
            ]),
          ),

          const SizedBox(height: 10),

          // ── Result ────────────────────────────────────────────────────
          if (isCompleted)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  const Color(0xFF1B5E20).withOpacity(0.7),
                  const Color(0xFF0A3D0A).withOpacity(0.5),
                ]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppTheme.success.withOpacity(0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.emoji_events_rounded,
                    color: AppTheme.accent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(data['result'] ?? 'Match Completed',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      )),
                ),
              ]),
            ),

          if (!isCompleted) ...[
            // ── At crease ──────────────────────────────────────────────
            _GlassCard(
              child: Column(children: [
                _AtCreaseRow(
                  emoji: '⚡',
                  role: 'STRIKER',
                  name: striker,
                  stats: _batterStats(striker),
                  roleColor: AppTheme.primaryLight,
                  highlight: true,
                ),
                const SizedBox(height: 12),
                const _Divider(),
                const SizedBox(height: 12),
                _AtCreaseRow(
                  emoji: '🏏',
                  role: 'NON-STRIKER',
                  name: nonStriker,
                  stats: _batterStats(nonStriker),
                  roleColor: AppTheme.textSecondary,
                ),
                const SizedBox(height: 12),
                const _Divider(),
                const SizedBox(height: 12),
                _AtCreaseRow(
                  emoji: '🎳',
                  role: 'BOWLING',
                  name: bowler,
                  stats: _bowlerStats(bowler),
                  roleColor: AppTheme.warning,
                ),
                if (partnerRuns > 0) ...[
                  const SizedBox(height: 12),
                  const _Divider(),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline_rounded,
                          color: AppTheme.textSecondary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Partnership  $partnerRuns runs ($partnerBalls balls)',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ]),
            ),

            const SizedBox(height: 10),

            // ── Current over ────────────────────────────────────────────
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('THIS OVER',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        )),
                    const SizedBox(width: 8),
                    Text(
                      'Over ${currentOver + 1} · $ballsInOver/6',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  currentOverBalls.isEmpty
                      ? const Text('Waiting for first ball...',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12))
                      : Wrap(
                    spacing: 8, runSpacing: 8,
                    children: currentOverBalls
                        .map((b) => _BallDot(ball: b))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // ── Extras row ─────────────────────────────────────────────────
          _GlassCard(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ExtrasCell(label: 'WD', value: wides),
                _VerticalDivider(),
                _ExtrasCell(label: 'NB', value: noBalls),
                _VerticalDivider(),
                _ExtrasCell(label: 'B', value: byes),
                _VerticalDivider(),
                _ExtrasCell(label: 'LB', value: legByes),
                _VerticalDivider(),
                _ExtrasCell(
                  label: 'TOTAL',
                  value: wides + noBalls + byes + legByes,
                  bold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _batterStats(String name) {
    final list = data['batters'] as List?;
    if (list == null) return '';
    for (final b in list) {
      final m = Map<String, dynamic>.from(b as Map);
      if (m['name'] == name) {
        final r  = m['runs'] as int? ?? 0;
        final bl = m['balls'] as int? ?? 0;
        final sr = bl > 0 ? (r * 100.0 / bl).toStringAsFixed(0) : '0';
        return '$r(${bl})  SR:$sr  4s:${m['fours']}  6s:${m['sixes']}';
      }
    }
    return '';
  }

  String _bowlerStats(String name) {
    final list = data['bowlers'] as List?;
    if (list == null) return '';
    for (final b in list) {
      final m  = Map<String, dynamic>.from(b as Map);
      if (m['name'] == name) {
        final balls = m['balls'] as int? ?? 0;
        final ov    = '${balls ~/ 6}.${balls % 6}';
        final econ  = balls > 0
            ? ((m['runs'] as int? ?? 0) * 6.0 / balls).toStringAsFixed(1)
            : '0.0';
        return '$ov ov  ${m['runs']}R  ${m['wickets']}W  Eco:$econ';
      }
    }
    return '';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — BATTING SCORECARD
// ═══════════════════════════════════════════════════════════════════════════════

class _BattingTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _BattingTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final batters     = ((data['batters'] as List?) ?? [])
        .map((b) => Map<String, dynamic>.from(b as Map))
        .toList();
    final battingTeam = data['battingTeam'] ?? '';
    final score       = data['score'] ?? 0;
    final wickets     = data['wickets'] ?? 0;
    final totalBalls  = data['totalBalls'] ?? 0;
    final wides       = data['wides'] ?? 0;
    final noBalls     = data['noBalls'] ?? 0;
    final byes        = data['byes'] ?? 0;
    final legByes     = data['legByes'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      child: Column(children: [
        // Team label
        _SectionLabel('🏏  $battingTeam  ·  Batting'),
        const SizedBox(height: 10),

        _GlassCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              child: Row(children: const [
                Expanded(flex: 5, child: _HdrCell('BATSMAN')),
                Expanded(flex: 2, child: _HdrCell('R', center: true)),
                Expanded(flex: 2, child: _HdrCell('B', center: true)),
                Expanded(flex: 2, child: _HdrCell('4s', center: true)),
                Expanded(flex: 2, child: _HdrCell('6s', center: true)),
                Expanded(flex: 3, child: _HdrCell('SR', center: true)),
              ]),
            ),
            const _Divider(),

            ...batters.map((b) => _BatterRow(b: b)),

            const _Divider(),

            // Extras
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              child: Row(children: [
                const Expanded(
                    flex: 5,
                    child: Text('Extras',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic))),
                Expanded(
                  flex: 11,
                  child: Text(
                    'WD $wides  NB $noBalls  B $byes  LB $legByes  = ${wides + noBalls + byes + legByes}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11),
                    textAlign: TextAlign.right,
                  ),
                ),
              ]),
            ),
            const _Divider(),

            // Total
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(children: [
                const Expanded(
                    flex: 5,
                    child: Text('TOTAL',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ))),
                Expanded(
                  flex: 11,
                  child: Text(
                    '$score/$wickets  (${totalBalls ~/ 6}.${totalBalls % 6} ov)',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _BatterRow extends StatelessWidget {
  final Map<String, dynamic> b;
  const _BatterRow({required this.b});

  @override
  Widget build(BuildContext context) {
    final isStriker    = b['isStriker']    as bool? ?? false;
    final isNonStriker = b['isNonStriker'] as bool? ?? false;
    final isOut        = b['isOut']        as bool? ?? false;
    final isBatting    = b['isBatting']    as bool? ?? false;
    final didBat       = b['didBat']       as bool? ?? false;
    final runs         = b['runs']  as int? ?? 0;
    final balls        = b['balls'] as int? ?? 0;
    final fours        = b['fours'] as int? ?? 0;
    final sixes        = b['sixes'] as int? ?? 0;
    final sr           = balls > 0
        ? (runs * 100.0 / balls).toStringAsFixed(1) : '-';

    Color bg = Colors.transparent;
    if (isStriker)    bg = AppTheme.primaryLight.withOpacity(0.07);
    if (isNonStriker) bg = Colors.white.withOpacity(0.025);

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        // Name + dismissal
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (isStriker)
                  const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Text('⚡', style: TextStyle(fontSize: 11))),
                if (isNonStriker)
                  const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Text('🏏', style: TextStyle(fontSize: 10))),
                Flexible(
                  child: Text(b['name'] ?? '',
                      style: TextStyle(
                        color: isOut
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                        fontWeight: isBatting
                            ? FontWeight.w700
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              if (isOut)
                Text(_dismissal(b),
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10),
                    overflow: TextOverflow.ellipsis)
              else if (!didBat)
                const Text('yet to bat',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10)),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Text('$runs',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: runs >= 100
                    ? AppTheme.accent
                    : runs >= 50
                    ? AppTheme.warning
                    : AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              )),
        ),
        Expanded(
          flex: 2,
          child: Text('$balls',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
        ),
        Expanded(
          flex: 2,
          child: Text('$fours',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.info, fontSize: 13)),
        ),
        Expanded(
          flex: 2,
          child: Text('$sixes',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.accent, fontSize: 13)),
        ),
        Expanded(
          flex: 3,
          child: Text(sr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
        ),
      ]),
    );
  }

  String _dismissal(Map<String, dynamic> b) {
    final wt      = b['wicketType']  as String? ?? '';
    final bowler  = b['bowlerName']  as String? ?? '';
    final fielder = b['fielderName'] as String? ?? '';
    if (wt == 'Caught' && fielder.isNotEmpty) return 'c $fielder b $bowler';
    if (wt == 'Run Out') return 'run out${fielder.isNotEmpty ? ' ($fielder)' : ''}';
    if (wt == 'Stumped') return 'st $fielder b $bowler';
    if (bowler.isNotEmpty) return '$wt b $bowler';
    return wt;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 3 — BOWLING
// ═══════════════════════════════════════════════════════════════════════════════

class _BowlingTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _BowlingTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final bowlers     = ((data['bowlers'] as List?) ?? [])
        .map((b) => Map<String, dynamic>.from(b as Map))
        .toList();
    final bowlingTeam = data['bowlingTeam'] ?? '';

    if (bowlers.isEmpty) {
      return const Center(
          child: Text('No bowling data yet',
              style: TextStyle(color: AppTheme.textSecondary)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      child: Column(children: [
        _SectionLabel('🎳  $bowlingTeam  ·  Bowling'),
        const SizedBox(height: 10),
        _GlassCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              child: Row(children: const [
                Expanded(flex: 5, child: _HdrCell('BOWLER')),
                Expanded(flex: 2, child: _HdrCell('O',    center: true)),
                Expanded(flex: 2, child: _HdrCell('R',    center: true)),
                Expanded(flex: 2, child: _HdrCell('W',    center: true)),
                Expanded(flex: 2, child: _HdrCell('WD',   center: true)),
                Expanded(flex: 2, child: _HdrCell('NB',   center: true)),
                Expanded(flex: 3, child: _HdrCell('ECO',  center: true)),
              ]),
            ),
            const _Divider(),
            ...bowlers.map((b) {
              final balls    = b['balls']   as int? ?? 0;
              final runs     = b['runs']    as int? ?? 0;
              final wickets  = b['wickets'] as int? ?? 0;
              final wides    = b['wides']   as int? ?? 0;
              final noBalls  = b['noBalls'] as int? ?? 0;
              final isBowling = b['isBowling'] as bool? ?? false;
              final overs    = '${balls ~/ 6}.${balls % 6}';
              final econ     = balls > 0
                  ? (runs * 6.0 / balls).toStringAsFixed(2)
                  : '-';

              return Container(
                color: isBowling
                    ? AppTheme.warning.withOpacity(0.05)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(children: [
                  Expanded(
                    flex: 5,
                    child: Row(children: [
                      if (isBowling)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Text('🎳',
                              style: TextStyle(fontSize: 10)),
                        ),
                      Flexible(
                        child: Text(b['name'] ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: isBowling
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              fontSize: 13,
                            )),
                      ),
                    ]),
                  ),
                  Expanded(flex: 2, child: Text(overs, textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
                  Expanded(flex: 2, child: Text('$runs', textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
                  Expanded(
                    flex: 2,
                    child: Text('$wickets',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: wickets > 0
                              ? AppTheme.error
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        )),
                  ),
                  Expanded(flex: 2, child: Text('$wides', textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.warning, fontSize: 12))),
                  Expanded(flex: 2, child: Text('$noBalls', textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.warning, fontSize: 12))),
                  Expanded(
                    flex: 3,
                    child: Text(econ,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: double.tryParse(econ) != null &&
                              double.parse(econ) > 10
                              ? AppTheme.error
                              : AppTheme.textSecondary,
                          fontSize: 12,
                        )),
                  ),
                ]),
              );
            }),
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 4 — BALL LOG
// ═══════════════════════════════════════════════════════════════════════════════

class _BallLogTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _BallLogTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final allBalls = ((data['balls'] as List?) ?? [])
        .map((b) => Map<String, dynamic>.from(b as Map))
        .toList();

    if (allBalls.isEmpty) {
      return const Center(
          child: Text('No balls yet',
              style: TextStyle(color: AppTheme.textSecondary)));
    }

    // Group by "Inn N · Over N+1"
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final b in allBalls) {
      final inn  = b['innings'] as int? ?? 1;
      final over = b['over']    as int? ?? 0;
      final key  = 'Inn $inn  ·  Over ${over + 1}';
      grouped.putIfAbsent(key, () => []).add(b);
    }
    final keys = grouped.keys.toList().reversed.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final key   = keys[i];
        final balls = grouped[key]!;
        final ovrRuns    = balls.fold(0, (s, b) => s + (b['total'] as int? ?? 0));
        final wkts       = balls.where((b) => b['isWicket'] as bool? ?? false).length;
        final isMaiden   = ovrRuns == 0 && balls.length == 6;
        final bowlerName = balls.isNotEmpty
            ? balls.first['bowler'] as String? ?? ''
            : '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Over header
                Row(children: [
                  // Over label
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.primaryLight.withOpacity(0.25)),
                    ),
                    child: Text(key,
                        style: const TextStyle(
                          color: AppTheme.primaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                  const SizedBox(width: 8),
                  // Runs
                  _OverBadge(label: '$ovrRuns R', color: AppTheme.bgSurface,
                      textColor: AppTheme.textSecondary),
                  if (wkts > 0) ...[
                    const SizedBox(width: 6),
                    _OverBadge(label: '${wkts}W',
                        color: AppTheme.error.withOpacity(0.12),
                        textColor: AppTheme.error),
                  ],
                  if (isMaiden) ...[
                    const SizedBox(width: 6),
                    _OverBadge(label: 'M',
                        color: AppTheme.info.withOpacity(0.12),
                        textColor: AppTheme.info),
                  ],
                  const Spacer(),
                  Text(bowlerName,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                ]),

                const SizedBox(height: 12),

                // Ball bubbles
                Wrap(
                  spacing: 7, runSpacing: 7,
                  children: balls.map((b) => _BallDot(ball: b)).toList(),
                ),

                const SizedBox(height: 12),
                const _Divider(),
                const SizedBox(height: 10),

                // Commentary lines
                ...balls.asMap().entries.map((e) =>
                    _CommentLine(ball: e.value, num: e.key + 1)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommentLine extends StatelessWidget {
  final Map<String, dynamic> ball;
  final int num;
  const _CommentLine({required this.ball, required this.num});

  @override
  Widget build(BuildContext context) {
    final isWicket  = ball['isWicket']  as bool? ?? false;
    final isWide    = ball['isWide']    as bool? ?? false;
    final isNoBall  = ball['isNoBall']  as bool? ?? false;
    final isBye     = ball['isBye']     as bool? ?? false;
    final isLegBye  = ball['isLegBye']  as bool? ?? false;
    final runs      = ball['runs']      as int? ?? 0;
    final total     = ball['total']     as int? ?? 0;
    final batsman   = ball['batsman']   as String? ?? '';
    final bowler    = ball['bowler']    as String? ?? '';
    final wicketType = ball['wicketType'] as String? ?? '';
    final outBatsman = ball['outBatsman'] as String? ?? '';
    final fielder   = ball['fielder']   as String? ?? '';
    final isValid   = ball['isValid']   as bool? ?? true;

    String text;
    Color  color;
    String emoji;

    if (isWicket) {
      color = AppTheme.error;
      emoji = '🚨';
      if (wicketType == 'Run Out') {
        text = 'OUT! ${outBatsman.isNotEmpty ? outBatsman : batsman} run out'
            '${fielder.isNotEmpty ? ' ($fielder)' : ''}';
      } else if (wicketType == 'Caught') {
        text = 'CAUGHT! ${outBatsman.isNotEmpty ? outBatsman : batsman}'
            ' c $fielder b $bowler  ·  $runs run${runs == 1 ? '' : 's'}';
      } else {
        text = '$wicketType!  ${outBatsman.isNotEmpty ? outBatsman : batsman}'
            ' b $bowler  ·  $runs run${runs == 1 ? '' : 's'}';
      }
    } else if (runs == 6) {
      color = AppTheme.accent;
      emoji = '🔥';
      text  = 'SIX!  $batsman  ·  off $bowler';
    } else if (runs == 4) {
      color = AppTheme.info;
      emoji = '💥';
      text  = 'FOUR!  $batsman  ·  off $bowler';
    } else if (isWide) {
      color = AppTheme.warning;
      emoji = '·';
      text  = 'Wide${total > 0 ? ' +$total' : ''}  ·  $bowler';
    } else if (isNoBall) {
      color = AppTheme.warning;
      emoji = '·';
      text  = 'No Ball${total > 0 ? ' +$total' : ''}  ·  $bowler';
    } else if (isBye) {
      color = AppTheme.textSecondary;
      emoji = '·';
      text  = '$total Bye${total != 1 ? 's' : ''}  ·  $bowler';
    } else if (isLegBye) {
      color = AppTheme.textSecondary;
      emoji = '·';
      text  = '$total Leg Bye${total != 1 ? 's' : ''}  ·  $bowler';
    } else if (total == 0) {
      color = AppTheme.textSecondary;
      emoji = '·';
      text  = 'Dot  ·  $batsman  ·  $bowler';
    } else {
      color = AppTheme.textPrimary;
      emoji = '·';
      text  = '$total run${total == 1 ? '' : 's'}  ·  $batsman  ·  $bowler';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Text(isValid ? '$num.' : '',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ),
          Text('$emoji  ', style: TextStyle(fontSize: 12, color: color)),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color, fontSize: 12, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final Color? borderColor;
  const _GlassCard(
      {required this.child, this.padding, this.color, this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color ?? AppTheme.bgCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor ?? AppTheme.borderColor),
    ),
    child: child,
  );
}

class _TeamChip extends StatelessWidget {
  final String name;
  final bool active;
  const _TeamChip({required this.name, required this.active});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: active
          ? AppTheme.primaryLight.withOpacity(0.12)
          : AppTheme.bgSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: active
            ? AppTheme.primaryLight.withOpacity(0.4)
            : AppTheme.borderColor,
      ),
    ),
    child: Text(name,
        style: TextStyle(
          color: active
              ? AppTheme.primaryLight
              : AppTheme.textSecondary,
          fontWeight:
          active ? FontWeight.w700 : FontWeight.normal,
          fontSize: 12,
        )),
  );
}

class _RateBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _RateBox(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label,
        style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8)),
    const SizedBox(height: 4),
    Text(value,
        style: TextStyle(
          color: valueColor ?? AppTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        )),
  ]);
}

class _AtCreaseRow extends StatelessWidget {
  final String emoji;
  final String role;
  final String name;
  final String stats;
  final Color roleColor;
  final bool highlight;
  const _AtCreaseRow({
    required this.emoji, required this.role, required this.name,
    required this.stats, required this.roleColor, this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 15)),
    const SizedBox(width: 10),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: roleColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(role,
          style: TextStyle(
              color: roleColor,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8)),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: Text(name.isEmpty ? '—' : name,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: highlight
                ? FontWeight.w800
                : FontWeight.normal,
            fontSize: 13,
          )),
    ),
    Text(stats,
        style: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 11)),
  ]);
}

class _BallDot extends StatelessWidget {
  final Map<String, dynamic> ball;
  const _BallDot({required this.ball});

  @override
  Widget build(BuildContext context) {
    final isWicket = ball['isWicket'] as bool? ?? false;
    final isWide   = ball['isWide']   as bool? ?? false;
    final isNoBall = ball['isNoBall'] as bool? ?? false;
    final runs     = ball['runs']     as int? ?? 0;
    final total    = ball['total']    as int? ?? 0;

    Color border;
    Color bg;
    String label;

    if (isWicket) {
      border = AppTheme.error;
      bg     = AppTheme.error.withOpacity(0.15);
      label  = 'W';
    } else if (isWide) {
      border = AppTheme.warning;
      bg     = AppTheme.warning.withOpacity(0.12);
      label  = 'Wd';
    } else if (isNoBall) {
      border = AppTheme.warning;
      bg     = AppTheme.warning.withOpacity(0.12);
      label  = 'Nb';
    } else if (runs == 6) {
      border = AppTheme.accent;
      bg     = AppTheme.accent.withOpacity(0.15);
      label  = '6';
    } else if (runs == 4) {
      border = AppTheme.info;
      bg     = AppTheme.info.withOpacity(0.12);
      label  = '4';
    } else if (total == 0) {
      border = AppTheme.borderColor;
      bg     = Colors.transparent;
      label  = '•';
    } else {
      border = AppTheme.success.withOpacity(0.6);
      bg     = AppTheme.success.withOpacity(0.08);
      label  = '$total';
    }

    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: border, width: 1.5),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(
              color: border == AppTheme.borderColor
                  ? AppTheme.textSecondary
                  : border,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            )),
      ),
    );
  }
}

class _ExtrasCell extends StatelessWidget {
  final String label;
  final int value;
  final bool bold;
  const _ExtrasCell(
      {required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label,
        style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8)),
    const SizedBox(height: 3),
    Text('$value',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight:
          bold ? FontWeight.w800 : FontWeight.normal,
          fontSize: 14,
        )),
  ]);
}

class _OverBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _OverBadge(
      {required this.label, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: textColor.withOpacity(0.3)),
    ),
    child: Text(label,
        style: TextStyle(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.w700)),
  );
}

class _LabelBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _LabelBanner(
      {required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    ]),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        )),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppTheme.borderColor);
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: AppTheme.borderColor);
}

// Header cell
class _HdrCell extends StatelessWidget {
  final String text;
  final bool center;
  const _HdrCell(this.text, {this.center = false});

  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: center ? TextAlign.center : TextAlign.left,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ));
}

// ── Utility screens ───────────────────────────────────────────────────────────

class _FullScreenLoader extends StatelessWidget {
  const _FullScreenLoader();
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: const Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
                color: AppTheme.primaryLight,
                strokeWidth: 2),
            SizedBox(height: 16),
            Text('Connecting...',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    ),
  );
}

class _NotFoundScreen extends StatelessWidget {
  final String matchCode;
  const _NotFoundScreen({required this.matchCode});

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: const Icon(Icons.sports_cricket,
                    size: 32, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              const Text('Match Not Found',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(matchCode,
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                      fontSize: 12)),
              const SizedBox(height: 28),
              TextButton.icon(
                onPressed: () => Get.offAllNamed(AppRoutes.home),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 14),
                label: const Text('Go Home'),
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryLight),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// NEXT MATCH BANNER — shown above the scoreboard when the live match belongs
// to a tournament. Pulls the next scheduled fixture from Firestore so viewers
// know which game is coming up (and who's playing whom).
// ═══════════════════════════════════════════════════════════════════════════════

class _NextMatchBanner extends StatefulWidget {
  final String tournamentId;
  final String currentMatchId;
  const _NextMatchBanner({
    required this.tournamentId,
    required this.currentMatchId,
  });

  @override
  State<_NextMatchBanner> createState() => _NextMatchBannerState();
}

class _NextMatchBannerState extends State<_NextMatchBanner> {
  TournamentMatchModel? _next;
  String? _tournamentName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo    = TournamentRepository();
      final matches = await repo.getMatches(widget.tournamentId);
      final t       = await repo.getTournament(widget.tournamentId);
      if (!mounted) return;

      // Prefer scheduled matches AFTER the current one; fallback to nearest
      // upcoming regardless of ordering.
      final upcoming = matches.where((m) =>
          m.id != widget.currentMatchId &&
          !m.isCompleted &&
          !m.isInProgress).toList()
        ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

      setState(() {
        _tournamentName = t?.name;
        _next = upcoming.isNotEmpty ? upcoming.first : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _next == null) return const SizedBox.shrink();
    final n = _next!;
    final timeLabel = DateFormat('E, d MMM · h:mm a').format(n.scheduledTime);
    final teamA = n.teamAIsPlaceholder ? 'TBD' : n.teamAName;
    final teamB = n.teamBIsPlaceholder ? 'TBD' : n.teamBName;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.info.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.event_rounded, color: AppTheme.info, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('NEXT MATCH',
                    style: TextStyle(
                        color: AppTheme.info,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4)),
                if (_tournamentName != null && _tournamentName!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('· $_tournamentName',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text('$teamA  vs  $teamB',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              Text(timeLabel,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ]),
    );
  }
}