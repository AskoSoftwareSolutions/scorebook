// ─────────────────────────────────────────────────────────────────────────────
// lib/views/tournament/tournament_create_view.dart  (UPDATED)
// Changes: Added "Custom" overs option with number input
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';
import '../../models/tournament_models.dart';
import '../../viewmodels/tournament_setup_viewmodel.dart';

class TournamentCreateView extends StatelessWidget {
  const TournamentCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = Get.put(TournamentSetupViewModel());

    return SafeArea(
      top: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New Tournament'),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.bgDark, AppTheme.bgCard],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('TOURNAMENT NAME'),
                const SizedBox(height: 8),
                TextField(
                  controller: vm.nameController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Summer Cup 2026',
                    prefixIcon: Icon(Icons.emoji_events_outlined,
                        color: AppTheme.primaryLight),
                  ),
                ),

                const SizedBox(height: 24),

                _label('FORMAT'),
                const SizedBox(height: 10),
                Obx(() => Column(
                  children: TournamentFormat.values
                      .map((f) => _FormatTile(
                    format: f,
                    selected: vm.format.value == f,
                    onTap: () => vm.format.value = f,
                  ))
                      .toList(),
                )),

                const SizedBox(height: 20),

                _label('OVERS PER MATCH'),
                const SizedBox(height: 10),
                _OversPicker(vm: vm),

                const SizedBox(height: 20),

                _label('UMPIRE MODE'),
                const SizedBox(height: 10),
                Obx(() => Row(
                  children: UmpireMode.values.map((m) {
                    final selected = vm.umpireMode.value == m;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => vm.umpireMode.value = m,
                        child: AnimatedContainer(
                          duration:
                          const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: selected
                                ? AppTheme.greenGradient
                                : null,
                            color: selected
                                ? null
                                : AppTheme.bgSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.borderColor,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Column(children: [
                            Icon(
                              m == UmpireMode.auto
                                  ? Icons.auto_awesome
                                  : Icons.person_outline_rounded,
                              color: selected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(height: 6),
                            Text(m.label,
                                style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : AppTheme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              m == UmpireMode.auto
                                  ? 'Auto pick'
                                  : 'You pick',
                              style: TextStyle(
                                color: selected
                                    ? Colors.white70
                                    : AppTheme.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),
                )),

                const SizedBox(height: 28),

                Obx(() => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.info.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppTheme.info, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(vm.formatDescription,
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                    ),
                  ]),
                )),

                const SizedBox(height: 24),

                Obx(() => SizedBox(
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
                        : () async {
                      final ok = await vm.createTournament();
                      if (ok) {
                        Get.toNamed(AppRoutes.tournamentTeams);
                      }
                    },
                    icon: vm.isLoading.value
                        ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      vm.isLoading.value
                          ? 'Creating...'
                          : 'Continue to Add Teams',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// OVERS PICKER — chips + custom input
// ═══════════════════════════════════════════════════════════════════════════════

class _OversPicker extends StatefulWidget {
  final TournamentSetupViewModel vm;
  const _OversPicker({required this.vm});

  @override
  State<_OversPicker> createState() => _OversPickerState();
}

class _OversPickerState extends State<_OversPicker> {
  final TextEditingController _customCtrl = TextEditingController();
  bool _customMode = false;

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = widget.vm.totalOvers.value;
      final isPreset = widget.vm.overOptions.contains(current);

      // If current value is not in preset, automatically switch to custom mode
      if (!isPreset && !_customMode) {
        _customMode = true;
        _customCtrl.text = '$current';
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...widget.vm.overOptions.map((ov) {
                final selected = current == ov && !_customMode;
                return GestureDetector(
                  onTap: () {
                    setState(() => _customMode = false);
                    widget.vm.totalOvers.value = ov;
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 58,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: selected ? AppTheme.greenGradient : null,
                      color: selected ? null : AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.borderColor,
                      ),
                    ),
                    child: Center(
                      child: Text('$ov',
                          style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                );
              }),

              // Custom chip
              GestureDetector(
                onTap: () => setState(() => _customMode = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 42,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient:
                    _customMode ? AppTheme.greenGradient : null,
                    color: _customMode ? null : AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _customMode
                          ? AppTheme.primary
                          : AppTheme.borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded,
                          size: 14,
                          color: _customMode
                              ? Colors.white
                              : AppTheme.textSecondary),
                      const SizedBox(width: 5),
                      Text('Custom',
                          style: TextStyle(
                              color: _customMode
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Custom input field
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            firstChild: const SizedBox(
                width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _customCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: 'Enter overs',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: AppTheme.bgSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppTheme.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppTheme.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppTheme.primary, width: 1.5),
                        ),
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v) ?? 0;
                        if (n > 0 && n <= 100) {
                          widget.vm.totalOvers.value = n;
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('overs',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                  const Spacer(),
                  Obx(() {
                    final ov = widget.vm.totalOvers.value;
                    if (ov <= 0 || ov > 100 || !_customMode) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('$ov overs',
                          style: const TextStyle(
                              color: AppTheme.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    );
                  }),
                ],
              ),
            ),
            crossFadeState: _customMode
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
        ],
      );
    });
  }
}

// ── Format tile ──────────────────────────────────────────────────────────────
class _FormatTile extends StatelessWidget {
  final TournamentFormat format;
  final bool selected;
  final VoidCallback onTap;

  const _FormatTile(
      {required this.format,
        required this.selected,
        required this.onTap});

  String get _description {
    switch (format) {
      case TournamentFormat.knockout: return 'Single elimination bracket';
      case TournamentFormat.random:   return 'Random pairing — all at once';
      case TournamentFormat.manual:   return 'Pick your own match pairs';
    }
  }

  IconData get _icon {
    switch (format) {
      case TournamentFormat.knockout: return Icons.emoji_events_rounded;
      case TournamentFormat.random:   return Icons.shuffle_rounded;
      case TournamentFormat.manual:   return Icons.touch_app_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryLight.withOpacity(0.08)
              : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.primaryLight
                : AppTheme.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (selected
                  ? AppTheme.primaryLight
                  : AppTheme.textSecondary)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon,
                color: selected
                    ? AppTheme.primaryLight
                    : AppTheme.textSecondary,
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(format.label,
                    style: TextStyle(
                      color: selected
                          ? AppTheme.primaryLight
                          : AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    )),
                Text(_description,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: selected
                      ? AppTheme.primaryLight
                      : AppTheme.textSecondary,
                  width: selected ? 0 : 1.5),
              color:
              selected ? AppTheme.primaryLight : Colors.transparent,
            ),
            child: selected
                ? const Icon(Icons.check_rounded,
                color: Colors.white, size: 14)
                : null,
          ),
        ]),
      ),
    );
  }
}