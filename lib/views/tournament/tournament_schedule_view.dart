// ─────────────────────────────────────────────────────────────────────────────
// lib/views/tournament/tournament_schedule_view.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tournament_models.dart';
import '../../viewmodels/tournament_setup_viewmodel.dart';

class TournamentScheduleView extends StatelessWidget {
  const TournamentScheduleView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = Get.find<TournamentSetupViewModel>();
    final isManual = vm.tournament.value?.format == TournamentFormat.manual;

    return SafeArea(
      top: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Schedule Matches'),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.bgDark, AppTheme.bgCard],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: isManual
              ? _ManualScheduleBody(vm: vm)
              : _AutoScheduleBody(vm: vm),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUTO MODE (Knockout / Random)
// ═══════════════════════════════════════════════════════════════════════════════

class _AutoScheduleBody extends StatelessWidget {
  final TournamentSetupViewModel vm;
  const _AutoScheduleBody({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoBanner(
                  format: vm.tournament.value?.format ??
                      TournamentFormat.random,
                  teamCount: vm.teams.length,
                ),

                const SizedBox(height: 24),

                _label('FIRST MATCH START TIME'),
                const SizedBox(height: 10),
                Obx(() => _TimePicker(
                  dateTime: vm.scheduleStartTime.value,
                  onChange: (dt) => vm.setScheduleStart(dt),
                )),

                const SizedBox(height: 20),

                _label('GAP BETWEEN MATCHES'),
                const SizedBox(height: 10),
                Obx(() => Wrap(
                  spacing: 10,
                  children: [1, 2, 3, 4].map((h) {
                    final sel = vm.matchGapHours.value == h;
                    return GestureDetector(
                      onTap: () => vm.matchGapHours.value = h,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: sel ? AppTheme.greenGradient : null,
                          color: sel ? null : AppTheme.bgSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: sel
                                  ? AppTheme.primary
                                  : AppTheme.borderColor),
                        ),
                        child: Text('${h}h',
                            style: TextStyle(
                                color: sel
                                    ? Colors.white
                                    : AppTheme.textPrimary,
                                fontWeight: FontWeight.w700)),
                      ),
                    );
                  }).toList(),
                )),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Obx(() => SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: vm.isLoading.value
                  ? null
                  : () => vm.generateAndSaveSchedule(),
              icon: vm.isLoading.value
                  ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                vm.isLoading.value
                    ? 'Generating...'
                    : 'Generate Pairings & Start',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          )),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5));
}

// ═══════════════════════════════════════════════════════════════════════════════
// MANUAL MODE
// ═══════════════════════════════════════════════════════════════════════════════

