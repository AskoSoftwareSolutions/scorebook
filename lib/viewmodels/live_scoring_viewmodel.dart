import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/models.dart';
import '../repositories/match_repository.dart';
import '../services/session_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/active_scorer_service.dart';
import '../services/match_cloud_pull_service.dart';
import '../services/deep_link_service.dart';
import 'dart:async';
import '../core/constants/app_constants.dart';
import '../core/constants/app_routes.dart';
import '../core/utils/app_utils.dart';
import '../core/theme/app_theme.dart';

class LiveScoringViewModel extends GetxController {
  final MatchRepository _repo = Get.find<MatchRepository>();
  final SessionService _session = SessionService();

  // ── Current Match State ───────────────────────────────────────────────────
  final Rx<MatchModel?> match = Rx<MatchModel?>(null);
  final Rx<InningsModel?> currentInnings = Rx<InningsModel?>(null);
  final RxList<PlayerModel> allPlayers = <PlayerModel>[].obs;
  final RxList<BallModel> currentOverBalls = <BallModel>[].obs;
  final RxList<BallModel> allBalls = <BallModel>[].obs;

  // ── Innings 1 complete share signal ──────────────────────────────────────────
  final RxBool showShareWithTeamB = false.obs;


  // ── Current Batsmen & Bowler ──────────────────────────────────────────────
  final Rx<PlayerModel?> striker = Rx<PlayerModel?>(null);
  final Rx<PlayerModel?> nonStriker = Rx<PlayerModel?>(null);
  final Rx<PlayerModel?> currentBowler = Rx<PlayerModel?>(null);

  // ── Over tracking ─────────────────────────────────────────────────────────
  final RxInt currentOver = 0.obs;
  final RxInt ballsInOver = 0.obs;
  final RxBool isOverComplete = false.obs;
  final RxBool isInningsComplete = false.obs;

  // ── Post-ball signals (view listens to these) ────────────────────────────
  /// Fires true when a wicket fell and a new batsman must be selected
  final RxBool needNewBatsman = false.obs;
  /// true = put new batsman at striker end, false = non-striker end
  final RxBool _newBatsmanAtStriker = true.obs;
  bool get newBatsmanAtStriker => _newBatsmanAtStriker.value;

  /// Fires true when batting team is "all out" but total players is small
  /// (<11) — scorer should choose to ADD MORE PLAYERS or END INNINGS.
  final RxBool needAddMorePlayersDecision = false.obs;

  // ── Extras in current ball ────────────────────────────────────────────────
  final RxBool isWide = false.obs;
  final RxBool isNoBall = false.obs;
  final RxBool isBye = false.obs;
  final RxBool isLegBye = false.obs;

  // ── Partnership ───────────────────────────────────────────────────────────
  final RxInt partnershipRuns = 0.obs;
  final RxInt partnershipBalls = 0.obs;

  // ── Loading ───────────────────────────────────────────────────────────────
  final RxBool isLoading = false.obs;
  final RxString status = ''.obs;

  // ── Online Mode ───────────────────────────────────────────────────────────
  final RxBool isOnlineMode = false.obs;
  final RxString matchCode = ''.obs;
  final RxString matchPassword = ''.obs;
  final FirebaseSyncService _firebaseSync = FirebaseSyncService();
  final DeepLinkService _deepLink = DeepLinkService();

  // ── Active-scorer exclusive lock ─────────────────────────────────────────
  /// Emits `true` exactly once when another device takes over scoring.
  /// The view watches this and auto-exits to the live viewer page.
  final RxBool lockLost = false.obs;
  final ActiveScorerService _lock = ActiveScorerService();
  final MatchCloudPullService _cloud = MatchCloudPullService();
  StreamSubscription<bool>? _lockSub;

  // ── Tournament linkage (optional, populated when match came from a bracket) ─
  final RxString tournamentId      = ''.obs;
  final RxString tournamentMatchId = ''.obs;

  int get matchId => match.value?.id ?? 0;
  int get inningsNumber => currentInnings.value?.inningsNumber ?? 1;

  @override
  void onInit() {
    super.onInit();
    final id = Get.arguments as int?;
    if (id != null) loadMatch(id);
  }

  @override
  void onClose() {
    _lockSub?.cancel();
    _lockSub = null;
    super.onClose();
  }

  /// Claim the active-scorer lock for [matchCode] and start watching for
  /// ownership changes. Called every time the scorer enters or resumes
  /// online scoring (initial online-mode toggle, app resume, innings-2
  /// start, or join-as-scorer). A subsequent claim from another device
  /// flips [lockLost] → the view reacts by auto-exiting to the live
  /// viewer page.
  Future<void> _claimAndWatchLock() async {
    final code = matchCode.value;
    if (code.isEmpty) return;
    await _lock.claim(code);
    _lockSub?.cancel();
    _lockSub = _lock.watch(code).listen((stillOwn) {
      if (!stillOwn && !lockLost.value) {
        lockLost.value = true;
      }
    });
  }

