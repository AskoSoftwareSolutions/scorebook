import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'session_service.dart';

/// Client-side 14-day retention sweep.
///
/// Authoritative cleanup runs in the Cloud Function `purgeOldMatches`
/// daily at 03:30 IST. This client-side service is a *fallback*:
///
///   - Runs at most once per app launch (idempotent).
///   - Only touches data this user owns (entries under
///     `/user_matches/{their phone}/`).
///   - Deletes both the user-index entry and the corresponding
///     `/matches/{matchCode}` node.
///
/// Errors are swallowed — purging is opportunistic, never blocking.
class FirebasePurgeService {
  static final FirebasePurgeService _i = FirebasePurgeService._();
  factory FirebasePurgeService() => _i;
  FirebasePurgeService._();

  static const _retentionMs = 14 * 24 * 60 * 60 * 1000;

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  bool _ranThisLaunch = false;

  Future<void> _ensureAuth() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (_) {}
  }

  /// Run the sweep once per app launch.
  Future<void> sweepIfNeeded() async {
    if (_ranThisLaunch) return;
    _ranThisLaunch = true;

    try {
      await _ensureAuth();
      final phone = await SessionService().getUserPhone();
      if (phone == null || phone.trim().isEmpty) return;

      final cutoff =
          DateTime.now().millisecondsSinceEpoch - _retentionMs;

      final snap = await _db.ref('user_matches/$phone').get();
      if (!snap.exists) return;
      final byCode = Map<String, dynamic>.from(snap.value as Map);

      final updates = <String, dynamic>{};
      for (final entry in byCode.entries) {
        final code = entry.key;
        final value = Map<String, dynamic>.from(entry.value as Map);
        final updatedAt = (value['updatedAt'] as int?) ?? 0;
        if (updatedAt > 0 && updatedAt < cutoff) {
          updates['matches/$code']             = null;
          updates['user_matches/$phone/$code'] = null;
        }
      }
      if (updates.isNotEmpty) {
        await _db.ref().update(updates);
      }
    } catch (_) {
      // Best-effort — never crash on cleanup.
    }
  }
}
