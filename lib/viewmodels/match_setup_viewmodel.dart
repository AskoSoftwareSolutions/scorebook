import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/models.dart';
import '../repositories/match_repository.dart';
import '../core/constants/app_routes.dart';
import '../core/constants/app_constants.dart';
import '../services/saved_team_service.dart';

class MatchSetupViewModel extends GetxController {
  final MatchRepository _repo = Get.find<MatchRepository>();
  final SavedTeamService _teamService = SavedTeamService();

  // ── Step tracking ─────────────────────────────────────────────────────────
  final RxInt currentStep = 0.obs;

  // ── Match Info ────────────────────────────────────────────────────────────
  final teamAController = TextEditingController();
  final teamBController = TextEditingController();
  final RxInt selectedOvers = 20.obs;
  final RxBool isCustomOvers = false.obs;
  final customOversController = TextEditingController();
  final List<int> overOptions = [5, 10, 15, 20, 25, 30, 40, 50];

  // ── Players ───────────────────────────────────────────────────────────────
  final RxList<String> teamAPlayers = <String>[].obs;
  final RxList<String> teamBPlayers = <String>[].obs;
  final playerController = TextEditingController();
  final RxBool addingToTeamA = true.obs;

  // ── Toss ──────────────────────────────────────────────────────────────────
  final RxString tossWinner = ''.obs;
  final RxString battingFirst = ''.obs;

  final RxBool isLoading = false.obs;

