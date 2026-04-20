// ─────────────────────────────────────────────────────────────────────────────
// Match Summary ViewModel
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:get/get.dart';
import '../models/models.dart';
import '../repositories/match_repository.dart';
import '../services/pdf_service.dart';
import '../services/share_service.dart';

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
      match.value = await _repo.getMatch(matchId);
      innings1.value = await _repo.getInnings(matchId, 1);
      innings2.value = await _repo.getInnings(matchId, 2);
      teamAPlayers.value =
          await _repo.getPlayersByTeam(matchId, match.value!.teamAName);
      teamBPlayers.value =
          await _repo.getPlayersByTeam(matchId, match.value!.teamBName);
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

  @override
  void onInit() {
    super.onInit();
    loadHistory();
  }

  Future<void> loadHistory() async {
    isLoading.value = true;
    try {
      matches.value = await _repo.getAllMatches();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteMatch(int matchId) async {
    await _repo.deleteMatch(matchId);
    matches.removeWhere((m) => m.id == matchId);
    Get.snackbar('Deleted', 'Match deleted successfully',
        snackPosition: SnackPosition.BOTTOM);
  }
}
