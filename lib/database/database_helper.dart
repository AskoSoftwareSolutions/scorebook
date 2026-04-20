import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../core/constants/app_constants.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Matches table
    await db.execute('''
      CREATE TABLE ${AppConstants.tableMatches} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        teamAName TEXT NOT NULL,
        teamBName TEXT NOT NULL,
        totalOvers INTEGER NOT NULL,
        tossWinner TEXT NOT NULL,
        battingFirst TEXT NOT NULL,
        matchDate TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'in_progress',
        result TEXT,
        manOfTheMatch TEXT,
        teamAScore INTEGER,
        teamAWickets INTEGER,
        teamABalls INTEGER,
        teamBScore INTEGER,
        teamBWickets INTEGER,
        teamBBalls INTEGER,
        currentInnings INTEGER DEFAULT 1
      )
    ''');

    // Players table
    await db.execute('''
      CREATE TABLE ${AppConstants.tablePlayers} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        matchId INTEGER NOT NULL,
        teamName TEXT NOT NULL,
        name TEXT NOT NULL,
        orderIndex INTEGER NOT NULL,
        runsScored INTEGER DEFAULT 0,
        ballsFaced INTEGER DEFAULT 0,
        fours INTEGER DEFAULT 0,
        sixes INTEGER DEFAULT 0,
        isOut INTEGER DEFAULT 0,
        wicketType TEXT,
        dismissedBy TEXT,
        bowlerName TEXT,
        didBat INTEGER DEFAULT 0,
        ballsBowled INTEGER DEFAULT 0,
        runsConceded INTEGER DEFAULT 0,
        wicketsTaken INTEGER DEFAULT 0,
        wides INTEGER DEFAULT 0,
        noBalls INTEGER DEFAULT 0,
        isOnStrike INTEGER DEFAULT 0,
        isBatting INTEGER DEFAULT 0,
        isBowling INTEGER DEFAULT 0,
        FOREIGN KEY (matchId) REFERENCES ${AppConstants.tableMatches}(id) ON DELETE CASCADE
      )
    ''');

    // Balls table (ball-by-ball)
    await db.execute('''
      CREATE TABLE ${AppConstants.tableBalls} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        matchId INTEGER NOT NULL,
        innings INTEGER NOT NULL,
        overNumber INTEGER NOT NULL,
        ballNumber INTEGER NOT NULL,
        batsmanName TEXT NOT NULL,
        bowlerName TEXT NOT NULL,
        runs INTEGER NOT NULL DEFAULT 0,
        isWide INTEGER DEFAULT 0,
        isNoBall INTEGER DEFAULT 0,
        isBye INTEGER DEFAULT 0,
        isLegBye INTEGER DEFAULT 0,
        isWicket INTEGER DEFAULT 0,
        wicketType TEXT,
        outBatsmanName TEXT,
        fielderName TEXT,
        extraRuns INTEGER DEFAULT 0,
        totalRuns INTEGER NOT NULL DEFAULT 0,
        isValid INTEGER DEFAULT 1,
        FOREIGN KEY (matchId) REFERENCES ${AppConstants.tableMatches}(id) ON DELETE CASCADE
      )
    ''');

    // Innings table
    await db.execute('''
      CREATE TABLE ${AppConstants.tableInnings} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        matchId INTEGER NOT NULL,
        inningsNumber INTEGER NOT NULL,
        battingTeam TEXT NOT NULL,
        bowlingTeam TEXT NOT NULL,
        totalRuns INTEGER DEFAULT 0,
        totalWickets INTEGER DEFAULT 0,
        totalBalls INTEGER DEFAULT 0,
        wides INTEGER DEFAULT 0,
        noBalls INTEGER DEFAULT 0,
        byes INTEGER DEFAULT 0,
        legByes INTEGER DEFAULT 0,
        isCompleted INTEGER DEFAULT 0,
        FOREIGN KEY (matchId) REFERENCES ${AppConstants.tableMatches}(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add resume-state columns to players — safe to run on existing DBs
      await db.execute(
          'ALTER TABLE ${AppConstants.tablePlayers} ADD COLUMN isOnStrike INTEGER DEFAULT 0');
      await db.execute(
          'ALTER TABLE ${AppConstants.tablePlayers} ADD COLUMN isBatting INTEGER DEFAULT 0');
      await db.execute(
          'ALTER TABLE ${AppConstants.tablePlayers} ADD COLUMN isBowling INTEGER DEFAULT 0');
    }
  }

  // ── Generic CRUD ──────────────────────────────────────────────────────────

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(
      String table, Map<String, dynamic> data, String where, List<dynamic> whereArgs) async {
    final db = await database;
    return db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, String where, List<dynamic> whereArgs) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> query(
      String table, {
        String? where,
        List<dynamic>? whereArgs,
        String? orderBy,
        int? limit,
      }) async {
    final db = await database;
    return db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> queryOne(
      String table, {
        required String where,
        required List<dynamic> whereArgs,
      }) async {
    final db = await database;
    final results = await db.query(table, where: where, whereArgs: whereArgs, limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> closeDatabase() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}