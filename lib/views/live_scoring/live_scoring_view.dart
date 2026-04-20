import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../services/ad_service.dart';
import '../../core/utils/app_utils.dart';
import '../../viewmodels/live_scoring_viewmodel.dart';
import '../../models/models.dart';
import '../../widgets/app_widgets.dart';

class LiveScoringView extends StatefulWidget {
  const LiveScoringView({super.key});

  @override
  State<LiveScoringView> createState() => _LiveScoringViewState();
}

class _LiveScoringViewState extends State<LiveScoringView> {
  late final LiveScoringViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = Get.put(LiveScoringViewModel());

    ever(vm.needNewBatsman, (bool needed) {
      if (!needed) return;
      vm.needNewBatsman.value = false;
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _selectNewBatsmanAfterWicket(context, vm);
      });
    });

    ever(vm.showShareWithTeamB, (bool show) {
      if (!show) return;
      vm.showShareWithTeamB.value = false;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _showInnings1CompleteSheet(context, vm);
      });
    });
  }

  void _showInnings1CompleteSheet(
      BuildContext context, LiveScoringViewModel vm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _Innings1CompleteSheet(
        vm: vm,
        onShowOnlineMode: () => _showOnlineModeSheet(context, vm), // ← callback pass
      ),
    );
  }

  /// Called automatically after a wicket — shows new batsman picker.
  /// Title tells scorer which end the new batsman is coming to.
  void _selectNewBatsmanAfterWicket(
      BuildContext context, LiveScoringViewModel vm) async {
    // atStriker = true  → mid-over wicket, new batsman comes to striker end
    // atStriker = false → 6th ball wicket, over swap happened,
    //                     new batsman comes to non-striker end
    final atStriker = vm.newBatsmanAtStriker;
    final endLabel  = atStriker ? 'Striker' : 'Non-Striker';

    final picked = await PlayerSearchPickerDialog.show<PlayerModel>(
      context,
      title: 'New Batsman',
      subtitle: 'Coming in at $endLabel end',
      icon: Icons.sports_cricket_rounded,
      accent: AppTheme.primary,
      items: vm.availableBatsmen,
      labelOf: (p) => p.name,
      subtitleOf: (p) =>
          p.didBat ? '${p.runsScored}(${p.ballsFaced})' : 'Yet to bat',
      onAddNew: (name) => vm.addNewBatsman(name),
    );

    if (picked != null) {
      vm.selectNewBatsmanAsStriker(picked);
    }
  }

  void _showExitConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.sports_cricket, color: AppTheme.primary, size: 24),
            SizedBox(width: 10),
            Text('Leave Match?',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
          'Match is in progress.\n'
              'Your data will be saved.\n'
              'You can resume from Home!',
          style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.5),
        ),
        actions: [
          // Cancel — continue scoring
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),

          // Go home — match will be saved
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Get.offAllNamed(AppRoutes.home);
            },
            icon: const Icon(Icons.home_rounded,
                color: Colors.white, size: 18),
            label: const Text('Go to Home',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitConfirm(context);
      },
      child: SafeArea(
        top: false,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F7F6),
          appBar: _MatchTitleAppBar(
            vm: vm,
            onBack: () => _showExitConfirm(context),
            onStats: () => _showBattingStatsSheet(context, vm),
            onOnline: () => _showOnlineModeSheet(context, vm),
          ),
          body: Obx(() {
            if (vm.isLoading.value) {
              return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary));
            }

            return Column(
              children: [
                _ScoreCard(vm: vm),
                _LiveBattersTable(
                  vm: vm,
                  onTapStriker: () => _selectBatsmanDialog(context, isStriker: true),
                  onTapNonStriker: () => _selectBatsmanDialog(context, isStriker: false),
                ),
                _LiveBowlerRow(
                  vm: vm,
                  onTapBowler: () => _selectBowlerDialog(context),
                ),
                _ThisOverRow(vm: vm),
                Obx(() => vm.isOverComplete.value
                    ? _OverCompleteBanner(vm: vm, parentContext: context)
                    : const SizedBox.shrink()),
                Expanded(
                  child: Obx(() => IgnorePointer(
                    ignoring: vm.isOverComplete.value,
                    child: AnimatedOpacity(
                      opacity: vm.isOverComplete.value ? 0.30 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            _ExtrasAndActionsRow(
                              vm: vm,
                              onWicket: () => _openWicketDialog(context),
                              onRetire: () => _confirmRetire(context),
                              onSwapBatsman: vm.changeStrike,
                            ),
                            const SizedBox(height: 10),
                            _ActionAndRunGrid(
                              vm: vm,
                              onUndo: () => _confirmUndo(context, vm),
                              onPartnerships: () => _showBattingStatsSheet(context, vm),
                              onExtras: () => _showOverHistorySheet(context, vm),
                            ),
                            const SizedBox(height: 10),
                            Center(child: AdService().buildBanner()),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  )),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── Dialog helpers for new layout ───────────────────────────────────────
  Future<void> _selectBatsmanDialog(BuildContext context,
      {required bool isStriker}) async {
    final picked = await PlayerSearchPickerDialog.show<PlayerModel>(
      context,
      title: isStriker ? 'Select Striker' : 'Select Non-Striker',
      subtitle: 'Type to filter or add a new player',
      icon: Icons.sports_cricket_rounded,
      accent: AppTheme.primary,
      items: vm.availableBatsmen,
      labelOf: (p) => p.name,
      subtitleOf: (p) =>
          p.didBat ? '${p.runsScored}(${p.ballsFaced})' : 'Yet to bat',
      onAddNew: (name) => vm.addNewBatsman(name),
    );
    if (picked != null) {
      if (isStriker) {
        vm.selectStriker(picked);
      } else {
        vm.selectNonStriker(picked);
      }
    }
  }

  Future<void> _selectBowlerDialog(BuildContext context) async {
    if (!vm.isOverComplete.value && vm.ballsInOver.value > 0) {
      Get.snackbar('Over In Progress', 'Cannot change bowler mid-over',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final blockedNames = <String>{
      if (vm.currentBowler.value != null) vm.currentBowler.value!.name,
      if (vm.lastCompletedOverBowler != null) vm.lastCompletedOverBowler!,
    };
    final available = vm.bowlingTeamPlayers
        .where((p) => !blockedNames.contains(p.name))
        .toList();
    final picked = await PlayerSearchPickerDialog.show<PlayerModel>(
      context,
      title: 'Select Bowler',
      subtitle:
          'Innings ${vm.inningsNumber}  •  Over ${vm.currentOver.value + 1}',
      icon: Icons.sports_handball_rounded,
      accent: AppTheme.warning,
      items: available,
      labelOf: (p) => p.name,
      subtitleOf: (p) {
        if (p.ballsBowled > 0) {
          return '${p.oversBoled} ov  •  ${p.runsConceded} runs  •  ${p.wicketsTaken} wkts';
        }
        if (p.runsScored > 0 || p.ballsFaced > 0) {
          return 'Batted: ${p.runsScored}(${p.ballsFaced})  •  Yet to bowl';
        }
        return 'Yet to bowl';
      },
      onAddNew: (name) => vm.addNewBowler(name),
    );
    if (picked != null) vm.selectBowler(picked);
  }

  void _openWicketDialog(BuildContext context) {
    final battingPlayers = [
      if (vm.striker.value != null) vm.striker.value!.name,
      if (vm.nonStriker.value != null) vm.nonStriker.value!.name,
    ];
    final fieldingPlayers = vm.bowlingTeamPlayers.map((p) => p.name).toList();
    WicketDialog.show(
      context,
      battingPlayers: battingPlayers,
      fieldingPlayers: fieldingPlayers,
      onConfirm: (type, outPlayer, fielder, runs) {
        vm.scoreBall(
          runs: runs,
          wicket: true,
          wicketType: type,
          outBatsmanName: outPlayer ?? vm.striker.value?.name,
          fielderName: fielder,
        );
      },
    );
  }

  void _confirmRetire(BuildContext context) {
    Get.snackbar(
      'Retire',
      'Retire feature is coming soon.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.bgCard,
      colorText: AppTheme.textPrimary,
    );
  }

  void _showOnlineModeSheet(BuildContext context, LiveScoringViewModel vm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OnlineModeSheet(vm: vm),
    );
  }

  void _showBattingStatsSheet(BuildContext context, LiveScoringViewModel vm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BattingStatsSheet(vm: vm),
    );
  }

  void _showOverHistorySheet(BuildContext context, LiveScoringViewModel vm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OverHistorySheet(vm: vm),
    );
  }

  void _confirmUndo(BuildContext context, LiveScoringViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppTheme.borderColor)),
        title: const Text('Undo Last Ball?',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text('This will reverse the last scored ball.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              vm.undoLastBall();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
            child: const Text('Undo'),
          ),
        ],
      ),
    );
  }
}

