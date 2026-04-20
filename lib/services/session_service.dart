import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  // ── Match keys ────────────────────────────────────────────────────────────
  static const _kMatchId   = 'active_match_id';
  static const _kTeamA     = 'active_match_team_a';
  static const _kTeamB     = 'active_match_team_b';
  static const _kOvers     = 'active_match_overs';

  // ── Online mode keys ──────────────────────────────────────────────────────
  static const _kOnline    = 'online_mode_active';
  static const _kMatchCode = 'online_match_code';
  static const _kMatchPass = 'online_match_password';

  // ── Watch Live session keys ───────────────────────────────────────────────
  static const _kWatchCode = 'watch_live_code';
  static const _kWatchPass = 'watch_live_password';

  // ── Tournament match linkage (so viewers can show "next match") ─────────
  static const _kTournamentId      = 'active_tournament_id';
  static const _kTournamentMatchId = 'active_tournament_match_id';

  // ── Auth keys ─────────────────────────────────────────────────────────────
  static const _kUserPhone = 'auth_user_phone';

  // ── Save active match ─────────────────────────────────────────────────────
  Future<void> saveActiveMatch({
    required int    matchId,
    required String teamA,
    required String teamB,
    required int    totalOvers,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt   (_kMatchId, matchId);
    await p.setString(_kTeamA,   teamA);
    await p.setString(_kTeamB,   teamB);
    await p.setInt   (_kOvers,   totalOvers);
  }

  // ── Save online mode ──────────────────────────────────────────────────────
  Future<void> saveOnlineMode({
    required bool   isActive,
    required String matchCode,
    required String password,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool  (_kOnline,    isActive);
    await p.setString(_kMatchCode, matchCode);
    await p.setString(_kMatchPass, password);
  }

  // ── Clear online mode ─────────────────────────────────────────────────────
  Future<void> clearOnlineMode() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kOnline);
    await p.remove(_kMatchCode);
    await p.remove(_kMatchPass);
  }

  // ── Clear active match ────────────────────────────────────────────────────
  Future<void> clearActiveMatch() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kMatchId);
    await p.remove(_kTeamA);
    await p.remove(_kTeamB);
    await p.remove(_kOvers);
    await clearOnlineMode();
    await clearActiveTournamentMatch();
  }

  // ── Active tournament match (optional context) ─────────────────────────
  Future<void> saveActiveTournamentMatch({
    required String tournamentId,
    required String tournamentMatchId,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTournamentId, tournamentId);
    await p.setString(_kTournamentMatchId, tournamentMatchId);
  }

  Future<TournamentLinkInfo?> getActiveTournamentMatch() async {
    final p    = await SharedPreferences.getInstance();
    final tId  = p.getString(_kTournamentId);
    final mId  = p.getString(_kTournamentMatchId);
    if (tId == null || tId.isEmpty || mId == null || mId.isEmpty) return null;
    return TournamentLinkInfo(tournamentId: tId, tournamentMatchId: mId);
  }

  Future<void> clearActiveTournamentMatch() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kTournamentId);
    await p.remove(_kTournamentMatchId);
  }

  // ── Get active match ──────────────────────────────────────────────────────
  Future<ActiveMatchInfo?> getActiveMatch() async {
    final p  = await SharedPreferences.getInstance();
    final id = p.getInt(_kMatchId);
    if (id == null) return null;
    return ActiveMatchInfo(
      matchId:    id,
      teamA:      p.getString(_kTeamA)  ?? '',
      teamB:      p.getString(_kTeamB)  ?? '',
      totalOvers: p.getInt(_kOvers)     ?? 20,
    );
  }

  // ── Get online mode ───────────────────────────────────────────────────────
  Future<OnlineModeInfo?> getOnlineMode() async {
    final p        = await SharedPreferences.getInstance();
    final isActive = p.getBool(_kOnline) ?? false;
    if (!isActive) return null;
    final code = p.getString(_kMatchCode) ?? '';
    final pass = p.getString(_kMatchPass) ?? '';
    if (code.isEmpty) return null;
    return OnlineModeInfo(matchCode: code, password: pass);
  }

  Future<bool> hasActiveMatch() async {
    final p = await SharedPreferences.getInstance();
    return p.containsKey(_kMatchId);
  }

  // ── Watch Live session ────────────────────────────────────────────────────

  Future<void> saveWatchLive({
    required String matchCode,
    required String password,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kWatchCode, matchCode);
    await p.setString(_kWatchPass, password);
  }

  Future<WatchLiveInfo?> getWatchLive() async {
    final p    = await SharedPreferences.getInstance();
    final code = p.getString(_kWatchCode) ?? '';
    final pass = p.getString(_kWatchPass) ?? '';
    if (code.isEmpty) return null;
    return WatchLiveInfo(matchCode: code, password: pass);
  }

  Future<void> clearWatchLive() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kWatchCode);
    await p.remove(_kWatchPass);
  }

  // ── User phone (saved after Firebase phone auth) ──────────────────────────
  Future<void> saveUserPhone(String phone) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUserPhone, phone);
  }

  Future<String?> getUserPhone() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kUserPhone);
  }

  Future<void> clearUserPhone() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kUserPhone);
  }

  /// Synchronous getter — returns cached phone or empty string.
  /// Call [getUserPhone] for async version.
  String get currentPhone {
    // This requires the cached instance to be initialized via loadCachedPhone()
    return _cachedPhone ?? '';
  }

  String? _cachedPhone;

  /// Call once at app startup to preload phone for sync access.
  Future<void> loadCachedPhone() async {
    final p = await SharedPreferences.getInstance();
    _cachedPhone = p.getString(_kUserPhone);
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class ActiveMatchInfo {
  final int    matchId;
  final String teamA;
  final String teamB;
  final int    totalOvers;
  const ActiveMatchInfo({
    required this.matchId,
    required this.teamA,
    required this.teamB,
    required this.totalOvers,
  });
}

class OnlineModeInfo {
  final String matchCode;
  final String password;
  const OnlineModeInfo({required this.matchCode, required this.password});
}

class WatchLiveInfo {
  final String matchCode;
  final String password;
  const WatchLiveInfo({required this.matchCode, required this.password});
}

class TournamentLinkInfo {
  final String tournamentId;
  final String tournamentMatchId;
  const TournamentLinkInfo({
    required this.tournamentId,
    required this.tournamentMatchId,
  });
}