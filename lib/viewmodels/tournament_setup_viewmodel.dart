// ─────────────────────────────────────────────────────────────────────────────
// lib/viewmodels/tournament_setup_viewmodel.dart
//
// Handles the multi-step flow: Create → Add Teams → Schedule.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../models/tournament_models.dart';
import '../repositories/tournament_repository.dart';
import '../services/pairing_service.dart';
import '../services/saved_team_service.dart';
import '../core/constants/app_routes.dart';

class TournamentSetupViewModel extends GetxController {
  final TournamentRepository _repo = TournamentRepository();
  final PairingService _pairing = PairingService();
  final ImagePicker _picker = ImagePicker();
  final SavedTeamService _savedTeamService = SavedTeamService();

  // ── Saved teams (local cache shared with single-match creation) ──────────
  final RxList<SavedTeam> savedTeams = <SavedTeam>[].obs;

  // ── Step 1: Create tournament ────────────────────────────────────────────
  final nameController = TextEditingController();
  final Rx<TournamentFormat> format = TournamentFormat.knockout.obs;
  final Rx<UmpireMode> umpireMode = UmpireMode.auto.obs;
  final RxInt totalOvers = 10.obs;
  final List<int> overOptions = [5, 6, 8, 10, 15, 20];

  // ── Created tournament (after step 1) ─────────────────────────────────────
  final Rx<TournamentModel?> tournament = Rx<TournamentModel?>(null);

  // ── Step 2: Teams ────────────────────────────────────────────────────────
  final RxList<TournamentTeamModel> teams = <TournamentTeamModel>[].obs;
  final teamNameController = TextEditingController();
  final Rx<File?> pendingLogo = Rx<File?>(null);
  final RxList<String> pendingPlayers = <String>[].obs;
  final playerNameController = TextEditingController();

  // ── Step 3: Schedule ─────────────────────────────────────────────────────
  final Rx<DateTime> scheduleStartTime = DateTime.now().add(const Duration(hours: 1)).obs;
  final RxInt matchGapHours = 2.obs;

