import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/models.dart';
import '../repositories/match_repository.dart';
import '../services/firebase_sync_service.dart';
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
      if (storedPassword.isNotEmpty && password.trim() != storedPassword.trim()) {
        return 'Incorrect password. Please try again.';
      }

      final status = data['status'] as String? ?? '';
      if (status == 'completed') return 'Match already completed.';

      final currentInnings = data['currentInnings'] as int? ?? 1;
      if (currentInnings != 2) {
        return 'Innings 1 not complete yet. Please wait.';
      }

      final teamA       = data['teamA']       as String? ?? 'Team A';
      final teamB       = data['teamB']       as String? ?? 'Team B';
      final totalOvers  = data['totalOvers']  as int?    ?? 20;
      final battingTeam = data['battingTeam'] as String? ?? teamB;
      final inn1Score   = data['inn1Score']   as int?    ?? 0;
      final inn1Wickets = data['inn1Wickets'] as int?    ?? 0;

      // ── Prefer full rosters; fall back to batter/bowler lists for
      //    older matches that predate the roster fields ────────────────────
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

      final isTeamABatting1st = battingTeam == teamB;

      final match = MatchModel(
        teamAName:      teamA,
        teamBName:      teamB,
        totalOvers:     totalOvers,
        tossWinner:     teamA,
        battingFirst:   isTeamABatting1st ? teamA : teamB,
        matchDate:      DateTime.now(),
        status:         AppConstants.matchStatusInProgress,
        currentInnings: 2,
        teamAScore:     isTeamABatting1st ? inn1Score : null,
        teamAWickets:   isTeamABatting1st ? inn1Wickets : null,
        teamABalls:     null,
        teamBScore:     isTeamABatting1st ? null : inn1Score,
        teamBWickets:   isTeamABatting1st ? null : inn1Wickets,
        teamBBalls:     null,
      );

      final matchId = await _repo.createMatch(match);

      Future<void> _importRoster(
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
            didBat: (r['didBat'] as bool?) ?? false,
            ballsBowled: (r['ballsBowled'] as int?) ?? 0,
            runsConceded: (r['runsConceded'] as int?) ?? 0,
            wicketsTaken: (r['wicketsTaken'] as int?) ?? 0,
            wides: (r['wides'] as int?) ?? 0,
            noBalls: (r['noBalls'] as int?) ?? 0,
          ));
        }
      }

      await _importRoster(effectiveRosterA, teamA);
      await _importRoster(effectiveRosterB, teamB);

      final inn1BattingTeam = isTeamABatting1st ? teamA : teamB;
      final inn1BowlingTeam = isTeamABatting1st ? teamB : teamA;

      await _repo.createInnings(InningsModel(
        matchId: matchId, inningsNumber: 1,
        battingTeam: inn1BattingTeam, bowlingTeam: inn1BowlingTeam,
        totalRuns: inn1Score, totalWickets: inn1Wickets,
        isCompleted: true,
      ));

      await _repo.createInnings(InningsModel(
        matchId: matchId, inningsNumber: 2,
        battingTeam: inn1BowlingTeam, bowlingTeam: inn1BattingTeam,
      ));

      await SessionService().saveActiveMatch(
        matchId: matchId, teamA: teamA,
        teamB: teamB, totalOvers: totalOvers,
      );

      // Route to roster confirmation; user starts scoring only after
      // they review + approve the imported names.
      Get.offAllNamed(AppRoutes.confirmRoster, arguments: matchId);
      return null;

    } catch (e) {
      debugPrint('[JoinScorerService] error: $e');
      return 'Something went wrong. Please try again.';
    }
  }
}