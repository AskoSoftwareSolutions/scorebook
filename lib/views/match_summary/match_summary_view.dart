import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/models.dart';
import '../../viewmodels/summary_history_viewmodel.dart';
import '../../core/constants/app_routes.dart';
import '../../widgets/app_widgets.dart';

class MatchSummaryView extends StatelessWidget {
  const MatchSummaryView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = Get.put(MatchSummaryViewModel());

    return SafeArea(
      top: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Match Summary'),
          leading: IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => Get.offAllNamed(AppRoutes.home),
          ),
          actions: [
            Obx(() => vm.isGeneratingPdf.value
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: AppTheme.primary, strokeWidth: 2)),
                  )
                : IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: vm.generateAndSharePdf,
                    tooltip: 'Generate & Share PDF',
                  )),
          ],
        ),
        body: Obx(() {
          if (vm.isLoading.value) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final match = vm.match.value;
          if (match == null) return const Center(child: Text('No data'));

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.bgDark, AppTheme.bgCard],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Result banner
                  _ResultBanner(match: match),
                  const SizedBox(height: 16),

                  // Man of Match
                  if (match.manOfTheMatch != null)
                    _MotmCard(name: match.manOfTheMatch!),

                  const SizedBox(height: 16),

                  // Innings 1 scorecard
                  if (vm.innings1.value != null)
                    _InningsScorecardCard(
                      innings: vm.innings1.value!,
                      batters: vm.innings1.value!.battingTeam == match.teamAName
                          ? vm.teamAPlayers
                          : vm.teamBPlayers,
                      bowlers: vm.innings1.value!.bowlingTeam == match.teamAName
                          ? vm.teamAPlayers
                          : vm.teamBPlayers,
                      vm: vm,
                    ),

                  const SizedBox(height: 16),

                  // Innings 2 scorecard
                  if (vm.innings2.value != null)
                    _InningsScorecardCard(
                      innings: vm.innings2.value!,
                      batters: vm.innings2.value!.battingTeam == match.teamAName
                          ? vm.teamAPlayers
                          : vm.teamBPlayers,
                      bowlers: vm.innings2.value!.bowlingTeam == match.teamAName
                          ? vm.teamAPlayers
                          : vm.teamBPlayers,
                      vm: vm,
                    ),

                  const SizedBox(height: 20),

                  // Share button
                  GradientButton(
                    label: '📤 Share PDF via WhatsApp',
                    icon: Icons.share_outlined,
                    onTap: vm.generateAndSharePdf,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                    ),
                  ),

                  const SizedBox(height: 12),

                  GradientButton(
                    label: '🏠 Back to Home',
                    onTap: () => Get.offAllNamed(AppRoutes.home),
                    gradient: AppTheme.greenGradient,
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final MatchModel match;
  const _ResultBanner({required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.greenGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '${match.teamAName} vs ${match.teamBName}',
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    match.teamAName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  Text(
                    match.teamAScore != null
                        ? '${match.teamAScore}/${match.teamAWickets} (${AppUtils.formatOvers(match.teamABalls ?? 0)})'
                        : '-',
                    style: const TextStyle(color: AppTheme.accent, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const Text('VS',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              Column(
                children: [
                  Text(
                    match.teamBName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  Text(
                    match.teamBScore != null
                        ? '${match.teamBScore}/${match.teamBWickets} (${AppUtils.formatOvers(match.teamBBalls ?? 0)})'
                        : '-',
                    style: const TextStyle(color: AppTheme.accent, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '🏆 ${match.result ?? 'Match in progress'}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _MotmCard extends StatelessWidget {
  final String name;
  const _MotmCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.goldGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('⭐', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Man of the Match',
                  style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w600)),
              Text(name,
                  style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InningsScorecardCard extends StatelessWidget {
  final InningsModel innings;
  final List<PlayerModel> batters;
  final List<PlayerModel> bowlers;
  final MatchSummaryViewModel vm;

  const _InningsScorecardCard({
    required this.innings,
    required this.batters,
    required this.bowlers,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: AppTheme.greenGradient,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Text(
                  'Innings ${innings.inningsNumber}: ${innings.battingTeam}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
                const Spacer(),
                Text(
                  '${innings.totalRuns}/${innings.totalWickets}  (${innings.oversBowled})',
                  style: const TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 14),
                ),
              ],
            ),
          ),

          // Batting table
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Batting'),
                const SizedBox(height: 10),
                _BattingTable(batters: batters, vm: vm),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      const Text('Extras: ',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      Text(
                        '${innings.extras}  (WD ${innings.wides}, NB ${innings.noBalls}, B ${innings.byes}, LB ${innings.legByes})',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionHeader(title: 'Bowling'),
                const SizedBox(height: 10),
                _BowlingTable(
                    bowlers: bowlers.where((p) => p.ballsBowled > 0).toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BattingTable extends StatelessWidget {
  final List<PlayerModel> batters;
  final MatchSummaryViewModel vm;
  const _BattingTable({required this.batters, required this.vm});

  @override
  Widget build(BuildContext context) {
    final played = batters.where((p) => p.didBat || p.ballsFaced > 0).toList();

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(0.7),
        4: FlexColumnWidth(0.7),
        5: FlexColumnWidth(1.3),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(6),
          ),
          children: ['Batsman', 'R', 'B', '4s', '6s', 'SR']
              .map((h) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Text(h,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ))
              .toList(),
        ),
        ...played.map((p) => TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      Text(
                        vm.dismissalText(p),
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _cell('${p.runsScored}', bold: true),
                _cell('${p.ballsFaced}'),
                _cell('${p.fours}'),
                _cell('${p.sixes}'),
                _cell(AppUtils.formatDouble(p.strikeRate)),
              ],
            )),
      ],
    );
  }

  Widget _cell(String t, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Text(t,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: bold ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
      );
}

class _BowlingTable extends StatelessWidget {
  final List<PlayerModel> bowlers;
  const _BowlingTable({required this.bowlers});

  @override
  Widget build(BuildContext context) {
    if (bowlers.isEmpty) {
      return const Text('No bowling data',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12));
    }
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1.3),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(6)),
          children: ['Bowler', 'O', 'R', 'W', 'Econ']
              .map((h) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Text(h,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ))
              .toList(),
        ),
        ...bowlers.map((p) => TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Text(p.name,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                _cell(p.oversBoled),
                _cell('${p.runsConceded}'),
                _cell('${p.wicketsTaken}', bold: true),
                _cell(AppUtils.formatDouble(p.economy)),
              ],
            )),
      ],
    );
  }

  Widget _cell(String t, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Text(t,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: bold ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
      );
}
