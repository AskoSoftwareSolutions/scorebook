// ─────────────────────────────────────────────────────────────────────────────
// lib/views/tournament/tournament_teams_view.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';
import '../../models/tournament_models.dart';
import '../../services/saved_team_service.dart';
import '../../viewmodels/tournament_setup_viewmodel.dart';

class TournamentTeamsView extends StatelessWidget {
  const TournamentTeamsView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = Get.find<TournamentSetupViewModel>();

    return SafeArea(
      top: false,
      child: Scaffold(
        appBar: AppBar(
          title: Obx(() =>
              Text('Teams (${vm.teams.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700))),
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
              Expanded(
                child: Obx(() => vm.teams.isEmpty
                    ? _EmptyHint()
                    : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: vm.teams.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) =>
                      _TeamCard(team: vm.teams[i], onDelete: () {
                        vm.deleteTeam(vm.teams[i].id);
                      }),
                )),
              ),
              // Add team button
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
                        onPressed: () => _showAddTeamSheet(context, vm),
                        icon: const Icon(Icons.group_add_rounded,
                            color: AppTheme.primaryLight),
                        label: const Text('Add Team',
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
                          backgroundColor: vm.canProceedToSchedule
                              ? AppTheme.primary
                              : AppTheme.bgSurface,
                          foregroundColor: vm.canProceedToSchedule
                              ? Colors.white
                              : AppTheme.textSecondary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: vm.canProceedToSchedule
                            ? () =>
                            Get.toNamed(AppRoutes.tournamentSchedule)
                            : null,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(
                          vm.canProceedToSchedule
                              ? 'Continue to Schedule'
                              : 'Add at least 2 teams',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTeamSheet(BuildContext context, TournamentSetupViewModel vm) {
    // Reset any lingering state before showing sheet
    vm.teamNameController.clear();
    vm.pendingLogo.value = null;
    vm.pendingPlayers.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTeamSheet(vm: vm),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('👥', style: TextStyle(fontSize: 54)),
            SizedBox(height: 18),
            Text('Add teams to get started',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text(
              'Each team needs a name. Logo and player names are optional.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Team card ────────────────────────────────────────────────────────────────
class _TeamCard extends StatelessWidget {
  final TournamentTeamModel team;
  final VoidCallback onDelete;
  const _TeamCard({required this.team, required this.onDelete});

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
        // Logo or placeholder
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: team.logoUrl != null
              ? Image.network(team.logoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder())
              : _placeholder(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(team.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 2),
              Text(
                team.players.isEmpty
                    ? 'No players added'
                    : '${team.players.length} players',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onDelete,
          child: const Icon(Icons.delete_outline_rounded,
              color: AppTheme.error, size: 20),
        ),
      ]),
    );
  }

  Widget _placeholder() => Container(
    color: AppTheme.bgSurface,
    child: const Icon(Icons.groups_rounded,
        color: AppTheme.textSecondary, size: 24),
  );
}

// ── Add team bottom sheet ────────────────────────────────────────────────────
class _AddTeamSheet extends StatefulWidget {
  final TournamentSetupViewModel vm;
  const _AddTeamSheet({required this.vm});

  @override
  State<_AddTeamSheet> createState() => _AddTeamSheetState();
}

class _AddTeamSheetState extends State<_AddTeamSheet> {
  TournamentSetupViewModel get vm => widget.vm;

  @override
  void initState() {
    super.initState();
    vm.teamNameController.addListener(_onNameChanged);
    vm.loadSavedTeams();
  }

  @override
  void dispose() {
    vm.teamNameController.removeListener(_onNameChanged);
    super.dispose();
  }

  void _onNameChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: const [
                  Icon(Icons.group_add_rounded,
                      color: AppTheme.primaryLight),
                  SizedBox(width: 10),
                  Text('Add Team',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              // Body
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Logo picker
                    Center(
                      child: Obx(() => GestureDetector(
                        onTap: () => _showLogoOptions(context),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                color: AppTheme.bgSurface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppTheme.borderColor,
                                    width: 2),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: vm.pendingLogo.value != null
                                  ? Image.file(
                                vm.pendingLogo.value!,
                                fit: BoxFit.cover,
                              )
                                  : const Icon(Icons.add_a_photo_outlined,
                                  color: AppTheme.textSecondary,
                                  size: 32),
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppTheme.bgCard, width: 2),
                              ),
                              child: const Icon(Icons.edit_rounded,
                                  color: Colors.white, size: 14),
                            ),
                          ],
                        ),
                      )),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Obx(() => TextButton(
                        onPressed: vm.pendingLogo.value == null
                            ? null
                            : vm.removePendingLogo,
                        child: Text(
                          vm.pendingLogo.value == null
                              ? 'Tap to add logo (optional)'
                              : 'Remove logo',
                          style: TextStyle(
                            color: vm.pendingLogo.value == null
                                ? AppTheme.textSecondary
                                : AppTheme.error,
                            fontSize: 11,
                          ),
                        ),
                      )),
                    ),

                    const SizedBox(height: 16),

                    _label('TEAM NAME *'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: vm.teamNameController,
                      style:
                      const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Chennai Warriors',
                        prefixIcon: Icon(Icons.badge_outlined,
                            color: AppTheme.textSecondary),
                      ),
                    ),

                    Obx(() {
                      final suggestions = vm
                          .matchingSavedTeams(vm.teamNameController.text);
                      if (suggestions.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SAVED TEAMS',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                )),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: suggestions
                                  .map((t) => _SavedTeamChip(
                                        team: t,
                                        onTap: () => vm.loadSavedTeam(t),
                                        onDelete: () =>
                                            vm.deleteSavedTeam(t.name),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 20),

                    _label('PLAYERS (OPTIONAL)'),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: vm.playerNameController,
                          style: const TextStyle(
                              color: AppTheme.textPrimary),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => vm.addPendingPlayer(),
                          decoration: const InputDecoration(
                            hintText: 'Player name',
                            prefixIcon: Icon(Icons.person_add_outlined,
                                color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: vm.addPendingPlayer,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              gradient: AppTheme.greenGradient,
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.add,
                              color: Colors.white),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 12),

                    Obx(() => Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: vm.pendingPlayers
                          .asMap()
                          .entries
                          .map((e) => _PlayerChip(
                        name: e.value,
                        onRemove: () =>
                            vm.removePendingPlayer(e.key),
                      ))
                          .toList(),
                    )),
                  ],
                ),
              ),
              // Footer save button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Obx(() => SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: vm.isLoading.value
                          ? null
                          : () async {
                        final ok = await vm.saveTeam();
                        if (ok) Navigator.pop(context);
                      },
                      child: vm.isLoading.value
                          ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                          : const Text('Save Team',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                    ),
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppTheme.primaryLight),
              title: const Text('From Gallery',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                vm.pickLogoFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppTheme.primaryLight),
              title: const Text('From Camera',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                vm.pickLogoFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ));
}

class _SavedTeamChip extends StatelessWidget {
  final SavedTeam team;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _SavedTeamChip({
    required this.team,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.info.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.info.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.bookmark_rounded,
              size: 12, color: AppTheme.info),
          const SizedBox(width: 6),
          Text(team.name,
              style: const TextStyle(
                  color: AppTheme.info,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Text('· ${team.players.length}',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close,
                size: 13, color: AppTheme.textSecondary),
          ),
        ]),
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final String name;
  final VoidCallback onRemove;
  const _PlayerChip({required this.name, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(name,
            style: const TextStyle(
                color: AppTheme.primaryLight,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close,
              size: 14, color: AppTheme.textSecondary),
        ),
      ]),
    );
  }
}