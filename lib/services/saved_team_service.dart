import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedTeam {
  final String name;
  final List<String> players;

  SavedTeam({required this.name, required this.players});

  Map<String, dynamic> toMap() => {'name': name, 'players': players};

  factory SavedTeam.fromMap(Map<String, dynamic> map) => SavedTeam(
    name: map['name'] as String,
    players: List<String>.from(map['players'] as List),
  );
}

class SavedTeamService {
  static const _key = 'saved_teams';

  Future<List<SavedTeam>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => SavedTeam.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTeam(String name, List<String> players) async {
    if (name.trim().isEmpty || players.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final teams = await getAll();

    // Update existing or add new
    final idx = teams.indexWhere(
            (t) => t.name.toLowerCase() == name.trim().toLowerCase());
    if (idx >= 0) {
      teams[idx] = SavedTeam(name: name.trim(), players: players);
    } else {
      teams.add(SavedTeam(name: name.trim(), players: players));
    }

    await prefs.setString(_key, jsonEncode(teams.map((t) => t.toMap()).toList()));
  }

  Future<void> deleteTeam(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final teams = await getAll();
    teams.removeWhere((t) => t.name.toLowerCase() == name.trim().toLowerCase());
    await prefs.setString(_key, jsonEncode(teams.map((t) => t.toMap()).toList()));
  }

  Future<SavedTeam?> findByName(String name) async {
    final teams = await getAll();
    try {
      return teams.firstWhere(
              (t) => t.name.toLowerCase() == name.trim().toLowerCase());
    } catch (_) {
      return null;
    }
  }
}