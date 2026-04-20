// ─────────────────────────────────────────────────────────────────────────────
// lib/views/tournament/tournament_poster_view.dart
//
// Full-screen preview of the generated poster + Share button.
// Arguments: {'tournamentId': <id>}
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tournament_models.dart';
import '../../repositories/tournament_repository.dart';
import '../../services/poster_share_service.dart';
import '../../widgets/tournament_poster.dart';

class TournamentPosterView extends StatefulWidget {
  const TournamentPosterView({super.key});

  @override
  State<TournamentPosterView> createState() => _TournamentPosterViewState();
}

class _TournamentPosterViewState extends State<TournamentPosterView> {
  final _posterKey = GlobalKey();
  final _repo = TournamentRepository();

  bool _sharing = false;
  bool _loading = true;

  TournamentModel? _tournament;
  List<TournamentMatchModel> _matches = [];
  List<TournamentTeamModel> _teams = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tournamentId = Get.arguments as String;
      final t = await _repo.getTournament(tournamentId);
      final matches = await _repo.getMatches(tournamentId);
      final teams = await _repo.getTeams(tournamentId);
      if (!mounted) return;
      setState(() {
        _tournament = t;
        _matches = matches;
        _teams = teams;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      Get.snackbar('Error', 'Failed to load: $e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _share() async {
    if (_sharing || _tournament == null) return;
    setState(() => _sharing = true);

    final ok = await PosterShareService().sharePoster(
      posterKey: _posterKey,
      tournamentName: _tournament!.name,
    );

    if (!mounted) return;
    setState(() => _sharing = false);

    if (!ok) {
      Get.snackbar('Error', 'Could not share poster',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        appBar: AppBar(
          title: const Text('Tournament Poster'),
          actions: [
            if (!_loading && _tournament != null)
              IconButton(
                icon: _sharing
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.share_rounded),
                onPressed: _sharing ? null : _share,
                tooltip: 'Share poster',
              ),
          ],
        ),
        body: _loading
            ? const Center(
            child: CircularProgressIndicator(color: AppTheme.primary))
            : _tournament == null
            ? const Center(
            child: Text('Tournament not found',
                style: TextStyle(color: AppTheme.textSecondary)))
            : Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                minScale: 0.3,
                maxScale: 2.5,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: RepaintBoundary(
                      key: _posterKey,
                      child: TournamentPoster(
                        tournament: _tournament!,
                        matches: _matches,
                        teams: _teams,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Bottom action bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                border: Border(
                  top: BorderSide(
                      color: AppTheme.borderColor.withOpacity(0.3)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(12)),
                    ),
                    onPressed: _sharing ? null : _share,
                    icon: _sharing
                        ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white))
                        : const Icon(Icons.share_rounded),
                    label: Text(
                      _sharing
                          ? 'Preparing...'
                          : 'Share to WhatsApp / Others',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}