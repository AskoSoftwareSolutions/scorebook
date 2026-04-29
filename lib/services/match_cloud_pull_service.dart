import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../repositories/match_repository.dart';

/// Pulls a completed (or in-progress) match from Firebase Realtime DB
/// into local SQLite. Used when:
///
///   1. A scorer's device opens history, but the match was finished by
///      another device (innings 2 was scored elsewhere) → local DB has
///      stale or no rows for innings 2.
///   2. A new device wants to see a match it never scored at all.
///
/// The pull is *idempotent* — repeated pulls upsert into the same local
/// row, keyed via SharedPreferences `cloud_match_<matchCode>` → local id.
class MatchCloudPullService {
  static final MatchCloudPullService _i = MatchCloudPullService._();
  factory MatchCloudPullService() => _i;
  MatchCloudPullService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final MatchRepository _repo = MatchRepository();

  static const _kPrefix  = 'cloud_match_';        // matchCode → local id
  static const _kReverse = 'local_to_cloud_';     // local id  → matchCode
  static const _kIndex   = 'cloud_match_codes';   // list of all cloud codes

  Future<void> _ensureAuth() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (_) {}
  }

  /// Returns the local match id (existing or newly created) after pulling
  /// /matches/{matchCode} into SQLite. Returns null on failure.
  Future<int?> pullIntoLocal(String matchCode) async {
    if (matchCode.trim().isEmpty) return null;
    try {
      await _ensureAuth();
      final snap = await _db.ref('matches/$matchCode').get();
      if (!snap.exists) return null;
      final data = Map<String, dynamic>.from(snap.value as Map);

      final teamA      = (data['teamA']      as String?) ?? 'Team A';
      final teamB      = (data['teamB']      as String?) ?? 'Team B';
      final totalOvers = (data['totalOvers'] as int?)    ?? 20;
      final status     = (data['status']     as String?) ?? 'in_progress';
      final result     = (data['result']     as String?);
      final currentBattingTeam = (data['battingTeam'] as String?) ?? teamA;
      final currentBowlingTeam = (data['bowlingTeam'] as String?) ??
          (currentBattingTeam == teamA ? teamB : teamA);
      final currentInn = (data['currentInnings'] as int?) ?? 1;
      final updatedAtMs = (data['updatedAt'] as int?) ??
          DateTime.now().millisecondsSinceEpoch;

      // ── Innings 1 totals from match meta ────────────────────────────────
      final teamAScore   = (data['teamAScore']   as int?) ?? 0;
      final teamAWickets = (data['teamAWickets'] as int?) ?? 0;
      final teamBScore   = (data['teamBScore']   as int?) ?? 0;
      final teamBWickets = (data['teamBWickets'] as int?) ?? 0;
      // teamABalls/teamBBalls aren't pushed today; derive from rosters.

      // ── Resolve which team batted FIRST ────────────────────────────────
      // After a takeover or match completion, the cloud's `battingTeam`
      // field reflects whoever is *currently* batting (or batted last).
      // For innings 1 we must invert when currentInnings >= 2.
      final inn1BattingTeam =
          currentInn >= 2 ? currentBowlingTeam : currentBattingTeam;
      final inn1BowlingTeam =
          currentInn >= 2 ? currentBattingTeam : currentBowlingTeam;

      // ── Find or create local match row ──────────────────────────────────
      final p = await SharedPreferences.getInstance();
      int? localId = p.getInt(_kPrefix + matchCode);
      MatchModel? existingMatch;
      if (localId != null) {
        existingMatch = await _repo.getMatch(localId);
      }

      // Prefer the higher of cloud-vs-local for innings totals so that
      // a takeover snapshot (which may zero-out the other innings) never
      // wipes the authoritative local figures.
      int _max(int a, int b) => a > b ? a : b;
      final mergedAScore   = _max(teamAScore,   existingMatch?.teamAScore   ?? 0);
      final mergedAWickets = _max(teamAWickets, existingMatch?.teamAWickets ?? 0);
      final mergedBScore   = _max(teamBScore,   existingMatch?.teamBScore   ?? 0);
      final mergedBWickets = _max(teamBWickets, existingMatch?.teamBWickets ?? 0);

      final matchModel = MatchModel(
        id: localId,
        teamAName: teamA,
        teamBName: teamB,
        totalOvers: totalOvers,
        tossWinner: teamA,
        battingFirst: inn1BattingTeam,
        matchDate: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
        status: status,
        result: result,
        teamAScore:   mergedAScore,
        teamAWickets: mergedAWickets,
        teamBScore:   mergedBScore,
        teamBWickets: mergedBWickets,
        currentInnings: (data['currentInnings'] as int?) ?? 1,
      );

      if (localId == null) {
        localId = await _repo.createMatch(matchModel);
        await p.setInt(_kPrefix + matchCode, localId);
        await p.setString('$_kReverse$localId', matchCode);
        final list = p.getStringList(_kIndex) ?? [];
        if (!list.contains(matchCode)) {
          list.add(matchCode);
          await p.setStringList(_kIndex, list);
        }
      } else {
        await _repo.updateMatch(matchModel);
        await p.setString('$_kReverse$localId', matchCode);
      }

      // ── Wipe + repopulate child rows (idempotent) ───────────────────────
      // Players: cloud rosterA/rosterB is the source of truth — re-create.
      final existingPlayers = await _repo.getPlayersByMatch(localId);
      for (final pl in existingPlayers) {
        if (pl.id != null) await _repo.deletePlayer(pl.id!);
      }
      final existingInn1 = await _repo.getInnings(localId, 1);
      final existingInn2 = await _repo.getInnings(localId, 2);

      // Balls: only wipe innings whose cloud actually contains balls.
      // Otherwise we'd nuke the local authoritative ball-by-ball that this
      // device originally scored (e.g. innings 1 on Phone A) when the cloud
      // snapshot we just downloaded was pushed by another device that only
      // re-pushed innings 2.
      final cloudBalls = (data['balls'] as List?) ?? [];
      bool _cloudHasInn(int n) => cloudBalls.any((b) {
            final m = Map<String, dynamic>.from(b as Map);
            return ((m['innings'] as int?) ?? 1) == n;
          });
      if (_cloudHasInn(1)) {
        final existingBalls1 = await _repo.getBallsByInnings(localId, 1);
        for (final b in existingBalls1) {
          if (b.id != null) await _repo.deleteBall(b.id!);
        }
      }
      if (_cloudHasInn(2)) {
        final existingBalls2 = await _repo.getBallsByInnings(localId, 2);
        for (final b in existingBalls2) {
          if (b.id != null) await _repo.deleteBall(b.id!);
        }
      }

      // ── Players: rosterA + rosterB ──────────────────────────────────────
      Future<void> _importRoster(String teamName, List<dynamic>? roster) async {
        if (roster == null) return;
        for (int i = 0; i < roster.length; i++) {
          final r = Map<String, dynamic>.from(roster[i] as Map);
          final name = (r['name'] as String? ?? '').trim();
          if (name.isEmpty) continue;
          await _repo.createPlayer(PlayerModel(
            matchId: localId!,
            teamName: teamName,
            name: name,
            orderIndex: (r['orderIndex'] as int?) ?? i,
            runsScored:  (r['runsScored']  as int?) ?? (r['runs']  as int?) ?? 0,
            ballsFaced:  (r['ballsFaced']  as int?) ?? (r['balls'] as int?) ?? 0,
            fours:       (r['fours']       as int?) ?? 0,
            sixes:       (r['sixes']       as int?) ?? 0,
            isOut:       (r['isOut']       as bool?) ?? false,
            wicketType:  _emptyToNull(r['wicketType'] as String?),
            dismissedBy: _emptyToNull(r['dismissedBy'] as String?),
            bowlerName:  _emptyToNull(r['bowlerName']  as String?),
            didBat:      (r['didBat']      as bool?) ?? false,
            ballsBowled: (r['ballsBowled'] as int?)  ?? 0,
            runsConceded:(r['runsConceded']as int?)  ?? 0,
            wicketsTaken:(r['wicketsTaken']as int?)  ?? 0,
            wides:       (r['wides']       as int?)  ?? 0,
            noBalls:     (r['noBalls']     as int?)  ?? 0,
          ));
        }
      }
      await _importRoster(teamA, data['rosterA'] as List?);
      await _importRoster(teamB, data['rosterB'] as List?);

      // ── Balls log ───────────────────────────────────────────────────────
      final ballsList = cloudBalls;
      for (final b in ballsList) {
        final m = Map<String, dynamic>.from(b as Map);
        final innings = (m['innings'] as int?) ?? 1;
        final isWide   = (m['isWide']   as bool?) ?? false;
        final isNoBall = (m['isNoBall'] as bool?) ?? false;
        final isBye    = (m['isBye']    as bool?) ?? false;
        final isLegBye = (m['isLegBye'] as bool?) ?? false;
        await _repo.addBall(BallModel(
          matchId: localId,
          innings: innings,
          overNumber: (m['over'] as int?) ?? 0,
          ballNumber: (m['ball'] as int?) ?? 1,
          batsmanName: (m['batsman'] as String?) ?? '',
          bowlerName:  (m['bowler']  as String?) ?? '',
          runs:        (m['runs']    as int?)    ?? 0,
          isWide: isWide,
          isNoBall: isNoBall,
          isBye: isBye,
          isLegBye: isLegBye,
          isWicket:        (m['isWicket']    as bool?)   ?? false,
          wicketType:      _emptyToNull(m['wicketType']  as String?),
          outBatsmanName:  _emptyToNull(m['outBatsman']  as String?),
          fielderName:     _emptyToNull(m['fielder']     as String?),
          extraRuns:  ((m['total'] as int?) ?? 0) - ((m['runs'] as int?) ?? 0),
          totalRuns:  (m['total'] as int?) ?? 0,
          isValid:    (m['isValid'] as bool?) ?? !(isWide || isNoBall),
        ));
      }

      // ── Innings rows: derive totals from balls & roster ─────────────────
      Future<void> _upsertInnings(
        int inningsNum,
        String battingTeamName,
        String bowlingTeamName,
        InningsModel? existing,
      ) async {
        // Sum of valid balls for the innings = totalBalls
        final innBalls = await _repo.getBallsByInnings(localId!, inningsNum);
        int totalRuns = 0;
        int totalBalls = 0;
        int wides = 0, noBalls = 0, byes = 0, legByes = 0, wickets = 0;
        for (final b in innBalls) {
          totalRuns += b.totalRuns;
          if (b.isValid) totalBalls++;
          if (b.isWide)   wides++;
          if (b.isNoBall) noBalls++;
          if (b.isBye)    byes++;
          if (b.isLegBye) legByes++;
          if (b.isWicket) wickets++;
        }
        // Fall back to roster + match meta when balls log was empty.
        // Order of preference: balls log → match meta totals → roster sum.
        if (totalRuns == 0) {
          final metaRuns = battingTeamName == teamA ? teamAScore : teamBScore;
          final metaWkts = battingTeamName == teamA ? teamAWickets : teamBWickets;
          if (metaRuns > 0 || metaWkts > 0) {
            totalRuns = metaRuns;
            wickets = metaWkts;
          } else {
            // Roster fallback — sum runsScored across the batting roster
            final List? roster = battingTeamName == teamA
                ? (data['rosterA'] as List?)
                : (data['rosterB'] as List?);
            if (roster != null) {
              int rRuns = 0, rWkts = 0, rBalls = 0;
              for (final r in roster) {
                final m = Map<String, dynamic>.from(r as Map);
                rRuns += ((m['runsScored'] as int?) ??
                    (m['runs'] as int?) ?? 0);
                rBalls += ((m['ballsFaced'] as int?) ??
                    (m['balls'] as int?) ?? 0);
                if ((m['isOut'] as bool?) ?? false) rWkts++;
              }
              if (rRuns > 0 || rWkts > 0) {
                totalRuns = rRuns;
                wickets = rWkts;
                if (totalBalls == 0) totalBalls = rBalls;
              }
            }
          }
        }
        final isCompleted = inningsNum == 1
            ? (data['currentInnings'] as int? ?? 1) >= 2
            : status == 'completed';
        final inn = InningsModel(
          id: existing?.id,
          matchId: localId,
          inningsNumber: inningsNum,
          battingTeam: battingTeamName,
          bowlingTeam: bowlingTeamName,
          totalRuns: totalRuns,
          totalWickets: wickets,
          totalBalls: totalBalls,
          wides: wides,
          noBalls: noBalls,
          byes: byes,
          legByes: legByes,
          isCompleted: isCompleted,
        );
        if (existing == null) {
          await _repo.createInnings(inn);
        } else {
          await _repo.updateInnings(inn);
        }
      }

      await _upsertInnings(1, inn1BattingTeam, inn1BowlingTeam, existingInn1);
      // Innings 2 only if it has been started (currentInnings == 2 OR completed)
      final inn2Started = ((data['currentInnings'] as int?) ?? 1) >= 2;
      if (inn2Started) {
        await _upsertInnings(2, inn1BowlingTeam, inn1BattingTeam, existingInn2);
      }

      return localId;
    } catch (_) {
      return null;
    }
  }

  /// Best-effort lookup of an already-pulled local id for [matchCode].
  Future<int?> localIdFor(String matchCode) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kPrefix + matchCode);
  }

  /// Reverse lookup — given a local match id, return the cloud match
  /// code (if this match was scored / pulled in online mode), else null.
  Future<String?> cloudCodeFor(int localId) async {
    final p = await SharedPreferences.getInstance();
    return p.getString('$_kReverse$localId');
  }

  /// Manually bind a local match id to a cloud match code. Called by
  /// LiveScoringViewModel when a match goes online so that a later
  /// summary-view open can transparently pull fresh innings 2 data even
  /// if the second innings was scored on a different device.
  Future<void> bindLocalToCloud(int localId, String matchCode) async {
    if (matchCode.trim().isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kPrefix + matchCode, localId);
    await p.setString('$_kReverse$localId', matchCode);
    final list = p.getStringList(_kIndex) ?? [];
    if (!list.contains(matchCode)) {
      list.add(matchCode);
      await p.setStringList(_kIndex, list);
    }
  }

  /// All match codes this device has previously pulled.
  Future<List<String>> pulledCodes() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_kIndex) ?? [];
  }

  String? _emptyToNull(String? s) => (s == null || s.isEmpty) ? null : s;
}
