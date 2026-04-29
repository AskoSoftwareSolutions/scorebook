// ─────────────────────────────────────────────────────────────────────────────
// Match Summary ViewModel
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:get/get.dart';
import '../models/models.dart';
import '../repositories/match_repository.dart';
import '../services/pdf_service.dart';
import '../services/share_service.dart';
import '../services/match_cloud_pull_service.dart';
import '../services/firebase_sync_service.dart';

class MatchSummaryViewModel extends GetxController {
  final MatchRepository _repo = Get.find<MatchRepository>();
  final PdfService _pdfService = PdfService();
  final ShareService _shareService = ShareService();

  final Rx<MatchModel?> match = Rx<MatchModel?>(null);
  final Rx<InningsModel?> innings1 = Rx<InningsModel?>(null);
  final Rx<InningsModel?> innings2 = Rx<InningsModel?>(null);
  final RxList<PlayerModel> teamAPlayers = <PlayerModel>[].obs;
  final RxList<PlayerModel> teamBPlayers = <PlayerModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isGeneratingPdf = false.obs;
  final Rx<File?> pdfFile = Rx<File?>(null);

  @override
  void onInit() {
    super.onInit();
    final id = Get.arguments as int?;
    if (id != null) loadMatchSummary(id);
  }

  Future<void> loadMatchSummary(int matchId) async {
    isLoading.value = true;
    try {
      // ── 1. Load whatever we have locally first (instant render) ─────
      match.value = await _repo.getMatch(matchId);
      innings1.value = await _repo.getInnings(matchId, 1);
      innings2.value = await _repo.getInnings(matchId, 2);
      teamAPlayers.value =
          await _repo.getPlayersByTeam(matchId, match.value!.teamAName);
      teamBPlayers.value =
          await _repo.getPlayersByTeam(matchId, match.value!.teamBName);

      // ── 2. If this match was scored in online mode, pull a fresh
      //       snapshot from Firebase. This handles the cross-device
      //       case: innings 2 was scored on a different phone and our
      //       local DB has the outdated picture. The pull is idempotent.
      final cloudCode = await MatchCloudPullService().cloudCodeFor(matchId);
      if (cloudCode != null && cloudCode.isNotEmpty) {
        final pulledLocalId =
            await MatchCloudPullService().pullIntoLocal(cloudCode);
        if (pulledLocalId != null && pulledLocalId == matchId) {
          // Re-read from local — totals, balls, players were just upserted.
          match.value = await _repo.getMatch(matchId);
          innings1.value = await _repo.getInnings(matchId, 1);
          innings2.value = await _repo.getInnings(matchId, 2);
          teamAPlayers.value =
              await _repo.getPlayersByTeam(matchId, match.value!.teamAName);
          teamBPlayers.value =
              await _repo.getPlayersByTeam(matchId, match.value!.teamBName);
        }
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> generateAndSharePdf() async {
    if (match.value == null) return;
    isGeneratingPdf.value = true;

    try {
      final matchId = match.value!.id!;
      final inn1Balls = await _repo.getBallsByInnings(matchId, 1);
      final inn2Balls = await _repo.getBallsByInnings(matchId, 2);

      final file = await _pdfService.generateMatchReport(
        match: match.value!,
        innings1: innings1.value!,
        innings2: innings2.value ?? InningsModel(
          matchId: matchId,
          inningsNumber: 2,
          battingTeam: '',
          bowlingTeam: '',
        ),
        teamAPlayers: teamAPlayers,
        teamBPlayers: teamBPlayers,
        innings1Balls: inn1Balls,
        innings2Balls: inn2Balls,
      );

      pdfFile.value = file;
      await _shareService.sharePdf(file, subject: 'Cricket Match Report');
    } catch (e) {
      Get.snackbar('Error', 'PDF generation failed: $e',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isGeneratingPdf.value = false;
    }
  }

  String dismissalText(PlayerModel p) {
    if (!p.isOut) return 'not out';
    switch (p.wicketType) {
      case 'Bowled': return 'b ${p.bowlerName ?? ''}';
      case 'Caught': return 'c ${p.dismissedBy ?? ''} b ${p.bowlerName ?? ''}';
      case 'LBW': return 'lbw b ${p.bowlerName ?? ''}';
      case 'Run Out': return 'run out (${p.dismissedBy ?? ''})';
      case 'Stumped': return 'st ${p.dismissedBy ?? ''} b ${p.bowlerName ?? ''}';
      case 'Hit Wicket': return 'hw b ${p.bowlerName ?? ''}';
      default: return p.wicketType ?? 'out';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Match History ViewModel
// ─────────────────────────────────────────────────────────────────────────────

class MatchHistoryViewModel extends GetxController {
  final MatchRepository _repo = Get.find<MatchRepository>();

  final RxList<MatchModel> matches = <MatchModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isCloudSyncing = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadHistory();
    // Background — pull any cloud matches I scored on other devices.
    syncFromCloud();
  }

  Future<void> loadHistory() async {
    isLoading.value = true;
    try {
      matches.value = await _repo.getAllMatches();
    } finally {
      isLoading.value = false;
    }
  }

  /// Best-effort: read /user_matches/{phone} from Firebase and pull
  /// every match into local SQLite. After this completes, [loadHistory]
  /// is called again so the list reflects new entries.
  Future<void> syncFromCloud() async {
    if (isCloudSyncing.value) return;
    isCloudSyncing.value = true;
    try {
      final list = await FirebaseSyncService().listMyMatches();
      if (list.isEmpty) return;
      final cloud = MatchCloudPullService();
      for (final m in list) {
        final code = (m['matchCode'] as String?) ?? '';
        if (code.isEmpty) continue;
        await cloud.pullIntoLocal(code);
      }
      await loadHistory();
    } finally {
      isCloudSyncing.value = false;
    }
  }

  Future<void> deleteMatch(int matchId) async {
    await _repo.deleteMatch(matchId);
    matches.removeWhere((m) => m.id == matchId);
    Get.snackbar('Deleted', 'Match deleted successfully',
        snackPosition: SnackPosition.BOTTOM);
  }
}
