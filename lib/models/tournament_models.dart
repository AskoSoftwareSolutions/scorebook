// ─────────────────────────────────────────────────────────────────────────────
// lib/models/tournament_models.dart
//
// Tournament domain models. All stored in Firestore:
//   tournaments/{tournamentId}
//     ├─ teams/{teamId}
//     └─ matches/{matchId}
//
// CHANGES IN THIS VERSION:
//   - Added `venue` field to TournamentModel
//   - Added placeholder helpers to TournamentMatchModel (WINNER_OF:/LOSER_OF:)
//   - Updated copyWith() to support team field changes (for placeholder resolution)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────

enum TournamentFormat {
  knockout,   // loser out, winner advances
  random,     // random pairing of teams
  manual,     // admin picks pairs
}

extension TournamentFormatX on TournamentFormat {
  String get label {
    switch (this) {
      case TournamentFormat.knockout: return 'Knockout';
      case TournamentFormat.random:   return 'Random Pairing';
      case TournamentFormat.manual:   return 'Manual Pairing';
    }
  }

  String get value => name; // 'knockout', 'random', 'manual'

  static TournamentFormat fromValue(String v) {
    return TournamentFormat.values.firstWhere(
          (f) => f.name == v,
      orElse: () => TournamentFormat.knockout,
    );
  }
}

enum TournamentStatus { setup, active, completed }

extension TournamentStatusX on TournamentStatus {
  String get value => name;
  static TournamentStatus fromValue(String v) {
    return TournamentStatus.values.firstWhere(
          (s) => s.name == v,
      orElse: () => TournamentStatus.setup,
    );
  }
}

enum UmpireMode { auto, manual }

extension UmpireModeX on UmpireMode {
  String get value => name;
  String get label => this == UmpireMode.auto ? 'Auto-assign' : 'Manual';
  static UmpireMode fromValue(String v) {
    return UmpireMode.values.firstWhere(
          (m) => m.name == v,
      orElse: () => UmpireMode.auto,
    );
  }
}

enum TournamentMatchStatus {
  scheduled,    // time set, waiting
  tossPending,  // 20-min reminder fired, waiting for toss
  inProgress,   // match started, live scoring active
  completed,    // match done
}

extension TournamentMatchStatusX on TournamentMatchStatus {
  String get value {
    switch (this) {
      case TournamentMatchStatus.scheduled:   return 'scheduled';
      case TournamentMatchStatus.tossPending: return 'toss_pending';
      case TournamentMatchStatus.inProgress:  return 'in_progress';
      case TournamentMatchStatus.completed:   return 'completed';
    }
  }

