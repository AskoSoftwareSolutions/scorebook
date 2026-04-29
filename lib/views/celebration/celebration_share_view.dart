import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/models.dart';
import '../../repositories/match_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CELEBRATION & SHARE — WhatsApp-status ready cards
//   • Winning team card with team photo upload + confetti animation
//   • Man of the Match card with player photo upload
//   • Capture card as PNG & share to WhatsApp
// Arguments: matchId (int)
// ═══════════════════════════════════════════════════════════════════════════════

class CelebrationShareView extends StatefulWidget {
  const CelebrationShareView({super.key});

  @override
  State<CelebrationShareView> createState() => _CelebrationShareViewState();
}

class _CelebrationShareViewState extends State<CelebrationShareView>
    with TickerProviderStateMixin {
  final _repo = Get.find<MatchRepository>();
  final _picker = ImagePicker();

  MatchModel? _match;
  List<PlayerModel> _winners = [];
  PlayerModel? _motmPlayer;
  bool _loading = true;

  File? _teamPhoto;
  File? _motmPhoto;
  bool _sharingTeam = false;
  bool _sharingMotm = false;

  final GlobalKey _teamCardKey = GlobalKey();
  final GlobalKey _motmCardKey = GlobalKey();

  late final AnimationController _confettiCtrl;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _load();
  }

  Future<void> _load() async {
    final id = Get.arguments as int?;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    final m = await _repo.getMatch(id);
    if (m == null) {
      setState(() => _loading = false);
      return;
    }
    final winnerName = _winnerTeamName(m);
    final players =
        winnerName == null ? <PlayerModel>[] : await _repo.getPlayersByTeam(m.id!, winnerName);

    PlayerModel? motm;
    if (m.manOfTheMatch != null) {
      final allA = await _repo.getPlayersByTeam(m.id!, m.teamAName);
      final allB = await _repo.getPlayersByTeam(m.id!, m.teamBName);
      final all = [...allA, ...allB];
      try {
        motm = all.firstWhere((p) => p.name == m.manOfTheMatch);
      } catch (_) {
        motm = null;
      }
    }

    if (!mounted) return;
    setState(() {
      _match = m;
      _winners = players;
      _motmPlayer = motm;
      _loading = false;
    });
  }

  String? _winnerTeamName(MatchModel m) {
    final aScore = m.teamAScore ?? 0;
    final bScore = m.teamBScore ?? 0;
    if (aScore == bScore) return null; // tie
    return aScore > bScore ? m.teamAName : m.teamBName;
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    super.dispose();
  }

  // ── Photo picker ────────────────────────────────────────────────────────
  Future<void> _pickPhoto({required bool forTeam}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Choose photo source',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: AppTheme.primary),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppTheme.primary),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (file == null) return;
      if (!mounted) return;
      setState(() {
        if (forTeam) {
          _teamPhoto = File(file.path);
        } else {
          _motmPhoto = File(file.path);
        }
      });
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Couldn\'t pick photo', '$e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  // ── Capture widget → PNG → share ────────────────────────────────────────
  Future<void> _share({
    required GlobalKey key,
    required String fileName,
    required String caption,
    required bool isTeam,
  }) async {
    setState(() {
      if (isTeam) {
        _sharingTeam = true;
      } else {
        _sharingMotm = true;
      }
    });
    try {
      final boundary = key.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Card not ready yet — try again');
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode PNG');
      final bytes = byteData.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/$fileName-${DateTime.now().millisecondsSinceEpoch}.png';
      final file = await File(path).writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: caption,
        subject: caption,
      );
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Share failed', '$e',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) {
        setState(() {
          _sharingTeam = false;
          _sharingMotm = false;
        });
      }
    }
  }

  // ── Top performers for captions ─────────────────────────────────────────
  PlayerModel? _topScorer(List<PlayerModel> ps) {
    if (ps.isEmpty) return null;
    final batters = ps.where((p) => p.ballsFaced > 0).toList()
      ..sort((a, b) => b.runsScored.compareTo(a.runsScored));
    return batters.isEmpty ? null : batters.first;
  }

  PlayerModel? _topWicketTaker(List<PlayerModel> ps) {
    if (ps.isEmpty) return null;
    final bowlers = ps.where((p) => p.ballsBowled > 0).toList()
      ..sort((a, b) => b.wicketsTaken.compareTo(a.wicketsTaken));
    return bowlers.isEmpty || bowlers.first.wicketsTaken == 0
        ? null
        : bowlers.first;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F2),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Celebrate & Share',
              style: TextStyle(fontWeight: FontWeight.w700)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : _match == null
                ? const Center(child: Text('Match not found'))
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final m = _match!;
    final winnerName = _winnerTeamName(m);
    final isTie = winnerName == null;
    final topScorer = _topScorer(_winners);
    final topBowler = _topWicketTaker(_winners);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 32),
      child: Column(
        children: [
          // ── Winning team celebration card ─────────────────────────────
          Row(
            children: const [
              Icon(Icons.emoji_events_rounded,
                  color: Color(0xFFFFB300), size: 22),
              SizedBox(width: 8),
              Text('Winning Team',
                  style: TextStyle(
                    color: Color(0xFF1B5E20),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  )),
            ],
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -.1),
          const SizedBox(height: 10),
          RepaintBoundary(
            key: _teamCardKey,
            child: _WinningTeamCard(
              match: m,
              isTie: isTie,
              winnerName: winnerName ?? 'Match Tied',
              teamPhoto: _teamPhoto,
              topScorer: topScorer,
              topBowler: topBowler,
              confetti: _confettiCtrl,
            ),
          ),
          const SizedBox(height: 12),
          _ActionRow(
            onPickPhoto: () => _pickPhoto(forTeam: true),
            onShare: _sharingTeam
                ? null
                : () => _share(
                      key: _teamCardKey,
                      fileName: 'winning-team',
                      caption: isTie
                          ? '🏏 Match ended in a tie! ${m.teamAName} vs ${m.teamBName}'
                          : '🏆 $winnerName won! ${m.result ?? ''}',
                      isTeam: true,
                    ),
            photoLabel: _teamPhoto == null ? 'Add Team Photo' : 'Change Team Photo',
            sharing: _sharingTeam,
          ),
          const SizedBox(height: 26),

          // ── Man of the match card ─────────────────────────────────────
          if (_motmPlayer != null) ...[
            Row(
              children: const [
                Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 22),
                SizedBox(width: 8),
                Text('Man of the Match',
                    style: TextStyle(
                      color: Color(0xFF1B5E20),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    )),
              ],
            ).animate().fadeIn(duration: 400.ms).slideX(begin: -.1),
            const SizedBox(height: 10),
            RepaintBoundary(
              key: _motmCardKey,
              child: _MotmCelebrationCard(
                match: m,
                player: _motmPlayer!,
                photo: _motmPhoto,
                confetti: _confettiCtrl,
              ),
            ),
            const SizedBox(height: 12),
            _ActionRow(
              onPickPhoto: () => _pickPhoto(forTeam: false),
              onShare: _sharingMotm
                  ? null
                  : () => _share(
                        key: _motmCardKey,
                        fileName: 'motm',
                        caption:
                            '⭐ Man of the Match: ${_motmPlayer!.name} — ${m.teamAName} vs ${m.teamBName}',
                        isTeam: false,
                      ),
              photoLabel:
                  _motmPhoto == null ? 'Add Player Photo' : 'Change Player Photo',
              sharing: _sharingMotm,
            ),
          ],
          const SizedBox(height: 20),
          _HintCard(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WINNING TEAM CARD
// ─────────────────────────────────────────────────────────────────────────────
class _WinningTeamCard extends StatelessWidget {
  final MatchModel match;
  final bool isTie;
  final String winnerName;
  final File? teamPhoto;
  final PlayerModel? topScorer;
  final PlayerModel? topBowler;
  final AnimationController confetti;

  const _WinningTeamCard({
    required this.match,
    required this.isTie,
    required this.winnerName,
    required this.teamPhoto,
    required this.topScorer,
    required this.topBowler,
    required this.confetti,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _GreenCelebrationBackdrop(),
            _ConfettiLayer(controller: confetti),
            // Team photo — wider region so landscape photos read clearly
            Positioned.fill(
              top: 60,
              bottom: 230,
              left: 14,
              right: 14,
              child: _PhotoFrame(
                photo: teamPhoto,
                placeholder: isTie ? 'Team Photo' : _initials(winnerName),
                isCircular: false,
              ),
            ),
            // Trophy + winner text
            Positioned(
              top: 18,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                          color: Color(0xFFFFD54F), size: 38)
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(duration: 1800.ms, color: Colors.white70)
                      .scale(
                        begin: const Offset(0.95, 0.95),
                        end: const Offset(1.08, 1.08),
                        duration: 900.ms,
                        curve: Curves.easeInOut,
                      )
                      .then()
                      .scale(
                        begin: const Offset(1.08, 1.08),
                        end: const Offset(0.95, 0.95),
                        duration: 900.ms,
                        curve: Curves.easeInOut,
                      ),
                  const SizedBox(height: 4),
                  Text(
                    isTie ? 'MATCH TIED' : 'CHAMPIONS',
                    style: const TextStyle(
                      color: Color(0xFFFFF59D),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms).moveY(begin: -12, end: 0),
            ),
            // Bottom info panel
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xCC000000), Color(0xFF000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      winnerName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 500.ms)
                        .moveY(begin: 20, end: 0),
                    const SizedBox(height: 4),
                    Text(
                      match.result ?? '${match.teamAName} vs ${match.teamBName}',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                        color: Color(0xFFFFE082),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Score pill
                    _ScoreLine(match: match),
                    const SizedBox(height: 12),
                    if (topScorer != null || topBowler != null)
                      Row(
                        children: [
                          if (topScorer != null)
                            Expanded(
                              child: _StarStat(
                                icon: Icons.sports_cricket_rounded,
                                label: 'TOP SCORE',
                                value:
                                    '${topScorer!.name}  ${topScorer!.runsScored}(${topScorer!.ballsFaced})',
                              ),
                            ),
                          if (topScorer != null && topBowler != null)
                            const SizedBox(width: 10),
                          if (topBowler != null)
                            Expanded(
                              child: _StarStat(
                                icon: Icons.sports_handball_rounded,
                                label: 'BEST BOWLER',
                                value:
                                    '${topBowler!.name}  ${topBowler!.wicketsTaken}/${topBowler!.runsConceded}',
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'ScoreBook • Cricket Scorer',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, math.min(2, parts.first.length)).toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAN OF THE MATCH CARD — premium Canva-style template
// ─────────────────────────────────────────────────────────────────────────────
class _MotmCelebrationCard extends StatelessWidget {
  final MatchModel match;
  final PlayerModel player;
  final File? photo;
  final AnimationController confetti;

  const _MotmCelebrationCard({
    required this.match,
    required this.player,
    required this.photo,
    required this.confetti,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.32),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layered backdrop
            const _MotmPremiumBackdrop(),
            // Soft star burst behind portrait
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _SunburstPainter()),
              ),
            ),
            _ConfettiLayer(controller: confetti),

            // ── Top banner: ornate "MAN OF THE MATCH" plate ─────────────
            Positioned(
              top: 22,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Glow ring around star
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0x66FFF59D),
                                Color(0x00FFF59D),
                              ],
                            ),
                          ),
                        ).animate(onPlay: (c) => c.repeat()).scale(
                              begin: const Offset(0.9, 0.9),
                              end: const Offset(1.18, 1.18),
                              duration: 1400.ms,
                              curve: Curves.easeInOut,
                            ).then().scale(
                              begin: const Offset(1.18, 1.18),
                              end: const Offset(0.9, 0.9),
                              duration: 1400.ms,
                              curve: Curves.easeInOut,
                            ),
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFFE082), size: 50),
                      ],
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(duration: 2200.ms, color: Colors.white70),
                  const SizedBox(height: 8),
                  // Engraved-look ribbon plate
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFE082),
                          Color(0xFFFFC107),
                          Color(0xFFFFE082),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                          color: const Color(0xFFFFF59D), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Text(
                      'MAN OF THE MATCH',
                      style: TextStyle(
                        color: Color(0xFF3E2723),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 450.ms).moveY(begin: -16, end: 0),
            ),

            // ── Player portrait — large, framed, glowing ─────────────────
            Align(
              alignment: const Alignment(0, -0.18),
              child: Container(
                width: 234,
                height: 234,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [
                      Color(0xFFFFE082),
                      Color(0xFFFFC107),
                      Color(0xFFB8860B),
                      Color(0xFFFFE082),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x66FFD54F).withOpacity(0.55),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 22,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(5),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1B0F00),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: ClipOval(
                    child: SizedBox(
                      width: 220,
                      height: 220,
                      child: _PhotoFrame(
                        photo: photo,
                        placeholder: _initials(player.name),
                        isCircular: true,
                      ),
                    ),
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 480.ms)
                .scale(begin: const Offset(0.85, 0.85)),

            // ── Bottom info: rich, premium card ──────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 26, 18, 22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0xCC0E0700),
                      Color(0xFF0E0700),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.35, 1.0],
                  ),
                ),
                child: Column(
                  children: [
                    // ── Player name banner ──────────────────────────────
                    _NameBanner(text: player.name.toUpperCase()),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFFFD54F).withOpacity(0.5)),
                      ),
                      child: Text(
                        player.teamName,
                        style: const TextStyle(
                          color: Color(0xFFFFE082),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ── Hero stat strip ─────────────────────────────────
                    _MotmHeroStats(player: player),
                    const SizedBox(height: 12),
                    // Versus line
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${match.teamAName}  vs  ${match.teamBName}',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Branded footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.sports_cricket_rounded,
                            color: Color(0xFFFFD54F), size: 10),
                        SizedBox(width: 4),
                        Text(
                          'SCOREBOOK',
                          style: TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.sports_cricket_rounded,
                            color: Color(0xFFFFD54F), size: 10),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Decorative corner ornaments ──────────────────────────────
            const Positioned(
              top: 8,
              left: 8,
              child: _CornerOrnament(),
            ),
            const Positioned(
              top: 8,
              right: 8,
              child: _CornerOrnament(flipX: true),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, math.min(2, parts.first.length)).toUpperCase();
    }
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }
}

