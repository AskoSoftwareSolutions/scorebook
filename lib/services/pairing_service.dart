// ─────────────────────────────────────────────────────────────────────────────
// lib/services/pairing_service.dart  (UPDATED)
//
// Changes:
//   1. Knockout — generate ALL rounds upfront (including Final) with placeholders
//   2. pickAutoUmpire — only consider teams NOT playing in the match + not eliminated
//   3. New helper: resolveWinnerAfterMatch — updates subsequent matches with winner
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';
import '../models/tournament_models.dart';
import '../repositories/tournament_repository.dart';

class PairingService {
  static final PairingService _i = PairingService._();
  factory PairingService() => _i;
  PairingService._();

  final _repo = TournamentRepository();

  /// Generate ALL matches (all rounds for knockout) upfront.
  List<TournamentMatchModel> generatePairings({
    required TournamentModel tournament,
    required List<TournamentTeamModel> teams,
    required DateTime startTime,
    Duration matchGap = const Duration(hours: 2),
  }) {
    switch (tournament.format) {
      case TournamentFormat.knockout:
        return _knockoutAllRounds(tournament, teams, startTime, matchGap);
      case TournamentFormat.random:
        return _randomPairings(tournament, teams, startTime, matchGap);
      case TournamentFormat.manual:
        return [];
    }
  }

  // ── KNOCKOUT — generate all rounds upfront ───────────────────────────────
  //
  // For 4 teams: Round 1 (2 matches) + Final (1 match with WINNER_OF: placeholders)
  // For 6 teams: Round 1 (3 matches) + SF (1 auto + 1 placeholder) + Final
  // For 8 teams: Round 1 (4) + QF (2 placeholders) + SF (1 placeholder) + Final
  //
  // Placeholder teams use special ID format:
  //   "WINNER_OF:<matchId>"   → will be resolved when source match completes
  //   "LOSER_OF:<matchId>"    → used for umpire assignment
  List<TournamentMatchModel> _knockoutAllRounds(
      TournamentModel t,
      List<TournamentTeamModel> teams,
      DateTime start,
      Duration gap,
      ) {
    if (teams.length < 2) return [];

    final shuffled = [...teams]..shuffle(Random());
    final allMatches = <TournamentMatchModel>[];
    DateTime nextTime = start;

    // ── ROUND 1 ───────────────────────────────────────────────
    final round1Matches = <TournamentMatchModel>[];
    final pairCount = shuffled.length ~/ 2;
    for (int i = 0; i < pairCount; i++) {
      final a = shuffled[i * 2];
      final b = shuffled[i * 2 + 1];
      final match = _buildMatch(
        tournament: t,
        teamAId: a.id,
        teamAName: a.name,
        teamBId: b.id,
        teamBName: b.name,
        scheduledTime: nextTime,
        round: 1,
        orderIndex: i,
      );
      round1Matches.add(match);
      allMatches.add(match);
      nextTime = nextTime.add(gap);
    }

    // ── Subsequent rounds with placeholders ───────────────────
    List<TournamentMatchModel> previousRound = round1Matches;
    int roundNum = 2;

    while (previousRound.length >= 2) {
      final nextRound = <TournamentMatchModel>[];

      for (int i = 0; i + 1 < previousRound.length; i += 2) {
        final sourceA = previousRound[i];
        final sourceB = previousRound[i + 1];

        final match = _buildMatch(
          tournament: t,
          teamAId: 'WINNER_OF:${sourceA.id}',
          teamAName: 'Winner of Match ${i + 1} (R${sourceA.round})',
          teamBId: 'WINNER_OF:${sourceB.id}',
          teamBName: 'Winner of Match ${i + 2} (R${sourceB.round})',
          scheduledTime: nextTime,
          round: roundNum,
          orderIndex: i ~/ 2,
        );
        nextRound.add(match);
        allMatches.add(match);
        nextTime = nextTime.add(gap);
      }

      previousRound = nextRound;
      roundNum++;
    }

    return allMatches;
  }

  // ── RANDOM PAIRING (single round) ────────────────────────────────────────
  List<TournamentMatchModel> _randomPairings(
      TournamentModel t,
      List<TournamentTeamModel> teams,
      DateTime start,
      Duration gap,
      ) {
    if (teams.length < 2) return [];

    final shuffled = [...teams]..shuffle(Random());
    final matches = <TournamentMatchModel>[];

    for (int i = 0; i + 1 < shuffled.length; i += 2) {
      matches.add(_buildMatch(
        tournament: t,
        teamAId: shuffled[i].id,
        teamAName: shuffled[i].name,
        teamBId: shuffled[i + 1].id,
        teamBName: shuffled[i + 1].name,
        scheduledTime: start.add(gap * (i ~/ 2)),
        round: 1,
        orderIndex: i ~/ 2,
      ));
    }

    return matches;
  }

