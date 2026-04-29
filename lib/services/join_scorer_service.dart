// ─────────────────────────────────────────────────────────────────────────────
// lib/services/join_scorer_service.dart
//
// Mid-match takeover by a second device.
//
// Phone B enters the match code (+ password) on the join screen and this
// service rebuilds the match locally from whatever Firebase currently has —
// regardless of whether Phone A is still in innings 1, between innings, or
// already in innings 2.
//
// We import:
//   • full match meta (teams, overs, current innings)
//   • full rosters with running batting + bowling stats
//   • current striker / non-striker / bowler flags
//   • ball-by-ball log so the over strip + undo continue to work
//   • innings 1 (and 2 if applicable) summaries
//
// Then we save online-mode session info, claim the active-scorer lock by
// way of LiveScoringViewModel.loadMatch(), and route Phone B straight into
// the live scoring screen — same screen Phone A is on, mirroring its state.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/models.dart';
import '../repositories/match_repository.dart';
import '../services/firebase_sync_service.dart';
import '../services/match_cloud_pull_service.dart';
import '../services/session_service.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_routes.dart';

class JoinScorerService {
  static final JoinScorerService _i = JoinScorerService._();
  factory JoinScorerService() => _i;
  JoinScorerService._();

  final _sync = FirebaseSyncService();
  final _repo = MatchRepository();