// ── Name banner: gold ribbon look ──────────────────────────────────────────
class _NameBanner extends StatelessWidget {
  final String text;
  const _NameBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFE082),
            Color(0xFFFFC107),
            Color(0xFFFFE082),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFF8E1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF1A0E00),
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
          height: 1.0,
        ),
      ),
    );
  }
}

// ── Hero stats row used in the MoM card ────────────────────────────────────
class _MotmHeroStats extends StatelessWidget {
  final PlayerModel player;
  const _MotmHeroStats({required this.player});

  @override
  Widget build(BuildContext context) {
    final didBowl = player.ballsBowled > 0;
    return Row(
      children: [
        Expanded(
          child: _BigStatTile(
            icon: Icons.sports_cricket_rounded,
            label: 'RUNS',
            big: '${player.runsScored}',
            sub: '${player.ballsFaced} balls',
            extra:
                'SR ${AppUtils.formatDouble(player.strikeRate)}  •  ${player.fours}×4  ${player.sixes}×6',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _BigStatTile(
            icon: Icons.sports_handball_rounded,
            label: 'WICKETS',
            big: didBowl ? '${player.wicketsTaken}' : '—',
            sub: didBowl
                ? '${player.runsConceded} runs'
                : 'did not bowl',
            extra: didBowl
                ? '(${player.oversBoled} ov)'
                : '',
          ),
        ),
      ],
    );
  }
}

class _BigStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String big;
  final String sub;
  final String extra;
  const _BigStatTile({
    required this.icon,
    required this.label,
    required this.big,
    required this.sub,
    required this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.13),
            Colors.white.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFFFD54F).withOpacity(0.32), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFFD54F), size: 12),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  )),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                big,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (extra.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              extra,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFFE082),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Decorative ornaments + premium backdrop ───────────────────────────────
