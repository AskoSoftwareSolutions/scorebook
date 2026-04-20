// ─────────────────────────────────────────────────────────────────────────────
// lib/viewmodels/tournament_toss_viewmodel.dart
//
// Handles the toss flow for a tournament match:
//   1. Load match + teams
//   2. Animate coin toss → random team wins
//   3. Team captain chooses bat/bowl
//   4. Edit player list (optional)
//   5. Start match → create local SQLite match → navigate to live scoring
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_routes.dart';
import '../models/models.dart';
import '../models/tournament_models.dart';
import '../repositories/match_repository.dart';
import '../repositories/tournament_repository.dart';
import '../services/pairing_service.dart';
import '../services/session_service.dart';

class TournamentTossViewModel extends GetxController {
  final TournamentRepository _tRepo = TournamentRepository();
  final MatchRepository _mRepo = Get.find<MatchRepository>();
  final PairingService _pairing = PairingService();
  final SessionService _session = SessionService();

  // IDs passed as arguments: {'tournamentId': '...', 'matchId': '...'}
  late final String tournamentId;
  late final String matchId;

  // Loaded data
  final Rx<TournamentModel?> tournament = Rx<TournamentModel?>(null);
  final Rx<TournamentMatchModel?> match = Rx<TournamentMatchModel?>(null);
  final Rx<TournamentTeamModel?> teamA = Rx<TournamentTeamModel?>(null);
  final Rx<TournamentTeamModel?> teamB = Rx<TournamentTeamModel?>(null);
  final RxList<TournamentTeamModel> allTeams = <TournamentTeamModel>[].obs;

  // Toss state
  final RxBool isTossing = false.obs;
  final RxBool tossComplete = false.obs;
  final Rx<TournamentTeamModel?> tossWinner = Rx<TournamentTeamModel?>(null);

  // Bat/Bowl choice
  final Rx<TournamentTeamModel?> battingFirst = Rx<TournamentTeamModel?>(null);

  // Editable players (prefilled from team, can be edited before match start)
  final RxList<String> teamAPlayers = <String>[].obs;
  final RxList<String> teamBPlayers = <String>[].obs;

  // Umpire (auto-assigned if tournament.umpireMode == auto and not yet set)
  final Rx<TournamentTeamModel?> umpireTeam = Rx<TournamentTeamModel?>(null);
  final RxBool canChangeUmpire = false.obs;