  Future<String?> joinAsScorer(String matchCode, String password) async {
    try {
      final data = await _sync.getMatchData(matchCode);
      if (data == null) return 'Match not found. Check the code.';

      // ── Password verify ───────────────────────────────────────────────
      final storedPassword = data['passwordHash'] as String? ?? '';
      if (storedPassword.isNotEmpty &&
          password.trim() != storedPassword.trim()) {
        return 'Incorrect password. Please try again.';
      }

      final status = data['status'] as String? ?? '';
      if (status == 'completed') return 'Match already completed.';

      // ── Read live state ────────────────────────────────────────────────
      // We support takeover at ANY point now — no innings-1 gate. Phone B
      // mirrors whatever Phone A's current state is.
      final currentInnings = data['currentInnings'] as int? ?? 1;
      final teamA       = data['teamA']       as String? ?? 'Team A';
      final teamB       = data['teamB']       as String? ?? 'Team B';
      final totalOvers  = data['totalOvers']  as int?    ?? 20;
      final battingTeam = data['battingTeam'] as String? ?? teamA;
      final bowlingTeam = data['bowlingTeam'] as String? ??
          (battingTeam == teamA ? teamB : teamA);

      final liveScore   = data['score']       as int? ?? 0;
      final liveWickets = data['wickets']     as int? ?? 0;
      final liveBalls   = data['totalBalls']  as int? ?? 0;
      final liveWides   = data['wides']       as int? ?? 0;
      final liveNoBalls = data['noBalls']     as int? ?? 0;
      final liveByes    = data['byes']        as int? ?? 0;
      final liveLegByes = data['legByes']     as int? ?? 0;

      final inn1Score   = data['inn1Score']   as int? ?? 0;
      final inn1Wickets = data['inn1Wickets'] as int? ?? 0;
      final inn1Balls   = data['inn1Balls']   as int? ?? 0;

      final strikerName    = (data['striker']    as String? ?? '').trim();
      final nonStrikerName = (data['nonStriker'] as String? ?? '').trim();
      final bowlerName     = (data['bowler']     as String? ?? '').trim();

      // ── Rosters ────────────────────────────────────────────────────────
      // Prefer full rosters; fall back to batter/bowler lists for older
      // matches that predate the roster fields.
      final rosterA = ((data['rosterA'] as List?) ?? [])
          .map((b) => Map<String, dynamic>.from(b as Map))
          .toList();
      final rosterB = ((data['rosterB'] as List?) ?? [])
          .map((b) => Map<String, dynamic>.from(b as Map))
          .toList();

      List<Map<String, dynamic>> fallbackRoster(String teamName) {
        final batters = ((data['batters'] as List?) ?? [])
            .map((b) => Map<String, dynamic>.from(b as Map))
            .toList();
        final bowlers = ((data['bowlers'] as List?) ?? [])
            .map((b) => Map<String, dynamic>.from(b as Map))
            .toList();
        final dataBatting = data['battingTeam'] as String? ?? '';
        final dataBowling = data['bowlingTeam'] as String? ?? '';
        if (teamName == dataBatting) return batters;
        if (teamName == dataBowling) return bowlers;
        return [];
      }

      final effectiveRosterA =
          rosterA.isNotEmpty ? rosterA : fallbackRoster(teamA);
      final effectiveRosterB =
          rosterB.isNotEmpty ? rosterB : fallbackRoster(teamB);

      if (effectiveRosterA.isEmpty && effectiveRosterB.isEmpty) {
        return 'Player data not available.';
      }

      // ── Who batted first? ──────────────────────────────────────────────
      // For currentInnings == 2: bowlingTeam now == team that batted first.
      // For currentInnings == 1: battingTeam IS the team batting first.
      final firstInnBatTeam =
          currentInnings == 2 ? bowlingTeam : battingTeam;
      final firstInnBowlTeam =
          firstInnBatTeam == teamA ? teamB : teamA;

      // ── Cross-innings totals on MatchModel ─────────────────────────────
      // Live totals reflect the CURRENT batting team. For a mid-innings-2
      // takeover, the bowling team's totals are the (frozen) innings-1
      // totals.
      int? maTeamAScore, maTeamAWickets, maTeamABalls;
      int? maTeamBScore, maTeamBWickets, maTeamBBalls;

      if (battingTeam == teamA) {
        maTeamAScore = liveScore;
        maTeamAWickets = liveWickets;
        maTeamABalls = liveBalls;
      } else {
        maTeamBScore = liveScore;
        maTeamBWickets = liveWickets;
        maTeamBBalls = liveBalls;
      }
      if (currentInnings == 2) {
        if (bowlingTeam == teamA) {
          maTeamAScore = inn1Score;
          maTeamAWickets = inn1Wickets;
          maTeamABalls = inn1Balls;
        } else {
          maTeamBScore = inn1Score;
          maTeamBWickets = inn1Wickets;
          maTeamBBalls = inn1Balls;
        }
      }

      final match = MatchModel(
        teamAName:      teamA,
        teamBName:      teamB,
        totalOvers:     totalOvers,
        tossWinner:     firstInnBatTeam,
        battingFirst:   firstInnBatTeam,
        matchDate:      DateTime.now(),
        status:         AppConstants.matchStatusInProgress,
        currentInnings: currentInnings,
        teamAScore:     maTeamAScore,
        teamAWickets:   maTeamAWickets,
        teamABalls:     maTeamABalls,
        teamBScore:     maTeamBScore,
        teamBWickets:   maTeamBWickets,
        teamBBalls:     maTeamBBalls,
      );

      final matchId = await _repo.createMatch(match);

      // ── Import rosters with stats + flag striker/nonStriker/bowler ───
      Future<void> importRoster(
          List<Map<String, dynamic>> roster, String teamName) async {
        if (roster.isEmpty) {
          await _repo.createPlayer(PlayerModel(
              matchId: matchId,
              teamName: teamName,
              name: 'Player 1',
              orderIndex: 0));
          await _repo.createPlayer(PlayerModel(
              matchId: matchId,
              teamName: teamName,
              name: 'Player 2',
              orderIndex: 1));
          return;
        }
        for (int i = 0; i < roster.length; i++) {
          final r = roster[i];
          final name = (r['name'] as String? ?? '').trim();
          if (name.isEmpty) continue;

          // Only flag positional state for players in the CURRENT batting
          // / bowling team — guards against same-name collisions.
          final isCurrentlyBatting = teamName == battingTeam;
          final isCurrentlyBowling = teamName == bowlingTeam;
          final isStriker    = isCurrentlyBatting && name == strikerName;
          final isNonStriker = isCurrentlyBatting && name == nonStrikerName;
          final isBowler     = isCurrentlyBowling && name == bowlerName;

          await _repo.createPlayer(PlayerModel(
            matchId: matchId,
            teamName: teamName,
            name: name,
            orderIndex: (r['orderIndex'] as int?) ?? i,
            runsScored: (r['runsScored'] as int?) ??
                (r['runs'] as int?) ??
                0,
            ballsFaced: (r['ballsFaced'] as int?) ??
                (r['balls'] as int?) ??
                0,
            fours: (r['fours'] as int?) ?? 0,
            sixes: (r['sixes'] as int?) ?? 0,
            isOut: (r['isOut'] as bool?) ?? false,
            wicketType: (r['wicketType'] as String?)?.isEmpty == true
                ? null
                : r['wicketType'] as String?,
            dismissedBy: (r['dismissedBy'] as String?)?.isEmpty == true
                ? null
                : r['dismissedBy'] as String?,
            bowlerName: (r['bowlerName'] as String?)?.isEmpty == true
                ? null
                : r['bowlerName'] as String?,
            didBat: ((r['didBat'] as bool?) ?? false) ||
                isStriker ||
                isNonStriker,
            ballsBowled: (r['ballsBowled'] as int?) ?? 0,
            runsConceded: (r['runsConceded'] as int?) ?? 0,
            wicketsTaken: (r['wicketsTaken'] as int?) ?? 0,
            wides: (r['wides'] as int?) ?? 0,
            noBalls: (r['noBalls'] as int?) ?? 0,
            isBatting:  isStriker || isNonStriker,
            isOnStrike: isStriker,
            isBowling:  isBowler,
          ));
        }
      }

      await importRoster(effectiveRosterA, teamA);
      await importRoster(effectiveRosterB, teamB);

      // ── Innings 1 ─────────────────────────────────────────────────────
      // For currentInnings==1 takeover, innings 1 is still in progress and
      // should reflect live totals. For currentInnings==2 takeover, innings
      // 1 is completed with frozen inn1Score/inn1Wickets.
      await _repo.createInnings(InningsModel(
        matchId: matchId,
        inningsNumber: 1,
        battingTeam: firstInnBatTeam,
        bowlingTeam: firstInnBowlTeam,
        totalRuns:    currentInnings == 1 ? liveScore   : inn1Score,
        totalWickets: currentInnings == 1 ? liveWickets : inn1Wickets,
        totalBalls:   currentInnings == 1 ? liveBalls   : inn1Balls,
        wides:        currentInnings == 1 ? liveWides   : 0,
        noBalls:      currentInnings == 1 ? liveNoBalls : 0,
        byes:         currentInnings == 1 ? liveByes    : 0,
        legByes:      currentInnings == 1 ? liveLegByes : 0,
        isCompleted:  currentInnings == 2,
      ));

      // ── Innings 2 (only if Phone A has already moved to innings 2) ───
      if (currentInnings == 2) {
        await _repo.createInnings(InningsModel(
          matchId: matchId,
          inningsNumber: 2,
          battingTeam: firstInnBowlTeam,
          bowlingTeam: firstInnBatTeam,
          totalRuns:    liveScore,
          totalWickets: liveWickets,
          totalBalls:   liveBalls,
          wides:        liveWides,
          noBalls:      liveNoBalls,
          byes:         liveByes,
          legByes:      liveLegByes,
        ));
      }

      // ── Import ball-by-ball log ───────────────────────────────────────
      // Drives the over strip, partnership calc, and undo. Wrapped in
      // try/catch per ball so one malformed entry can't break the whole
      // takeover.
      final ballLog = ((data['balls'] as List?) ?? [])
          .whereType<Map>()
          .map((b) => Map<String, dynamic>.from(b))
          .toList();
      for (final b in ballLog) {
        try {
          await _repo.addBall(BallModel(
            matchId:    matchId,
            innings:    (b['innings'] as int?) ?? 1,
            overNumber: (b['over']    as int?) ?? 0,
            ballNumber: (b['ball']    as int?) ?? 1,
            batsmanName: (b['batsman'] as String?) ?? '',
            bowlerName:  (b['bowler']  as String?) ?? '',
            runs:        (b['runs']    as int?)    ?? 0,
            isWide:      (b['isWide']    as bool?) ?? false,
            isNoBall:    (b['isNoBall']  as bool?) ?? false,
            isBye:       (b['isBye']     as bool?) ?? false,
            isLegBye:    (b['isLegBye']  as bool?) ?? false,
            isWicket:    (b['isWicket']  as bool?) ?? false,
            wicketType:    (b['wicketType']  as String?)?.isEmpty == true
                ? null
                : b['wicketType'] as String?,
            outBatsmanName: (b['outBatsman'] as String?)?.isEmpty == true
                ? null
                : b['outBatsman'] as String?,
            fielderName:    (b['fielder']    as String?)?.isEmpty == true
                ? null
                : b['fielder']    as String?,
            extraRuns: 0,
            totalRuns: (b['total'] as int?) ?? 0,
            isValid:   (b['isValid'] as bool?) ?? true,
          ));
        } catch (_) {/* skip malformed entries */}
      }

      // ── Session + lock + cloud bind ───────────────────────────────────
      await SessionService().saveActiveMatch(
        matchId: matchId, teamA: teamA,
        teamB: teamB, totalOvers: totalOvers,
      );
      // Persist online-mode context so LiveScoringViewModel.loadMatch()
      // re-claims the exclusive scoring lock → Phone A is bumped to the
      // live viewer page automatically.
      await SessionService().saveOnlineMode(
        isActive:  true,
        matchCode: matchCode,
        password:  password,
      );
      // Bind local↔cloud so summary auto-pulls remote data.
      await MatchCloudPullService().bindLocalToCloud(matchId, matchCode);

      // ── Route directly to live scoring ────────────────────────────────
      // The match is already in progress with current striker / non-striker
      // / bowler set on Phone A's side, so there's nothing for Phone B to
      // "confirm" — route straight into the same view Phone A is on.
      Get.offAllNamed(AppRoutes.liveScoring, arguments: matchId);
      return null;

    } catch (e) {
      debugPrint('[JoinScorerService] error: $e');
      return 'Something went wrong. Please try again.';
    }
  }
}
