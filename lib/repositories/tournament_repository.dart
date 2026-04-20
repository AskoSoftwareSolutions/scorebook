// ─────────────────────────────────────────────────────────────────────────────
// lib/repositories/tournament_repository.dart
//
// Firestore CRUD for tournaments, teams, and matches.
// Structure:
//   tournaments/{tournamentId}
//     ├─ teams/{teamId}
//     └─ matches/{matchId}
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/tournament_models.dart';
import '../services/session_service.dart';

class TournamentRepository {
  static final TournamentRepository _i = TournamentRepository._();
  factory TournamentRepository() => _i;
  TournamentRepository._();

  final _db      = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth    = FirebaseAuth.instance;
  final _uuid    = const Uuid();

  // ── Collection references ──────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _tournamentsCol =>
      _db.collection('tournaments');

  CollectionReference<Map<String, dynamic>> _teamsCol(String tournamentId) =>
      _tournamentsCol.doc(tournamentId).collection('teams');

  CollectionReference<Map<String, dynamic>> _matchesCol(String tournamentId) =>
      _tournamentsCol.doc(tournamentId).collection('matches');

  /// Returns the current user identifier. Priority:
  ///   1. Firebase phone number (if set)
  ///   2. Firebase UID (always present when signed in)
  String? get _currentPhone {
    final user = _auth.currentUser;
    if (user == null) return null;

    // Phone number is preferred
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      return user.phoneNumber;
    }

    // UID fallback — always available when signed in
    return user.uid;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TOURNAMENTS
  // ═══════════════════════════════════════════════════════════════════════

  /// Create a new tournament. Returns the generated tournamentId.
  Future<String> createTournament({
    required String name,
    required TournamentFormat format,
    required UmpireMode umpireMode,
    required int totalOvers,
  }) async {
    // ── DEBUG ────────────────────────────────────
    print('🔥 currentUser: ${_auth.currentUser}');
    print('🔥 uid: ${_auth.currentUser?.uid}');
    print('🔥 phone: "${_auth.currentUser?.phoneNumber}"');
    print('🔥 computed _currentPhone: $_currentPhone');
    // ── END DEBUG ────────────────────────────────
    final phone = _currentPhone;
    if (phone == null) {
      throw Exception('User must be logged in to create tournament');
    }

    final id = _uuid.v4();
    final tournament = TournamentModel(
      id:         id,
      name:       name.trim(),
      format:     format,
      status:     TournamentStatus.setup,
      umpireMode: umpireMode,
      totalOvers: totalOvers,
      createdBy:  phone,
      createdAt:  DateTime.now(),
    );

    await _tournamentsCol.doc(id).set(tournament.toMap());
    return id;
  }

  /// Fetch a single tournament by id.
  Future<TournamentModel?> getTournament(String id) async {
    final doc = await _tournamentsCol.doc(id).get();
    if (!doc.exists) return null;
    return TournamentModel.fromMap(doc.data()!);
  }