  static TournamentMatchStatus fromValue(String v) {
    switch (v) {
      case 'scheduled':    return TournamentMatchStatus.scheduled;
      case 'toss_pending': return TournamentMatchStatus.tossPending;
      case 'in_progress':  return TournamentMatchStatus.inProgress;
      case 'completed':    return TournamentMatchStatus.completed;
      default:             return TournamentMatchStatus.scheduled;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TournamentModel
// ─────────────────────────────────────────────────────────────────────────────

class TournamentModel {
  final String id;
  final String name;
  final String venue;                    // ← NEW: tournament venue
  final TournamentFormat format;
  final TournamentStatus status;
  final UmpireMode umpireMode;           // default for all matches
  final int totalOvers;                  // default overs per match
  final String createdBy;                // phone number or uid
  final DateTime createdAt;
  final DateTime? completedAt;

  const TournamentModel({
    required this.id,
    required this.name,
    this.venue = '',                     // ← NEW: default empty
    required this.format,
    required this.status,
    required this.umpireMode,
    required this.totalOvers,
    required this.createdBy,
    required this.createdAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'venue': venue,                          // ← NEW
    'format': format.value,
    'status': status.value,
    'umpireMode': umpireMode.value,
    'totalOvers': totalOvers,
    'createdBy': createdBy,
    'createdAt': Timestamp.fromDate(createdAt),
    if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
  };

  factory TournamentModel.fromMap(Map<String, dynamic> m) => TournamentModel(
    id:          m['id']          as String,
    name:        m['name']        as String,
    venue:       m['venue']       as String? ?? '',  // ← NEW, backward compat
    format:      TournamentFormatX.fromValue(m['format'] as String? ?? ''),
    status:      TournamentStatusX.fromValue(m['status'] as String? ?? ''),
    umpireMode:  UmpireModeX.fromValue(m['umpireMode'] as String? ?? ''),
    totalOvers:  m['totalOvers']  as int? ?? 20,
    createdBy:   m['createdBy']   as String? ?? '',
    createdAt:   (m['createdAt']  as Timestamp).toDate(),
    completedAt: (m['completedAt'] as Timestamp?)?.toDate(),
  );

  TournamentModel copyWith({
    String? name,
    String? venue,                                 // ← NEW
    TournamentFormat? format,
    TournamentStatus? status,
    UmpireMode? umpireMode,
    int? totalOvers,
    DateTime? completedAt,
  }) =>
      TournamentModel(
        id:          id,
        name:        name        ?? this.name,
        venue:       venue       ?? this.venue,    // ← NEW
        format:      format      ?? this.format,
        status:      status      ?? this.status,
        umpireMode:  umpireMode  ?? this.umpireMode,
        totalOvers:  totalOvers  ?? this.totalOvers,
        createdBy:   createdBy,
        createdAt:   createdAt,
        completedAt: completedAt ?? this.completedAt,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TournamentTeamModel
// ─────────────────────────────────────────────────────────────────────────────

class TournamentTeamModel {
  final String id;
  final String tournamentId;
  final String name;
  final String? logoUrl;        // Firebase Storage URL, null if no logo
  final List<String> players;
  final int orderIndex;         // display order

  // Match stats (computed — updated as matches complete)
  final int matchesPlayed;
  final int matchesWon;
  final int matchesLost;
  final bool eliminated;        // for knockout format

  const TournamentTeamModel({
    required this.id,
    required this.tournamentId,
    required this.name,
    this.logoUrl,
    this.players = const [],
    this.orderIndex = 0,
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.matchesLost = 0,
    this.eliminated = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'tournamentId': tournamentId,
    'name': name,
    'logoUrl': logoUrl,
    'players': players,
    'orderIndex': orderIndex,
    'matchesPlayed': matchesPlayed,
    'matchesWon': matchesWon,
    'matchesLost': matchesLost,
    'eliminated': eliminated,
  };

  factory TournamentTeamModel.fromMap(Map<String, dynamic> m) =>
      TournamentTeamModel(
        id:             m['id']             as String,
        tournamentId:   m['tournamentId']   as String,
        name:           m['name']           as String,
        logoUrl:        m['logoUrl']        as String?,
        players:        List<String>.from(m['players'] as List? ?? []),
        orderIndex:     m['orderIndex']     as int? ?? 0,
        matchesPlayed:  m['matchesPlayed']  as int? ?? 0,
        matchesWon:     m['matchesWon']     as int? ?? 0,
        matchesLost:    m['matchesLost']    as int? ?? 0,
        eliminated:     m['eliminated']     as bool? ?? false,
      );

  TournamentTeamModel copyWith({
    String? name,
    String? logoUrl,
    List<String>? players,
    int? orderIndex,
    int? matchesPlayed,
    int? matchesWon,
    int? matchesLost,
    bool? eliminated,
  }) =>
      TournamentTeamModel(
        id:            id,
        tournamentId:  tournamentId,
        name:          name          ?? this.name,
        logoUrl:       logoUrl       ?? this.logoUrl,
        players:       players       ?? this.players,
        orderIndex:    orderIndex    ?? this.orderIndex,
        matchesPlayed: matchesPlayed ?? this.matchesPlayed,
        matchesWon:    matchesWon    ?? this.matchesWon,
        matchesLost:   matchesLost   ?? this.matchesLost,
        eliminated:    eliminated    ?? this.eliminated,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TournamentMatchModel
// ─────────────────────────────────────────────────────────────────────────────

class TournamentMatchModel {
  final String id;
  final String tournamentId;

  // Teams — for knockout future rounds, may contain placeholders like
  // "WINNER_OF:<matchId>" until resolved
  final String teamAId;
  final String teamAName;
  final String teamBId;
  final String teamBName;

  // Umpire
  final UmpireMode umpireMode;
  final String? umpireTeamId;
  final String? umpireTeamName;

  // Schedule
  final DateTime scheduledTime;
  final DateTime? notifiedAt;

  // Status
  final TournamentMatchStatus status;

  // Toss
  final String? tossWinnerTeamId;
  final String? tossWinnerTeamName;
  final String? battingFirstTeamId;
  final String? battingFirstTeamName;

  // Link to local SQLite match
  final int? liveMatchId;

  // Result
  final String? winnerTeamId;
  final String? winnerTeamName;
  final String? resultText;
  final int? totalOvers;

  // Knockout / round tracking
  final int round;
  final int orderIndex;

  const TournamentMatchModel({
    required this.id,
    required this.tournamentId,
    required this.teamAId,
    required this.teamAName,
    required this.teamBId,
    required this.teamBName,
    required this.umpireMode,
    this.umpireTeamId,
    this.umpireTeamName,
    required this.scheduledTime,
    this.notifiedAt,
    required this.status,
    this.tossWinnerTeamId,
    this.tossWinnerTeamName,
    this.battingFirstTeamId,
    this.battingFirstTeamName,
    this.liveMatchId,
    this.winnerTeamId,
    this.winnerTeamName,
    this.resultText,
    this.totalOvers,
    this.round = 1,
    this.orderIndex = 0,
  });

  Map<String, dynamic> toMap() => {
    'id':                   id,
    'tournamentId':         tournamentId,
    'teamAId':              teamAId,
    'teamAName':            teamAName,
    'teamBId':              teamBId,
    'teamBName':            teamBName,
    'umpireMode':           umpireMode.value,
    'umpireTeamId':         umpireTeamId,
    'umpireTeamName':       umpireTeamName,
    'scheduledTime':        Timestamp.fromDate(scheduledTime),
    'notifiedAt':           notifiedAt != null ? Timestamp.fromDate(notifiedAt!) : null,
    'status':               status.value,
    'tossWinnerTeamId':     tossWinnerTeamId,
    'tossWinnerTeamName':   tossWinnerTeamName,
    'battingFirstTeamId':   battingFirstTeamId,
    'battingFirstTeamName': battingFirstTeamName,
    'liveMatchId':          liveMatchId,
    'winnerTeamId':         winnerTeamId,
    'winnerTeamName':       winnerTeamName,
    'resultText':           resultText,
    'totalOvers':           totalOvers,
    'round':                round,
    'orderIndex':           orderIndex,
  };

  factory TournamentMatchModel.fromMap(Map<String, dynamic> m) =>
      TournamentMatchModel(
        id:                   m['id']                   as String,
        tournamentId:         m['tournamentId']         as String,
        teamAId:              m['teamAId']              as String,
        teamAName:            m['teamAName']            as String,
        teamBId:              m['teamBId']              as String,
        teamBName:            m['teamBName']            as String,
        umpireMode:           UmpireModeX.fromValue(m['umpireMode'] as String? ?? ''),
        umpireTeamId:         m['umpireTeamId']         as String?,
        umpireTeamName:       m['umpireTeamName']       as String?,
        scheduledTime:        (m['scheduledTime']       as Timestamp).toDate(),
        notifiedAt:           (m['notifiedAt']          as Timestamp?)?.toDate(),
        status:               TournamentMatchStatusX.fromValue(m['status'] as String? ?? ''),
        tossWinnerTeamId:     m['tossWinnerTeamId']     as String?,
        tossWinnerTeamName:   m['tossWinnerTeamName']   as String?,
        battingFirstTeamId:   m['battingFirstTeamId']   as String?,
        battingFirstTeamName: m['battingFirstTeamName'] as String?,
        liveMatchId:          m['liveMatchId']          as int?,
        winnerTeamId:         m['winnerTeamId']         as String?,
        winnerTeamName:       m['winnerTeamName']       as String?,
        resultText:           m['resultText']           as String?,
        totalOvers:           m['totalOvers']           as int?,
        round:                m['round']                as int? ?? 1,
        orderIndex:           m['orderIndex']           as int? ?? 0,
      );

  // ── copyWith — now supports team field changes for placeholder resolution ──
  TournamentMatchModel copyWith({
    String? teamAId,
    String? teamAName,
    String? teamBId,
    String? teamBName,
    UmpireMode? umpireMode,
    String? umpireTeamId,
    String? umpireTeamName,
    DateTime? scheduledTime,
    DateTime? notifiedAt,
    TournamentMatchStatus? status,
    String? tossWinnerTeamId,
    String? tossWinnerTeamName,
    String? battingFirstTeamId,
    String? battingFirstTeamName,
    int? liveMatchId,
    String? winnerTeamId,
    String? winnerTeamName,
    String? resultText,
    int? totalOvers,
  }) =>
      TournamentMatchModel(
        id:                   id,
        tournamentId:         tournamentId,
        teamAId:              teamAId              ?? this.teamAId,
        teamAName:            teamAName            ?? this.teamAName,
        teamBId:              teamBId              ?? this.teamBId,
        teamBName:            teamBName            ?? this.teamBName,
        umpireMode:           umpireMode           ?? this.umpireMode,
        umpireTeamId:         umpireTeamId         ?? this.umpireTeamId,
        umpireTeamName:       umpireTeamName       ?? this.umpireTeamName,
        scheduledTime:        scheduledTime        ?? this.scheduledTime,
        notifiedAt:           notifiedAt           ?? this.notifiedAt,
        status:               status               ?? this.status,
        tossWinnerTeamId:     tossWinnerTeamId     ?? this.tossWinnerTeamId,
        tossWinnerTeamName:   tossWinnerTeamName   ?? this.tossWinnerTeamName,
        battingFirstTeamId:   battingFirstTeamId   ?? this.battingFirstTeamId,
        battingFirstTeamName: battingFirstTeamName ?? this.battingFirstTeamName,
        liveMatchId:          liveMatchId          ?? this.liveMatchId,
        winnerTeamId:         winnerTeamId         ?? this.winnerTeamId,
        winnerTeamName:       winnerTeamName       ?? this.winnerTeamName,
        resultText:           resultText           ?? this.resultText,
        totalOvers:           totalOvers           ?? this.totalOvers,
        round:                round,
        orderIndex:           orderIndex,
      );

  // ── Convenience getters ────────────────────────────────────────────────────
  bool get isScheduled   => status == TournamentMatchStatus.scheduled;
  bool get isTossPending => status == TournamentMatchStatus.tossPending;
  bool get isInProgress  => status == TournamentMatchStatus.inProgress;
  bool get isCompleted   => status == TournamentMatchStatus.completed;

  Duration get timeUntilStart => scheduledTime.difference(DateTime.now());
  bool get isStartingSoon =>
      timeUntilStart.inMinutes <= 20 && timeUntilStart.inMinutes > 0;

  // ── Placeholder helpers (for knockout Final/SF generated upfront) ─────────
  bool get teamAIsPlaceholder =>
      teamAId.startsWith('WINNER_OF:') || teamAId.startsWith('LOSER_OF:');
  bool get teamBIsPlaceholder =>
      teamBId.startsWith('WINNER_OF:') || teamBId.startsWith('LOSER_OF:');
  bool get hasPlaceholders => teamAIsPlaceholder || teamBIsPlaceholder;

  /// If teamAId/teamBId starts with WINNER_OF: or LOSER_OF:, extract the
  /// source match id (for later resolution).
  String? get teamASourceMatchId {
    if (!teamAIsPlaceholder) return null;
    return teamAId.split(':').last;
  }

  String? get teamBSourceMatchId {
    if (!teamBIsPlaceholder) return null;
    return teamBId.split(':').last;
  }
}