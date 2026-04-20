import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import '../../services/saved_team_service.dart';
import '../../viewmodels/match_setup_viewmodel.dart';
import '../../widgets/app_widgets.dart';

class CreateMatchView extends StatelessWidget {
  const CreateMatchView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = Get.put(MatchSetupViewModel());

    return SafeArea(
      top: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New Match'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () {
              if (vm.currentStep.value > 0) {
                vm.previousStep();
              } else {
                Get.back();
              }
            },
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
              // Step indicator
              Obx(() => _StepIndicator(currentStep: vm.currentStep.value)),

              // Content
              Expanded(
                child: Obx(() {
                  switch (vm.currentStep.value) {
                    case 0:
                      return _Step1MatchInfo(vm: vm);
                    case 1:
                      return _Step2Players(vm: vm);
                    case 2:
                      return _Step3Toss(vm: vm);
                    default:
                      return const SizedBox();
                  }
                }),
              ),

              // Bottom buttons
              Obx(() => Padding(
                padding: const EdgeInsets.all(20),
                child: vm.isLoading.value
                    ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primary))
                    : GradientButton(
                  label: vm.currentStep.value == 2
                      ? '🏏 Start Match'
                      : 'Next →',
                  onTap: vm.nextStep,
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step Indicator ────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final steps = ['Match Info', 'Players', 'Toss'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: steps.asMap().entries.map((e) {
          final isActive = e.key == currentStep;
          final isDone = e.key < currentStep;
          return Expanded(
            child: Row(
              children: [
                if (e.key > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isDone ? AppTheme.primary : AppTheme.borderColor,
                    ),
                  ),
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: isActive || isDone
                            ? AppTheme.greenGradient
                            : null,
                        color: isActive || isDone ? null : AppTheme.bgSurface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive || isDone
                              ? AppTheme.primary
                              : AppTheme.borderColor,
                        ),
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : Text(
                          '${e.key + 1}',
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.value,
                      style: TextStyle(
                        color: isActive
                            ? AppTheme.primaryLight
                            : AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                if (e.key < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: e.key < currentStep
                          ? AppTheme.primary
                          : AppTheme.borderColor,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Step 1: Match Info ────────────────────────────────────────────────────────
class _Step1MatchInfo extends StatefulWidget {
  final MatchSetupViewModel vm;
  const _Step1MatchInfo({required this.vm});
  @override
  State<_Step1MatchInfo> createState() => _Step1MatchInfoState();
}

class _Step1MatchInfoState extends State<_Step1MatchInfo> {
  MatchSetupViewModel get vm => widget.vm;

  // Rebuild suggestions when user types
  String _teamAQuery = '';
  String _teamBQuery = '';

  @override
  void initState() {
    super.initState();
    vm.teamAController.addListener(
            () => setState(() => _teamAQuery = vm.teamAController.text));
    vm.teamBController.addListener(
            () => setState(() => _teamBQuery = vm.teamBController.text));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Match Details',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Enter team names and select the number of overs',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 28),

          _label('Team A Name'),
          const SizedBox(height: 8),
          TextField(
            controller: vm.teamAController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'e.g. Mumbai Indians',
              prefixIcon: Icon(Icons.group, color: AppTheme.primaryLight),
            ),
          ),
          _SavedTeamSuggestions(
            vm: vm,
            query: _teamAQuery,
            isTeamA: true,
          ),

          const SizedBox(height: 20),

          _label('Team B Name'),
          const SizedBox(height: 8),
          TextField(
            controller: vm.teamBController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'e.g. Chennai Super Kings',
              prefixIcon: Icon(Icons.group, color: AppTheme.accent),
            ),
          ),
          _SavedTeamSuggestions(
            vm: vm,
            query: _teamBQuery,
            isTeamA: false,
          ),

          const SizedBox(height: 24),

          _label('Number of Overs'),
          const SizedBox(height: 12),

          // ── Preset over chips ──────────────────────────────────────────
          Obx(() => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Preset chips
              ...vm.overOptions.map((ov) {
                final isSelected =
                    vm.selectedOvers.value == ov && !vm.isCustomOvers.value;
                return GestureDetector(
                  onTap: () {
                    vm.isCustomOvers.value = false;
                    vm.selectedOvers.value = ov;
                    vm.customOversController.clear();
                    FocusScope.of(context).unfocus();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 60,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppTheme.greenGradient : null,
                      color: isSelected ? null : AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.borderColor,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$ov',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Custom chip
              GestureDetector(
                onTap: () {
                  vm.isCustomOvers.value = true;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: vm.isCustomOvers.value
                        ? AppTheme.greenGradient
                        : null,
                    color: vm.isCustomOvers.value
                        ? null
                        : AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: vm.isCustomOvers.value
                          ? AppTheme.primary
                          : AppTheme.borderColor,
                      width: vm.isCustomOvers.value ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: vm.isCustomOvers.value
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Custom',
                        style: TextStyle(
                          color: vm.isCustomOvers.value
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )),

          // ── Custom overs input ─────────────────────────────────────────
          Obx(() => vm.isCustomOvers.value
              ? Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: vm.customOversController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Enter overs  (e.g. 7, 12, 35…)',
                      prefixIcon: Icon(Icons.sports_cricket,
                          color: AppTheme.primaryLight, size: 20),
                      suffixText: 'overs',
                      suffixStyle: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    onChanged: (val) {
                      final n = int.tryParse(val);
                      if (n != null && n > 0 && n <= 90) {
                        vm.selectedOvers.value = n;
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // Confirm ✓ button
                GestureDetector(
                  onTap: () {
                    final n = int.tryParse(
                        vm.customOversController.text.trim());
                    if (n == null || n <= 0 || n > 90) {
                      Get.snackbar('Invalid Overs',
                          'Enter a number between 1 and 90',
                          snackPosition: SnackPosition.BOTTOM);
                      return;
                    }
                    vm.selectedOvers.value = n;
                    FocusScope.of(context).unfocus();
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppTheme.greenGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          )
              : const SizedBox.shrink()),

          // ── Selected overs summary ─────────────────────────────────────
          Obx(() => Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: AppTheme.success, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Selected: ${vm.selectedOvers.value} overs'
                      '  ·  ${vm.selectedOvers.value * 6} balls per innings',
                  style: const TextStyle(
                    color: AppTheme.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ── Step 2: Players ───────────────────────────────────────────────────────────
class _Step2Players extends StatelessWidget {
  final MatchSetupViewModel vm;
  const _Step2Players({required this.vm});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                gradient: AppTheme.greenGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: [
                Tab(text: vm.teamAController.text.isNotEmpty
                    ? vm.teamAController.text
                    : 'Team A'),
                Tab(text: vm.teamBController.text.isNotEmpty
                    ? vm.teamBController.text
                    : 'Team B'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _PlayerListTab(vm: vm, isTeamA: true),
                _PlayerListTab(vm: vm, isTeamA: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerListTab extends StatelessWidget {
  final MatchSetupViewModel vm;
  final bool isTeamA;
  const _PlayerListTab({required this.vm, required this.isTeamA});

  void _showEditDialog(BuildContext context, MatchSetupViewModel vm,
      bool isTeamA, int index, String currentName) {
    final ctrl = TextEditingController(text: currentName);
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
            enabledBorder: OutlineInputBorder(
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
            onPressed: () {
              vm.editPlayer(isTeamA, index, ctrl.text);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final players = isTeamA ? vm.teamAPlayers : vm.teamBPlayers;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Add player row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: vm.playerController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  onSubmitted: (_) => vm.addPlayer(isTeamA),
                  decoration: InputDecoration(
                    hintText: 'Player name',
                    prefixIcon: const Icon(Icons.person_add_outlined,
                        color: AppTheme.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => vm.addPlayer(isTeamA),
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

          const SizedBox(height: 12),

          // Players count + Save Team button
          Obx(() => Row(
            children: [
              Text(
                '${players.length} players added',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
              const Spacer(),
              Text(
                'Min 2, Max 20',
                style: TextStyle(
                  color: players.length >= 2
                      ? AppTheme.success
                      : AppTheme.warning,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 10),
              // Save team button
              GestureDetector(
                onTap: () => vm.saveCurrentTeam(isTeamA: isTeamA),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_add_outlined,
                          color: AppTheme.primaryLight, size: 13),
                      SizedBox(width: 4),
                      Text(
                        'Save Team',
                        style: TextStyle(
                          color: AppTheme.primaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )),

          const SizedBox(height: 8),

          Expanded(
            child: Obx(() => players.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group_add_outlined,
                      color: AppTheme.textSecondary, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Add players for ${isTeamA ? vm.teamAController.text : vm.teamBController.text}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : ListView.separated(
              itemCount: players.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        gradient: AppTheme.greenGradient,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Center(
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(players[i],
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w500)),
                    ),
                    // ── Edit button ──────────────────────────────
                    GestureDetector(
                      onTap: () => _showEditDialog(ctx, vm, isTeamA, i, players[i]),
                      child: const Icon(Icons.edit_outlined,
                          color: AppTheme.textSecondary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => vm.removePlayer(isTeamA, i),
                      child: const Icon(Icons.close,
                          color: AppTheme.error, size: 18),
                    ),
                  ],
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }
}

// ── Saved Team Suggestions ────────────────────────────────────────────────────
class _SavedTeamSuggestions extends StatelessWidget {
  final MatchSetupViewModel vm;
  final String query;
  final bool isTeamA;
  const _SavedTeamSuggestions(
      {required this.vm, required this.query, required this.isTeamA});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (vm.savedTeams.isEmpty) return const SizedBox.shrink();

      final matches = vm.matchingSavedTeams(query);
      if (matches.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bookmark_outlined,
                    color: AppTheme.textSecondary, size: 12),
                const SizedBox(width: 4),
                const Text(
                  'Saved Teams',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: matches.map((team) {
                return GestureDetector(
                  onTap: () {
                    vm.loadSavedTeam(team, isTeamA: isTeamA);
                    FocusScope.of(context).unfocus();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isTeamA
                          ? AppTheme.primaryLight.withOpacity(0.1)
                          : AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isTeamA
                            ? AppTheme.primaryLight.withOpacity(0.4)
                            : AppTheme.accent.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.group,
                          size: 13,
                          color: isTeamA
                              ? AppTheme.primaryLight
                              : AppTheme.accent,
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              team.name,
                              style: TextStyle(
                                color: isTeamA
                                    ? AppTheme.primaryLight
                                    : AppTheme.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${team.players.length} players',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        // Delete button
                        GestureDetector(
                          onTap: () => _confirmDelete(context, team.name),
                          child: const Icon(Icons.close,
                              size: 14, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    });
  }

  void _confirmDelete(BuildContext context, String teamName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Saved Team',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: Text('Remove "$teamName" from saved teams?',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              vm.deleteSavedTeam(teamName);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Toss ──────────────────────────────────────────────────────────────
class _Step3Toss extends StatelessWidget {
  final MatchSetupViewModel vm;
  const _Step3Toss({required this.vm});

  @override
  Widget build(BuildContext context) {
    final teamA = vm.teamAController.text.trim();
    final teamB = vm.teamBController.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Toss & Batting Order',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Who won the toss and who bats first?',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 32),

          // Toss winner
          _label('Toss Won By'),
          const SizedBox(height: 12),
          Obx(() => Row(
            children: [teamA, teamB].map((team) {
              final isSelected = vm.tossWinner.value == team;
              return Expanded(
                child: GestureDetector(
                  onTap: () => vm.tossWinner.value = team,
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppTheme.goldGradient : null,
                      color: isSelected ? null : AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.accent
                            : AppTheme.borderColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isSelected ? '🪙' : '⚪',
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          team,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.black87
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          )),

          const SizedBox(height: 32),

          _label('Batting First'),
          const SizedBox(height: 12),
          Obx(() => Row(
            children: [teamA, teamB].map((team) {
              final isSelected = vm.battingFirst.value == team;
              return Expanded(
                child: GestureDetector(
                  onTap: () => vm.battingFirst.value = team,
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppTheme.greenGradient : null,
                      color: isSelected ? null : AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.borderColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isSelected ? '🏏' : '🏏',
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          team,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          )),
        ],
      ),
    );
  }
}

Widget _label(String text) => Text(
  text,
  style: const TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5),
);