  // ── MANUAL PAIRING (single match) ────────────────────────────────────────
  TournamentMatchModel createManualPairing({
    required TournamentModel tournament,
    required TournamentTeamModel teamA,
    required TournamentTeamModel teamB,
    required DateTime scheduledTime,
    int round = 1,
    int orderIndex = 0,
  }) {
    return _buildMatch(
      tournament: tournament,
      teamAId: teamA.id,
      teamAName: teamA.name,
      teamBId: teamB.id,
      teamBName: teamB.name,
      scheduledTime: scheduledTime,
      round: round,
      orderIndex: orderIndex,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UMPIRE ASSIGNMENT
  // ═══════════════════════════════════════════════════════════════════════

  /// Pick an umpire from teams NOT currently playing in this match.
  /// Excludes teams that:
  ///   - Are playing in this match (teamAId, teamBId)
  ///   - Are eliminated (for knockout tournaments)
  ///   - Are already umpiring OTHER parallel matches (optional strict mode)
  TournamentTeamModel? pickAutoUmpire({
    required List<TournamentTeamModel> allTeams,
    required String playingTeamAId,
    required String playingTeamBId,
    List<String> excludeTeamIds = const [],  // optional: teams umpiring other matches
  }) {
    final candidates = allTeams.where((t) {
      // Not playing this match
      if (t.id == playingTeamAId) return false;
      if (t.id == playingTeamBId) return false;
      // Not eliminated
      if (t.eliminated) return false;
      // Not in exclude list
      if (excludeTeamIds.contains(t.id)) return false;
      return true;
    }).toList();

    if (candidates.isEmpty) return null;
    candidates.shuffle(Random());
    return candidates.first;
  }

  /// Get list of "free" teams (not playing, not eliminated) for a specific match.
  /// Used in UI to show umpire selection dropdown.
  List<TournamentTeamModel> getFreeTeamsForMatch({
    required List<TournamentTeamModel> allTeams,
    required String playingTeamAId,
    required String playingTeamBId,
  }) {
    return allTeams.where((t) {
      if (t.id == playingTeamAId) return false;
      if (t.id == playingTeamBId) return false;
      if (t.eliminated) return false;
      return true;
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PLACEHOLDER RESOLUTION (Knockout)
  // ═══════════════════════════════════════════════════════════════════════

  /// After a match completes with a winner, find all subsequent matches that
  /// have placeholders referring to this match and update them with the actual
  /// winner's team info.
  ///
  /// Returns list of updated matches (call repo.updateMatch for each).
  List<TournamentMatchModel> resolveWinnerPlaceholders({
    required TournamentMatchModel completedMatch,
    required List<TournamentMatchModel> allMatches,
    required List<TournamentTeamModel> allTeams,
  }) {
    if (completedMatch.winnerTeamId == null) return [];

    final winnerId = completedMatch.winnerTeamId!;
    final winner = allTeams.firstWhere(
          (t) => t.id == winnerId,
      orElse: () => TournamentTeamModel(
        id: winnerId,
        tournamentId: completedMatch.tournamentId,
        name: completedMatch.winnerTeamName ?? 'Winner',
      ),
    );

    final updates = <TournamentMatchModel>[];

    for (final m in allMatches) {
      if (m.id == completedMatch.id) continue;
      if (m.status != TournamentMatchStatus.scheduled) continue;

      var updated = m;
      bool changed = false;

      // Team A placeholder?
      if (m.teamAIsPlaceholder &&
          m.teamASourceMatchId == completedMatch.id &&
          m.teamAId.startsWith('WINNER_OF:')) {
        updated = updated.copyWith(
          teamAId: winner.id,
          teamAName: winner.name,
        );
        changed = true;
      }

      // Team B placeholder?
      if (m.teamBIsPlaceholder &&
          m.teamBSourceMatchId == completedMatch.id &&
          m.teamBId.startsWith('WINNER_OF:')) {
        updated = updated.copyWith(
          teamBId: winner.id,
          teamBName: winner.name,
        );
        changed = true;
      }

      if (changed) updates.add(updated);
    }

    return updates;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD MATCH (private helper)
  // ═══════════════════════════════════════════════════════════════════════

  TournamentMatchModel _buildMatch({
    required TournamentModel tournament,
    required String teamAId,
    required String teamAName,
    required String teamBId,
    required String teamBName,
    required DateTime scheduledTime,
    required int round,
    required int orderIndex,
  }) {
    return TournamentMatchModel(
      id:              _repo.generateId(),
      tournamentId:    tournament.id,
      teamAId:         teamAId,
      teamAName:       teamAName,
      teamBId:         teamBId,
      teamBName:       teamBName,
      umpireMode:      tournament.umpireMode,
      umpireTeamId:    null,
      umpireTeamName:  null,
      scheduledTime:   scheduledTime,
      status:          TournamentMatchStatus.scheduled,
      totalOvers:      tournament.totalOvers,
      round:           round,
      orderIndex:      orderIndex,
    );
  }
}