  Future<void> loadMatch(int id) async {
    isLoading.value = true;
    try {
      match.value = await _repo.getMatch(id);
      allPlayers.value = await _repo.getPlayersByMatch(id);

      final inn = match.value!.currentInnings;
      currentInnings.value = await _repo.getInnings(id, inn);
      allBalls.value = await _repo.getBallsByInnings(id, inn);

      _refreshCurrentOverBalls();
      _restoreState();

      if (match.value!.status == AppConstants.matchStatusInProgress) {
        await _session.saveActiveMatch(
          matchId: id,
          teamA: match.value!.teamAName,
          teamB: match.value!.teamBName,
          totalOvers: match.value!.totalOvers,
        );

        // ── Restore tournament linkage if this match came from a bracket ───
        final tLink = await _session.getActiveTournamentMatch();
        if (tLink != null) {
          tournamentId.value      = tLink.tournamentId;
          tournamentMatchId.value = tLink.tournamentMatchId;
        }

        // ── Restore online mode if it was active before app went background ──
        final onlineInfo = await _session.getOnlineMode();
        if (onlineInfo != null) {
          matchCode.value     = onlineInfo.matchCode;
          matchPassword.value = onlineInfo.password;
          isOnlineMode.value  = true;
          // Re-bind local↔cloud (idempotent), so summary view can pull.
          await _cloud.bindLocalToCloud(id, onlineInfo.matchCode);
          // Re-claim the active-scorer lock (in case another device took over
          // while we were backgrounded; this device intentionally resumes
          // scoring → overwrite. Also start listening so the next remote
          // takeover kicks us out.)
          await _claimAndWatchLock();
          // Re-push current snapshot so viewers get immediate update
          _syncToFirebase();
        }
      }
    } finally {
      isLoading.value = false;
    }
  }

  void _restoreState() {
    final battingTeam = currentInnings.value!.battingTeam;
    final bowlingTeam = currentInnings.value!.bowlingTeam;

    striker.value = allPlayers
        .where((p) => p.teamName == battingTeam && p.isBatting && p.isOnStrike)
        .firstOrNull;
    nonStriker.value = allPlayers
        .where((p) => p.teamName == battingTeam && p.isBatting && !p.isOnStrike)
        .firstOrNull;
    currentBowler.value = allPlayers
        .where((p) => p.teamName == bowlingTeam && p.isBowling)
        .firstOrNull;

    // Use shared helper so load and undo use identical over-state logic
    _rebuildOverStateFromBalls();
    _recalcPartnership();
  }

  void _recalcPartnership() {
    if (allBalls.isEmpty) {
      partnershipRuns.value = 0;
      partnershipBalls.value = 0;
      return;
    }
    int lastWicketIdx = -1;
    for (int i = allBalls.length - 1; i >= 0; i--) {
      if (allBalls[i].isWicket) {
        lastWicketIdx = i;
        break;
      }
    }
    final partnerBalls = allBalls.sublist(lastWicketIdx + 1);
    partnershipRuns.value = partnerBalls.fold(0, (sum, b) => sum + b.totalRuns);
    partnershipBalls.value = partnerBalls.where((b) => b.isValid).length;
  }

  void _refreshCurrentOverBalls() {
    // Always use currentOver.value as source of truth (set by _rebuildOverStateFromBalls)
    // Fallback: use last ball's over if currentOver not yet initialised
    final over = allBalls.isEmpty ? 0 : currentOver.value;
    currentOverBalls.value = allBalls
        .where((b) => b.innings == inningsNumber && b.overNumber == over)
        .toList();
  }