  /// Live stream of a single tournament (for real-time updates).
  Stream<TournamentModel?> tournamentStream(String id) {
    return _tournamentsCol.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return TournamentModel.fromMap(doc.data()!);
    });
  }

  /// Fetch all tournaments created by the current user (most recent first).
  Future<List<TournamentModel>> getMyTournaments() async {
    final phone = _currentPhone;
    if (phone == null) return [];

    final snap = await _tournamentsCol
        .where('createdBy', isEqualTo: phone)
        .get();

    final list = snap.docs
        .map((d) => TournamentModel.fromMap(d.data()))
        .toList();

    // Sort client-side → no composite index needed
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Live stream of user's tournaments.
  Stream<List<TournamentModel>> myTournamentsStream() {
    final phone = _currentPhone;
    if (phone == null) return Stream.value([]);

    return _tournamentsCol
        .where('createdBy', isEqualTo: phone)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => TournamentModel.fromMap(d.data()))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> updateTournament(TournamentModel tournament) async {
    await _tournamentsCol.doc(tournament.id).update(tournament.toMap());
  }

  /// Delete tournament + all subcollections + all logos in Storage.
  Future<void> deleteTournament(String id) async {
    // 1. Fetch all teams to remove their logos from Storage
    final teams = await getTeams(id);
    for (final team in teams) {
      if (team.logoUrl != null) {
        try {
          await _storage.refFromURL(team.logoUrl!).delete();
        } catch (_) {
          // Ignore — file may already be gone
        }
      }
    }

    // 2. Delete all matches subcollection
    final matchesSnap = await _matchesCol(id).get();
    for (final doc in matchesSnap.docs) {
      await doc.reference.delete();
    }

    // 3. Delete all teams subcollection
    final teamsSnap = await _teamsCol(id).get();
    for (final doc in teamsSnap.docs) {
      await doc.reference.delete();
    }

    // 4. Delete tournament document
    await _tournamentsCol.doc(id).delete();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TEAMS
  // ═══════════════════════════════════════════════════════════════════════

  /// Create a team in a tournament. Returns the generated teamId.
  Future<String> createTeam({
    required String tournamentId,
    required String name,
    List<String> players = const [],
    File? logoFile,
    int orderIndex = 0,
  }) async {
    final id = _uuid.v4();

    String? logoUrl;
    if (logoFile != null) {
      logoUrl = await _uploadLogo(tournamentId, id, logoFile);
    }

    final team = TournamentTeamModel(
      id:           id,
      tournamentId: tournamentId,
      name:         name.trim(),
      logoUrl:      logoUrl,
      players:      players,
      orderIndex:   orderIndex,
    );

    await _teamsCol(tournamentId).doc(id).set(team.toMap());
    return id;
  }

  /// Upload team logo to Firebase Storage, return download URL.
  Future<String> _uploadLogo(
      String tournamentId, String teamId, File file) async {
    final ref = _storage
        .ref()
        .child('tournament_logos')
        .child(tournamentId)
        .child('$teamId.jpg');
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  /// Update team — optionally replace logo.
  Future<void> updateTeam(
      TournamentTeamModel team, {
        File? newLogoFile,
        bool removeLogo = false,
      }) async {
    String? newLogoUrl = team.logoUrl;

    if (removeLogo && team.logoUrl != null) {
      try {
        await _storage.refFromURL(team.logoUrl!).delete();
      } catch (_) {}
      newLogoUrl = null;
    } else if (newLogoFile != null) {
      // Delete old logo first
      if (team.logoUrl != null) {
        try {
          await _storage.refFromURL(team.logoUrl!).delete();
        } catch (_) {}
      }
      newLogoUrl = await _uploadLogo(team.tournamentId, team.id, newLogoFile);
    }

    final updated = team.copyWith(logoUrl: newLogoUrl);
    await _teamsCol(team.tournamentId).doc(team.id).update(updated.toMap());
  }

  Future<List<TournamentTeamModel>> getTeams(String tournamentId) async {
    final snap =
    await _teamsCol(tournamentId).orderBy('orderIndex').get();
    return snap.docs
        .map((d) => TournamentTeamModel.fromMap(d.data()))
        .toList();
  }

  Stream<List<TournamentTeamModel>> teamsStream(String tournamentId) {
    return _teamsCol(tournamentId)
        .orderBy('orderIndex')
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => TournamentTeamModel.fromMap(d.data()))
        .toList());
  }

  Future<TournamentTeamModel?> getTeam(
      String tournamentId, String teamId) async {
    final doc = await _teamsCol(tournamentId).doc(teamId).get();
    if (!doc.exists) return null;
    return TournamentTeamModel.fromMap(doc.data()!);
  }

  /// Delete team + remove logo from Storage.
  Future<void> deleteTeam(String tournamentId, String teamId) async {
    final team = await getTeam(tournamentId, teamId);
    if (team == null) return;

    if (team.logoUrl != null) {
      try {
        await _storage.refFromURL(team.logoUrl!).delete();
      } catch (_) {}
    }

    await _teamsCol(tournamentId).doc(teamId).delete();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MATCHES
  // ═══════════════════════════════════════════════════════════════════════

  /// Create a match. Returns the generated matchId.
  Future<String> createMatch(TournamentMatchModel match) async {
    await _matchesCol(match.tournamentId).doc(match.id).set(match.toMap());
    return match.id;
  }

  /// Batch-create multiple matches (useful for auto-pairing).
  Future<void> createMatches(
      String tournamentId, List<TournamentMatchModel> matches) async {
    final batch = _db.batch();
    for (final m in matches) {
      batch.set(_matchesCol(tournamentId).doc(m.id), m.toMap());
    }
    await batch.commit();
  }

  Future<void> updateMatch(TournamentMatchModel match) async {
    await _matchesCol(match.tournamentId)
        .doc(match.id)
        .update(match.toMap());
  }

  Future<void> deleteMatch(String tournamentId, String matchId) async {
    await _matchesCol(tournamentId).doc(matchId).delete();
  }

  /// Fetch all matches in a tournament, ordered by scheduled time.
  Future<List<TournamentMatchModel>> getMatches(String tournamentId) async {
    final snap = await _matchesCol(tournamentId)
        .orderBy('scheduledTime')
        .get();
    return snap.docs
        .map((d) => TournamentMatchModel.fromMap(d.data()))
        .toList();
  }

  Stream<List<TournamentMatchModel>> matchesStream(String tournamentId) {
    return _matchesCol(tournamentId)
        .orderBy('scheduledTime')
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => TournamentMatchModel.fromMap(d.data()))
        .toList());
  }

  Future<TournamentMatchModel?> getMatch(
      String tournamentId, String matchId) async {
    final doc = await _matchesCol(tournamentId).doc(matchId).get();
    if (!doc.exists) return null;
    return TournamentMatchModel.fromMap(doc.data()!);
  }

  Stream<TournamentMatchModel?> matchStream(
      String tournamentId, String matchId) {
    return _matchesCol(tournamentId).doc(matchId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return TournamentMatchModel.fromMap(doc.data()!);
    });
  }

  /// Get all matches across all tournaments for the current user,
  /// filtered to those starting in the given time window.
  /// Used by toss reminder / upcoming matches list.
  Future<List<TournamentMatchModel>> getUpcomingMatches({
    required Duration within,
  }) async {
    final phone = _currentPhone;
    if (phone == null) return [];

    // Get user's active tournaments
    final tournaments = await getMyTournaments();
    final activeIds = tournaments
        .where((t) => t.status != TournamentStatus.completed)
        .map((t) => t.id)
        .toList();

    final now  = DateTime.now();
    final end  = now.add(within);
    final all  = <TournamentMatchModel>[];

    for (final tId in activeIds) {
      final snap = await _matchesCol(tId)
          .where('status',
          whereIn: ['scheduled', 'toss_pending'])
          .where('scheduledTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('scheduledTime',
          isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      all.addAll(
          snap.docs.map((d) => TournamentMatchModel.fromMap(d.data())));
    }

    all.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return all;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  /// Generate a new UUID (exposed for use in pairing logic etc.)
  String generateId() => _uuid.v4();
}