import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../repositories/match_repository.dart';
import '../../services/session_service.dart';

/// After Team B's scorer joins via match code + password, we pull the full
/// roster (both teams + innings-1 stats) from Firebase and land on this screen.
/// They can tweak names, remove stale entries, and confirm before scoring
/// innings 2 kicks off.
class ConfirmRosterView extends StatefulWidget {
  const ConfirmRosterView({super.key});

  @override
  State<ConfirmRosterView> createState() => _ConfirmRosterViewState();
}

class _ConfirmRosterViewState extends State<ConfirmRosterView> {
  int _tab = 0;
  final _newPlayerCtrl = TextEditingController();
  late final int matchId;
  final _repo = MatchRepository();

  MatchModel? match;
  final RxList<PlayerModel> teamAPlayers = <PlayerModel>[].obs;
  final RxList<PlayerModel> teamBPlayers = <PlayerModel>[].obs;
  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    matchId = Get.arguments as int;
    _load();
  }

  Future<void> _load() async {
    match = await _repo.getMatch(matchId);
    final allPlayers = await _repo.getPlayersByMatch(matchId);
    teamAPlayers.assignAll(
        allPlayers.where((p) => p.teamName == match!.teamAName).toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)));
    teamBPlayers.assignAll(
        allPlayers.where((p) => p.teamName == match!.teamBName).toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)));
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _newPlayerCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app_rounded,
                color: AppTheme.warning, size: 22),
            SizedBox(width: 10),
            Text('Leave Setup?',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
          'You can resume this match from Home — any roster edits will be saved.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.home_rounded,
                color: Colors.white, size: 18),
            label: const Text('Go Home',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (leave == true) Get.offAllNamed(AppRoutes.home);
  }

  void _showEditDialog(PlayerModel player, RxList<PlayerModel> list) {
    final ctrl = TextEditingController(text: player.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppTheme.borderColor)),
        title: const Text('Edit Player Name',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Player name',
            filled: true,
            fillColor: AppTheme.bgSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              final idx = list.indexOf(player);
              if (idx == -1) return;
              final replaced = PlayerModel(
                id: player.id,
                matchId: player.matchId,
                teamName: player.teamName,
                name: newName,
                orderIndex: player.orderIndex,
                runsScored: player.runsScored,
                ballsFaced: player.ballsFaced,
                fours: player.fours,
                sixes: player.sixes,
                isOut: player.isOut,
                wicketType: player.wicketType,
                dismissedBy: player.dismissedBy,
                bowlerName: player.bowlerName,
                didBat: player.didBat,
                ballsBowled: player.ballsBowled,
                runsConceded: player.runsConceded,
                wicketsTaken: player.wicketsTaken,
                wides: player.wides,
                noBalls: player.noBalls,
                isOnStrike: player.isOnStrike,
                isBatting: player.isBatting,
                isBowling: player.isBowling,
              );
              list[idx] = replaced;
              await _repo.updatePlayer(replaced);
              if (mounted) Navigator.of(ctx).pop();
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPlayer(RxList<PlayerModel> list, String teamName) async {
    final name = _newPlayerCtrl.text.trim();
    if (name.isEmpty) return;
    if (list.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
      Get.snackbar('Duplicate', '$name is already in the list',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final p = PlayerModel(
      matchId: matchId,
      teamName: teamName,
      name: name,
      orderIndex: list.length,
    );
    final id = await _repo.createPlayer(p);
    final saved = p.copyWith(id: id);
    list.add(saved);
    _newPlayerCtrl.clear();
  }

  Future<void> _removePlayer(PlayerModel p, RxList<PlayerModel> list) async {
    list.remove(p);
    if (p.id != null) await _repo.deletePlayer(p.id!);
  }

  Future<void> _confirmAndContinue() async {
    if (teamAPlayers.length < 2 || teamBPlayers.length < 2) {
      Get.snackbar('Need Players',
          'Each team needs at least 2 players to continue',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() => _saving = true);
    // Persist session then move to live scoring
    await SessionService().saveActiveMatch(
      matchId: matchId,
      teamA: match!.teamAName,
      teamB: match!.teamBName,
      totalOvers: match!.totalOvers,
    );
    Get.offAllNamed(AppRoutes.liveScoring, arguments: matchId);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave(context);
      },
      child: SafeArea(
      top: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Confirm Rosters'),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: AppTheme.textPrimary, size: 20),
            tooltip: 'Back to Home',
            onPressed: () => _confirmLeave(context),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.bgDark, AppTheme.bgCard],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              // Summary banner
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppTheme.info.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline_rounded,
                          color: AppTheme.info, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Review players on both sides, edit names if needed, '
                          'then tap Confirm to start Innings 2.',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tab selector
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    _TabButton(
                      label: match!.teamAName,
                      active: _tab == 0,
                      onTap: () => setState(() => _tab = 0),
                    ),
                    _TabButton(
                      label: match!.teamBName,
                      active: _tab == 1,
                      onTap: () => setState(() => _tab = 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: Obx(() {
                  // Explicit reads so Obx subscribes to both lists.
                  final aCount = teamAPlayers.length;
                  final bCount = teamBPlayers.length;
                  final list = _tab == 0 ? teamAPlayers : teamBPlayers;
                  final teamName =
                      _tab == 0 ? match!.teamAName : match!.teamBName;
                  return _RosterList(
                    key: ValueKey('roster_${_tab}_${aCount}_$bCount'),
                    list: list.toList(),
                    teamName: teamName,
                    newPlayerCtrl: _newPlayerCtrl,
                    onAdd: () => _addPlayer(list, teamName),
                    onEdit: (p) => _showEditDialog(p, list),
                    onRemove: (p) => _removePlayer(p, list),
                  );
                }),
              ),

              // Footer: confirm button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _saving ? null : _confirmAndContinue,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: const Text('Confirm & Start Innings 2',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            gradient: active ? AppTheme.greenGradient : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RosterList extends StatelessWidget {
  final List<PlayerModel> list;
  final String teamName;
  final TextEditingController newPlayerCtrl;
  final VoidCallback onAdd;
  final void Function(PlayerModel) onEdit;
  final void Function(PlayerModel) onRemove;

  const _RosterList({
    super.key,
    required this.list,
    required this.teamName,
    required this.newPlayerCtrl,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: newPlayerCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  onSubmitted: (_) => onAdd(),
                  decoration: const InputDecoration(
                    hintText: 'Add player name',
                    prefixIcon: Icon(Icons.person_add_outlined,
                        color: AppTheme.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppTheme.greenGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${list.length} players',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              const Spacer(),
              const Text('Tap pencil to edit',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.group_add_outlined,
                            color: AppTheme.textSecondary, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'No players yet for $teamName',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, i) {
                      final p = list[i];
                      final battedLine = (p.ballsFaced > 0 || p.runsScored > 0)
                          ? 'Batted: ${p.runsScored}(${p.ballsFaced})'
                          : null;
                      final bowledLine = p.ballsBowled > 0
                          ? '${p.oversBoled} ov · ${p.runsConceded}/${p.wicketsTaken}'
                          : null;
                      final subtitle =
                          [battedLine, bowledLine].whereType<String>().join('  ·  ');

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.bgSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                gradient: AppTheme.greenGradient,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Center(
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                  if (subtitle.isNotEmpty)
                                    Text(subtitle,
                                        style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11)),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => onEdit(p),
                              child: const Icon(Icons.edit_outlined,
                                  color: AppTheme.textSecondary, size: 18),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => onRemove(p),
                              child: const Icon(Icons.close,
                                  color: AppTheme.error, size: 18),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
