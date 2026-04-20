// ─────────────────────────────────────────────────────────────────────────────
// lib/widgets/tournament_poster.dart
//
// Renders a cricket-themed tournament poster.
// Wrap in RepaintBoundary to capture as an image for sharing.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tournament_models.dart';

class TournamentPoster extends StatelessWidget {
  final TournamentModel tournament;
  final List<TournamentMatchModel> matches;
  final List<TournamentTeamModel> teams;

  const TournamentPoster({
    super.key,
    required this.tournament,
    required this.matches,
    required this.teams,
  });

  @override
  Widget build(BuildContext context) {
    // Sort matches: by round, then by scheduledTime
    final sortedMatches = [...matches]
      ..sort((a, b) {
        final r = a.round.compareTo(b.round);
        return r != 0 ? r : a.scheduledTime.compareTo(b.scheduledTime);
      });

    final firstDate = sortedMatches.isNotEmpty
        ? sortedMatches.first.scheduledTime
        : DateTime.now();

    return Container(
      width: 900,
      padding: const EdgeInsets.all(40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0D1B2A),
            Color(0xFF1B263B),
            Color(0xFF0D1B2A),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PosterHeader(tournament: tournament),
          const SizedBox(height: 20),
          _VenueDate(tournament: tournament, date: firstDate),
          const SizedBox(height: 28),
          ..._buildMatchBlocks(sortedMatches),
          const SizedBox(height: 24),
          _ImportantNote(),
          const SizedBox(height: 20),
          _Footer(),
        ],
      ),
    );
  }

  List<Widget> _buildMatchBlocks(List<TournamentMatchModel> ms) {
    final widgets = <Widget>[];
    for (int i = 0; i < ms.length; i++) {
      final m = ms[i];
      widgets.add(_MatchBlock(
        label: _matchLabel(i, ms.length, m),
        match: m,
      ));
      if (i < ms.length - 1) {
        widgets.add(const SizedBox(height: 16));
      }
    }
    return widgets;
  }

  String _matchLabel(int idx, int total, TournamentMatchModel m) {
    if (tournament.format == TournamentFormat.knockout) {
      if (m.round == 1) {
        // Round 1 → First Match, Second Match...
        final ordinals = ['FIRST', 'SECOND', 'THIRD', 'FOURTH', 'FIFTH'];
        final roundMatches = matches.where((x) => x.round == 1).toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        final pos = roundMatches.indexOf(m);
        if (pos >= 0 && pos < ordinals.length) return '${ordinals[pos]} MATCH';
        return 'MATCH ${pos + 1}';
      }
      // Last round = FINAL
      final maxRound = matches.map((x) => x.round).reduce((a, b) => a > b ? a : b);
      if (m.round == maxRound) return 'FINAL MATCH';
      if (m.round == maxRound - 1) return 'SEMI-FINAL';
      return 'ROUND ${m.round}';
    }
    return 'MATCH ${idx + 1}';
  }
}

// ── Header ──────────────────────────────────────────────────────────────────
class _PosterHeader extends StatelessWidget {
  final TournamentModel tournament;
  const _PosterHeader({required this.tournament});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Cricket emoji banner
        const Text('🏏',
            style: TextStyle(fontSize: 68)),
        const SizedBox(height: 4),
        // Tournament name with border box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFC107).withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(color: const Color(0xFFFFC107), width: 2),
          ),
          child: Text(
            tournament.name.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              shadows: [
                Shadow(
                    color: Colors.black54,
                    blurRadius: 6,
                    offset: Offset(0, 2))
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Venue & Date ────────────────────────────────────────────────────────────
class _VenueDate extends StatelessWidget {
  final TournamentModel tournament;
  final DateTime date;
  const _VenueDate({required this.tournament, required this.date});

  @override
  Widget build(BuildContext context) {
    final hasVenue = tournament.venue.trim().isNotEmpty;
    return Column(
      children: [
        if (hasVenue) ...[
          _InfoRow(
            icon: '📍',
            label: 'VENUE',
            value: tournament.venue.toUpperCase(),
          ),
          const SizedBox(height: 8),
        ],
        _InfoRow(
          icon: '📅',
          label: 'DATE',
          value: DateFormat('d MMMM y (EEEE)').format(date).toUpperCase(),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: '$icon  ',
            style: const TextStyle(fontSize: 20),
          ),
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: Color(0xFFFFC107),
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Match block ─────────────────────────────────────────────────────────────
class _MatchBlock extends StatelessWidget {
  final String label;
  final TournamentMatchModel match;
  const _MatchBlock({required this.label, required this.match});

  @override
  Widget build(BuildContext context) {
    final isFinal = label.contains('FINAL');
    final accent = isFinal ? const Color(0xFFFFD54F) : const Color(0xFFFFC107);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withOpacity(0.1),
            Colors.white.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        children: [
          // Match label banner
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF0D1B2A),
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Crossed bats icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TeamText(name: match.teamAName, isPlaceholder: match.teamAIsPlaceholder),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const Text('⚔️', style: TextStyle(fontSize: 22)),
                    const SizedBox(height: 4),
                    Text('VS',
                        style: TextStyle(
                            color: accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              _TeamText(name: match.teamBName, isPlaceholder: match.teamBIsPlaceholder),
            ],
          ),
          const SizedBox(height: 14),

          // Umpire + Time row
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 6,
            children: [
              _MetaChip(
                icon: '👤',
                label: 'UMPIRE',
                value: match.umpireTeamName ?? 'TBD',
              ),
              _MetaChip(
                icon: '🕒',
                label: 'TIME',
                value: DateFormat('h:mm a').format(match.scheduledTime),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamText extends StatelessWidget {
  final String name;
  final bool isPlaceholder;
  const _TeamText({required this.name, required this.isPlaceholder});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Text(
        name.toUpperCase(),
        textAlign: TextAlign.center,
        maxLines: 2,
        style: TextStyle(
          color: isPlaceholder ? Colors.white70 : Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
          letterSpacing: 0.8,
          shadows: const [
            Shadow(
                color: Colors.black54,
                blurRadius: 4,
                offset: Offset(0, 2))
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: '$icon  ', style: const TextStyle(fontSize: 14)),
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: Color(0xFFFFC107),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          TextSpan(
            text: value.toUpperCase(),
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
}

// ── Important Note ──────────────────────────────────────────────────────────
class _ImportantNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFFFC107).withOpacity(0.3)),
      ),
      child: Column(
        children: const [
          Text(
            'IMPORTANT NOTE',
            style: TextStyle(
              color: Color(0xFFFFC107),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Match timings are approximate and may vary slightly depending on gameplay. A 15-minute grace period will be allowed before the start of each match.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Footer ──────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Text('🏆  GOOD LUCK TO ALL TEAMS  🏆',
            style: TextStyle(
              color: Color(0xFFFFC107),
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            )),
        SizedBox(height: 6),
        Text('Generated by ScoreBook',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 1,
            )),
      ],
    );
  }
}