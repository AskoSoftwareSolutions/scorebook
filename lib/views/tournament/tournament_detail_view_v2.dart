// ─────────────────────────────────────────────────────────────────────────────
// lib/views/tournament/tournament_detail_view.dart  (UPDATED)
//
// Changes from Phase 2:
//   - Match cards are now tappable
//   - Scheduled/toss_pending → toss page
//   - In progress → resume live scoring
//   - Completed → match summary
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';
import '../../models/tournament_models.dart';
import '../../repositories/tournament_repository.dart';

class TournamentDetailView extends StatelessWidget {
  const TournamentDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final String tournamentId = Get.arguments as String;
    final repo = TournamentRepository();

    return SafeArea(
      top: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tournament'),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.bgDark, AppTheme.bgCard],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: StreamBuilder<TournamentModel?>(
            stream: repo.tournamentStream(tournamentId),
            builder: (ctx, tSnap) {
              if (!tSnap.hasData || tSnap.data == null) {
                return const Center(
                    child:
                    CircularProgressIndicator(color: AppTheme.primary));
              }
              final tournament = tSnap.data!;

              return Column(
                children: [
                  _Header(tournament: tournament),
                  Expanded(
                    child: StreamBuilder<List<TournamentMatchModel>>(
                      stream: repo.matchesStream(tournamentId),
                      builder: (ctx, mSnap) {
                        if (!mSnap.hasData) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.primary));
                        }
                        final matches = mSnap.data!;
                        if (matches.isEmpty) {
                          return const Center(
                              child: Text('No matches scheduled',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary)));
                        }

                        final Map<int, List<TournamentMatchModel>> byRound = {};
                        for (final m in matches) {
                          byRound.putIfAbsent(m.round, () => []).add(m);
                        }
                        final rounds = byRound.keys.toList()..sort();

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: rounds.length,
                          itemBuilder: (ctx, i) {
                            final round = rounds[i];
                            final roundMatches = byRound[round]!;
                            return Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
                                  child: Text(
                                    _roundLabel(round, rounds.length,
                                        tournament.format),
                                    style: const TextStyle(
                                      color: AppTheme.primaryLight,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                ...roundMatches.map((m) => _MatchCard(
                                  match: m,
                                  onTap: () =>
                                      _handleMatchTap(ctx, m),
                                )),
                                const SizedBox(height: 12),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _roundLabel(int round, int total, TournamentFormat format) {
    if (format != TournamentFormat.knockout) return 'MATCHES';
    if (round == total && total > 1) return 'FINAL';
    if (round == total - 1 && total > 2) return 'SEMI-FINALS';
    if (round == total - 2 && total > 3) return 'QUARTER-FINALS';
    return 'ROUND $round';
  }

  void _handleMatchTap(BuildContext context, TournamentMatchModel m) {
    switch (m.status) {
      case TournamentMatchStatus.scheduled:
      case TournamentMatchStatus.tossPending:
        // Edit / toss allowed only until 20 min before scheduled start.
        final editCutoff =
            m.scheduledTime.subtract(const Duration(minutes: 20));
        if (DateTime.now().isAfter(editCutoff)) {
          Get.snackbar(
            'Edit window closed',
            'Match edits are locked within 20 minutes of start time.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppTheme.warning,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
          return;
        }
        Get.toNamed(AppRoutes.tournamentToss, arguments: {
          'tournamentId': m.tournamentId,
          'matchId':      m.id,
        });
        break;
      case TournamentMatchStatus.inProgress:
        if (m.liveMatchId != null) {
          Get.toNamed(AppRoutes.liveScoring, arguments: m.liveMatchId);
        }
        break;
      case TournamentMatchStatus.completed:
        if (m.liveMatchId != null) {
          Get.toNamed(AppRoutes.matchSummary, arguments: m.liveMatchId);
        }
        break;
    }
  }
}

// ── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final TournamentModel tournament;
  const _Header({required this.tournament});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.greenGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(tournament.format.label.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(tournament.status.name.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ),
          ]),
          const SizedBox(height: 12),
          Text(tournament.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.timer_outlined,
                color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text('${tournament.totalOvers} overs',
                style:
                const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 14),
            const Icon(Icons.sports, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text('Umpire: ${tournament.umpireMode.label}',
                style:
                const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ],
      ),
    );
  }
}

// ── Match card ───────────────────────────────────────────────────────────────
class _MatchCard extends StatelessWidget {
  final TournamentMatchModel match;
  final VoidCallback onTap;
  const _MatchCard({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _statusBorderColor()),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _StatusBadge(status: match.status),
              const Spacer(),
              const Icon(Icons.calendar_today_outlined,
                  size: 12, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                DateFormat('d MMM, h:mm a').format(match.scheduledTime),
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Text(match.teamAName,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('VS',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
              Expanded(
                child: Text(match.teamBName,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            if (match.umpireTeamName != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.sports,
                    color: AppTheme.warning, size: 13),
                const SizedBox(width: 4),
                Text('Umpire: ${match.umpireTeamName}',
                    style: const TextStyle(
                        color: AppTheme.warning, fontSize: 11)),
              ]),
            ],
            if (match.resultText != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('🏆  ${match.resultText!}',
                    style: const TextStyle(
                        color: AppTheme.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ],
            const SizedBox(height: 8),
            // CTA line
            Row(children: [
              const Spacer(),
              Icon(_ctaIcon(), size: 12, color: _ctaColor()),
              const SizedBox(width: 4),
              Text(_ctaText(),
                  style: TextStyle(
                      color: _ctaColor(),
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ]),
          ],
        ),
      ),
    );
  }

  Color _statusBorderColor() {
    switch (match.status) {
      case TournamentMatchStatus.scheduled:   return AppTheme.borderColor;
      case TournamentMatchStatus.tossPending: return AppTheme.warning.withOpacity(0.5);
      case TournamentMatchStatus.inProgress:  return AppTheme.success.withOpacity(0.5);
      case TournamentMatchStatus.completed:   return AppTheme.info.withOpacity(0.3);
    }
  }

  String _ctaText() {
    switch (match.status) {
      case TournamentMatchStatus.scheduled:   return 'Start toss';
      case TournamentMatchStatus.tossPending: return 'Resume toss';
      case TournamentMatchStatus.inProgress:  return 'Resume scoring';
      case TournamentMatchStatus.completed:   return 'View summary';
    }
  }

  IconData _ctaIcon() {
    switch (match.status) {
      case TournamentMatchStatus.scheduled:   return Icons.play_arrow_rounded;
      case TournamentMatchStatus.tossPending: return Icons.play_arrow_rounded;
      case TournamentMatchStatus.inProgress:  return Icons.sports_cricket;
      case TournamentMatchStatus.completed:   return Icons.receipt_long;
    }
  }

  Color _ctaColor() {
    switch (match.status) {
      case TournamentMatchStatus.scheduled:   return AppTheme.primaryLight;
      case TournamentMatchStatus.tossPending: return AppTheme.warning;
      case TournamentMatchStatus.inProgress:  return AppTheme.success;
      case TournamentMatchStatus.completed:   return AppTheme.info;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final TournamentMatchStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (text, color) = _info();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5)),
    );
  }

  (String, Color) _info() {
    switch (status) {
      case TournamentMatchStatus.scheduled:   return ('SCHEDULED', AppTheme.textSecondary);
      case TournamentMatchStatus.tossPending: return ('TOSS PENDING', AppTheme.warning);
      case TournamentMatchStatus.inProgress:  return ('LIVE', AppTheme.success);
      case TournamentMatchStatus.completed:   return ('COMPLETED', AppTheme.info);
    }
  }
}