class _MotmPremiumBackdrop extends StatelessWidget {
  const _MotmPremiumBackdrop();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.3),
          radius: 1.2,
          colors: [
            Color(0xFF6E3B00),
            Color(0xFF3E2200),
            Color(0xFF180D00),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle gold sheen overlay
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x33FFD54F),
                  Color(0x00FFD54F),
                  Color(0x22FFB300),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          CustomPaint(painter: _StarfieldPainter(golden: true)),
        ],
      ),
    );
  }
}

class _SunburstPainter extends CustomPainter {
  const _SunburstPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.32;
    final radius = size.shortestSide * 1.0;
    final paint = Paint()..style = PaintingStyle.fill;
    const beams = 18;
    for (var i = 0; i < beams; i++) {
      final t = i / beams;
      final color = Color.lerp(
        const Color(0x33FFE082),
        const Color(0x11FFD54F),
        t,
      )!;
      paint.color = color;
      final theta1 = (i / beams) * 2 * math.pi;
      final theta2 = ((i + 0.45) / beams) * 2 * math.pi;
      final p1 = Offset(cx + math.cos(theta1) * radius,
          cy + math.sin(theta1) * radius);
      final p2 = Offset(cx + math.cos(theta2) * radius,
          cy + math.sin(theta2) * radius);
      final path = Path()
        ..moveTo(cx, cy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CornerOrnament extends StatelessWidget {
  final bool flipX;
  const _CornerOrnament({this.flipX = false});

  @override
  Widget build(BuildContext context) {
    final widget = SizedBox(
      width: 56,
      height: 56,
      child: CustomPaint(painter: _CornerPainter()),
    );
    if (!flipX) return widget;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(-1, 1, 1),
      child: widget,
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFFFD54F).withOpacity(0.8);
    final p = Path()
      ..moveTo(4, 28)
      ..lineTo(4, 8)
      ..lineTo(28, 8);
    canvas.drawPath(p, paint);
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFE082);
    canvas.drawCircle(const Offset(8, 8), 2.4, paint);
    canvas.drawCircle(const Offset(28, 8), 1.6, paint);
    canvas.drawCircle(const Offset(8, 28), 1.6, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo frame, stats, backdrops, confetti
// ─────────────────────────────────────────────────────────────────────────────
class _PhotoFrame extends StatelessWidget {
  final File? photo;
  final String placeholder;
  final bool isCircular;
  const _PhotoFrame({
    required this.photo,
    required this.placeholder,
    required this.isCircular,
  });

  @override
  Widget build(BuildContext context) {
    final radius = isCircular
        ? BorderRadius.circular(500)
        : BorderRadius.circular(20);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: Colors.white.withOpacity(0.85), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: photo != null
          ? _SmartFitPhoto(file: photo!, isCircular: isCircular)
          : Container(
              color: Colors.white.withOpacity(0.15),
              alignment: Alignment.center,
              child: Text(
                placeholder,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
    );
  }
}

/// Renders a user-provided photo so the **whole** image is visible regardless
/// of orientation — uses a blurred copy of the image as backdrop, then the
/// original on top with [BoxFit.contain]. Circular crops still cover (so the
/// avatar fills its disc), but the rectangular team-photo frame uses contain
/// so landscape photos no longer get cropped.
class _SmartFitPhoto extends StatelessWidget {
  final File file;
  final bool isCircular;
  const _SmartFitPhoto({required this.file, required this.isCircular});

  @override
  Widget build(BuildContext context) {
    if (isCircular) {
      // Circular avatar still uses cover for an aesthetically full disc
      return Image.file(file, fit: BoxFit.cover);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred backdrop fills the rectangle for any aspect ratio
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Image.file(
            file,
            fit: BoxFit.cover,
            colorBlendMode: BlendMode.darken,
            color: Colors.black.withOpacity(0.25),
          ),
        ),
        // Soft overlay so the front photo pops
        Container(color: Colors.black.withOpacity(0.18)),
        // The actual photo — full picture, no crop
        Image.file(file, fit: BoxFit.contain),
      ],
    );
  }
}

class _StarStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StarStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFFD54F), size: 13),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  )),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreLine extends StatelessWidget {
  final MatchModel match;
  const _ScoreLine({required this.match});