// ── Scoreboard Header ─────────────────────────────────────────────────────────
class _ScoreboardHeader extends StatelessWidget {
  final LiveScoringViewModel vm;
  const _ScoreboardHeader({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.greenGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // ── Score centered ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                Obx(() => Text(
                  vm.scoreDisplay,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                )),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Obx(() => Text(
                      '${vm.oversDisplay} ov',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    )),
                    const SizedBox(width: 10),
                    Container(
                        width: 3, height: 3,
                        decoration: const BoxDecoration(
                            color: Colors.white54, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Obx(() => Text(
                      'RR: ${AppUtils.formatDouble(vm.runRate)}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11),
                    )),
                    if (vm.inningsNumber == 2) ...[
                      const SizedBox(width: 10),
                      Container(
                          width: 3, height: 3,
                          decoration: const BoxDecoration(
                              color: Colors.white54, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Obx(() => Text(
                        'Need ${vm.runsNeeded}',
                        style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      )),
                    ],
                  ],
                ),
                if (vm.inningsNumber == 2)
                  Obx(() => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Req RR: ${AppUtils.formatDouble(vm.requiredRunRate)}',
                      style: const TextStyle(
                          color: AppTheme.accent, fontSize: 11),
                    ),
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom Action Bar — 5 icons split evenly ─────────────────────────────────
class _BottomActionBar extends StatelessWidget {
  final LiveScoringViewModel vm;
  final VoidCallback onOnlineTap;
  final VoidCallback onStatsTap;
  final VoidCallback onHistoryTap;
  final VoidCallback onUndoTap;
  final VoidCallback onSwapTap;

  const _BottomActionBar({
    required this.vm,
    required this.onOnlineTap,
    required this.onStatsTap,
    required this.onHistoryTap,
    required this.onUndoTap,
    required this.onSwapTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          // ── Wifi / Online ──────────────────────────────────────────────
          Expanded(
            child: Obx(() => _ActionBtn(
              icon: vm.isOnlineMode.value ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              label: vm.isOnlineMode.value ? 'Live' : 'Offline',
              color: vm.isOnlineMode.value ? const Color(0xFF66BB6A) : AppTheme.textSecondary,
              onTap: onOnlineTap,
              showDot: vm.isOnlineMode.value,
            )),
          ),
          _Divider(),
          // ── Batting Stats ──────────────────────────────────────────────
          Expanded(
            child: _ActionBtn(
              icon: Icons.bar_chart_rounded,
              label: 'Stats',
              color: AppTheme.primaryLight,
              onTap: onStatsTap,
            ),
          ),
          _Divider(),
          // ── Over History ───────────────────────────────────────────────
          Expanded(
            child: _ActionBtn(
              icon: Icons.history_rounded,
              label: 'History',
              color: AppTheme.accent,
              onTap: onHistoryTap,
            ),
          ),
          _Divider(),
          // ── Undo ──────────────────────────────────────────────────────
          Expanded(
            child: _ActionBtn(
              icon: Icons.undo_rounded,
              label: 'Undo',
              color: AppTheme.warning,
              onTap: onUndoTap,
            ),
          ),
          _Divider(),
          // ── Swap Strike ───────────────────────────────────────────────
          Expanded(
            child: _ActionBtn(
              icon: Icons.swap_horiz_rounded,
              label: 'Swap',
              color: AppTheme.info,
              onTap: onSwapTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool showDot;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 22),
              if (showDot)
                Positioned(
                  top: -2,
                  right: -4,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.bgCard, width: 1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppTheme.borderColor,
    );
  }
}

// ── Online Toggle — wifi icon only (kept for compatibility) ───────────────────

class _OnlineTogglePill extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onTap;
  const _OnlineTogglePill({required this.isOnline, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isOnline
              ? Colors.white.withOpacity(0.20)
              : Colors.black.withOpacity(0.25),
          shape: BoxShape.circle,
          border: Border.all(
            color: isOnline ? Colors.white70 : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Icon(
          isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
          color: isOnline ? Colors.white : Colors.white38,
          size: 20,
        ),
      ),
    );
  }
}

// ── Batsmen & Bowler ──────────────────────────────────────────────────────────
class _BatsmenBowlerPanel extends StatelessWidget {
  final LiveScoringViewModel vm;
  const _BatsmenBowlerPanel({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          // ── Batting row ────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.sports_cricket, color: AppTheme.primaryLight, size: 16),
              const SizedBox(width: 6),
              Obx(() => _BatsmanTile(
                player: vm.striker.value,
                label: 'Striker',
                isStriker: true,
                onTap: () => _selectBatsman(context, vm, isStriker: true),
              )),
              const SizedBox(width: 8),
              Obx(() => _BatsmanTile(
                player: vm.nonStriker.value,
                label: 'Non-Striker',
                isStriker: false,
                onTap: () => _selectBatsman(context, vm, isStriker: false),
              )),
            ],
          ),

          const Divider(height: 16),

          // ── Bowling row ────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sports_handball,
                    color: AppTheme.warning, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Obx(() => GestureDetector(
                  onTap: () => _selectBowler(context, vm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: vm.currentBowler.value != null
                            ? AppTheme.warning.withOpacity(0.45)
                            : AppTheme.borderColor,
                      ),
                    ),
                    child: vm.currentBowler.value != null
                        ? Row(children: [
                      Expanded(
                        child: Text(
                          vm.currentBowler.value!.name,
                          style: const TextStyle(
                              color: AppTheme.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                      ),
                      Text(
                        '${vm.currentBowler.value!.oversBoled}-'
                            '${vm.currentBowler.value!.runsConceded}-'
                            '${vm.currentBowler.value!.wicketsTaken}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12),
                      ),
                    ])
                        : const Text('Tap to select bowler',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12)),
                  ),
                )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _selectBatsman(BuildContext context, LiveScoringViewModel vm,
      {required bool isStriker}) async {
    final picked = await PlayerSearchPickerDialog.show<PlayerModel>(
      context,
      title: isStriker ? 'Select Striker' : 'Select Non-Striker',
      subtitle: 'Type to filter or add a new player',
      icon: Icons.sports_cricket_rounded,
      accent: AppTheme.primary,
      items: vm.availableBatsmen,
      labelOf: (p) => p.name,
      subtitleOf: (p) =>
          p.didBat ? '${p.runsScored}(${p.ballsFaced})' : 'Yet to bat',
      onAddNew: (name) => vm.addNewBatsman(name),
    );

    if (picked != null) {
      if (isStriker) {
        vm.selectStriker(picked);
      } else {
        vm.selectNonStriker(picked);
      }
    }
  }

  void _selectBowler(BuildContext context, LiveScoringViewModel vm) async {
    if (!vm.isOverComplete.value && vm.ballsInOver.value > 0) {
      Get.snackbar('Over In Progress', 'Cannot change bowler mid-over',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // Current bowler + last-over bowler both blocked
    final blockedNames = <String>{
      if (vm.currentBowler.value != null) vm.currentBowler.value!.name,
      if (vm.lastCompletedOverBowler != null) vm.lastCompletedOverBowler!,
    };

    final available = vm.bowlingTeamPlayers
        .where((p) => !blockedNames.contains(p.name))
        .toList();

    final picked = await PlayerSearchPickerDialog.show<PlayerModel>(
      context,
      title: 'Select Bowler',
      subtitle:
          'Innings ${vm.inningsNumber}  •  Over ${vm.currentOver.value + 1}',
      icon: Icons.sports_handball_rounded,
      accent: AppTheme.warning,
      items: available,
      labelOf: (p) => p.name,
      subtitleOf: (p) {
        if (p.ballsBowled > 0) {
          return '${p.oversBoled} ov  •  ${p.runsConceded} runs  •  ${p.wicketsTaken} wkts';
        }
        if (p.runsScored > 0 || p.ballsFaced > 0) {
          return 'Batted: ${p.runsScored}(${p.ballsFaced})  •  Yet to bowl';
        }
        return 'Yet to bowl';
      },
      onAddNew: (name) => vm.addNewBowler(name),
    );

    if (picked != null) vm.selectBowler(picked);
  }
}

class _BatsmanTile extends StatelessWidget {
  final PlayerModel? player;
  final String label;
  final bool isStriker;
  final VoidCallback onTap;

  const _BatsmanTile({
    required this.player,
    required this.label,
    required this.isStriker,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = player != null;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: active && isStriker
                ? AppTheme.primaryLight.withOpacity(0.07)
                : AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active && isStriker
                  ? AppTheme.primaryLight.withOpacity(0.55)
                  : active
                  ? AppTheme.borderColor.withOpacity(0.8)
                  : AppTheme.borderColor,
              width: isStriker && active ? 1.5 : 1.0,
            ),
          ),
          child: player != null
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isStriker)
                    const Text('* ',
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  Expanded(
                    child: Text(
                      player!.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: isStriker
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
              Text(
                '${player!.runsScored}(${player!.ballsFaced})',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          )
              : Text(
            'Tap: $label',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

// ── Over Ball Row ─────────────────────────────────────────────────────────────
class _OverBallRow extends StatelessWidget {
  final LiveScoringViewModel vm;
  const _OverBallRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final balls = vm.currentOverBalls;
      final validCount = balls.where((b) => b.isValid).length;
      final emptyDots = (6 - validCount).clamp(0, 6);

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Over label + counters
            Row(
              children: [
                Text(
                  'Over ${vm.currentOver.value + 1}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                  ),
                  child: Text(
                    '$validCount / 6',
                    style: const TextStyle(
                      color: AppTheme.primaryLight,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (balls.length > validCount) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
                    ),
                    child: Text(
                      '+${balls.length - validCount} extra ball',
                      style: const TextStyle(
                        color: AppTheme.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Wrap prevents overflow when extras push beyond 6 balls
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...balls.map((b) => _BallBubble(ball: b)),
                ...List.generate(
                  emptyDots,
                      (_) => Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

}

// ── Ball Bubble — standalone widget used by _OverBallRow ─────────────────────
class _BallBubble extends StatelessWidget {
  final BallModel ball;
  const _BallBubble({required this.ball});

  String get _label {
    if (ball.isWicket) return 'W';
    if (ball.isWide) return 'WD';
    if (ball.isNoBall) return 'NB';
    if (ball.isBye) return 'B';
    if (ball.isLegBye) return 'LB';
    return '${ball.runs}';
  }

  Color get _color {
    if (ball.isWicket) return AppTheme.error;
    if (ball.isWide || ball.isNoBall) return AppTheme.warning;
    if (ball.isBye || ball.isLegBye) return AppTheme.info;
    if (ball.runs == 4) return AppTheme.info;
    if (ball.runs == 6) return AppTheme.accent;
    if (ball.runs == 0) return AppTheme.textSecondary;
    return AppTheme.success;
  }

  bool get _isExtra => ball.isWide || ball.isNoBall || ball.isBye || ball.isLegBye;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: _color.withOpacity(0.18),
        shape: BoxShape.circle,
        border: Border.all(
          color: _color,
          width: _isExtra ? 1.5 : 1,
          // Dashed visual cue for extras via strokeAlign
        ),
      ),
      child: Center(
        child: Text(
          _label,
          style: TextStyle(
            color: _color,
            fontSize: _label.length > 1 ? 8 : 11,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

// ── Extras Panel ──────────────────────────────────────────────────────────────
class _ExtrasPanel extends StatelessWidget {
  final LiveScoringViewModel vm;
  const _ExtrasPanel({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Extras',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              ExtraToggle(
                label: 'Wide',
                isActive: vm.isWide.value,
                onTap: vm.toggleWide,
                activeColor: AppTheme.warning,
              ),
              const SizedBox(width: 8),
              ExtraToggle(
                label: 'No Ball',
                isActive: vm.isNoBall.value,
                onTap: vm.toggleNoBall,
                activeColor: AppTheme.warning,
              ),
              const SizedBox(width: 8),
              ExtraToggle(
                label: 'Bye',
                isActive: vm.isBye.value,
                onTap: vm.toggleBye,
                activeColor: AppTheme.info,
              ),
              const SizedBox(width: 8),
              ExtraToggle(
                label: 'Leg Bye',
                isActive: vm.isLegBye.value,
                onTap: vm.toggleLegBye,
                activeColor: AppTheme.info,
              ),
            ],
          ),
        ],
      ),
    ));
  }
}

// ── Run Buttons ───────────────────────────────────────────────────────────────
class _RunButtons extends StatelessWidget {
  final LiveScoringViewModel vm;
  const _RunButtons({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [0, 1, 2, 3].map((run) {
            final bg = run == 0
                ? const Color(0xFFFAFAFA)   // 0 = light grey
                : const Color(0xFFF1F8F1);  // 1,2,3 = light green

            final textColor = run == 0
                ? const Color(0xFF9E9E9E)   // 0 = grey text
                : const Color(0xFF2E7D32);  // 1,2,3 = green text

            final borderColor = run == 0
                ? const Color(0xFFE0E0E0)   // 0 = grey border
                : const Color(0xFFA5D6A7);  // 1,2,3 = green border

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: run < 3 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => vm.scoreBall(runs: run),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Center(
                      child: Text(
                        '$run',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // 4 runs ← light blue
            Expanded(
              child: GestureDetector(
                onTap: () => vm.scoreBall(runs: 4),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4FD),  // ← light blue bg
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF1E88E5), width: 1.5),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('4',
                          style: TextStyle(
                              color: Color(0xFF1565C0),  // ← dark blue text
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                      Text('FOUR',
                          style: TextStyle(
                              color: Color(0xFF1E88E5),
                              fontSize: 9,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 6 runs ← light amber
            Expanded(
              child: GestureDetector(
                onTap: () => vm.scoreBall(runs: 6),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDE7),  // ← light yellow bg
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFF9A825), width: 1.5),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('6',
                          style: TextStyle(
                              color: Color(0xFFF57F17),  // ← dark orange text
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                      Text('SIX',
                          style: TextStyle(
                              color: Color(0xFFF9A825),
                              fontSize: 9,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Wicket Section ────────────────────────────────────────────────────────────
class _WicketSection extends StatelessWidget {
  final LiveScoringViewModel vm;
  const _WicketSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showWicketDialog(context, vm),
      child: Container(
        width: double.infinity,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.error.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.error.withOpacity(0.5)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_cricket, color: AppTheme.error, size: 22),
            SizedBox(width: 8),
            Text(
              'WICKET',
              style: TextStyle(
                color: AppTheme.error,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWicketDialog(BuildContext context, LiveScoringViewModel vm) {
    final battingPlayers = [
      if (vm.striker.value != null) vm.striker.value!.name,
      if (vm.nonStriker.value != null) vm.nonStriker.value!.name,
    ];
    final fieldingPlayers = vm.bowlingTeamPlayers.map((p) => p.name).toList();

    WicketDialog.show(
      context,
      battingPlayers: battingPlayers,
      fieldingPlayers: fieldingPlayers,
      onConfirm: (type, outPlayer, fielder, runs) {
        vm.scoreBall(
          runs: runs, // ← run-out runs (0 for all other dismissals)
          wicket: true,
          wicketType: type,
          outBatsmanName: outPlayer ?? vm.striker.value?.name,
          fielderName: fielder,
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOWLER TIMELINE — horizontal strip showing bowler for each completed over
// ═══════════════════════════════════════════════════════════════════════════════

class _BowlerTimeline extends StatelessWidget {
  final LiveScoringViewModel vm;
  const _BowlerTimeline({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final timeline = vm.bowlerOverTimeline;
      if (timeline.isEmpty) return const SizedBox.shrink();

      return Container(
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: timeline.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (ctx, i) {
            final item = timeline[i];
            final over = item['over'] as int;
            final bowler = item['bowler'] as String;
            final runs = item['runs'] as int;
            final wickets = item['wickets'] as int;
            final isCurrent = item['isCurrentOver'] as bool;

            // Short name — first 6 chars
            final shortName = bowler.length > 7
                ? bowler.substring(0, 6).trim()
                : bowler;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppTheme.primary.withOpacity(0.2)
                    : AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCurrent
                      ? AppTheme.primaryLight
                      : wickets > 0
                      ? AppTheme.error.withOpacity(0.45)
                      : AppTheme.borderColor,
                  width: isCurrent ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Over number + bowler name
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'O${over + 1} ',
                        style: TextStyle(
                          color: isCurrent
                              ? AppTheme.primaryLight
                              : AppTheme.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        shortName,
                        style: TextStyle(
                          color: isCurrent
                              ? AppTheme.primaryLight
                              : AppTheme.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Runs + wickets
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$runs',
                        style: TextStyle(
                          color: runs >= 12
                              ? AppTheme.error
                              : runs <= 4
                              ? AppTheme.success
                              : AppTheme.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (wickets > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${wickets}W',
                            style: const TextStyle(
                              color: AppTheme.error,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// OVER COMPLETE BANNER — mandatory bowler change prompt
// ═══════════════════════════════════════════════════════════════════════════════

class _OverCompleteBanner extends StatelessWidget {
  final LiveScoringViewModel vm;
  final BuildContext parentContext;
  const _OverCompleteBanner(
      {required this.vm, required this.parentContext});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickBowler(parentContext),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.warning.withOpacity(0.18),
              AppTheme.accent.withOpacity(0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.warning, width: 1.5),
        ),
        child: Row(
          children: [
            // Pulse icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sports_handball,
                  color: AppTheme.warning, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Over ${vm.currentOver.value} Complete!',
                    style: const TextStyle(
                      color: AppTheme.warning,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'Tap to select new bowler to continue',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.warning,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'SELECT',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBowler(BuildContext context) async {
    // Block the bowler who just completed the over
    final blockedNames = <String>{
      if (vm.lastCompletedOverBowler != null) vm.lastCompletedOverBowler!,
    };

    final available = vm.bowlingTeamPlayers
        .where((p) => !blockedNames.contains(p.name))
        .toList();

    final picked = await PlayerSearchPickerDialog.show<PlayerModel>(
      context,
      title: 'Select Bowler',
      subtitle:
          'Innings ${vm.inningsNumber}  •  Over ${vm.currentOver.value + 1}',
      icon: Icons.sports_handball_rounded,
      accent: AppTheme.warning,
      items: available,
      labelOf: (p) => p.name,
      subtitleOf: (p) {
        if (p.ballsBowled > 0) {
          return '${p.oversBoled} ov  •  ${p.runsConceded} runs  •  ${p.wicketsTaken} wkts';
        }
        if (p.runsScored > 0 || p.ballsFaced > 0) {
          return 'Batted: ${p.runsScored}(${p.ballsFaced})  •  Yet to bowl';
        }
        return 'Yet to bowl';
      },
      onAddNew: (name) => vm.addNewBowler(name),
    );

    if (picked != null) vm.selectBowler(picked);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATTING STATS BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _BattingStatsSheet extends StatelessWidget {
  final LiveScoringViewModel vm;
  const _BattingStatsSheet({required this.vm});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: AppTheme.borderColor),
            left: BorderSide(color: AppTheme.borderColor),
            right: BorderSide(color: AppTheme.borderColor),
          ),
        ),
        child: Column(
          children: [
            // Handle
            _SheetHandle(),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.bar_chart_rounded,
                      color: AppTheme.primaryLight, size: 22),
                  const SizedBox(width: 10),
                  Obx(() => Text(
                    '${vm.currentInnings.value?.battingTeam ?? ''} — Live Scorecard',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  )),
                ],
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: Obx(() {
                  final innings = vm.currentInnings.value;
                  final batters = vm.battingScorecard;
                  final bowlers = vm.bowlingScorecard;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Partnership banner ─────────────────────────────
                      if (vm.striker.value != null && vm.nonStriker.value != null)
                        _PartnershipBanner(vm: vm),

                      const SizedBox(height: 16),

                      // ── Batting table ──────────────────────────────────
                      _SheetSectionHeader(
                          icon: Icons.sports_cricket,
                          label: 'Batting',
                          color: AppTheme.primaryLight),
                      const SizedBox(height: 10),
                      _BattingTable(batters: batters, vm: vm),

                      const SizedBox(height: 20),

                      // ── Extras & Total ────────────────────────────────
                      if (innings != null) ...[
                        _ExtrasTotalRow(innings: innings),
                        const SizedBox(height: 20),
                      ],

                      // ── Bowling table ─────────────────────────────────
                      if (bowlers.isNotEmpty) ...[
                        _SheetSectionHeader(
                            icon: Icons.sports_handball,
                            label: 'Bowling',
                            color: AppTheme.warning),
                        const SizedBox(height: 10),
                        _BowlingTable(bowlers: bowlers),
                      ],

                      const SizedBox(height: 20),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Partnership Banner ────────────────────────────────────────────────────────
class _PartnershipBanner extends StatelessWidget {
  final LiveScoringViewModel vm;
  const _PartnershipBanner({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.greenGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Partnership',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                Obx(() => Text(
                  '${vm.partnershipRuns.value} (${vm.partnershipBalls.value})',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                )),
              ],
            ),
          ),
          // Striker
          Obx(() => _MiniPlayerStat(
            name: vm.striker.value?.name ?? '-',
            runs: vm.striker.value?.runsScored ?? 0,
            balls: vm.striker.value?.ballsFaced ?? 0,
            isStriker: true,
          )),
          const SizedBox(width: 12),
          // Non-striker
          Obx(() => _MiniPlayerStat(
            name: vm.nonStriker.value?.name ?? '-',
            runs: vm.nonStriker.value?.runsScored ?? 0,
            balls: vm.nonStriker.value?.ballsFaced ?? 0,
            isStriker: false,
          )),
        ],
      ),
    );
  }
}

class _MiniPlayerStat extends StatelessWidget {
  final String name;
  final int runs;
  final int balls;
  final bool isStriker;
  const _MiniPlayerStat(
      {required this.name,
        required this.runs,
        required this.balls,
        required this.isStriker});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isStriker)
                const Text('* ',
                    style: TextStyle(
                        color: AppTheme.accent, fontWeight: FontWeight.bold)),
              Text(name.length > 8 ? '${name.substring(0, 7)}…' : name,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          Text('$runs ($balls)',
              style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ── Batting Table ─────────────────────────────────────────────────────────────
class _BattingTable extends StatelessWidget {
  final List<PlayerModel> batters;
  final LiveScoringViewModel vm;
  const _BattingTable({required this.batters, required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          // Header row
          _tableHeaderRow(),
          const Divider(height: 1),
          // Player rows
          ...batters.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final isStriker = p.id == vm.striker.value?.id;
            final isNonStriker = p.id == vm.nonStriker.value?.id;
            final isBatting = isStriker || isNonStriker;
            final didPlay = p.didBat || p.ballsFaced > 0;

            return Column(
              children: [
                Container(
                  color: isBatting
                      ? AppTheme.primary.withOpacity(0.08)
                      : i.isOdd
                      ? AppTheme.bgCard
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // Name + status
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            if (isStriker)
                              const Text('🏏 ',
                                  style: TextStyle(fontSize: 12))
                            else if (isNonStriker)
                              const Text('⚡ ',
                                  style: TextStyle(fontSize: 12))
                            else
                              const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isBatting
                                          ? AppTheme.primaryLight
                                          : didPlay
                                          ? AppTheme.textPrimary
                                          : AppTheme.textSecondary,
                                      fontSize: 12,
                                      fontWeight: isBatting
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  if (p.isOut)
                                    Text(
                                      _dismissalText(p),
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 9),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  else if (!didPlay)
                                    const Text('yet to bat',
                                        style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 9)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // R
                      _statCell(
                        didPlay ? '${p.runsScored}' : '-',
                        bold: true,
                        color: p.runsScored >= 50
                            ? AppTheme.accent
                            : AppTheme.textPrimary,
                      ),
                      // B
                      _statCell(didPlay ? '${p.ballsFaced}' : '-'),
                      // 4s
                      _statCell(didPlay ? '${p.fours}' : '-',
                          color: AppTheme.info),
                      // 6s
                      _statCell(didPlay ? '${p.sixes}' : '-',
                          color: AppTheme.accent),
                      // SR
                      _statCell(
                        didPlay
                            ? AppUtils.formatDouble(p.strikeRate)
                            : '-',
                        color: p.strikeRate >= 150
                            ? AppTheme.success
                            : p.strikeRate > 0 && p.strikeRate < 80
                            ? AppTheme.error
                            : AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ),
                if (i < batters.length - 1) const Divider(height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _tableHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.2),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          const Expanded(
              flex: 3,
              child: Text('Batsman',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600))),
          ...[('R', null), ('B', null), ('4s', AppTheme.info), ('6s', AppTheme.accent), ('SR', null)]
              .map((h) => SizedBox(
            width: 38,
            child: Text(
              h.$1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: h.$2 ?? AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _statCell(String val, {bool bold = false, Color? color}) {
    return SizedBox(
      width: 38,
      child: Text(
        val,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color ?? AppTheme.textPrimary,
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        ),
      ),
    );
  }

  String _dismissalText(PlayerModel p) {
    switch (p.wicketType) {
      case 'Bowled': return 'b ${p.bowlerName ?? ''}';
      case 'Caught': return 'c ${p.dismissedBy ?? ''} b ${p.bowlerName ?? ''}';
      case 'LBW': return 'lbw b ${p.bowlerName ?? ''}';
      case 'Run Out': return 'run out';
      case 'Stumped': return 'st b ${p.bowlerName ?? ''}';
      case 'Hit Wicket': return 'hw b ${p.bowlerName ?? ''}';
      default: return p.wicketType ?? 'out';
    }
  }
}

// ── Bowling Table ─────────────────────────────────────────────────────────────
class _BowlingTable extends StatelessWidget {
  final List<PlayerModel> bowlers;
  const _BowlingTable({required this.bowlers});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.12),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                const Expanded(
                    flex: 3,
                    child: Text('Bowler',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                ...['O', 'R', 'W', 'WD', 'NB', 'Econ'].map((h) => SizedBox(
                  width: 36,
                  child: Text(h,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                )),
              ],
            ),
          ),
          const Divider(height: 1),
          ...bowlers.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            return Column(
              children: [
                Container(
                  color:
                  i.isOdd ? AppTheme.bgCard : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(p.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                      _cell(p.oversBoled),
                      _cell('${p.runsConceded}'),
                      _cell('${p.wicketsTaken}',
                          bold: true, color: AppTheme.error),
                      _cell('${p.wides}',
                          color: p.wides > 0
                              ? AppTheme.warning
                              : AppTheme.textSecondary),
                      _cell('${p.noBalls}',
                          color: p.noBalls > 0
                              ? AppTheme.warning
                              : AppTheme.textSecondary),
                      _cell(AppUtils.formatDouble(p.economy)),
                    ],
                  ),
                ),
                if (i < bowlers.length - 1) const Divider(height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _cell(String val, {bool bold = false, Color? color}) => SizedBox(
    width: 36,
    child: Text(val,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color ?? AppTheme.textPrimary,
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        )),
  );
}

// ── Extras & Total Row ────────────────────────────────────────────────────────
class _ExtrasTotalRow extends StatelessWidget {
  final InningsModel innings;
  const _ExtrasTotalRow({required this.innings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Extras  ',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              Text('${innings.extras}',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                'WD ${innings.wides}  NB ${innings.noBalls}  B ${innings.byes}  LB ${innings.legByes}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const Divider(height: 12),
          Row(
            children: [
              const Text('Total',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '${innings.totalRuns}/${innings.totalWickets}  (${innings.oversBowled} ov)  RR: ${AppUtils.formatDouble(innings.runRate)}',
                style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// OVER HISTORY BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _OverHistorySheet extends StatelessWidget {
  final LiveScoringViewModel vm;
  const _OverHistorySheet({required this.vm});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: AppTheme.borderColor),
            left: BorderSide(color: AppTheme.borderColor),
            right: BorderSide(color: AppTheme.borderColor),
          ),
        ),
        child: Column(
          children: [
            _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded,
                      color: AppTheme.accent, size: 22),
                  const SizedBox(width: 10),
                  const Text('Over-by-Over History',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Obx(() => Text(
                    '${vm.previousOversHistory.length} overs',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  )),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Obx(() {
                final history = vm.previousOversHistory;
                if (history.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🏏', style: TextStyle(fontSize: 40)),
                        SizedBox(height: 12),
                        Text('No completed overs yet',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14)),
                      ],
                    ),
                  );
                }
                // Show latest over first
                final reversed = history.reversed.toList();
                return ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: reversed.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final item = reversed[i];
                    return _OverHistoryCard(
                      overIndex: item['over'] as int,
                      balls: item['balls'] as List<BallModel>,
                      runs: item['runs'] as int,
                      wickets: item['wickets'] as int,
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverHistoryCard extends StatelessWidget {
  final int overIndex;
  final List<BallModel> balls;
  final int runs;
  final int wickets;

  const _OverHistoryCard({
    required this.overIndex,
    required this.balls,
    required this.runs,
    required this.wickets,
  });

  @override
  Widget build(BuildContext context) {
    final hasMaiden = runs == 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: wickets > 0
              ? AppTheme.error.withOpacity(0.35)
              : hasMaiden
              ? AppTheme.success.withOpacity(0.35)
              : AppTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Over header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppTheme.greenGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Over ${overIndex + 1}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              // Runs badge
              _OverBadge(
                  label: '$runs runs',
                  color: runs >= 12
                      ? AppTheme.error
                      : runs >= 8
                      ? AppTheme.warning
                      : AppTheme.success),
              if (wickets > 0) ...[
                const SizedBox(width: 6),
                _OverBadge(
                    label: '$wickets wkt${wickets > 1 ? 's' : ''}',
                    color: AppTheme.error),
              ],
              if (hasMaiden) ...[
                const SizedBox(width: 6),
                _OverBadge(label: 'Maiden', color: AppTheme.success),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // Ball-by-ball bubbles
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: balls.map((b) => _HistoryBallBubble(ball: b)).toList(),
          ),

          const SizedBox(height: 8),

          // Bowler info
          if (balls.isNotEmpty)
            Text(
              'Bowled by: ${balls.first.bowlerName}',
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }
}

class _OverBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _OverBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _HistoryBallBubble extends StatelessWidget {
  final BallModel ball;
  const _HistoryBallBubble({required this.ball});

  String get _label {
    if (ball.isWicket) return 'W';
    if (ball.isWide) return 'WD';
    if (ball.isNoBall) return 'NB';
    if (ball.isBye) return 'B';
    if (ball.isLegBye) return 'LB';
    return '${ball.runs}';
  }

  Color get _color {
    if (ball.isWicket) return AppTheme.error;
    if (ball.isWide || ball.isNoBall) return AppTheme.warning;
    if (ball.isBye || ball.isLegBye) return AppTheme.info;
    if (ball.runs == 6) return AppTheme.accent;
    if (ball.runs == 4) return AppTheme.info;
    if (ball.runs == 0) return AppTheme.textSecondary;
    return AppTheme.success;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: _color, width: 1.5),
      ),
      child: Center(
        child: Text(
          _label,
          style: TextStyle(
            color: _color,
            fontSize: _label.length > 1 ? 8 : 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ── Shared Sheet Helpers ──────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.borderColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetSectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SheetSectionHeader(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Expanded(
            child: Container(height: 1, color: color.withOpacity(0.2))),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ONLINE MODE BOTTOM SHEET — Premium Redesign
// ═══════════════════════════════════════════════════════════════════════════════

class _OnlineModeSheet extends StatefulWidget {
  final LiveScoringViewModel vm;
  const _OnlineModeSheet({required this.vm});

  @override
  State<_OnlineModeSheet> createState() => _OnlineModeSheetState();
}

class _OnlineModeSheetState extends State<_OnlineModeSheet>
    with SingleTickerProviderStateMixin {
  final _pwCtrl = TextEditingController();
  bool _obscure = true;
  String? _pwError;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pwCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _enableWithPassword() {
    final pw = _pwCtrl.text.trim();
    if (pw.isEmpty) {
      setState(() => _pwError = 'Password required for viewers');
      return;
    }
    if (pw.length < 4) {
      setState(() => _pwError = 'Minimum 4 characters');
      return;
    }
    setState(() => _pwError = null);
    widget.vm.enableOnlineMode(password: pw);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.50,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.zero,
          children: [
            // ── Drag handle ────────────────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Hero header ────────────────────────────────────────────────
            Obx(() => _OnlineModeHero(
              isOnline: vm.isOnlineMode.value,
              pulse: _pulse,
            )),

            // ── Body ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Obx(() => vm.isOnlineMode.value
                  ? _ActiveState(vm: vm)
                  : _SetupState(
                pwCtrl: _pwCtrl,
                obscure: _obscure,
                pwError: _pwError,
                onToggleObscure: () => setState(() => _obscure = !_obscure),
                onEnable: _enableWithPassword,
              )),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero header (top section with animated icon) ─────────────────────────────

class _OnlineModeHero extends StatelessWidget {
  final bool isOnline;
  final Animation<double> pulse;
  const _OnlineModeHero({required this.isOnline, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        gradient: isOnline
            ? LinearGradient(
          colors: [
            const Color(0xFF1B5E20).withOpacity(0.9),
            const Color(0xFF2E7D32).withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : LinearGradient(
          colors: [
            AppTheme.bgSurface,
            AppTheme.bgSurface,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOnline
              ? const Color(0xFF4CAF50).withOpacity(0.5)
              : AppTheme.borderColor,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Animated icon
          Stack(
            alignment: Alignment.center,
            children: [
              if (isOnline)
                AnimatedBuilder(
                  animation: pulse,
                  builder: (_, __) => Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.withOpacity(0.08 * pulse.value),
                    ),
                  ),
                ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline
                      ? Colors.green.withOpacity(0.2)
                      : Colors.white.withOpacity(0.06),
                  border: Border.all(
                    color: isOnline
                        ? Colors.green.withOpacity(0.5)
                        : Colors.white12,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isOnline ? Icons.cell_tower_rounded : Icons.wifi_off_rounded,
                  color: isOnline ? const Color(0xFF69F0AE) : Colors.white38,
                  size: 26,
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    isOnline ? 'LIVE' : 'OFFLINE',
                    style: TextStyle(
                      color: isOnline
                          ? const Color(0xFF69F0AE)
                          : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  if (isOnline) ...[
                    const SizedBox(width: 8),
                    AnimatedBuilder(
                      animation: pulse,
                      builder: (_, __) => Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red
                              .withOpacity(0.5 + 0.5 * pulse.value),
                        ),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(
                  isOnline
                      ? 'Score is broadcasting live'
                      : 'Share score with viewers',
                  style: TextStyle(
                    color: isOnline ? Colors.white : Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isOnline
                      ? 'Anyone with the link can watch'
                      : 'Set a password & go online',
                  style: TextStyle(
                    color: isOnline
                        ? Colors.white.withOpacity(0.55)
                        : Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // OFF button when online
          if (isOnline)
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                (context
                    .findAncestorStateOfType<State>() as dynamic)
                    ?.setState(() {});
                GetX<LiveScoringViewModel>(
                  builder: (vm) {
                    vm.disableOnlineMode();
                    return const SizedBox.shrink();
                  },
                );
                // Simpler: call directly
                final vm = Get.find<LiveScoringViewModel>();
                vm.disableOnlineMode();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.red.withOpacity(0.3)),
                ),
                child: const Text(
                  'STOP',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Setup state (password input + enable) ────────────────────────────────────

class _SetupState extends StatelessWidget {
  final TextEditingController pwCtrl;
  final bool obscure;
  final String? pwError;
  final VoidCallback onToggleObscure;
  final VoidCallback onEnable;
  const _SetupState({
    required this.pwCtrl,
    required this.obscure,
    required this.pwError,
    required this.onToggleObscure,
    required this.onEnable,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── How it works ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            children: [
              _HowItWorksRow(
                step: '1',
                icon: Icons.lock_outline_rounded,
                text: 'Set a password for viewers',
              ),
              const SizedBox(height: 10),
              _HowItWorksRow(
                step: '2',
                icon: Icons.share_rounded,
                text: 'Share link via WhatsApp',
              ),
              const SizedBox(height: 10),
              _HowItWorksRow(
                step: '3',
                icon: Icons.sports_cricket_rounded,
                text: 'Viewers watch live in real-time',
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Password label ────────────────────────────────────────────────
        Row(children: [
          const Icon(Icons.lock_rounded,
              color: AppTheme.textSecondary, size: 13),
          const SizedBox(width: 6),
          const Text(
            'VIEWER PASSWORD',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ]),
        const SizedBox(height: 8),

        // ── Password field ────────────────────────────────────────────────
        TextField(
          controller: pwCtrl,
          obscureText: obscure,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'e.g.  match123',
            hintStyle: const TextStyle(
              color: AppTheme.textSecondary,
              letterSpacing: 1,
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: AppTheme.bgDark,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: pwError != null
                    ? AppTheme.error
                    : AppTheme.borderColor,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: pwError != null
                    ? AppTheme.error.withOpacity(0.6)
                    : AppTheme.borderColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: pwError != null
                    ? AppTheme.error
                    : AppTheme.primaryLight,
                width: 1.5,
              ),
            ),
            prefixIcon: const Icon(Icons.shield_rounded,
                color: AppTheme.textSecondary, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              onPressed: onToggleObscure,
            ),
          ),
        ),

        if (pwError != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.error_outline,
                color: AppTheme.error, size: 13),
            const SizedBox(width: 4),
            Text(pwError!,
                style: const TextStyle(
                    color: AppTheme.error, fontSize: 11)),
          ]),
        ],

        const SizedBox(height: 6),
        const Text(
          'Viewers must type this password to watch live score',
          style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 11),
        ),

        const SizedBox(height: 20),

        // ── Enable button ─────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onEnable,
              icon: const Icon(Icons.cell_tower_rounded,
                  color: Colors.white, size: 20),
              label: const Text(
                'Go Live',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Active state (match code + share) ────────────────────────────────────────

class _ActiveState extends StatelessWidget {
  final LiveScoringViewModel vm;
  const _ActiveState({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Match code card ───────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.bgDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryLight.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.tag_rounded,
                    color: AppTheme.textSecondary, size: 12),
                const SizedBox(width: 5),
                const Text(
                  'MATCH CODE',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Text(
                vm.matchCode.value,
                style: const TextStyle(
                  color: AppTheme.primaryLight,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 5,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 12),
              // Divider
              Container(height: 1, color: AppTheme.borderColor),
              const SizedBox(height: 12),
              // Password row
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppTheme.warning.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.lock_rounded,
                        color: AppTheme.warning, size: 12),
                    const SizedBox(width: 5),
                    Text(
                      vm.matchPassword.value,
                      style: const TextStyle(
                        color: AppTheme.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                const Text('share this with viewers',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ]),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Share buttons ─────────────────────────────────────────────────
        // WhatsApp primary
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF075E54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await vm.shareLink();
            },
            icon: const Icon(Icons.share_rounded,
                color: Colors.white, size: 22),
            label: const Text(
              'Share on WhatsApp',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Other share
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.borderColor),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await vm.shareLink();
            },
            icon: const Icon(Icons.share_rounded,
                color: AppTheme.textSecondary, size: 18),
            label: const Text(
              'Share via other apps',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Info strip ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.info.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppTheme.info.withOpacity(0.15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline_rounded,
                  color: AppTheme.info, size: 15),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'App installed → opens directly\n'
                      'No app → redirected to Play Store / App Store',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── How It Works row ─────────────────────────────────────────────────────────

class _HowItWorksRow extends StatelessWidget {
  final String step;
  final IconData icon;
  final String text;
  const _HowItWorksRow(
      {required this.step, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: AppTheme.primaryLight.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(
              color: AppTheme.primaryLight.withOpacity(0.3)),
        ),
        child: Center(
          child: Text(step,
              style: const TextStyle(
                color: AppTheme.primaryLight,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              )),
        ),
      ),
      const SizedBox(width: 12),
      Icon(icon, color: AppTheme.textSecondary, size: 16),
      const SizedBox(width: 8),
      Text(text,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
          )),
    ]);
  }
}


class _Innings1CompleteSheet extends StatelessWidget {
  final LiveScoringViewModel vm;
  final VoidCallback onShowOnlineMode;

  const _Innings1CompleteSheet({
    required this.vm,
    required this.onShowOnlineMode,
  });

  @override
  Widget build(BuildContext context) {
    // Innings 2 has started — innings 1 score is saved on teamA or teamB.
    final m = vm.match.value;
    final battingTeam = vm.currentInnings.value?.battingTeam ?? '';

    // Pull the innings 1 batting team's score.
    final inn1BattingTeam = m?.teamAName == battingTeam
        ? m?.teamBName ?? ''  // innings 2 batting = team B, so innings 1 = team A
        : m?.teamAName ?? '';

    final inn1Score = (m?.teamAName == inn1BattingTeam)
        ? m?.teamAScore ?? 0
        : m?.teamBScore ?? 0;
    final inn1Wickets = (m?.teamAName == inn1BattingTeam)
        ? m?.teamAWickets ?? 0
        : m?.teamBWickets ?? 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Trophy icon
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_rounded,
                  color: AppTheme.primary, size: 34),
            ),
            const SizedBox(height: 12),

            const Text('Innings 1 Complete! 🏏',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),

            // Score pill
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Text(
                '$inn1Score / $inn1Wickets',
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Now $battingTeam will bat — Target: ${inn1Score + 1}',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),

            const SizedBox(height: 20),

            // Info box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.info.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline_rounded,
                      color: AppTheme.info, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Share match code + password with Team B.\n'
                          'They can join using "Join Match" button in the app!',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.6),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Online mode check
            Obx(() => vm.isOnlineMode.value
                ? Column(
              children: [
                // Code + password display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Match Code',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12)),
                          Obx(() => Text(vm.matchCode.value,
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                              ))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Password',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12)),
                          Obx(() => Text(vm.matchPassword.value,
                              style: const TextStyle(
                                color: AppTheme.warning,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // WhatsApp share
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await vm.shareLink();
                    },
                    icon: const Icon(Icons.share_rounded,
                        color: Colors.white),
                    label: const Text('Share via WhatsApp',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ),
                ),
              ],
            )
                : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.warning.withOpacity(0.3)),
                  ),
                  child: Row(children: const [
                    Icon(Icons.warning_amber_rounded,
                        color: AppTheme.warning, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Enable Live Mode to share.\n'
                            'Tap the Wifi icon in the bottom bar.',
                        style: TextStyle(
                            color: AppTheme.warning,
                            fontSize: 12,
                            height: 1.5),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Future.delayed(
                          const Duration(milliseconds: 200),
                          onShowOnlineMode);
                    },
                    icon: const Icon(Icons.cell_tower_rounded,
                        color: Colors.white),
                    label: const Text('Enable Live Mode',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ),
                ),
              ],
            )),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.borderColor),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Skip — Start Innings 2',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NEW LIVE-SCORING UI — matches design spec
// ═══════════════════════════════════════════════════════════════════════════════

const Color _kDeepGreen = Color(0xFF1B5E20);
const Color _kFieldGreen = Color(0xFF2E7D32);
const Color _kLightGreen = Color(0xFFE8F5E9);
const Color _kSoftBorder = Color(0xFFD7E3DA);
const Color _kMutedText  = Color(0xFF5B6B60);

class _MatchTitleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final LiveScoringViewModel vm;
  final VoidCallback onBack;
  final VoidCallback onStats;
  final VoidCallback onOnline;

  const _MatchTitleAppBar({
    required this.vm,
    required this.onBack,
    required this.onStats,
    required this.onOnline,
  });

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final m = vm.match.value;
      final title = m != null ? '${m.teamAName} v/s ${m.teamBName}' : 'Match';
      return AppBar(
        backgroundColor: _kDeepGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 52,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: onBack,
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
            onPressed: onStats,
            tooltip: 'Stats',
          ),
          GestureDetector(
            onTap: onOnline,
            child: Container(
              margin: const EdgeInsets.only(right: 10, left: 2),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.18),
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(
                vm.isOnlineMode.value
                    ? Icons.wifi_rounded
                    : Icons.person_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _ScoreCard extends StatelessWidget {
  final LiveScoringViewModel vm;
  const _ScoreCard({required this.vm});

  String _ordinalInning(int n) => n == 1 ? '1st inning' : '2nd inning';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kSoftBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Obx(() {
                final inn = vm.currentInnings.value;
                final team = inn?.battingTeam ?? '';
                return Text(
                  '$team  ${_ordinalInning(vm.inningsNumber)}',
                  style: const TextStyle(
                    color: _kDeepGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }),
              const Text(
                'CRR',
                style: TextStyle(
                  color: _kMutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Obx(() => Text(
                    '${vm.scoreDisplay} (${vm.oversDisplay})',
                    style: const TextStyle(
                      color: Color(0xFF101A12),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  )),
              const Spacer(),
              Obx(() => Text(
                    AppUtils.formatDouble(vm.runRate),
                    style: const TextStyle(
                      color: _kFieldGreen,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  )),
            ],
          ),
          Obx(() => vm.inningsNumber == 2
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Need ${vm.runsNeeded}',
                        style: const TextStyle(
                          color: AppTheme.accentDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'RRR ${AppUtils.formatDouble(vm.requiredRunRate)}',
                        style: const TextStyle(
                          color: AppTheme.accentDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _LiveBattersTable extends StatelessWidget {
  final LiveScoringViewModel vm;
  final VoidCallback onTapStriker;
  final VoidCallback onTapNonStriker;

  const _LiveBattersTable({
    required this.vm,
    required this.onTapStriker,
    required this.onTapNonStriker,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kSoftBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: _kLightGreen,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 4,
                  child: Text('Batsman',
                      style: TextStyle(
                          color: _kDeepGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                _ColumnLabel('R'),
                _ColumnLabel('B'),
                _ColumnLabel('4s'),
                _ColumnLabel('6s'),
                _ColumnLabel('SR'),
              ],
            ),
          ),
          Obx(() => _BatterRow(
                player: vm.striker.value,
                isStriker: true,
                onTap: onTapStriker,
              )),
          const Divider(height: 1, color: _kSoftBorder),
          Obx(() => _BatterRow(
                player: vm.nonStriker.value,
                isStriker: false,
                onTap: onTapNonStriker,
              )),
        ],
      ),
    );
  }
}

class _BatterRow extends StatelessWidget {
  final PlayerModel? player;
  final bool isStriker;
  final VoidCallback onTap;
  const _BatterRow({
    required this.player,
    required this.isStriker,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = player;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  if (isStriker)
                    const Text('* ',
                        style: TextStyle(
                          color: _kFieldGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        )),
                  Expanded(
                    child: Text(
                      p?.name ??
                          (isStriker
                              ? 'Tap to pick striker'
                              : 'Tap to pick non-striker'),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p != null ? _kFieldGreen : _kMutedText,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _NumCell(p?.runsScored.toString() ?? '-'),
            _NumCell(p?.ballsFaced.toString() ?? '-'),
            _NumCell(p?.fours.toString() ?? '-'),
            _NumCell(p?.sixes.toString() ?? '-'),
            _NumCell(
                p == null ? '-' : AppUtils.formatDouble(p.strikeRate)),
          ],
        ),
      ),
    );
  }
}

class _ColumnLabel extends StatelessWidget {
  final String text;
  const _ColumnLabel(this.text);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kDeepGreen,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _NumCell extends StatelessWidget {
  final String text;
  const _NumCell(this.text);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF101A12),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _LiveBowlerRow extends StatelessWidget {
  final LiveScoringViewModel vm;
  final VoidCallback onTapBowler;
  const _LiveBowlerRow({required this.vm, required this.onTapBowler});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kSoftBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: _kLightGreen,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 4,
                  child: Text('Bowler',
                      style: TextStyle(
                          color: _kDeepGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                _ColumnLabel('O'),
                _ColumnLabel('M'),
                _ColumnLabel('R'),
                _ColumnLabel('W'),
                _ColumnLabel('ER'),
              ],
            ),
          ),
          InkWell(
            onTap: onTapBowler,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Obx(() {
                final b = vm.currentBowler.value;
                return Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        b?.name ?? 'Tap to pick bowler',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: b != null ? _kFieldGreen : _kMutedText,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    _NumCell(b?.oversBoled ?? '-'),
                    _NumCell('0'),
                    _NumCell(b?.runsConceded.toString() ?? '-'),
                    _NumCell(b?.wicketsTaken.toString() ?? '-'),
                    _NumCell(
                        b == null ? '-' : AppUtils.formatDouble(b.economy)),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThisOverRow extends StatelessWidget {
  final LiveScoringViewModel vm;
  const _ThisOverRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Obx(() {
        final balls = vm.currentOverBalls;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'This over:',
              style: TextStyle(
                color: _kDeepGreen,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      balls.map((b) => _OverBallDot(ball: b)).toList(),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _OverBallDot extends StatelessWidget {
  final BallModel ball;
  const _OverBallDot({required this.ball});

  @override
  Widget build(BuildContext context) {
    String label;
    Color bg;
    Color fg;
    Color border = _kFieldGreen;
    bool filled = true;

    if (ball.isWicket) {
      label = 'W';
      bg = AppTheme.error;
      fg = Colors.white;
      border = AppTheme.error;
    } else if (ball.isWide) {
      label = 'Wd';
      bg = Colors.orangeAccent;
      fg = _kFieldGreen;
      filled = false;
    } else if (ball.isNoBall) {
      label = 'Nb';
      bg = Colors.white;
      fg = _kFieldGreen;
      filled = false;
    } else if (ball.isBye) {
      label = 'B${ball.runs}';
      bg = Colors.white;
      fg = _kFieldGreen;
      filled = false;
    } else if (ball.isLegBye) {
      label = 'Lb${ball.runs}';
      bg = Colors.white;
      fg = _kFieldGreen;
      filled = false;
    } else if (ball.runs == 4) {
      label = '4';
      bg = _kFieldGreen;
      fg = Colors.white;
    } else if (ball.runs == 6) {
      label = '6';
      bg = AppTheme.accentDark;
      fg = Colors.white;
      border = AppTheme.accentDark;
    } else {
      label = ball.runs.toString();
      bg = _kFieldGreen;
      fg = Colors.white;
    }

    return Container(
      margin: const EdgeInsets.only(right: 6),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: filled ? bg : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ExtrasAndActionsRow extends StatelessWidget {
  final LiveScoringViewModel vm;
  final VoidCallback onWicket;
  final VoidCallback onRetire;
  final VoidCallback onSwapBatsman;

  const _ExtrasAndActionsRow({
    required this.vm,
    required this.onWicket,
    required this.onRetire,
    required this.onSwapBatsman,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kSoftBorder),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.start,
            children: [
              Obx(() => _CheckChip(
                    label: 'Wide',
                    active: vm.isWide.value,
                    onTap: vm.toggleWide,
                  )),
              Obx(() => _CheckChip(
                    label: 'No Ball',
                    active: vm.isNoBall.value,
                    onTap: vm.toggleNoBall,
                  )),
              Obx(() => _CheckChip(
                    label: 'Byes',
                    active: vm.isBye.value,
                    onTap: vm.toggleBye,
                  )),
              Obx(() => _CheckChip(
                    label: 'Leg Byes',
                    active: vm.isLegBye.value,
                    onTap: vm.toggleLegBye,
                  )),
              _CheckChip(
                label: 'Wicket',
                active: false,
                onTap: onWicket,
                accent: AppTheme.error,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _GreenOutlineButton(
                  label: 'Retire',
                  icon: Icons.exit_to_app_rounded,
                  onTap: onRetire,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GreenOutlineButton(
                  label: 'Swap Batsman',
                  icon: Icons.swap_horiz_rounded,
                  onTap: onSwapBatsman,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? accent;
  const _CheckChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? _kFieldGreen;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(active ? 1.0 : 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GreenOutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GreenOutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kFieldGreen, width: 1.2),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _kFieldGreen, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _kFieldGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionAndRunGrid extends StatelessWidget {
  final LiveScoringViewModel vm;
  final VoidCallback onUndo;
  final VoidCallback onPartnerships;
  final VoidCallback onExtras;

  const _ActionAndRunGrid({
    required this.vm,
    required this.onUndo,
    required this.onPartnerships,
    required this.onExtras,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Column(
            children: [
              _GreenOutlineButton(
                  label: 'Undo', icon: Icons.undo_rounded, onTap: onUndo),
              const SizedBox(height: 8),
              _GreenOutlineButton(
                  label: 'Partnerships',
                  icon: Icons.people_alt_rounded,
                  onTap: onPartnerships),
              const SizedBox(height: 8),
              _GreenOutlineButton(
                  label: 'Extras',
                  icon: Icons.add_circle_outline_rounded,
                  onTap: onExtras),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RunGrid(vm: vm),
        ),
      ],
    );
  }
}

class _RunGrid extends StatelessWidget {
  final LiveScoringViewModel vm;
  const _RunGrid({required this.vm});

  @override
  Widget build(BuildContext context) {
    const runs = [0, 1, 2, 3, 4, 5, 6];
    return LayoutBuilder(builder: (context, constraints) {
      final tileWidth = (constraints.maxWidth - 8) / 5;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: runs.map((r) {
          return SizedBox(
            width: tileWidth,
            height: 52,
            child: _RunTile(
              value: r,
              onTap: () => vm.scoreBall(runs: r),
            ),
          );
        }).toList(),
      );
    });
  }
}

class _RunTile extends StatelessWidget {
  final int value;
  final VoidCallback onTap;
  const _RunTile({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;
    String? subtitle;

    if (value == 4) {
      bg = const Color(0xFFE8F4FD);
      fg = const Color(0xFF1565C0);
      border = const Color(0xFF1E88E5);
      subtitle = 'FOUR';
    } else if (value == 6) {
      bg = const Color(0xFFFFFDE7);
      fg = const Color(0xFFF57F17);
      border = const Color(0xFFF9A825);
      subtitle = 'SIX';
    } else if (value == 0) {
      bg = Colors.white;
      fg = _kMutedText;
      border = _kSoftBorder;
    } else {
      bg = _kLightGreen;
      fg = _kDeepGreen;
      border = _kFieldGreen.withOpacity(0.4);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.2),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: fg,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(
                  color: fg,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
          ],
        ),
      ),
    );
  }
}