  void _updatePlayerLocal(PlayerModel player) {
    final idx = allPlayers.indexWhere((p) => p.id == player.id);
    if (idx != -1) allPlayers[idx] = player;
    _repo.updatePlayer(player);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SELECT batsmen / bowler
  // ═══════════════════════════════════════════════════════════════════════════

  void selectStriker(PlayerModel player) {
    if (striker.value != null) {
      final old = striker.value!;
      old.isOnStrike = false;
      old.isBatting = false;
      _updatePlayerLocal(old);
    }
    player.isBatting = true;
    player.isOnStrike = true;
    player.didBat = true;
    striker.value = player;
    _updatePlayerLocal(player);
  }

  /// Called after a wicket — places new batsman at the correct end:
  ///   mid-over wicket  → striker end  (_newBatsmanAtStriker == true)
  ///   6th-ball wicket  → non-striker end (_newBatsmanAtStriker == false)
  void selectNewBatsmanAsStriker(PlayerModel player) {
    final atStriker = _newBatsmanAtStriker.value;

    if (atStriker) {
      // Clear stale striker if any
      if (striker.value != null) {
        striker.value!.isOnStrike = false;
        striker.value!.isBatting  = false;
        _updatePlayerLocal(striker.value!);
      }
      player.isBatting  = true;
      player.isOnStrike = true;
      player.didBat     = true;
      striker.value     = player;
    } else {
      // 6th ball wicket: place at non-striker end
      if (nonStriker.value != null) {
        nonStriker.value!.isOnStrike = false;
        nonStriker.value!.isBatting  = false;
        _updatePlayerLocal(nonStriker.value!);
      }
      player.isBatting  = true;
      player.isOnStrike = false;
      player.didBat     = true;
      nonStriker.value  = player;
    }

    _updatePlayerLocal(player);
    allPlayers.refresh();
  }

  void selectNonStriker(PlayerModel player) {
    if (nonStriker.value != null) {
      final old = nonStriker.value!;
      old.isOnStrike = false;
      old.isBatting = false;
      _updatePlayerLocal(old);
    }
    player.isBatting = true;
    player.isOnStrike = false;
    player.didBat = true;
    nonStriker.value = player;
    _updatePlayerLocal(player);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Add a brand-new player on the fly (from the batsman / bowler picker)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create a new batsman (belongs to current batting team) and add to roster.
  /// Returns the saved PlayerModel or null if a player with same name exists.
  Future<PlayerModel?> addNewBatsman(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final team = currentInnings.value?.battingTeam ?? match.value?.teamAName;
    if (team == null) return null;
    return _addPlayerToTeam(trimmed, team);
  }

  /// Create a new bowler (belongs to current bowling team) and add to roster.
  Future<PlayerModel?> addNewBowler(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final team = currentInnings.value?.bowlingTeam ?? match.value?.teamBName;
    if (team == null) return null;
    return _addPlayerToTeam(trimmed, team);
  }

  Future<PlayerModel?> _addPlayerToTeam(String name, String team) async {
    final exists = allPlayers.any(
      (p) => p.teamName == team && p.name.toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      Get.snackbar('Already exists', '$name is already in the team',
          snackPosition: SnackPosition.BOTTOM);
      return null;
    }
    final teamCount =
        allPlayers.where((p) => p.teamName == team).length;
    final model = PlayerModel(
      matchId: matchId,
      teamName: team,
      name: name,
      orderIndex: teamCount,
    );
    final id = await _repo.createPlayer(model);
    final saved = model.copyWith(id: id);
    allPlayers.add(saved);
    allPlayers.refresh();
    if (isOnlineMode.value) _syncToFirebase();
    return saved;
  }

  void selectBowler(PlayerModel player) {
    if (currentBowler.value != null) {
      currentBowler.value!.isBowling = false;
      _updatePlayerLocal(currentBowler.value!);
    }
    player.isBowling = true;
    currentBowler.value = player;
    _updatePlayerLocal(player);
    isOverComplete.value = false;
    ballsInOver.value    = 0;
    currentOverBalls.clear();
    // Refresh so striker/nonStriker cards reflect the post-over-swap positions
    allPlayers.refresh();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SCORE A BALL
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> scoreBall({
    required int runs,
    bool wicket = false,
    String? wicketType,
    String? outBatsmanName,
    String? fielderName,
  }) async {
    if (striker.value == null ||
        nonStriker.value == null ||
        currentBowler.value == null) {
      Get.snackbar('Setup Required', 'Please select batsmen and bowler',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final bowler = currentBowler.value!;
    final bat = striker.value!;
    final inn = currentInnings.value!;

    final wide = isWide.value;
    final noBall = isNoBall.value;
    final bye = isBye.value;
    final legBye = isLegBye.value;

    final bool isValidDelivery = !wide && !noBall;
    final int extraRuns = (wide || noBall) ? 1 : 0;
    final int totalRuns = runs + extraRuns;

    final ball = BallModel(
      matchId: matchId,
      innings: inningsNumber,
      overNumber: currentOver.value,
      ballNumber: ballsInOver.value + 1,
      batsmanName: bat.name,
      bowlerName: bowler.name,
      runs: runs,
      isWide: wide,
      isNoBall: noBall,
      isBye: bye,
      isLegBye: legBye,
      isWicket: wicket,
      wicketType: wicketType,
      outBatsmanName: outBatsmanName ?? (wicket ? bat.name : null),
      fielderName: fielderName,
      extraRuns: extraRuns,
      totalRuns: totalRuns,
      isValid: isValidDelivery,
    );

    final ballId = await _repo.addBall(ball);
    final savedBall = ball.toMap();
    savedBall['id'] = ballId;

    allBalls.add(BallModel.fromMap(savedBall));
    currentOverBalls.add(BallModel.fromMap(savedBall));

    // ── Update innings totals ─────────────────────────────────────────────
    inn.totalRuns += totalRuns;
    if (isValidDelivery) inn.totalBalls += 1;
    if (wide) inn.wides += 1 + runs;
    if (noBall) inn.noBalls += 1;
    if (bye) inn.byes += runs;
    if (legBye) inn.legByes += runs;
    if (wicket) inn.totalWickets += 1;
    currentInnings.refresh();

    // ── Update batsman stats ──────────────────────────────────────────────
    if (!wide && !bye && !legBye) {
      bat.runsScored += runs;
      if (runs == 4) bat.fours += 1;
      if (runs == 6) bat.sixes += 1;
    }
    if (isValidDelivery) bat.ballsFaced += 1;

    // ── Update bowler stats ───────────────────────────────────────────────
    if (isValidDelivery) bowler.ballsBowled += 1;
    if (!bye && !legBye) bowler.runsConceded += runs + extraRuns;
    if (wide) bowler.wides += 1;
    if (noBall) bowler.noBalls += 1;
    if (wicket && wicketType != AppConstants.wicketRunOut) {
      bowler.wicketsTaken += 1;
    }

    // ── Partnership ───────────────────────────────────────────────────────
    partnershipRuns.value += totalRuns;
    if (isValidDelivery) partnershipBalls.value += 1;

    // ── Handle Wicket ─────────────────────────────────────────────────────
    if (wicket) {
      final outPlayer = outBatsmanName == nonStriker.value?.name
          ? nonStriker.value!
          : bat;
      outPlayer.isOut = true;
      outPlayer.isBatting = false;
      outPlayer.isOnStrike = false;
      outPlayer.wicketType = wicketType;
      outPlayer.bowlerName =
      wicketType != AppConstants.wicketRunOut ? bowler.name : null;
      outPlayer.dismissedBy = fielderName;
      await _repo.updatePlayer(outPlayer);
      _updatePlayerLocal(outPlayer);

      partnershipRuns.value = 0;
      partnershipBalls.value = 0;

      if (outPlayer.name == bat.name) {
        striker.value = null;
      } else {
        nonStriker.value = null;
      }

      if (runs > 0 && runs % 2 == 1) {
        _swapStrike();
      }
    } else {
      if ((runs % 2 == 1) && !wide) {
        _swapStrike();
      }
    }

    // ── Save to DB ────────────────────────────────────────────────────────
    await _repo.updatePlayer(bat);
    await _repo.updatePlayer(bowler);
    await _repo.updateInnings(inn);

    // ── Check over complete ───────────────────────────────────────────────
    if (isValidDelivery) {
      ballsInOver.value += 1;
      if (ballsInOver.value == 6) {
        _handleOverComplete();
      }
    }

    // ── Reset extras ──────────────────────────────────────────────────────
    isWide.value   = false;
    isNoBall.value = false;
    isBye.value    = false;
    isLegBye.value = false;

    // Show interstitial ad after wicket

    // ── Signal view to show new batsman picker if wicket fell ─────────────
    // Case 1: mid-over wicket → striker is null (normal)
    // Case 2: 6th ball wicket → over-end swap happened → nonStriker is null
    if (wicket && (striker.value == null || nonStriker.value == null)) {
      // Tell view whether to put new batsman at striker or nonStriker end
      _newBatsmanAtStriker.value = striker.value == null;
      needNewBatsman.value = true;
    }

    // ── Firebase sync ─────────────────────────────────────────────────────
    if (isOnlineMode.value) _syncToFirebase();

    // ── Check innings complete ────────────────────────────────────────────
    await _checkInningsComplete();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ONLINE MODE
  // ═══════════════════════════════════════════════════════════════════════════

  String _generateMatchCode() {
    final m = match.value!;
    final a = m.teamAName.length >= 2
        ? m.teamAName.substring(0, 2).toUpperCase()
        : m.teamAName.toUpperCase();
    final b = m.teamBName.length >= 2
        ? m.teamBName.substring(0, 2).toUpperCase()
        : m.teamBName.toUpperCase();
    final rand = (DateTime.now().millisecondsSinceEpoch % 9000 + 1000).toString();
    return 'CS-$a$b-$rand';
  }

  Future<void> enableOnlineMode({required String password}) async {
    if (match.value == null) return;
    if (isOnlineMode.value) {
      await shareLink();
      return;
    }
    matchCode.value = _generateMatchCode();
    matchPassword.value = password;
    isOnlineMode.value = true;
    // Persist online state so it survives app background/resume
    await _session.saveOnlineMode(
      isActive:  true,
      matchCode: matchCode.value,
      password:  password,
    );
    // Bind local id ↔ cloud code so that when the user later opens the
    // match summary, we can transparently pull fresh data (handles the
    // case where innings 2 was scored on a different device).
    if (match.value?.id != null) {
      await _cloud.bindLocalToCloud(match.value!.id!, matchCode.value);
    }
    // This device becomes the exclusive scorer; start watching for takeover.
    await _claimAndWatchLock();
    _syncToFirebase();
    Get.snackbar(
      '🌐 Online Mode ON',
      'Code: ${matchCode.value}  •  Password: $password',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
      backgroundColor: AppTheme.primary,
      colorText: const Color(0xFF000000),
    );
  }

  Future<void> disableOnlineMode() async {
    isOnlineMode.value = false;
    matchCode.value = '';
    matchPassword.value = '';
    // Remove persisted online state
    await _session.clearOnlineMode();
    Get.snackbar('Online Mode OFF', 'Live sharing stopped',
        snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> shareLink() async {
    if (matchCode.value.isEmpty) return;
    await _deepLink.shareToWhatsApp(
      matchCode: matchCode.value,
      password: matchPassword.value,
      teamA: match.value!.teamAName,
      teamB: match.value!.teamBName,
    );
  }

  /// Returns the underlying Future so callers that need to know the cloud
  /// write has actually landed (e.g. innings-2 transition before showing
  /// the "share with Phone B" popup) can `await` it. Most callers ignore
  /// the future and run fire-and-forget — that's still fine, the void
  /// dropped is harmless.
  Future<void> _syncToFirebase() async {
    if (!isOnlineMode.value || matchCode.value.isEmpty) return;
    if (match.value == null || currentInnings.value == null) return;
    await _firebaseSync.pushLiveSnapshot(
      matchCode: matchCode.value,
      passwordHash: matchPassword.value,
      match: match.value!,
      innings: currentInnings.value!,
      players: allPlayers.toList(),
      allBalls: allBalls.toList(),
      strikerName: striker.value?.name,
      nonStrikerName: nonStriker.value?.name,
      bowlerName: currentBowler.value?.name,
      currentOver: currentOver.value,
      ballsInOver: ballsInOver.value,
      tournamentId:      tournamentId.value.isEmpty ? null : tournamentId.value,
      tournamentMatchId: tournamentMatchId.value.isEmpty ? null : tournamentMatchId.value,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STRIKE / OVER / INNINGS helpers
  // ═══════════════════════════════════════════════════════════════════════════

  void _swapStrike() {
    final temp = striker.value;
    striker.value = nonStriker.value;
    nonStriker.value = temp;
    striker.value?.isOnStrike = true;
    nonStriker.value?.isOnStrike = false;
  }

  void changeStrike() {
    _swapStrike();
    allPlayers.refresh();
  }

  void _handleOverComplete() {
    isOverComplete.value = true;
    _swapStrike();
    // Show ad after every over

    currentBowler.value?.isBowling = false;
    if (currentBowler.value != null) {
      _updatePlayerLocal(currentBowler.value!);
    }

    currentOver.value += 1;
    ballsInOver.value = 0;
    currentOverBalls.clear();

    currentInnings.refresh();
  }

  Future<void> _checkInningsComplete() async {
    final inn = currentInnings.value!;
    final match = this.match.value!;
    final maxBalls = match.totalOvers * 6;
    final teamSize = _getBattingTeamSize();
    final allOut = inn.totalWickets >= teamSize - 1;
    final oversUp = inn.totalBalls >= maxBalls;

    // 2nd innings: winning by reaching target (1st innings total + 1) ends match.
    bool targetReached = false;
    if (inn.inningsNumber == 2) {
      final firstInningsTotal = inn.battingTeam == match.teamAName
          ? (match.teamBScore ?? 0)   // team A is batting now → team B batted first
          : (match.teamAScore ?? 0);  // team B is batting now → team A batted first
      final target = firstInningsTotal + 1;
      if (inn.totalRuns >= target) targetReached = true;
    }

    // Small team "all out" (size < 11) → don't auto-progress. Ask scorer.
    if (allOut && !oversUp && !targetReached && teamSize < 11) {
      needAddMorePlayersDecision.value = true;
      return;
    }

    if (allOut || oversUp || targetReached) {
      inn.isCompleted = true;
      await _repo.updateInnings(inn);
      isInningsComplete.value = true;

      if (inn.inningsNumber == 1) {
        await _startInnings2();
      } else {
        await _completeMatch();
      }
    }
  }

  /// Called from the view after user chose "End Innings" in the add-more
  /// players prompt. Forces the current innings to finalise.
  Future<void> forceEndInnings() async {
    final inn = currentInnings.value!;
    inn.isCompleted = true;
    await _repo.updateInnings(inn);
    isInningsComplete.value = true;
    if (inn.inningsNumber == 1) {
      await _startInnings2();
    } else {
      await _completeMatch();
    }
  }

  int _getBattingTeamSize() {
    final team = currentInnings.value!.battingTeam;
    return allPlayers.where((p) => p.teamName == team).length;
  }

  Future<void> _startInnings2() async {
    final m = match.value!;
    final inn1 = currentInnings.value!;

    final updated = m.copyWith(
      currentInnings: 2,
      teamAScore: inn1.battingTeam == m.teamAName ? inn1.totalRuns : null,
      teamAWickets: inn1.battingTeam == m.teamAName ? inn1.totalWickets : null,
      teamABalls: inn1.battingTeam == m.teamAName ? inn1.totalBalls : null,
      teamBScore: inn1.battingTeam == m.teamBName ? inn1.totalRuns : null,
      teamBWickets: inn1.battingTeam == m.teamBName ? inn1.totalWickets : null,
      teamBBalls: inn1.battingTeam == m.teamBName ? inn1.totalBalls : null,
    );
    await _repo.updateMatch(updated);
    match.value = updated;

    final inn2Seed = InningsModel(
      matchId: m.id!,
      inningsNumber: 2,
      battingTeam: inn1.bowlingTeam,
      bowlingTeam: inn1.battingTeam,
    );
    final inn2Id = await _repo.createInnings(inn2Seed);

    // 🔑 Re-hydrate with the returned DB id so future updateInnings()
    // calls actually match a row (WHERE id = ?). Without this, inn2.id
    // stays null and totals silently fail to persist → Innings 2 shows 0/0.
    final inn2 = InningsModel(
      id: inn2Id,
      matchId: m.id!,
      inningsNumber: 2,
      battingTeam: inn1.bowlingTeam,
      bowlingTeam: inn1.battingTeam,
    );
    currentInnings.value = inn2;
    allBalls.clear();
    currentOverBalls.clear();
    currentOver.value = 0;
    ballsInOver.value = 0;
    isOverComplete.value = false;
    isInningsComplete.value = false;
    striker.value = null;
    nonStriker.value = null;
    currentBowler.value = null;
    partnershipRuns.value = 0;
    partnershipBalls.value = 0;

    for (final p in allPlayers) {
      p.isBatting = false;
      p.isOnStrike = false;
      p.isBowling = false;
    }
    allPlayers.refresh();

    // Sync innings 2 start to Firebase + re-affirm this device as the
    // active scorer (covers the case where innings-1 was done on this
    // device and innings-2 continues here — no takeover happens, but we
    // want the lock row present so a later takeover is detectable).
    //
    // ⚠️ The cloud write here MUST land before the share-with-Phone-B
    // popup appears, otherwise Phone B can enter the code+password and
    // the takeover gate (`join_scorer_service`) will read currentInnings
    // = 1 from cloud and reject with "Innings 1 not complete yet".
    // That's why this is awaited — and bounded with a timeout so a
    // flaky network can't lock up the UI.
    if (isOnlineMode.value) {
      await _claimAndWatchLock();
      try {
        await _syncToFirebase().timeout(const Duration(seconds: 6));
      } catch (e) {
        // Swallow — the popup still shows. If the cloud was unreachable
        // the global offline banner will already be visible and the
        // user can retry from there.
        // ignore: avoid_print
        print('⚠️ innings-2 cloud sync failed/timed out: $e');
      }
    }

    Get.snackbar(
      'Innings 2',
      'Time for ${inn2.battingTeam} to bat!',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      showShareWithTeamB.value = true;
    });
  }

  Future<void> _completeMatch() async {
    final m = match.value!;
    final allInn = await _repo.getAllInnings(m.id!);
    final inn1 = allInn.firstWhere((i) => i.inningsNumber == 1);
    final inn2 = allInn.firstWhere((i) => i.inningsNumber == 2);

    final team1Runs = inn1.totalRuns;
    final team2Runs = inn2.totalRuns;
    String result;
    String? winner;

    if (team2Runs > team1Runs) {
      final wicketsLeft = _getBattingTeamSize() - 1 - inn2.totalWickets;
      result = '${inn2.battingTeam} won by $wicketsLeft wickets';
      winner = inn2.battingTeam;
    } else if (team1Runs > team2Runs) {
      final diff = team1Runs - team2Runs;
      result = '${inn1.battingTeam} won by $diff runs';
      winner = inn1.battingTeam;
    } else {
      result = 'Match Tied';
    }

    final players = await _repo.getPlayersByMatch(m.id!);
    final winnerPlayers = winner != null
        ? players.where((p) => p.teamName == winner).toList()
        : players;
    winnerPlayers.sort((a, b) => b.runsScored.compareTo(a.runsScored));
    final motm = winnerPlayers.isNotEmpty ? winnerPlayers.first.name : null;

    final updated = m.copyWith(
      status: AppConstants.matchStatusCompleted,
      result: result,
      manOfTheMatch: motm,
      teamAScore: inn1.battingTeam == m.teamAName
          ? inn1.totalRuns
          : inn2.totalRuns,
      teamAWickets: inn1.battingTeam == m.teamAName
          ? inn1.totalWickets
          : inn2.totalWickets,
      teamABalls: inn1.battingTeam == m.teamAName
          ? inn1.totalBalls
          : inn2.totalBalls,
      teamBScore: inn1.battingTeam == m.teamBName
          ? inn1.totalRuns
          : inn2.totalRuns,
      teamBWickets: inn1.battingTeam == m.teamBName
          ? inn1.totalWickets
          : inn2.totalWickets,
      teamBBalls: inn1.battingTeam == m.teamBName
          ? inn1.totalBalls
          : inn2.totalBalls,
    );
    await _repo.updateMatch(updated);
    match.value = updated;

    // Mark completed in Firebase
    if (isOnlineMode.value && matchCode.value.isNotEmpty) {
      await _firebaseSync.markMatchCompleted(
        matchCode: matchCode.value,
        result: result,
        match: updated,
      );
      // Match is over — release the active-scorer lock so the node is
      // clean. Other devices opening this code will now just hydrate
      // from history, no scoring lock remains.
      await _lock.release(matchCode.value);
      _lockSub?.cancel();
      _lockSub = null;
    }

    await _session.clearActiveMatch();

    Get.offAllNamed(AppRoutes.matchSummary, arguments: m.id);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UNDO last ball
  //
  // Core insight: BallModel.batsmanName = who was on strike for that ball.
  // After undo, the striker is whoever faced the last remaining ball.
  // The nonStriker is whichever other batsman is still isBatting=true.
  // No need to replay complex swap logic.
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> undoLastBall() async {
    if (allBalls.isEmpty) return;
    final removed = allBalls.last;

    // ── 1. Delete ball from DB ─────────────────────────────────────────────
    await _repo.deleteBall(removed.id!);
    allBalls.removeLast();

    // ── 2. Reverse player stats for batter ────────────────────────────────
    final bat = allPlayers.firstWhereOrNull((p) => p.name == removed.batsmanName);
    if (bat != null) {
      if (!removed.isWide && !removed.isBye && !removed.isLegBye)
        bat.runsScored -= removed.runs;
      if (removed.runs == 4) bat.fours -= 1;
      if (removed.runs == 6) bat.sixes -= 1;
      if (removed.isValid)   bat.ballsFaced -= 1;
      await _repo.updatePlayer(bat);
      _updatePlayerLocal(bat);
    }

    // ── 3. Reverse player stats for bowler ────────────────────────────────
    final bowler = allPlayers.firstWhereOrNull((p) => p.name == removed.bowlerName);
    if (bowler != null) {
      if (removed.isValid)   bowler.ballsBowled  -= 1;
      if (!removed.isBye && !removed.isLegBye)
        bowler.runsConceded -= removed.totalRuns;
      if (removed.isWide)    bowler.wides        -= 1;
      if (removed.isNoBall)  bowler.noBalls      -= 1;
      if (removed.isWicket && removed.wicketType != AppConstants.wicketRunOut)
        bowler.wicketsTaken -= 1;
      await _repo.updatePlayer(bowler);
      _updatePlayerLocal(bowler);
    }

    // ── 4. Reverse wicket: restore dismissed batsman ───────────────────────
    if (removed.isWicket) {
      final outName = removed.outBatsmanName ?? removed.batsmanName;
      final outP    = allPlayers.firstWhereOrNull((p) => p.name == outName);
      if (outP != null) {
        outP.isOut       = false;
        outP.isBatting   = true;
        outP.isOnStrike  = false; // will be correctly set below
        outP.wicketType  = null;
        outP.bowlerName  = null;
        outP.dismissedBy = null;
        await _repo.updatePlayer(outP);
        _updatePlayerLocal(outP);
      }
    }

    // ── 5. Reverse innings totals ──────────────────────────────────────────
    final inn = currentInnings.value!;
    inn.totalRuns   -= removed.totalRuns;
    if (removed.isValid)  inn.totalBalls   -= 1;
    if (removed.isWide)   inn.wides        -= (1 + removed.runs);
    if (removed.isNoBall) inn.noBalls      -= 1;
    if (removed.isBye)    inn.byes         -= removed.runs;
    if (removed.isLegBye) inn.legByes      -= removed.runs;
    if (removed.isWicket) inn.totalWickets -= 1;
    await _repo.updateInnings(inn);

    // ── 6. Rebuild over state ──────────────────────────────────────────────
    _rebuildOverStateFromBalls();

    // ── 7. Assign striker / nonStriker from ball history ──────────────────
    _assignStrikerFromBallHistory(removed);

    // ── 8. Restore bowler ─────────────────────────────────────────────────
    _restoreBowlerFromBalls();

    // ── 9. Recalculate partnership ─────────────────────────────────────────
    _recalcPartnership();

    currentInnings.refresh();
    allPlayers.refresh();

    if (isOnlineMode.value) _syncToFirebase();
  }

  // ── Rebuild over counter from remaining balls ──────────────────────────────
  void _rebuildOverStateFromBalls() {
    if (allBalls.isEmpty) {
      currentOver.value    = 0;
      ballsInOver.value    = 0;
      isOverComplete.value = false;
      currentOverBalls.clear();
      return;
    }

    final lastBall = allBalls.last;
    final validInLastOver = allBalls
        .where((b) =>
    b.innings == inningsNumber &&
        b.overNumber == lastBall.overNumber &&
        b.isValid)
        .length;

    if (validInLastOver >= 6) {
      // Last over fully bowled — waiting for new bowler
      currentOver.value    = lastBall.overNumber + 1;
      ballsInOver.value    = 0;
      isOverComplete.value = true;
    } else {
      currentOver.value    = lastBall.overNumber;
      ballsInOver.value    = validInLastOver;
      isOverComplete.value = false;
    }

    _refreshCurrentOverBalls();
  }

  // ── Assign striker/nonStriker using ball history as ground truth ───────────
  //
  // Key rule: removed.batsmanName = who was ON STRIKE when that ball was bowled.
  //
  // Case A — normal ball (no over boundary after):
  //   Striker for NEXT ball = whoever should be on strike after this ball's runs.
  //   We don't need to compute this — just use the PREVIOUS ball's batsmanName
  //   as the striker, because the removed ball hasn't been bowled yet.
  //   → striker = removed.batsmanName, nonStriker = the other batsman.
  //
  // Case B — 6th ball (over boundary, _swapStrike was called):
  //   After undo of the 6th ball, we're back to ball 5 state.
  //   The over swap has been undone. So the striker at ball 5 end =
  //   whoever was striker BEFORE the 6th ball = removed.batsmanName.
  //   → same rule: striker = removed.batsmanName.
  //
  // Case C — wicket (dismissed batsman restored in step 4):
  //   removed.batsmanName = who was on strike (may be the dismissed one).
  //   After undo: both batsmen are back. The dismissed one returns to striker.
  //   removed.outBatsmanName tells us who was out.
  //   If outBatsmanName == batsmanName → striker was out → returns to striker.
  //   If outBatsmanName != batsmanName → nonStriker (run-out) was out → striker stays.
  //   → striker = removed.batsmanName always (the one who faced the ball).
  void _assignStrikerFromBallHistory(BallModel removed) {
    // After undo, striker = whoever faced the removed ball
    final strikerName    = removed.batsmanName;
    final allBatting     = allPlayers.where((p) => p.isBatting && !p.isOut).toList();

    if (allBatting.isEmpty) {
      striker.value    = null;
      nonStriker.value = null;
      return;
    }

    // Clear all isOnStrike flags first
    for (final p in allBatting) {
      p.isOnStrike = false;
    }

    final newStriker    = allBatting.firstWhereOrNull((p) => p.name == strikerName);
    final newNonStriker = allBatting.firstWhereOrNull((p) => p.name != strikerName);

    if (newStriker != null) {
      newStriker.isOnStrike    = true;
      striker.value            = newStriker;
      _repo.updatePlayer(newStriker);
      _updatePlayerLocal(newStriker);
    } else {
      // Striker name not in batting list (shouldn't happen) — pick first
      allBatting[0].isOnStrike = true;
      striker.value            = allBatting[0];
      _repo.updatePlayer(allBatting[0]);
      _updatePlayerLocal(allBatting[0]);
    }

    if (newNonStriker != null) {
      newNonStriker.isOnStrike = false;
      nonStriker.value         = newNonStriker;
      _repo.updatePlayer(newNonStriker);
      _updatePlayerLocal(newNonStriker);
    } else {
      nonStriker.value = null;
    }
  }

  // ── Restore current bowler from last remaining ball ────────────────────────
  void _restoreBowlerFromBalls() {
    if (allBalls.isEmpty) {
      if (currentBowler.value != null) {
        currentBowler.value!.isBowling = false;
        _repo.updatePlayer(currentBowler.value!);
        _updatePlayerLocal(currentBowler.value!);
        currentBowler.value = null;
      }
      return;
    }

    final lastBowlerName = allBalls.last.bowlerName;
    final prevBowler = allPlayers.firstWhereOrNull((p) => p.name == lastBowlerName);
    if (prevBowler == null) return;

    // Clear old bowler flag
    if (currentBowler.value != null && currentBowler.value!.name != prevBowler.name) {
      currentBowler.value!.isBowling = false;
      _repo.updatePlayer(currentBowler.value!);
      _updatePlayerLocal(currentBowler.value!);
    }

    // isBowling = true only if mid-over (not waiting for new bowler selection)
    prevBowler.isBowling = !isOverComplete.value;
    currentBowler.value  = prevBowler;
    _repo.updatePlayer(prevBowler);
    _updatePlayerLocal(prevBowler);
  }

  // ─── Extras toggle helpers ────────────────────────────────────────────────

  void toggleWide() {
    isWide.value = !isWide.value;
    if (isWide.value) isNoBall.value = false;
  }

  void toggleNoBall() {
    isNoBall.value = !isNoBall.value;
    if (isNoBall.value) isWide.value = false;
  }

  void toggleBye() {
    isBye.value = !isBye.value;
    if (isBye.value) isLegBye.value = false;
  }

  void toggleLegBye() {
    isLegBye.value = !isLegBye.value;
    if (isLegBye.value) isBye.value = false;
  }

  // ─── Getters ──────────────────────────────────────────────────────────────

  List<PlayerModel> get battingTeamPlayers {
    final team = currentInnings.value?.battingTeam ?? '';
    return allPlayers.where((p) => p.teamName == team).toList();
  }

  List<PlayerModel> get bowlingTeamPlayers {
    final team = currentInnings.value?.bowlingTeam ?? '';
    return allPlayers.where((p) => p.teamName == team).toList();
  }

  List<PlayerModel> get availableBatsmen {
    return battingTeamPlayers
        .where((p) =>
    !p.isOut &&
        p.id != striker.value?.id &&
        p.id != nonStriker.value?.id)
        .toList();
  }

  String? get lastCompletedOverBowler {
    if (allBalls.isEmpty) return null;
    final completedOverNum = currentOver.value - 1;
    if (completedOverNum < 0) return null;
    final prevBalls = allBalls
        .where((b) =>
    b.innings == inningsNumber &&
        b.overNumber == completedOverNum)
        .toList();
    return prevBalls.isNotEmpty ? prevBalls.first.bowlerName : null;
  }

  List<PlayerModel> get availableBowlers {
    final blocked = lastCompletedOverBowler;
    return bowlingTeamPlayers.where((p) => p.name != blocked).toList();
  }

  List<Map<String, dynamic>> get bowlerOverTimeline {
    if (allBalls.isEmpty) return [];
    final Map<int, List<BallModel>> grouped = {};
    for (final b in allBalls) {
      if (b.innings == inningsNumber) {
        grouped.putIfAbsent(b.overNumber, () => []).add(b);
      }
    }
    final result = <Map<String, dynamic>>[];
    final sortedOvers = grouped.keys.toList()..sort();
    for (final over in sortedOvers) {
      final balls = grouped[over]!;
      final runs = balls.fold<int>(0, (s, b) => s + b.totalRuns);
      final wickets = balls.where((b) => b.isWicket).length;
      final bowlerName = balls.first.bowlerName;
      result.add({
        'over': over,
        'bowler': bowlerName,
        'runs': runs,
        'wickets': wickets,
        'isCurrentOver': over == currentOver.value,
        'balls': balls,
      });
    }
    return result;
  }

  String get scoreDisplay {
    final inn = currentInnings.value;
    if (inn == null) return '0/0';
    return '${inn.totalRuns}/${inn.totalWickets}';
  }

  String get oversDisplay {
    final inn = currentInnings.value;
    if (inn == null) return '0.0';
    return AppUtils.formatOvers(inn.totalBalls);
  }

  double get runRate {
    final inn = currentInnings.value;
    if (inn == null || inn.totalBalls == 0) return 0.0;
    return AppUtils.calculateRunRate(inn.totalRuns, inn.totalBalls);
  }

  double get requiredRunRate {
    if (inningsNumber != 2) return 0.0;
    final inn = currentInnings.value;
    final m = match.value;
    if (inn == null || m == null) return 0.0;
    final inn1Score = inn.bowlingTeam == m.teamAName
        ? (m.teamAScore ?? 0)
        : (m.teamBScore ?? 0);
    final runsNeeded = inn1Score - inn.totalRuns + 1;
    final ballsRemaining = m.totalOvers * 6 - inn.totalBalls;
    return AppUtils.calculateRequiredRunRate(runsNeeded, ballsRemaining);
  }

  int get runsNeeded {
    if (inningsNumber != 2) return 0;
    final inn = currentInnings.value;
    final m = match.value;
    if (inn == null || m == null) return 0;
    final inn1Score = inn.bowlingTeam == m.teamAName
        ? (m.teamAScore ?? 0)
        : (m.teamBScore ?? 0);
    return inn1Score - inn.totalRuns + 1;
  }

  String get currentInningsLabel {
    return currentInnings.value != null
        ? 'Innings ${currentInnings.value!.inningsNumber}: ${currentInnings.value!.battingTeam}'
        : '';
  }

  List<Map<String, dynamic>> get previousOversHistory {
    if (allBalls.isEmpty) return [];
    final Map<int, List<BallModel>> grouped = {};
    for (final b in allBalls) {
      grouped.putIfAbsent(b.overNumber, () => []).add(b);
    }
    final result = <Map<String, dynamic>>[];
    final sortedOvers = grouped.keys.toList()..sort();
    for (final over in sortedOvers) {
      if (over == currentOver.value && !isOverComplete.value) continue;
      final balls = grouped[over]!;
      final runs = balls.fold<int>(0, (sum, b) => sum + b.totalRuns);
      final wickets = balls.where((b) => b.isWicket).length;
      result.add({
        'over': over,
        'balls': balls,
        'runs': runs,
        'wickets': wickets,
      });
    }
    return result;
  }

  List<PlayerModel> get battingScorecard {
    final team = currentInnings.value?.battingTeam ?? '';
    return allPlayers
        .where((p) => p.teamName == team)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  List<PlayerModel> get bowlingScorecard {
    final team = currentInnings.value?.bowlingTeam ?? '';
    return allPlayers
        .where((p) => p.teamName == team && p.ballsBowled > 0)
        .toList()
      ..sort((a, b) => b.ballsBowled.compareTo(a.ballsBowled));
  }
}