  String _fmt(int? runs, int? wickets, int? balls) {
    if (runs == null) return '—';
    final o = AppUtils.formatOvers(balls ?? 0);
    return '$runs/${wickets ?? 0}  ($o)';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(match.teamAName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFFE082),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 2),
                Text(
                  _fmt(match.teamAScore, match.teamAWickets, match.teamABalls),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: Colors.white24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(match.teamBName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFFE082),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 2),
                Text(
                  _fmt(match.teamBScore, match.teamBWickets, match.teamBBalls),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GreenCelebrationBackdrop extends StatelessWidget {
  const _GreenCelebrationBackdrop();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0A3D0A),
            Color(0xFF1B5E20),
            Color(0xFF2E7D32),
            Color(0xFF1B5E20),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(painter: _StarfieldPainter()),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  final bool golden;
  _StarfieldPainter({this.golden = false});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(42);
    final paint = Paint()
      ..color = (golden ? const Color(0xFFFFF59D) : Colors.white).withOpacity(0.35);
    for (var i = 0; i < 50; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final r = rnd.nextDouble() * 1.8 + 0.4;
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ConfettiLayer extends StatelessWidget {
  final AnimationController controller;
  const _ConfettiLayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) => CustomPaint(
          painter: _ConfettiPainter(progress: controller.value),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  _ConfettiPainter({required this.progress});

  static const _colors = [
    Color(0xFFFFD54F),
    Color(0xFF4FC3F7),
    Color(0xFFE91E63),
    Color(0xFF66BB6A),
    Color(0xFFFF7043),
    Color(0xFFBA68C8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 38; i++) {
      final color = _colors[i % _colors.length];
      final startX = rnd.nextDouble() * size.width;
      final speed = 0.6 + rnd.nextDouble() * 0.9;
      final phase = rnd.nextDouble();
      final t = (progress + phase) % 1.0;
      final y = t * size.height * speed - 20;
      final sway = math.sin((t + phase) * math.pi * 4) * 14;
      final x = startX + sway;
      final rot = (t + phase) * math.pi * 2;
      final w = 5.0 + rnd.nextDouble() * 4;
      final h = 9.0 + rnd.nextDouble() * 6;
      paint.color = color.withOpacity(0.85);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Action row (add photo + share)
// ─────────────────────────────────────────────────────────────────────────────
class _ActionRow extends StatelessWidget {
  final VoidCallback? onPickPhoto;
  final VoidCallback? onShare;
  final String photoLabel;
  final bool sharing;
  const _ActionRow({
    required this.onPickPhoto,
    required this.onShare,
    required this.photoLabel,
    required this.sharing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPickPhoto,
            icon: const Icon(Icons.camera_alt_rounded, size: 18),
            label: Text(photoLabel, overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1B5E20),
              side: const BorderSide(color: Color(0xFF1B5E20), width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onShare,
            icon: sharing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.share_rounded, size: 18),
            label: const Text('Share on WhatsApp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

class _HintCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(
        children: const [
          Icon(Icons.lightbulb_rounded,
              color: Color(0xFF1B5E20), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tap “Add Photo”, then “Share on WhatsApp”. '
              'On the WhatsApp share sheet choose “Status” to post it.',
              style: TextStyle(
                color: Color(0xFF1B5E20),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
