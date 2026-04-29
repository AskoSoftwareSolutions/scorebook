import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/models.dart';
import '../../viewmodels/summary_history_viewmodel.dart';
import '../../core/constants/app_routes.dart';

class MatchHistoryView extends StatelessWidget {
  const MatchHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = Get.put(MatchHistoryViewModel());

    return SafeArea(
      top: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Match History'),
          actions: [
            // ── Pull-from-cloud button ────────────────────────────────
            // Forces a fresh sync from Firebase so matches scored on
            // other devices show up here too.
            Obx(() => IconButton(
                  icon: vm.isCloudSyncing.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.primary),
                        )
                      : const Icon(Icons.cloud_download_outlined),
                  tooltip: 'Sync from cloud',
                  onPressed: vm.isCloudSyncing.value
                      ? null
                      : () async {
                          await vm.syncFromCloud();
                          Get.snackbar(
                            'Cloud sync',
                            'History updated from your other devices.',
                            snackPosition: SnackPosition.BOTTOM,
                            duration: const Duration(seconds: 2),
                          );
                        },
                )),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: vm.loadHistory,
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
      
            if (vm.matches.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🏏', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    const Text('No matches yet',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text('Start a new match to see it here',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Get.toNamed(AppRoutes.createMatch),
                      icon: const Icon(Icons.add),
                      label: const Text('New Match'),
                    ),
                  ],
                ),
              );
            }
      
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: vm.matches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final match = vm.matches[i];
                return _MatchHistoryCard(
                  match: match,
                  onTap: () {
                    Get.toNamed(AppRoutes.matchSummary, arguments: match.id);
                  },
                  onDelete: () => _confirmDelete(ctx, vm, match),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, MatchHistoryViewModel vm, MatchModel match) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppTheme.borderColor)),
        title: const Text('Delete Match?',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Delete the match "${match.teamAName} vs ${match.teamBName}"? This cannot be undone.',
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
              vm.deleteMatch(match.id!);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _MatchHistoryCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MatchHistoryCard({
    required this.match,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = match.status == 'completed';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted
                ? AppTheme.primary.withOpacity(0.3)
                : AppTheme.warning.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & date
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppTheme.success.withOpacity(0.15)
                        : AppTheme.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isCompleted ? 'Completed' : 'In Progress',
                    style: TextStyle(
                      color: isCompleted ? AppTheme.success : AppTheme.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  AppUtils.formatDate(match.matchDate),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline,
                      color: AppTheme.error, size: 18),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Teams & scores
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.teamAName,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                      if (match.teamAScore != null)
                        Text(
                          '${match.teamAScore}/${match.teamAWickets} (${AppUtils.formatOvers(match.teamABalls ?? 0)})',
                          style: const TextStyle(
                              color: AppTheme.primaryLight,
                              fontSize: 18,
                              fontWeight: FontWeight.w800),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('VS',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        match.teamBName,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                      if (match.teamBScore != null)
                        Text(
                          '${match.teamBScore}/${match.teamBWickets} (${AppUtils.formatOvers(match.teamBBalls ?? 0)})',
                          style: const TextStyle(
                              color: AppTheme.primaryLight,
                              fontSize: 18,
                              fontWeight: FontWeight.w800),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            if (match.result != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🏆 ${match.result}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.primaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Match info row
            Row(
              children: [
                const Icon(Icons.timer_outlined,
                    color: AppTheme.textSecondary, size: 14),
                const SizedBox(width: 4),
                Text('${match.totalOvers} Overs',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: AppTheme.textSecondary, size: 12),
                const Text(' View Scorecard',
                    style: TextStyle(
                        color: AppTheme.primaryLight, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
