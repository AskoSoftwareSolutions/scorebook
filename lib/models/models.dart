
export 'tournament_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// lib/models/match_model.dart
// ─────────────────────────────────────────────────────────────────────────────

class MatchModel {
  final int? id;
  final String teamAName;
  final String teamBName;
  final int totalOvers;
  final String tossWinner;
  final String battingFirst;      // team name batting first
  final DateTime matchDate;
  final String status;            // 'in_progress' | 'completed'
  final String? result;
  final String? manOfTheMatch;
  final int? teamAScore;
  final int? teamAWickets;
  final int? teamABalls;
  final int? teamBScore;
  final int? teamBWickets;
  final int? teamBBalls;
  final int currentInnings;       // 1 or 2

  MatchModel({
    this.id,
    required this.teamAName,
    required this.teamBName,
    required this.totalOvers,
    required this.tossWinner,
    required this.battingFirst,
    required this.matchDate,
    required this.status,
    this.result,
    this.manOfTheMatch,
    this.teamAScore,
    this.teamAWickets,
    this.teamABalls,
    this.teamBScore,
    this.teamBWickets,
    this.teamBBalls,
    this.currentInnings = 1,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'teamAName': teamAName,
    'teamBName': teamBName,
    'totalOvers': totalOvers,
    'tossWinner': tossWinner,
    'battingFirst': battingFirst,
    'matchDate': matchDate.toIso8601String(),
    'status': status,
    'result': result,
    'manOfTheMatch': manOfTheMatch,
    'teamAScore': teamAScore,
    'teamAWickets': teamAWickets,
    'teamABalls': teamABalls,
    'teamBScore': teamBScore,
    'teamBWickets': teamBWickets,
    'teamBBalls': teamBBalls,
    'currentInnings': currentInnings,
  };

  factory MatchModel.fromMap(Map<String, dynamic> map) => MatchModel(
    id: map['id'] as int?,
    teamAName: map['teamAName'] as String,
    teamBName: map['teamBName'] as String,
    totalOvers: map['totalOvers'] as int,
    tossWinner: map['tossWinner'] as String,
    battingFirst: map['battingFirst'] as String,
    matchDate: DateTime.parse(map['matchDate'] as String),
    status: map['status'] as String,
    result: map['result'] as String?,
    manOfTheMatch: map['manOfTheMatch'] as String?,
    teamAScore: map['teamAScore'] as int?,
    teamAWickets: map['teamAWickets'] as int?,
    teamABalls: map['teamABalls'] as int?,
    teamBScore: map['teamBScore'] as int?,
    teamBWickets: map['teamBWickets'] as int?,
    teamBBalls: map['teamBBalls'] as int?,
    currentInnings: map['currentInnings'] as int? ?? 1,
  );

  MatchModel copyWith({
    int? id,
    String? teamAName,
    String? teamBName,
    int? totalOvers,
    String? tossWinner,
    String? battingFirst,
    DateTime? matchDate,
    String? status,
    String? result,
    String? manOfTheMatch,
    int? teamAScore,
    int? teamAWickets,
    int? teamABalls,
    int? teamBScore,
    int? teamBWickets,
    int? teamBBalls,
    int? currentInnings,
  }) =>
      MatchModel(
        id: id ?? this.id,
        teamAName: teamAName ?? this.teamAName,
        teamBName: teamBName ?? this.teamBName,
        totalOvers: totalOvers ?? this.totalOvers,
        tossWinner: tossWinner ?? this.tossWinner,
        battingFirst: battingFirst ?? this.battingFirst,
        matchDate: matchDate ?? this.matchDate,
        status: status ?? this.status,
        result: result ?? this.result,
        manOfTheMatch: manOfTheMatch ?? this.manOfTheMatch,
        teamAScore: teamAScore ?? this.teamAScore,
        teamAWickets: teamAWickets ?? this.teamAWickets,
        teamABalls: teamABalls ?? this.teamABalls,
        teamBScore: teamBScore ?? this.teamBScore,
        teamBWickets: teamBWickets ?? this.teamBWickets,
        teamBBalls: teamBBalls ?? this.teamBBalls,
        currentInnings: currentInnings ?? this.currentInnings,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// PlayerModel
// ─────────────────────────────────────────────────────────────────────────────

class PlayerModel {
  final int? id;
  final int matchId;
  final String teamName;
  final String name;
  final int orderIndex;

  // Batting stats
  int runsScored;
  int ballsFaced;
  int fours;
  int sixes;
  bool isOut;
  String? wicketType;
  String? dismissedBy;    // fielder name for caught/run out
  String? bowlerName;     // bowler who took the wicket
  bool didBat;

  // Bowling stats
  int ballsBowled;
  int runsConceded;
  int wicketsTaken;
  int wides;
  int noBalls;

  // Match
  bool isOnStrike;
  bool isBatting;
  bool isBowling;

  PlayerModel({
    this.id,
    required this.matchId,
    required this.teamName,
    required this.name,
    required this.orderIndex,
    this.runsScored = 0,
    this.ballsFaced = 0,
    this.fours = 0,
    this.sixes = 0,
    this.isOut = false,
    this.wicketType,
    this.dismissedBy,
    this.bowlerName,
    this.didBat = false,
    this.ballsBowled = 0,
    this.runsConceded = 0,
    this.wicketsTaken = 0,
    this.wides = 0,
    this.noBalls = 0,
    this.isOnStrike = false,
    this.isBatting = false,
    this.isBowling = false,
  });

  double get strikeRate =>
      ballsFaced == 0 ? 0.0 : (runsScored / ballsFaced) * 100;

  double get economy =>
      ballsBowled == 0 ? 0.0 : (runsConceded / ballsBowled) * 6;

  String get oversBoled {
    final o = ballsBowled ~/ 6;
    final b = ballsBowled % 6;
    return '$o.$b';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'matchId': matchId,
    'teamName': teamName,
    'name': name,
    'orderIndex': orderIndex,
    'runsScored': runsScored,
    'ballsFaced': ballsFaced,
    'fours': fours,
    'sixes': sixes,
    'isOut': isOut ? 1 : 0,
    'wicketType': wicketType,
    'dismissedBy': dismissedBy,
    'bowlerName': bowlerName,
    'didBat': didBat ? 1 : 0,
    'ballsBowled': ballsBowled,
    'runsConceded': runsConceded,
    'wicketsTaken': wicketsTaken,
    'wides': wides,
    'noBalls': noBalls,
    'isOnStrike': isOnStrike ? 1 : 0,
    'isBatting': isBatting ? 1 : 0,
    'isBowling': isBowling ? 1 : 0,
  };

  factory PlayerModel.fromMap(Map<String, dynamic> map) => PlayerModel(
    id: map['id'] as int?,
    matchId: map['matchId'] as int,
    teamName: map['teamName'] as String,
    name: map['name'] as String,
    orderIndex: map['orderIndex'] as int,
    runsScored: map['runsScored'] as int? ?? 0,
    ballsFaced: map['ballsFaced'] as int? ?? 0,
    fours: map['fours'] as int? ?? 0,
    sixes: map['sixes'] as int? ?? 0,
    isOut: (map['isOut'] as int? ?? 0) == 1,
    wicketType: map['wicketType'] as String?,
    dismissedBy: map['dismissedBy'] as String?,
    bowlerName: map['bowlerName'] as String?,
    didBat: (map['didBat'] as int? ?? 0) == 1,
    ballsBowled: map['ballsBowled'] as int? ?? 0,
    runsConceded: map['runsConceded'] as int? ?? 0,
    wicketsTaken: map['wicketsTaken'] as int? ?? 0,
    wides: map['wides'] as int? ?? 0,
    noBalls: map['noBalls'] as int? ?? 0,
    isOnStrike: (map['isOnStrike'] as int? ?? 0) == 1,
    isBatting: (map['isBatting'] as int? ?? 0) == 1,
    isBowling: (map['isBowling'] as int? ?? 0) == 1,
  );

  PlayerModel copyWith({
    int? id,
    int? runsScored,
    int? ballsFaced,
    int? fours,
    int? sixes,
    bool? isOut,
    String? wicketType,
    String? dismissedBy,
    String? bowlerName,
    bool? didBat,
    int? ballsBowled,
    int? runsConceded,
    int? wicketsTaken,
    int? wides,
    int? noBalls,
    bool? isOnStrike,
    bool? isBatting,
    bool? isBowling,
  }) =>
      PlayerModel(
        id: id ?? this.id,
        matchId: matchId,
        teamName: teamName,
        name: name,
        orderIndex: orderIndex,
        runsScored: runsScored ?? this.runsScored,
        ballsFaced: ballsFaced ?? this.ballsFaced,
        fours: fours ?? this.fours,
        sixes: sixes ?? this.sixes,
        isOut: isOut ?? this.isOut,
        wicketType: wicketType ?? this.wicketType,
        dismissedBy: dismissedBy ?? this.dismissedBy,
        bowlerName: bowlerName ?? this.bowlerName,
        didBat: didBat ?? this.didBat,
        ballsBowled: ballsBowled ?? this.ballsBowled,
        runsConceded: runsConceded ?? this.runsConceded,
        wicketsTaken: wicketsTaken ?? this.wicketsTaken,
        wides: wides ?? this.wides,
        noBalls: noBalls ?? this.noBalls,
        isOnStrike: isOnStrike ?? this.isOnStrike,
        isBatting: isBatting ?? this.isBatting,
        isBowling: isBowling ?? this.isBowling,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// BallModel — one delivery
// ─────────────────────────────────────────────────────────────────────────────

class BallModel {
  final int? id;
  final int matchId;
  final int innings;
  final int overNumber;     // 0-indexed over
  final int ballNumber;     // 1-indexed ball in over
  final String batsmanName;
  final String bowlerName;
  final int runs;           // runs scored off bat
  final bool isWide;
  final bool isNoBall;
  final bool isBye;
  final bool isLegBye;
  final bool isWicket;
  final String? wicketType;
  final String? outBatsmanName;
  final String? fielderName;
  final int extraRuns;      // wide/no-ball penalty runs
  final int totalRuns;      // runs + extras for this ball
  final bool isValid;       // counts toward over? (wide/noball don't)

  BallModel({
    this.id,
    required this.matchId,
    required this.innings,
    required this.overNumber,
    required this.ballNumber,
    required this.batsmanName,
    required this.bowlerName,
    required this.runs,
    this.isWide = false,
    this.isNoBall = false,
    this.isBye = false,
    this.isLegBye = false,
    this.isWicket = false,
    this.wicketType,
    this.outBatsmanName,
    this.fielderName,
    this.extraRuns = 0,
    required this.totalRuns,
    required this.isValid,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'matchId': matchId,
    'innings': innings,
    'overNumber': overNumber,
    'ballNumber': ballNumber,
    'batsmanName': batsmanName,
    'bowlerName': bowlerName,
    'runs': runs,
    'isWide': isWide ? 1 : 0,
    'isNoBall': isNoBall ? 1 : 0,
    'isBye': isBye ? 1 : 0,
    'isLegBye': isLegBye ? 1 : 0,
    'isWicket': isWicket ? 1 : 0,
    'wicketType': wicketType,
    'outBatsmanName': outBatsmanName,
    'fielderName': fielderName,
    'extraRuns': extraRuns,
    'totalRuns': totalRuns,
    'isValid': isValid ? 1 : 0,
  };

  factory BallModel.fromMap(Map<String, dynamic> map) => BallModel(
    id: map['id'] as int?,
    matchId: map['matchId'] as int,
    innings: map['innings'] as int,
    overNumber: map['overNumber'] as int,
    ballNumber: map['ballNumber'] as int,
    batsmanName: map['batsmanName'] as String,
    bowlerName: map['bowlerName'] as String,
    runs: map['runs'] as int,
    isWide: (map['isWide'] as int) == 1,
    isNoBall: (map['isNoBall'] as int) == 1,
    isBye: (map['isBye'] as int) == 1,
    isLegBye: (map['isLegBye'] as int) == 1,
    isWicket: (map['isWicket'] as int) == 1,
    wicketType: map['wicketType'] as String?,
    outBatsmanName: map['outBatsmanName'] as String?,
    fielderName: map['fielderName'] as String?,
    extraRuns: map['extraRuns'] as int,
    totalRuns: map['totalRuns'] as int,
    isValid: (map['isValid'] as int) == 1,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// InningsModel — summary of one innings
// ─────────────────────────────────────────────────────────────────────────────

class InningsModel {
  final int? id;
  final int matchId;
  final int inningsNumber;
  final String battingTeam;
  final String bowlingTeam;
  int totalRuns;
  int totalWickets;
  int totalBalls;         // valid balls
  int wides;
  int noBalls;
  int byes;
  int legByes;
  bool isCompleted;

  InningsModel({
    this.id,
    required this.matchId,
    required this.inningsNumber,
    required this.battingTeam,
    required this.bowlingTeam,
    this.totalRuns = 0,
    this.totalWickets = 0,
    this.totalBalls = 0,
    this.wides = 0,
    this.noBalls = 0,
    this.byes = 0,
    this.legByes = 0,
    this.isCompleted = false,
  });

  double get runRate =>
      totalBalls == 0 ? 0.0 : (totalRuns / totalBalls) * 6;

  int get extras => wides + noBalls + byes + legByes;

  String get oversBowled {
    final o = totalBalls ~/ 6;
    final b = totalBalls % 6;
    return '$o.$b';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'matchId': matchId,
    'inningsNumber': inningsNumber,
    'battingTeam': battingTeam,
    'bowlingTeam': bowlingTeam,
    'totalRuns': totalRuns,
    'totalWickets': totalWickets,
    'totalBalls': totalBalls,
    'wides': wides,
    'noBalls': noBalls,
    'byes': byes,
    'legByes': legByes,
    'isCompleted': isCompleted ? 1 : 0,
  };

  factory InningsModel.fromMap(Map<String, dynamic> map) => InningsModel(
    id: map['id'] as int?,
    matchId: map['matchId'] as int,
    inningsNumber: map['inningsNumber'] as int,
    battingTeam: map['battingTeam'] as String,
    bowlingTeam: map['bowlingTeam'] as String,
    totalRuns: map['totalRuns'] as int? ?? 0,
    totalWickets: map['totalWickets'] as int? ?? 0,
    totalBalls: map['totalBalls'] as int? ?? 0,
    wides: map['wides'] as int? ?? 0,
    noBalls: map['noBalls'] as int? ?? 0,
    byes: map['byes'] as int? ?? 0,
    legByes: map['legByes'] as int? ?? 0,
    isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MatchSetupModel — transient model used during match creation
// ─────────────────────────────────────────────────────────────────────────────

class MatchSetupModel {
  String teamAName;
  String teamBName;
  int totalOvers;
  List<String> teamAPlayers;
  List<String> teamBPlayers;
  String tossWinner;
  String battingFirst;

  MatchSetupModel({
    this.teamAName = '',
    this.teamBName = '',
    this.totalOvers = 20,
    List<String>? teamAPlayers,
    List<String>? teamBPlayers,
    this.tossWinner = '',
    this.battingFirst = '',
  })  : teamAPlayers = teamAPlayers ?? [],
        teamBPlayers = teamBPlayers ?? [];
}
