// ─────────────────────────────────────────────────────────────────────────────
// lib/views/tournament/tournament_toss_view.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tournament_models.dart';
import '../../viewmodels/tournament_toss_viewmodel.dart';

class TournamentTossView extends StatefulWidget {
  const TournamentTossView({super.key});

  @override
  State<TournamentTossView> createState() => _TournamentTossViewState();
}

class _TournamentTossViewState extends State<TournamentTossView>
    with SingleTickerProviderStateMixin {
  late final TournamentTossViewModel vm;
  late AnimationController _coinCtrl;

  @override
  void initState() {
    super.initState();
    vm = Get.put(TournamentTossViewModel());
    _coinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  @override
  void dispose() {
    _coinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Match Toss'),
        ),
        body: Obx(() {
          if (vm.isLoading.value) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (vm.match.value == null) {
            return const Center(
              child: Text('Match not found',
                  style: TextStyle(color: AppTheme.textSecondary)),
            );
          }

          return Container(
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
                children: [
                  _MatchHeader(vm: vm),
                  const SizedBox(height: 20),

                  // Stage 1: Coin toss
                  if (!vm.tossComplete.value)
                    _TossStage(vm: vm, coinCtrl: _coinCtrl),

                  // Stage 2: Bat/Bowl choice
                  if (vm.tossComplete.value && vm.battingFirst.value == null)
                    _BatBowlStage(vm: vm),

                  // Stage 3: Umpire + Players (review before start)
                  if (vm.tossComplete.value && vm.battingFirst.value != null)
                    _ReviewStage(vm: vm),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Match header ─────────────────────────────────────────────────────────────
class _MatchHeader extends StatelessWidget {
  final TournamentTossViewModel vm;
  const _MatchHeader({required this.vm});

  @override
  Widget build(BuildContext context) {
    final a = vm.teamA.value;
    final b = vm.teamB.value;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.greenGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Text('MATCH',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              )),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TeamBadge(team: a),
              const Text('VS',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  )),
              _TeamBadge(team: b),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${vm.match.value?.totalOvers ?? 0} overs',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TeamBadge extends StatelessWidget {
  final TournamentTeamModel? team;
  const _TeamBadge({required this.team});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: team?.logoUrl != null
                ? Image.network(team!.logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initial())
                : _initial(),
          ),
          const SizedBox(height: 6),
          Text(
            team?.name ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _initial() => Center(
    child: Text(
      (team?.name.isNotEmpty ?? false)
          ? team!.name[0].toUpperCase()
          : '?',
      style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAGE 1: COIN TOSS
// ═══════════════════════════════════════════════════════════════════════════════

class _TossStage extends StatelessWidget {
  final TournamentTossViewModel vm;
  final AnimationController coinCtrl;
  const _TossStage({required this.vm, required this.coinCtrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 28),
        const Text('Toss Time! 🪙',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Tap the coin to flip',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 36),

        GestureDetector(
          onTap: vm.isTossing.value
              ? null
              : () {
            coinCtrl.forward(from: 0);
            vm.runToss();
          },
          child: AnimatedBuilder(
            animation: coinCtrl,
            builder: (_, __) {
              // Multiple spins
              final angle = coinCtrl.value * 8 * 3.14159;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(angle),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🪙',
                        style: TextStyle(fontSize: 72)),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 36),

        if (vm.isTossing.value)
          const Text('Spinning...',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600))
        else
          SizedBox(
            width: 200,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                coinCtrl.forward(from: 0);
                vm.runToss();
              },
              child: const Text('Flip Coin',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAGE 2: BAT OR BOWL CHOICE
// ═══════════════════════════════════════════════════════════════════════════════

class _BatBowlStage extends StatelessWidget {
  final TournamentTossViewModel vm;
  const _BatBowlStage({required this.vm});

  @override
  Widget build(BuildContext context) {
    final winner = vm.tossWinner.value!;
    return Column(
      children: [
        const SizedBox(height: 28),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: AppTheme.goldGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text('🏆 TOSS WINNER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  )),
              const SizedBox(height: 8),
              Text(winner.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text('What would you like to do?',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _ChoiceCard(
                emoji: '🏏',
                label: 'Bat First',
                subtitle: 'Start batting',
                color: AppTheme.primary,
                onTap: () => vm.chooseBatOrBowl(batFirst: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ChoiceCard(
                emoji: '🎳',
                label: 'Bowl First',
                subtitle: 'Start bowling',
                color: AppTheme.warning,
                onTap: () => vm.chooseBatOrBowl(batFirst: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'If you choose wrongly, you can still edit team details before match starts.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 11, height: 1.5),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    color: color.withOpacity(0.7), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAGE 3: REVIEW (umpire + players) BEFORE START
// ═══════════════════════════════════════════════════════════════════════════════

class _ReviewStage extends StatelessWidget {
  final TournamentTossViewModel vm;
  const _ReviewStage({required this.vm});

  @override
  Widget build(BuildContext context) {
    final winner = vm.tossWinner.value!;
    final bf = vm.battingFirst.value!;
    final batChose = winner.id == bf.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        // Toss summary strip
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.success.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: AppTheme.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${winner.name} won the toss & chose to ${batChose ? 'bat' : 'bowl'} first',
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // Umpire section
        _UmpireSection(vm: vm),

        const SizedBox(height: 20),

        // Players — editable
        _PlayersSection(vm: vm),

        const SizedBox(height: 20),

        // Start match button
        Obx(() => SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: vm.isStarting.value ? null : vm.startMatch,
            icon: vm.isStarting.value
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sports_cricket_rounded),
            label: Text(
              vm.isStarting.value ? 'Starting...' : 'Start Match',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        )),
      ],
    );
  }
}

// ── Umpire section ───────────────────────────────────────────────────────────
class _UmpireSection extends StatelessWidget {
  final TournamentTossViewModel vm;
  const _UmpireSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.sports, color: AppTheme.warning, size: 16),
            const SizedBox(width: 6),
            const Text('UMPIRE TEAM',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
            const Spacer(),
            Obx(() => vm.canChangeUmpire.value
                ? TextButton.icon(
              onPressed: () => _pickUmpire(context),
              icon: const Icon(Icons.edit_rounded, size: 14),
              label: const Text('Change',
                  style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryLight),
            )
                : const SizedBox.shrink()),
          ]),
          const SizedBox(height: 10),
          Obx(() {
            final u = vm.umpireTeam.value;
            if (u == null) {
              return GestureDetector(
                onTap: () => _pickUmpire(context),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.warning.withOpacity(0.3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppTheme.warning, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Tap to assign umpire team',
                          style: TextStyle(
                              color: AppTheme.warning, fontSize: 12)),
                    ),
                  ]),
                ),
              );
            }
            return Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.2),
                    shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: u.logoUrl != null
                    ? Image.network(u.logoUrl!, fit: BoxFit.cover)
                    : Center(
                  child: Text(u.name[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.name,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text(
                      vm.tournament.value?.umpireMode == UmpireMode.auto
                          ? 'Auto-assigned'
                          : 'Manually assigned',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ]);
          }),
        ],
      ),
    );
  }

  void _pickUmpire(BuildContext context) {
    final candidates = vm.allTeams.where((t) {
      if (t.id == vm.teamA.value?.id) return false;   // playing team A
      if (t.id == vm.teamB.value?.id) return false;   // playing team B
      if (t.eliminated) return false;                  // knocked out
      return true;
    }).toList();

    if (candidates.isEmpty) {
      Get.snackbar('No teams', 'No non-playing teams to assign as umpire',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Pick umpire team',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ),
            const Divider(),
            ...candidates.map((t) => ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.warning.withOpacity(0.2),
                backgroundImage: t.logoUrl != null
                    ? NetworkImage(t.logoUrl!)
                    : null,
                child: t.logoUrl == null
                    ? Text(t.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.warning))
                    : null,
              ),
              title: Text(t.name,
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                vm.setUmpire(t);
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }
}

// ── Players section (editable) ───────────────────────────────────────────────
class _PlayersSection extends StatelessWidget {
  final TournamentTossViewModel vm;
  const _PlayersSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.info.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: const [
            Icon(Icons.info_outline_rounded,
                color: AppTheme.info, size: 14),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Review players — you can edit, add, or remove before starting',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        _TeamRoster(
          teamName: vm.teamA.value?.name ?? '',
          players: vm.teamAPlayers,
          onEdit: (i, name) => vm.updateTeamAPlayer(i, name),
          onRemove: vm.removeTeamAPlayer,
          onAdd: vm.addTeamAPlayer,
        ),
        const SizedBox(height: 14),
        _TeamRoster(
          teamName: vm.teamB.value?.name ?? '',
          players: vm.teamBPlayers,
          onEdit: (i, name) => vm.updateTeamBPlayer(i, name),
          onRemove: vm.removeTeamBPlayer,
          onAdd: vm.addTeamBPlayer,
        ),
      ],
    );
  }
}

class _TeamRoster extends StatefulWidget {
  final String teamName;
  final RxList<String> players;
  final void Function(int, String) onEdit;
  final void Function(int) onRemove;
  final void Function(String) onAdd;

  const _TeamRoster({
    required this.teamName,
    required this.players,
    required this.onEdit,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  State<_TeamRoster> createState() => _TeamRosterState();
}

class _TeamRosterState extends State<_TeamRoster> {
  final TextEditingController _addCtrl = TextEditingController();

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.sports_cricket,
                color: AppTheme.primaryLight, size: 14),
            const SizedBox(width: 6),
            Text(widget.teamName,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Obx(() => Text('${widget.players.length} players',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11))),
          ]),
          const Divider(height: 14),
          Obx(() => widget.players.isEmpty
              ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('No players yet',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
          )
              : Column(
            children: widget.players
                .asMap()
                .entries
                .map((e) => _PlayerRow(
              index: e.key,
              name: e.value,
              onEdit: (n) => widget.onEdit(e.key, n),
              onRemove: () => widget.onRemove(e.key),
            ))
                .toList(),
          )),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _addCtrl,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Add player',
                  isDense: true,
                  filled: true,
                  fillColor: AppTheme.bgSurface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                    const BorderSide(color: AppTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                    const BorderSide(color: AppTheme.borderColor),
                  ),
                ),
                onSubmitted: (v) {
                  widget.onAdd(v);
                  _addCtrl.clear();
                },
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                widget.onAdd(_addCtrl.text);
                _addCtrl.clear();
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppTheme.greenGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add,
                    color: Colors.white, size: 18),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final int index;
  final String name;
  final ValueChanged<String> onEdit;
  final VoidCallback onRemove;

  const _PlayerRow({
    required this.index,
    required this.name,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              shape: BoxShape.circle),
          child: Center(
            child: Text('${index + 1}',
                style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 13)),
        ),
        GestureDetector(
          onTap: () => _showEditDialog(context),
          child: const Icon(Icons.edit_rounded,
              color: AppTheme.textSecondary, size: 16),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close_rounded,
              color: AppTheme.error, size: 16),
        ),
      ]),
    );
  }

  void _showEditDialog(BuildContext context) {
    final ctrl = TextEditingController(text: name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: const Text('Edit player',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.bgSurface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white),
            onPressed: () {
              onEdit(ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}