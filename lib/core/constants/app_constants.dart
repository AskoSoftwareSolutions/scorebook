class AppConstants {
  // App
  static const String appName = 'Cricket Scorer';
  static const String appVersion = '1.0.0';

  // Database
  static const String dbName = 'cricket_scorer.db';
  static const int dbVersion = 2;

  // Table Names
  static const String tableMatches = 'matches';
  static const String tableTeams = 'teams';
  static const String tablePlayers = 'players';
  static const String tableBalls = 'balls';
  static const String tableInnings = 'innings';

  // Default Values
  static const int defaultOvers = 20;
  static const int maxPlayers = 20;
  static const int minPlayers = 2;

  // Extras
  static const String extraWide = 'wide';
  static const String extraNoBall = 'noball';
  static const String extraBye = 'bye';
  static const String extraLegBye = 'legbye';

  // Wicket Types
  static const String wicketBowled = 'Bowled';
  static const String wicketCaught = 'Caught';
  static const String wicketLBW = 'LBW';
  static const String wicketRunOut = 'Run Out';
  static const String wicketStumped = 'Stumped';
  static const String wicketHitWicket = 'Hit Wicket';

  // Match Status
  static const String matchStatusInProgress = 'in_progress';
  static const String matchStatusCompleted = 'completed';

  // Innings
  static const int innings1 = 1;
  static const int innings2 = 2;

  // PDF
  static const String pdfReportTitle = 'Cricket Match Report';
}