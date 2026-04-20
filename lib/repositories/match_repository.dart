import '../database/database_helper.dart';
import '../models/models.dart';
import '../core/constants/app_constants.dart';

class MatchRepository {
  final DatabaseHelper _db = DatabaseHelper();

  // ── Match ─────────────────────────────────────────────────────────────────

  Future<int> createMatch(MatchModel match) async {
    final map = match.toMap();
    map.remove('id');
    return _db.insert(AppConstants.tableMatches, map);
  }

  Future<MatchModel?> getMatch(int id) async {
    final map = await _db.queryOne(
      AppConstants.tableMatches,
      where: 'id = ?',
      whereArgs: [id],
    );
    return map != null ? MatchModel.fromMap(map) : null;
  }

  Future<List<MatchModel>> getAllMatches() async {
    final results = await _db.query(
      AppConstants.tableMatches,
      orderBy: 'matchDate DESC',
    );
    return results.map(MatchModel.fromMap).toList();
  }

  Future<void> updateMatch(MatchModel match) async {
    await _db.update(
      AppConstants.tableMatches,
      match.toMap(),
      'id = ?',
      [match.id],
    );
  }

  Future<void> deleteMatch(int matchId) async {
    await _db.delete(AppConstants.tableMatches, 'id = ?', [matchId]);
    await _db.delete(AppConstants.tablePlayers, 'matchId = ?', [matchId]);
    await _db.delete(AppConstants.tableBalls, 'matchId = ?', [matchId]);
    await _db.delete(AppConstants.tableInnings, 'matchId = ?', [matchId]);
  }

  // ── Players ───────────────────────────────────────────────────────────────

  Future<int> createPlayer(PlayerModel player) async {
    final map = player.toMap();
    map.remove('id');
    return _db.insert(AppConstants.tablePlayers, map);
  }

  Future<void> updatePlayer(PlayerModel player) async {
    await _db.update(
      AppConstants.tablePlayers,
      player.toMap(),
      'id = ?',
      [player.id],
    );
  }

  Future<void> deletePlayer(int playerId) async {
    await _db.delete(AppConstants.tablePlayers, 'id = ?', [playerId]);
  }

  Future<List<PlayerModel>> getPlayersByMatch(int matchId) async {
    final results = await _db.query(
      AppConstants.tablePlayers,
      where: 'matchId = ?',
      whereArgs: [matchId],
      orderBy: 'teamName, orderIndex',
    );
    return results.map(PlayerModel.fromMap).toList();
  }

  Future<List<PlayerModel>> getPlayersByTeam(int matchId, String teamName) async {
    final results = await _db.query(
      AppConstants.tablePlayers,
      where: 'matchId = ? AND teamName = ?',
      whereArgs: [matchId, teamName],
      orderBy: 'orderIndex',
    );
    return results.map(PlayerModel.fromMap).toList();
  }

  Future<PlayerModel?> getPlayerByName(int matchId, String name, String teamName) async {
    final map = await _db.queryOne(
      AppConstants.tablePlayers,
      where: 'matchId = ? AND name = ? AND teamName = ?',
      whereArgs: [matchId, name, teamName],
    );
    return map != null ? PlayerModel.fromMap(map) : null;
  }

  // ── Balls ─────────────────────────────────────────────────────────────────

  Future<int> addBall(BallModel ball) async {
    final map = ball.toMap();
    map.remove('id');
    return _db.insert(AppConstants.tableBalls, map);
  }

  Future<void> deleteBall(int ballId) async {
    await _db.delete(AppConstants.tableBalls, 'id = ?', [ballId]);
  }

  Future<List<BallModel>> getBallsByInnings(int matchId, int innings) async {
    final results = await _db.query(
      AppConstants.tableBalls,
      where: 'matchId = ? AND innings = ?',
      whereArgs: [matchId, innings],
      orderBy: 'overNumber, ballNumber',
    );
    return results.map(BallModel.fromMap).toList();
  }

  Future<BallModel?> getLastBall(int matchId, int innings) async {
    final db = DatabaseHelper();
    final results = await db.query(
      AppConstants.tableBalls,
      where: 'matchId = ? AND innings = ?',
      whereArgs: [matchId, innings],
      orderBy: 'id DESC',
      limit: 1,
    );
    return results.isNotEmpty ? BallModel.fromMap(results.first) : null;
  }

  Future<List<BallModel>> getBallsByOver(int matchId, int innings, int over) async {
    final results = await _db.query(
      AppConstants.tableBalls,
      where: 'matchId = ? AND innings = ? AND overNumber = ?',
      whereArgs: [matchId, innings, over],
      orderBy: 'ballNumber',
    );
    return results.map(BallModel.fromMap).toList();
  }

  // ── Innings ───────────────────────────────────────────────────────────────

  Future<int> createInnings(InningsModel innings) async {
    final map = innings.toMap();
    map.remove('id');
    return _db.insert(AppConstants.tableInnings, map);
  }

  Future<void> updateInnings(InningsModel innings) async {
    await _db.update(
      AppConstants.tableInnings,
      innings.toMap(),
      'id = ?',
      [innings.id],
    );
  }

  Future<InningsModel?> getInnings(int matchId, int inningsNumber) async {
    final map = await _db.queryOne(
      AppConstants.tableInnings,
      where: 'matchId = ? AND inningsNumber = ?',
      whereArgs: [matchId, inningsNumber],
    );
    return map != null ? InningsModel.fromMap(map) : null;
  }

  Future<List<InningsModel>> getAllInnings(int matchId) async {
    final results = await _db.query(
      AppConstants.tableInnings,
      where: 'matchId = ?',
      whereArgs: [matchId],
      orderBy: 'inningsNumber',
    );
    return results.map(InningsModel.fromMap).toList();
  }
}