class _ManualScheduleBody extends StatelessWidget {
  final TournamentSetupViewModel vm;
  const _ManualScheduleBody({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Obx(() {
            if (vm.manualPairs.isEmpty) {
              return _ManualEmpty();
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: vm.manualPairs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final p = vm.manualPairs[i];
                return _ManualPairCard(
                  index: i + 1,
                  teamA: p.teamA,
                  teamB: p.teamB,
                  time: p.time,
                  onRemove: () => vm.removeManualPair(i),
                );
              },
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppTheme.primaryLight, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showAddPairDialog(context, vm),
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      color: AppTheme.primaryLight),
                  label: const Text('Add Match Pair',
                      style: TextStyle(
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ),
              ),
              const SizedBox(height: 10),
              Obx(() => SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vm.manualPairs.isNotEmpty
                        ? AppTheme.primary
                        : AppTheme.bgSurface,
                    foregroundColor: vm.manualPairs.isNotEmpty
                        ? Colors.white
                        : AppTheme.textSecondary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: vm.manualPairs.isEmpty || vm.isLoading.value
                      ? null
                      : () => vm.saveManualPairings(),
                  icon: vm.isLoading.value
                      ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    vm.isLoading.value
                        ? 'Saving...'
                        : vm.manualPairs.isEmpty
                        ? 'Add at least one pair'
                        : 'Save & Start',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddPairDialog(
      BuildContext context, TournamentSetupViewModel vm) {
    TournamentTeamModel? teamA;
    TournamentTeamModel? teamB;
    DateTime time =
    DateTime.now().add(const Duration(hours: 1));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Pair',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Team A',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
                const SizedBox(height: 6),
                _TeamDropdown(
                  teams: vm.teams,
                  selected: teamA,
                  onChanged: (t) => setState(() => teamA = t),
                  exclude: teamB,
                ),
                const SizedBox(height: 12),
                const Text('Team B',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
                const SizedBox(height: 6),
                _TeamDropdown(
                  teams: vm.teams,
                  selected: teamB,
                  onChanged: (t) => setState(() => teamB = t),
                  exclude: teamA,
                ),
                const SizedBox(height: 12),
                const Text('Match Time',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
                const SizedBox(height: 6),
                _TimePicker(
                  dateTime: time,
                  onChange: (dt) => setState(() => time = dt),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white),
              onPressed: (teamA != null && teamB != null)
                  ? () {
                vm.addManualPair(
                    teamA: teamA!, teamB: teamB!, time: time);
                Navigator.pop(ctx);
              }
                  : null,
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info banner ──────────────────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  final TournamentFormat format;
  final int teamCount;
  const _InfoBanner({required this.format, required this.teamCount});

  @override
  Widget build(BuildContext context) {
    final matchCount = teamCount ~/ 2;
    final hasBye = teamCount.isOdd;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.info.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.info.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppTheme.info, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${format.label} Format',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '$teamCount teams → $matchCount match${matchCount == 1 ? '' : 'es'} in round 1'
                      '${hasBye ? ' (1 team gets bye)' : ''}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Time picker row ──────────────────────────────────────────────────────────
class _TimePicker extends StatelessWidget {
  final DateTime dateTime;
  final ValueChanged<DateTime> onChange;

  const _TimePicker({required this.dateTime, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: GestureDetector(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: dateTime,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (d != null) {
              onChange(DateTime(
                  d.year, d.month, d.day, dateTime.hour, dateTime.minute));
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  color: AppTheme.primaryLight, size: 16),
              const SizedBox(width: 8),
              Text(DateFormat('d MMM y').format(dateTime),
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: GestureDetector(
          onTap: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(dateTime),
            );
            if (t != null) {
              onChange(DateTime(dateTime.year, dateTime.month, dateTime.day,
                  t.hour, t.minute));
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(children: [
              const Icon(Icons.access_time_outlined,
                  color: AppTheme.primaryLight, size: 16),
              const SizedBox(width: 8),
              Text(DateFormat('h:mm a').format(dateTime),
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ── Team dropdown ────────────────────────────────────────────────────────────
class _TeamDropdown extends StatelessWidget {
  final List<TournamentTeamModel> teams;
  final TournamentTeamModel? selected;
  final ValueChanged<TournamentTeamModel?> onChanged;
  final TournamentTeamModel? exclude;

  const _TeamDropdown({
    required this.teams,
    required this.selected,
    required this.onChanged,
    this.exclude,
  });

  @override
  Widget build(BuildContext context) {
    final available =
    teams.where((t) => t.id != exclude?.id).toList();
    return DropdownButtonFormField<TournamentTeamModel>(
      value: selected,
      dropdownColor: AppTheme.bgCard,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppTheme.bgSurface,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
      ),
      items: available
          .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
          .toList(),
      onChanged: onChanged,
      hint: const Text('Select team',
          style: TextStyle(color: AppTheme.textSecondary)),
    );
  }
}

class _ManualEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('🎯', style: TextStyle(fontSize: 54)),
            SizedBox(height: 16),
            Text('Build your matches',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text(
              'Pick 2 teams per match and set the time. Add as many pairs as you need.',
              textAlign: TextAlign.center,
              style:
              TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualPairCard extends StatelessWidget {
  final int index;
  final TournamentTeamModel teamA;
  final TournamentTeamModel teamB;
  final DateTime time;
  final VoidCallback onRemove;

  const _ManualPairCard({
    required this.index,
    required this.teamA,
    required this.teamB,
    required this.time,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: AppTheme.greenGradient,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('$index',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${teamA.name}  vs  ${teamB.name}',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(DateFormat('d MMM, h:mm a').format(time),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        ),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close_rounded,
              color: AppTheme.error, size: 18),
        ),
      ]),
    );
  }
}