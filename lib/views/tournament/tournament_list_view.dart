// ─────────────────────────────────────────────────────────────────────────────
// lib/views/tournament/tournament_list_view.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';
import '../../models/tournament_models.dart';
import '../../viewmodels/tournament_list_viewmodel.dart';

class TournamentListView extends StatelessWidget {
  const TournamentListView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = Get.put(TournamentListViewModel());

    return SafeArea(
      top: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Tournaments'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: vm.loadTournaments,
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.bgDark, AppTheme.bgCard],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Obx(() {
            if (vm.isLoading.value) {
              return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary));
            }
            if (vm.tournaments.isEmpty) {
              return _EmptyState();
            }
            return RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: vm.loadTournaments,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: vm.tournaments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final t = vm.tournaments[i];
                  return _TournamentCard(
                    tournament: t,
                    onTap: () => Get.toNamed(
                      AppRoutes.tournamentDetail,
                      arguments: t.id,
                    ),
                    onDelete: () => _confirmDelete(ctx, vm, t),
                  );
                },
              ),
            );
          }),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Tournament',
              style: TextStyle(fontWeight: FontWeight.w700)),
          onPressed: () => Get.toNamed(AppRoutes.tournamentCreate),
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, TournamentListViewModel vm, TournamentModel t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppTheme.borderColor)),
        title: const Text('Delete Tournament?',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Delete "${t.name}"? All teams, matches, and logos will be removed.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              vm.deleteTournament(t.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            const Text('No tournaments yet',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Create your first tournament to schedule matches, assign umpires, and get match reminders.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Get.toNamed(AppRoutes.tournamentCreate),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Create Tournament',
                  style:
                  TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tournament card ──────────────────────────────────────────────────────────
class _TournamentCard extends StatelessWidget {
  final TournamentModel tournament;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TournamentCard(
      {required this.tournament,
        required this.onTap,
        required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // Format badge
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tournament.format.label.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Status badge
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tournament.status.name.toUpperCase(),
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline,
                    color: AppTheme.error, size: 18),
              ),
            ]),
            const SizedBox(height: 12),
            Text(tournament.name,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(children: [
              _InfoChip(
                  icon: Icons.timer_outlined,
                  text: '${tournament.totalOvers} overs'),
              const SizedBox(width: 8),
              _InfoChip(
                  icon: Icons.sports,
                  text: tournament.umpireMode.label),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  color: AppTheme.textSecondary, size: 12),
              const SizedBox(width: 5),
              Text(
                'Created ${DateFormat('d MMM y').format(tournament.createdAt)}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppTheme.primaryLight, size: 12),
            ]),
          ],
        ),
      ),
    );
  }

  Color _statusColor() {
    switch (tournament.status) {
      case TournamentStatus.setup:     return AppTheme.warning;
      case TournamentStatus.active:    return AppTheme.success;
      case TournamentStatus.completed: return AppTheme.info;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(text,
            style:
            const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ]),
    );
  }
}