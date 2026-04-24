import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

/// Handles all Firebase Realtime Database sync for Online Mode.
///
/// Data structure at: /matches/{matchCode}/
///   ├── meta/         — match info + password hash
///   ├── live/         — current live state (score, batsmen, bowler)
///   ├── innings/      — all innings summaries
///   ├── batters/      — batting scorecard (all players)
///   ├── bowlers/      — bowling figures
///   └── balls/        — FULL ball-by-ball log (all balls, no truncation)
class FirebaseSyncService {
  static final FirebaseSyncService _instance = FirebaseSyncService._();
  factory FirebaseSyncService() => _instance;
  FirebaseSyncService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // ── Write: Push full live snapshot ───────────────────────────────────────

  // ── Ensure we have Firebase Auth (anonymous) so DB writes work ────────────
  Future<void> _ensureAuth() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (_) {}
  }

  Future<void> pushLiveSnapshot({
    required String matchCode,
    required String passwordHash,
    required MatchModel match,
    required InningsModel innings,
    required List<PlayerModel> players,
    required List<BallModel> allBalls,
    required String? strikerName,
    required String? nonStrikerName,
    required String? bowlerName,
    required int currentOver,
    required int ballsInOver,
    String? tournamentId,
    String? tournamentMatchId,
  }) async {
    try {
      await _ensureAuth(); // ← ensure authenticated before write
      final ref = _db.ref('matches/$matchCode');
      final battingTeam = innings.battingTeam;
      final bowlingTeam = innings.bowlingTeam;

      // ── Batting scorecard (all batting team players) ─────────────────────
      final batters = players
          .where((p) => p.teamName == battingTeam)
          .map((p) => {
        'name': p.name,
        'runs': p.runsScored,
        'balls': p.ballsFaced,
        'fours': p.fours,
        'sixes': p.sixes,
        'isOut': p.isOut,
        'wicketType': p.wicketType ?? '',
        'bowlerName': p.bowlerName ?? '',
        'fielderName': p.dismissedBy ?? '',
        'isStriker': p.name == strikerName,
        'isNonStriker': p.name == nonStrikerName,
        'isBatting': p.isBatting,
        'didBat': p.didBat,
        'orderIndex': p.orderIndex,
      })
          .toList()
        ..sort((a, b) =>
            (a['orderIndex'] as int).compareTo(b['orderIndex'] as int));

      // ── Bowling figures (all players who bowled) ─────────────────────────
      final bowlers = players
          .where((p) => p.teamName == bowlingTeam && p.ballsBowled > 0)
          .map((p) => {
        'name': p.name,
        'balls': p.ballsBowled,
        'runs': p.runsConceded,
        'wickets': p.wicketsTaken,
        'wides': p.wides,
        'noBalls': p.noBalls,
        'isBowling': p.name == bowlerName,
      })
          .toList()
        ..sort((a, b) => (b['balls'] as int).compareTo(a['balls'] as int));

      // ── Full roster for each team (for join-as-scorer & cross-innings view)
      Map<String, dynamic> _rosterEntry(PlayerModel p) => {
        'name': p.name,
        'orderIndex': p.orderIndex,
        'runsScored': p.runsScored,
        'ballsFaced': p.ballsFaced,
        'fours': p.fours,
        'sixes': p.sixes,
        'isOut': p.isOut,
        'wicketType': p.wicketType ?? '',
        'dismissedBy': p.dismissedBy ?? '',
        'bowlerName': p.bowlerName ?? '',
        'didBat': p.didBat,
        'ballsBowled': p.ballsBowled,
        'runsConceded': p.runsConceded,
        'wicketsTaken': p.wicketsTaken,
        'wides': p.wides,
        'noBalls': p.noBalls,
      };
      final rosterA = players
          .where((p) => p.teamName == match.teamAName)
          .map(_rosterEntry)
          .toList()
        ..sort((a, b) =>
            (a['orderIndex'] as int).compareTo(b['orderIndex'] as int));
      final rosterB = players
          .where((p) => p.teamName == match.teamBName)
          .map(_rosterEntry)
          .toList()
        ..sort((a, b) =>
            (a['orderIndex'] as int).compareTo(b['orderIndex'] as int));

      // ── FULL ball-by-ball log ─────────────────────────────────────────────
      final ballLog = allBalls
          .map((b) => {
        'over': b.overNumber,
        'ball': b.ballNumber,
        'runs': b.runs,
        'total': b.totalRuns,
        'isWide': b.isWide,
        'isNoBall': b.isNoBall,
        'isBye': b.isBye,
        'isLegBye': b.isLegBye,
        'isWicket': b.isWicket,
        'wicketType': b.wicketType ?? '',
        'outBatsman': b.outBatsmanName ?? '',
        'fielder': b.fielderName ?? '',
        'batsman': b.batsmanName,
        'bowler': b.bowlerName,
        'isValid': b.isValid,
        'innings': b.innings,
      })
          .toList();

      // ── Current over balls only ───────────────────────────────────────────
      final currentOverBalls = allBalls
          .where((b) =>
      b.innings == innings.inningsNumber &&
          b.overNumber == currentOver)
          .map((b) => {
        'runs': b.runs,
        'total': b.totalRuns,
        'isWide': b.isWide,
        'isNoBall': b.isNoBall,
        'isWicket': b.isWicket,
        'isBye': b.isBye,
        'isLegBye': b.isLegBye,
        'isValid': b.isValid,
      })
          .toList();

      // ── Partnership (runs since last wicket) ─────────────────────────────
      int lastWicketIdx = -1;
      for (int i = allBalls.length - 1; i >= 0; i--) {
        if (allBalls[i].isWicket) {
          lastWicketIdx = i;
          break;
        }
      }
      final partnerBalls = allBalls.sublist(lastWicketIdx + 1);
      final partnerRuns = partnerBalls.fold(0, (s, b) => s + b.totalRuns);
      final partnerBallsCount = partnerBalls.where((b) => b.isValid).length;

      // ── Run rate ──────────────────────────────────────────────────────────
      final double crr = innings.totalBalls > 0
          ? (innings.totalRuns * 6.0 / innings.totalBalls)
          : 0.0;
      final int inn1Score = innings.inningsNumber == 2
          ? (innings.bowlingTeam == match.teamAName
          ? (match.teamAScore ?? 0)
          : (match.teamBScore ?? 0))
          : 0;
      final int inn1Wickets = innings.inningsNumber == 2
          ? (innings.bowlingTeam == match.teamAName
          ? (match.teamAWickets ?? 0)
          : (match.teamBWickets ?? 0))
          : 0;
      final int inn1Balls = innings.inningsNumber == 2
          ? (innings.bowlingTeam == match.teamAName
          ? (match.teamABalls ?? 0)
          : (match.teamBBalls ?? 0))
          : 0;
      final int target = inn1Score + 1;
      final int runsNeeded = target - innings.totalRuns;
      final int ballsLeft = match.totalOvers * 6 - innings.totalBalls;
      final double rrr = (innings.inningsNumber == 2 && ballsLeft > 0)
          ? (runsNeeded * 6.0 / ballsLeft)
          : 0.0;

      await ref.set({
        // ── Auth ──────────────────────────────────────────────────────────
        'passwordHash': passwordHash,

        // ── Match meta ────────────────────────────────────────────────────
        'matchCode': matchCode,
        'teamA': match.teamAName,
        'teamB': match.teamBName,
        'totalOvers': match.totalOvers,
        'status': match.status,

        // ── Tournament linkage (optional) ────────────────────────────────
        if (tournamentId != null && tournamentId.isNotEmpty)
          'tournamentId': tournamentId,
        if (tournamentMatchId != null && tournamentMatchId.isNotEmpty)
          'tournamentMatchId': tournamentMatchId,

        // ── Current innings live state ────────────────────────────────────
        'currentInnings': innings.inningsNumber,
        'battingTeam': battingTeam,
        'bowlingTeam': bowlingTeam,
        'score': innings.totalRuns,
        'wickets': innings.totalWickets,
        'totalBalls': innings.totalBalls,
        'wides': innings.wides,
        'noBalls': innings.noBalls,
        'byes': innings.byes,
        'legByes': innings.legByes,
        'currentOver': currentOver,
        'ballsInOver': ballsInOver,
        'currentOverBalls': currentOverBalls,
        'striker': strikerName ?? '',
        'nonStriker': nonStrikerName ?? '',
        'bowler': bowlerName ?? '',

        // ── Stats ─────────────────────────────────────────────────────────
        'crr': double.parse(crr.toStringAsFixed(2)),
        'rrr': double.parse(rrr.toStringAsFixed(2)),
        'target': innings.inningsNumber == 2 ? target : 0,
        'runsNeeded': innings.inningsNumber == 2 ? runsNeeded : 0,
        'ballsLeft': innings.inningsNumber == 2 ? ballsLeft : 0,
        'inn1Score': inn1Score,
        'inn1Wickets': inn1Wickets,
        'inn1Balls': inn1Balls,

        // ── Partnership ───────────────────────────────────────────────────
        'partnerRuns': partnerRuns,
        'partnerBalls': partnerBallsCount,

        // ── Scorecards ────────────────────────────────────────────────────
        'batters': batters,
        'bowlers': bowlers,

        // ── Full rosters (used by join-as-scorer) ────────────────────────
        'rosterA': rosterA,
        'rosterB': rosterB,

        // ── Full ball log ─────────────────────────────────────────────────
        'balls': ballLog,

        'updatedAt': ServerValue.timestamp,
      });
    } catch (e) {
      // ignore: avoid_print
      print('[FirebaseSync] pushLiveSnapshot error: $e');
    }
  }

  /// Get full match data for Team B to start scoring
  Future<Map<String, dynamic>?> getMatchData(String matchCode) async {
    try {
      await _ensureAuth();
      final snap = await _db.ref('matches/$matchCode').get();
      if (!snap.exists) return null;
      return Map<String, dynamic>.from(snap.value as Map);
    } catch (_) {
      return null;
    }
  }

  /// Mark match as completed in Firebase
  Future<void> markMatchCompleted({
    required String matchCode,
    required String result,
    required MatchModel match,
  }) async {
    try {
      await _db.ref('matches/$matchCode').update({
        'status': 'completed',
        'result': result,
        'teamAScore': match.teamAScore ?? 0,
        'teamAWickets': match.teamAWickets ?? 0,
        'teamBScore': match.teamBScore ?? 0,
        'teamBWickets': match.teamBWickets ?? 0,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (_) {}
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  Stream<DatabaseEvent> liveStream(String matchCode) =>
      _db.ref('matches/$matchCode').onValue;

  Future<bool> matchExists(String matchCode) async {
    try {
      final snap = await _db.ref('matches/$matchCode').get();
      return snap.exists;
    } catch (_) {
      return false;
    }
  }

  /// Verify password — returns true if hash matches stored hash
  Future<bool> verifyPassword(String matchCode, String inputHash) async {
    try {
      final snap = await _db.ref('matches/$matchCode/passwordHash').get();
      if (!snap.exists) return true; // no password set
      return snap.value == inputHash;
    } catch (_) {
      return false;
    }
  }
}