  final RxBool isLoading = false.obs;
  final RxBool isStarting = false.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>;
    tournamentId = args['tournamentId'] as String;
    matchId      = args['matchId']      as String;
    _load();
  }

  Future<void> _load() async {
    isLoading.value = true;
    try {
      tournament.value = await _tRepo.getTournament(tournamentId);
      match.value      = await _tRepo.getMatch(tournamentId, matchId);
      allTeams.value   = await _tRepo.getTeams(tournamentId);

      if (match.value != null) {
        teamA.value = allTeams.firstWhereOrNull(
                (t) => t.id == match.value!.teamAId);
        teamB.value = allTeams.firstWhereOrNull(
                (t) => t.id == match.value!.teamBId);

        teamAPlayers.value = teamA.value?.players.toList() ?? [];
        teamBPlayers.value = teamB.value?.players.toList() ?? [];

        // If umpire already assigned (manual mode), load it
        if (match.value!.umpireTeamId != null) {
          umpireTeam.value = allTeams.firstWhereOrNull(
                  (t) => t.id == match.value!.umpireTeamId);
        }

        // If tournament is manual umpire and umpire not yet set → user picks
        // If auto → auto-pick right now if not already picked
        final mode = tournament.value?.umpireMode ?? UmpireMode.auto;
        if (mode == UmpireMode.auto && umpireTeam.value == null) {
          _autoAssignUmpire();
        }
        canChangeUmpire.value = mode == UmpireMode.manual;
      }
    } finally {
      isLoading.value = false;
    }
  }

  void _autoAssignUmpire() {
    final match = this.match.value;
    if (match == null) return;
    final picked = _pairing.pickAutoUmpire(
      allTeams:        allTeams.toList(),
      playingTeamAId:  match.teamAId,
      playingTeamBId:  match.teamBId,
    );
    umpireTeam.value = picked;
  }

  void setUmpire(TournamentTeamModel team) {
    umpireTeam.value = team;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TOSS
  // ═══════════════════════════════════════════════════════════════════════

  /// Run coin toss animation. After ~2 seconds, a random team wins.
  Future<void> runToss() async {
    if (isTossing.value || tossComplete.value) return;
    if (teamA.value == null || teamB.value == null) return;

    isTossing.value = true;

    // Simulate coin spin
    await Future.delayed(const Duration(milliseconds: 2200));

    // 50/50 random winner
    final winner =
    Random().nextBool() ? teamA.value! : teamB.value!;
    tossWinner.value = winner;

    isTossing.value = false;
    tossComplete.value = true;
  }

  /// Captain of winning team chooses to bat or bowl
  void chooseBatOrBowl({required bool batFirst}) {
    final winner = tossWinner.value;
    if (winner == null) return;

    if (batFirst) {
      battingFirst.value = winner;
    } else {
      // Bowl first → other team bats first
      battingFirst.value =
      winner.id == teamA.value?.id ? teamB.value : teamA.value;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PLAYER EDIT
  // ═══════════════════════════════════════════════════════════════════════

  void updateTeamAPlayer(int index, String newName) {
    final name = newName.trim();
    if (name.isEmpty) return;
    teamAPlayers[index] = name;
  }

  void updateTeamBPlayer(int index, String newName) {
    final name = newName.trim();
    if (name.isEmpty) return;
    teamBPlayers[index] = name;
  }

  void addTeamAPlayer(String name) {
    final n = name.trim();
    if (n.isEmpty || teamAPlayers.contains(n)) return;
    if (teamAPlayers.length >= AppConstants.maxPlayers) {
      Get.snackbar('Max reached',
          'Max ${AppConstants.maxPlayers} players',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    teamAPlayers.add(n);
  }

  void addTeamBPlayer(String name) {
    final n = name.trim();
    if (n.isEmpty || teamBPlayers.contains(n)) return;
    if (teamBPlayers.length >= AppConstants.maxPlayers) {
      Get.snackbar('Max reached',
          'Max ${AppConstants.maxPlayers} players',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    teamBPlayers.add(n);
  }

  void removeTeamAPlayer(int idx) => teamAPlayers.removeAt(idx);
  void removeTeamBPlayer(int idx) => teamBPlayers.removeAt(idx);

  // ═══════════════════════════════════════════════════════════════════════
  // START MATCH
  // ═══════════════════════════════════════════════════════════════════════

  /// Validate → create local SQLite match → link it to tournament match →
  /// update tournament match status → navigate to live scoring.
  Future<void> startMatch() async {
    if (isStarting.value) return;

    final m  = match.value;
    final t  = tournament.value;
    final a  = teamA.value;
    final b  = teamB.value;
    final tw = tossWinner.value;
    final bf = battingFirst.value;

    if (m == null || t == null || a == null || b == null) {
      Get.snackbar('Error', 'Match data not loaded',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (tw == null) {
      Get.snackbar('Toss required', 'Complete the toss first',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (bf == null) {
      Get.snackbar('Choose', 'Bat or bowl — please decide',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (teamAPlayers.length < AppConstants.minPlayers) {
      Get.snackbar('Error',
          '${a.name} needs at least ${AppConstants.minPlayers} players',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (teamBPlayers.length < AppConstants.minPlayers) {
      Get.snackbar('Error',
          '${b.name} needs at least ${AppConstants.minPlayers} players',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (tournament.value?.umpireMode == UmpireMode.manual &&
        umpireTeam.value == null) {
      Get.snackbar('Umpire required', 'Please assign an umpire team',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    isStarting.value = true;
    try {
      // 1. Create local SQLite match
      final localMatch = MatchModel(
        teamAName:    a.name,
        teamBName:    b.name,
        totalOvers:   m.totalOvers ?? t.totalOvers,
        tossWinner:   tw.name,
        battingFirst: bf.name,
        matchDate:    DateTime.now(),
        status:       AppConstants.matchStatusInProgress,
      );
      final localMatchId = await _mRepo.createMatch(localMatch);

      // 2. Create players in local DB
      for (int i = 0; i < teamAPlayers.length; i++) {
        await _mRepo.createPlayer(PlayerModel(
          matchId:    localMatchId,
          teamName:   a.name,
          name:       teamAPlayers[i],
          orderIndex: i,
        ));
      }
      for (int i = 0; i < teamBPlayers.length; i++) {
        await _mRepo.createPlayer(PlayerModel(
          matchId:    localMatchId,
          teamName:   b.name,
          name:       teamBPlayers[i],
          orderIndex: i,
        ));
      }

      // 3. Create innings 1
      await _mRepo.createInnings(InningsModel(
        matchId:       localMatchId,
        inningsNumber: 1,
        battingTeam:   bf.name,
        bowlingTeam:   bf.id == a.id ? b.name : a.name,
      ));

      // 4. Update tournament match — link to local match + toss + umpire + status
      final updated = m.copyWith(
        status:               TournamentMatchStatus.inProgress,
        tossWinnerTeamId:     tw.id,
        tossWinnerTeamName:   tw.name,
        battingFirstTeamId:   bf.id,
        battingFirstTeamName: bf.name,
        umpireTeamId:         umpireTeam.value?.id,
        umpireTeamName:       umpireTeam.value?.name,
        liveMatchId:          localMatchId,
      );
      await _tRepo.updateMatch(updated);

      // 5. Save active match to session (+ tournament linkage so viewers
      //    can surface "next match" context during live viewing)
      await _session.saveActiveMatch(
        matchId:    localMatchId,
        teamA:      a.name,
        teamB:      b.name,
        totalOvers: m.totalOvers ?? t.totalOvers,
      );
      await _session.saveActiveTournamentMatch(
        tournamentId:      tournamentId,
        tournamentMatchId: matchId,
      );

      // 6. Navigate to live scoring
      Get.offAllNamed(AppRoutes.liveScoring, arguments: localMatchId);
    } catch (e) {
      Get.snackbar('Error', 'Failed to start match: $e',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isStarting.value = false;
    }
  }
}