  // ── Saved Teams ───────────────────────────────────────────────────────────
  final RxList<SavedTeam> savedTeams = <SavedTeam>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadSavedTeams();
    // Auto-pull players when user types a team name that exactly matches
    // a previously-saved team. Cross-flow recall: works for both freshly
    // created matches and matches whose teams were saved in tournaments.
    teamAController.addListener(() => _autofillFromSaved(isTeamA: true));
    teamBController.addListener(() => _autofillFromSaved(isTeamA: false));
  }

  /// Public so views can refresh after returning from another flow.
  Future<void> loadSavedTeams() async {
    final teams = await _teamService.getAll();
    savedTeams.assignAll(teams);
  }

  /// Returns saved teams whose name matches the query (case-insensitive, partial)
  List<SavedTeam> matchingSavedTeams(String query) {
    if (query.trim().isEmpty) return savedTeams.toList();
    final q = query.trim().toLowerCase();
    return savedTeams.where((t) => t.name.toLowerCase().contains(q)).toList();
  }

  /// Load a saved team into Team A or B players list
  void loadSavedTeam(SavedTeam team, {required bool isTeamA}) {
    if (isTeamA) {
      teamAController.text = team.name;
      teamAPlayers.assignAll(team.players);
    } else {
      teamBController.text = team.name;
      teamBPlayers.assignAll(team.players);
    }
  }

  // Autofill guard so we don't recursively trigger via setText below.
  String _lastAutofillA = '';
  String _lastAutofillB = '';

  void _autofillFromSaved({required bool isTeamA}) {
    final raw = (isTeamA ? teamAController.text : teamBController.text).trim();
    if (raw.isEmpty) return;
    final lastKey = isTeamA ? _lastAutofillA : _lastAutofillB;
    if (raw.toLowerCase() == lastKey) return;
    SavedTeam? match;
    for (final t in savedTeams) {
      if (t.name.toLowerCase() == raw.toLowerCase()) {
        match = t;
        break;
      }
    }
    if (match == null) return;
    final currentPlayers = isTeamA ? teamAPlayers : teamBPlayers;
    // Only auto-replace when the side has no players yet, or the user
    // hasn't manually changed the player list. We check via "all players
    // are a subset of the saved team's players" — strict but safe.
    final isFresh = currentPlayers.isEmpty ||
        currentPlayers.every((p) => match!.players.contains(p));
    if (!isFresh) return;
    if (isTeamA) {
      _lastAutofillA = raw.toLowerCase();
      teamAPlayers.assignAll(match.players);
    } else {
      _lastAutofillB = raw.toLowerCase();
      teamBPlayers.assignAll(match.players);
    }
  }

  /// Save current team A or B to saved teams
  Future<void> saveCurrentTeam({required bool isTeamA}) async {
    final name = isTeamA
        ? teamAController.text.trim()
        : teamBController.text.trim();
    final players = isTeamA ? teamAPlayers : teamBPlayers;

    if (name.isEmpty) {
      Get.snackbar('Error', 'Enter a team name first',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (players.isEmpty) {
      Get.snackbar('Error', 'Add players before saving',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    await _teamService.saveTeam(name, players.toList());
    await loadSavedTeams();
    Get.snackbar('Saved', '"$name" saved with ${players.length} players',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1B5E20),
        colorText: const Color(0xFFFFFFFF));
  }

  /// Delete a saved team by name
  Future<void> deleteSavedTeam(String name) async {
    await _teamService.deleteTeam(name);
    await loadSavedTeams();
  }

  @override
  void onClose() {
    teamAController.dispose();
    teamBController.dispose();
    playerController.dispose();
    customOversController.dispose();
    super.onClose();
  }

  // ── Step 1: Match Info ────────────────────────────────────────────────────

  bool validateMatchInfo() {
    if (teamAController.text.trim().isEmpty) {
      Get.snackbar('Error', 'Enter Team A name',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (teamBController.text.trim().isEmpty) {
      Get.snackbar('Error', 'Enter Team B name',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (teamAController.text.trim() == teamBController.text.trim()) {
      Get.snackbar('Error', 'Team names must be different',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    return true;
  }

  // ── Step 2: Players ───────────────────────────────────────────────────────

  void addPlayer(bool toTeamA) {
    final name = playerController.text.trim();
    if (name.isEmpty) return;

    if (toTeamA) {
      if (teamAPlayers.length >= AppConstants.maxPlayers) {
        Get.snackbar('Max Players', 'Maximum ${AppConstants.maxPlayers} players allowed',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      if (!teamAPlayers.contains(name)) {
        teamAPlayers.add(name);
      }
    } else {
      if (teamBPlayers.length >= AppConstants.maxPlayers) {
        Get.snackbar('Max Players', 'Maximum ${AppConstants.maxPlayers} players allowed',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      if (!teamBPlayers.contains(name)) {
        teamBPlayers.add(name);
      }
    }
    playerController.clear();
  }

  void editPlayer(bool inTeamA, int index, String newName) {
    final name = newName.trim();
    if (name.isEmpty) return;
    if (inTeamA) {
      teamAPlayers[index] = name;
    } else {
      teamBPlayers[index] = name;
    }
  }
  
  void removePlayer(bool fromTeamA, int index) {
    if (fromTeamA) {
      teamAPlayers.removeAt(index);
    } else {
      teamBPlayers.removeAt(index);
    }
  }

  bool validatePlayers() {
    if (teamAPlayers.length < AppConstants.minPlayers) {
      Get.snackbar('Error',
          '${teamAController.text} needs at least ${AppConstants.minPlayers} players',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (teamBPlayers.length < AppConstants.minPlayers) {
      Get.snackbar('Error',
          '${teamBController.text} needs at least ${AppConstants.minPlayers} players',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    return true;
  }

  // ── Step 3: Toss ──────────────────────────────────────────────────────────

  bool validateToss() {
    if (tossWinner.isEmpty) {
      Get.snackbar('Error', 'Select toss winner', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (battingFirst.isEmpty) {
      Get.snackbar('Error', 'Select batting team', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    return true;
  }

  // ── Create Match ──────────────────────────────────────────────────────────

  Future<void> createMatch() async {
    if (!validateToss()) return;
    isLoading.value = true;

    try {
      final teamA = teamAController.text.trim();
      final teamB = teamBController.text.trim();

      // Auto-save teams when starting a match (so next time the user types
      // the same team name in either New-Match or Tournament forms, the
      // player list autofills).
      await _teamService.saveTeam(teamA, teamAPlayers.toList());
      await _teamService.saveTeam(teamB, teamBPlayers.toList());
      await loadSavedTeams();

      // 1. Create match record
      final match = MatchModel(
        teamAName: teamA,
        teamBName: teamB,
        totalOvers: selectedOvers.value,
        tossWinner: tossWinner.value,
        battingFirst: battingFirst.value,
        matchDate: DateTime.now(),
        status: AppConstants.matchStatusInProgress,
      );
      final matchId = await _repo.createMatch(match);

      // 2. Create players for Team A
      for (int i = 0; i < teamAPlayers.length; i++) {
        await _repo.createPlayer(PlayerModel(
          matchId: matchId,
          teamName: teamA,
          name: teamAPlayers[i],
          orderIndex: i,
        ));
      }

      // 3. Create players for Team B
      for (int i = 0; i < teamBPlayers.length; i++) {
        await _repo.createPlayer(PlayerModel(
          matchId: matchId,
          teamName: teamB,
          name: teamBPlayers[i],
          orderIndex: i,
        ));
      }

      // 4. Create innings 1
      final battingTeam = battingFirst.value;
      final bowlingTeam = battingTeam == teamA ? teamB : teamA;

      await _repo.createInnings(InningsModel(
        matchId: matchId,
        inningsNumber: 1,
        battingTeam: battingTeam,
        bowlingTeam: bowlingTeam,
      ));

      // 5. Navigate to live scoring
      Get.offAllNamed(AppRoutes.liveScoring, arguments: matchId);
    } catch (e) {
      Get.snackbar('Error', 'Failed to create match: $e',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  void nextStep() {
    switch (currentStep.value) {
      case 0:
        if (validateMatchInfo()) currentStep.value = 1;
        break;
      case 1:
        if (validatePlayers()) currentStep.value = 2;
        break;
      case 2:
        createMatch();
        break;
    }
  }

  void previousStep() {
    if (currentStep.value > 0) currentStep.value--;
  }
}