  // ── Manual pairing state ─────────────────────────────────────────────────
  final RxList<_ManualPair> manualPairs = <_ManualPair>[].obs;

  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadSavedTeams();
    // Auto-pull players when the user types a team name that exactly
    // matches a previously-saved team. Mirrors the behaviour in the
    // single-match setup VM so saved rosters surface in either flow.
    teamNameController.addListener(_autofillFromSaved);
  }

  Future<void> loadSavedTeams() async {
    savedTeams.assignAll(await _savedTeamService.getAll());
  }

  // Guard to stop the listener re-firing for the same name once we've
  // already auto-applied it.
  String _lastAutofillName = '';

  void _autofillFromSaved() {
    final raw = teamNameController.text.trim();
    if (raw.isEmpty) return;
    if (raw.toLowerCase() == _lastAutofillName) return;

    SavedTeam? match;
    for (final t in savedTeams) {
      if (t.name.toLowerCase() == raw.toLowerCase()) {
        match = t;
        break;
      }
    }
    if (match == null) return;

    // Don't overwrite a roster the user has manually edited — only fill
    // when the pending list is empty or is a strict subset of the saved
    // team's roster.
    final isFresh = pendingPlayers.isEmpty ||
        pendingPlayers.every((p) => match!.players.contains(p));
    if (!isFresh) return;

    _lastAutofillName = raw.toLowerCase();
    pendingPlayers.assignAll(match.players);
  }

  /// Saved teams whose name matches the current query (case-insensitive) and
  /// isn't already part of this tournament.
  List<SavedTeam> matchingSavedTeams(String query) {
    final q = query.trim().toLowerCase();
    return savedTeams.where((t) {
      final alreadyAdded =
          teams.any((tt) => tt.name.toLowerCase() == t.name.toLowerCase());
      if (alreadyAdded) return false;
      if (q.isEmpty) return true;
      return t.name.toLowerCase().contains(q);
    }).toList();
  }

  /// Populate the pending team form with the chosen saved team's roster.
  void loadSavedTeam(SavedTeam team) {
    teamNameController.text = team.name;
    pendingPlayers.assignAll(team.players);
  }

  Future<void> deleteSavedTeam(String name) async {
    await _savedTeamService.deleteTeam(name);
    await loadSavedTeams();
  }

  @override
  void onClose() {
    nameController.dispose();
    teamNameController.dispose();
    playerNameController.dispose();
    super.onClose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 1 — Create tournament
  // ═══════════════════════════════════════════════════════════════════════

  Future<bool> createTournament() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      Get.snackbar('Error', 'Enter tournament name',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    // ── Check login before proceeding ──────────────────────────────────
    final user = FirebaseAuth.instance.currentUser;
    print('🔥 Before create: user=$user uid=${user?.uid} phone=${user?.phoneNumber}');
    if (user == null) {
      Get.snackbar(
        'Login Required',
        'Please login to create tournaments',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      // Wait briefly so snackbar is visible, then redirect to login
      await Future.delayed(const Duration(milliseconds: 800));
      Get.toNamed(AppRoutes.login);
      return false;
    }

    isLoading.value = true;
    try {
      final id = await _repo.createTournament(
        name:       name,
        format:     format.value,
        umpireMode: umpireMode.value,
        totalOvers: totalOvers.value,
      );
      tournament.value = await _repo.getTournament(id);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to create: $e',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 2 — Add teams
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> pickLogoFromGallery() async {
    try {
      final img = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (img != null) pendingLogo.value = File(img.path);
    } catch (e) {
      Get.snackbar('Error', 'Could not pick image: $e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> pickLogoFromCamera() async {
    try {
      final img = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (img != null) pendingLogo.value = File(img.path);
    } catch (e) {
      Get.snackbar('Error', 'Could not capture image: $e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void removePendingLogo() {
    pendingLogo.value = null;
  }

  void addPendingPlayer() {
    final n = playerNameController.text.trim();
    if (n.isEmpty) return;
    if (!pendingPlayers.contains(n)) {
      pendingPlayers.add(n);
    }
    playerNameController.clear();
  }

  void removePendingPlayer(int idx) {
    pendingPlayers.removeAt(idx);
  }

  Future<bool> saveTeam() async {
    final t = tournament.value;
    if (t == null) return false;

    final name = teamNameController.text.trim();
    if (name.isEmpty) {
      Get.snackbar('Error', 'Team name required',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    // Duplicate name check
    if (teams.any((tt) => tt.name.toLowerCase() == name.toLowerCase())) {
      Get.snackbar('Error', 'Team name already exists',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    isLoading.value = true;
    try {
      await _repo.createTeam(
        tournamentId: t.id,
        name:         name,
        players:      pendingPlayers.toList(),
        logoFile:     pendingLogo.value,
        orderIndex:   teams.length,
      );
      // Cache the team locally so it can be suggested on future setups.
      await _savedTeamService.saveTeam(name, pendingPlayers.toList());
      await loadSavedTeams();
      await refreshTeams();
      _resetPendingTeam();
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Save failed: $e',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  void _resetPendingTeam() {
    teamNameController.clear();
    pendingLogo.value = null;
    pendingPlayers.clear();
    // Reset autofill guard so the next typed name is considered fresh
    // even if it matches the previous entry.
    _lastAutofillName = '';
  }

  Future<void> refreshTeams() async {
    final t = tournament.value;
    if (t == null) return;
    teams.value = await _repo.getTeams(t.id);
  }

  Future<void> deleteTeam(String teamId) async {
    final t = tournament.value;
    if (t == null) return;
    await _repo.deleteTeam(t.id, teamId);
    await refreshTeams();
  }

  bool get canProceedToSchedule => teams.length >= 2;

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 3 — Schedule matches
  // ═══════════════════════════════════════════════════════════════════════

  void setScheduleStart(DateTime dt) {
    scheduleStartTime.value = dt;
  }

  /// For auto formats (knockout, random) — generate all pairings and save
  Future<bool> generateAndSaveSchedule() async {
    final t = tournament.value;
    if (t == null) return false;
    if (teams.length < 2) {
      Get.snackbar('Error', 'Need at least 2 teams',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    isLoading.value = true;
    try {
      final matches = _pairing.generatePairings(
        tournament: t,
        teams:      teams.toList(),
        startTime:  scheduleStartTime.value,
        matchGap:   Duration(hours: matchGapHours.value),
      );

      if (matches.isEmpty) {
        Get.snackbar('Error', 'Could not generate matches',
            snackPosition: SnackPosition.BOTTOM);
        return false;
      }

      await _repo.createMatches(t.id, matches);

      // Mark tournament as active
      await _repo.updateTournament(t.copyWith(status: TournamentStatus.active));

      // Navigate to detail
      Get.offNamed(AppRoutes.tournamentDetail, arguments: t.id);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Schedule generation failed: $e',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Manual pairing
  // ═══════════════════════════════════════════════════════════════════════

  void addManualPair({
    required TournamentTeamModel teamA,
    required TournamentTeamModel teamB,
    required DateTime time,
  }) {
    if (teamA.id == teamB.id) {
      Get.snackbar('Error', 'Teams must be different',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    manualPairs.add(_ManualPair(teamA: teamA, teamB: teamB, time: time));
  }

  void removeManualPair(int idx) {
    manualPairs.removeAt(idx);
  }

  Future<bool> saveManualPairings() async {
    final t = tournament.value;
    if (t == null) return false;
    if (manualPairs.isEmpty) {
      Get.snackbar('Error', 'Add at least one pair',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    isLoading.value = true;
    try {
      final matches = <TournamentMatchModel>[];
      for (int i = 0; i < manualPairs.length; i++) {
        final p = manualPairs[i];
        matches.add(_pairing.createManualPairing(
          tournament:    t,
          teamA:         p.teamA,
          teamB:         p.teamB,
          scheduledTime: p.time,
          round:         1,
          orderIndex:    i,
        ));
      }

      await _repo.createMatches(t.id, matches);
      await _repo.updateTournament(t.copyWith(status: TournamentStatus.active));

      Get.offNamed(AppRoutes.tournamentDetail, arguments: t.id);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Save failed: $e',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════════

  String get formatDescription {
    switch (format.value) {
      case TournamentFormat.knockout:
        return 'Loser is out, winner advances to next round';
      case TournamentFormat.random:
        return 'Teams randomly paired into matches';
      case TournamentFormat.manual:
        return 'You pick each match pairing manually';
    }
  }
}

// ── Simple holder for manual pair UI state ───────────────────────────────────
class _ManualPair {
  final TournamentTeamModel teamA;
  final TournamentTeamModel teamB;
  final DateTime time;
  _ManualPair({required this.teamA, required this.teamB, required this.time});
}