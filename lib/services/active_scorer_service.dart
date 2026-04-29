import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'session_service.dart';

/// Exclusive scoring lock across devices.
///
/// Firebase path: /matches/{matchCode}/activeScorer
///   ├── deviceId   — UUID unique per install (stable)
/// │ ├── phone      — user phone from SessionService
///   ├── claimedAt  — ServerValue.timestamp
///   └── userAgent  — short description (e.g. "Android")
///
/// Usage contract:
///
/// 1. Scoring device calls [claim] every time a scorer enters the live
///    scoring view or resumes online mode → this writes its own
///    [deviceId] into `activeScorer`, **forcibly** taking over from any
///    previous scorer.
///
/// 2. Scoring device calls [watch] to listen for ownership changes.
///    Stream emits `true` while we still own the lock. When another
///    device writes a new `activeScorer`, this emits `false` exactly
///    once, then the caller should navigate out of the scoring view.
///
/// 3. [release] is optional — called on normal exit. Not required for
///    correctness because subsequent claims overwrite.
class ActiveScorerService {
  static final ActiveScorerService _i = ActiveScorerService._();
  factory ActiveScorerService() => _i;
  ActiveScorerService._();

  static const _kDeviceId = 'active_scorer_device_id';

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final SessionService _session = SessionService();
  String? _cachedDeviceId;

  /// Stable install-level device id. Generated once per install, persisted
  /// in SharedPreferences. Not PII — purely an opaque lock holder id.
  Future<String> deviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    final p = await SharedPreferences.getInstance();
    var id = p.getString(_kDeviceId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await p.setString(_kDeviceId, id);
    }
    _cachedDeviceId = id;
    return id;
  }

  Future<void> _ensureAuth() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (_) {}
  }

  /// Claim (or take over) the lock for [matchCode]. Overwrites whatever
  /// was previously there. Returns our own [deviceId] on success.
  Future<String?> claim(String matchCode) async {
    if (matchCode.trim().isEmpty) return null;
    try {
      await _ensureAuth();
      final id = await deviceId();
      final phone = await _session.getUserPhone() ?? '';
      await _db.ref('matches/$matchCode/activeScorer').set({
        'deviceId': id,
        'phone': phone,
        'claimedAt': ServerValue.timestamp,
      });
      return id;
    } catch (_) {
      return null;
    }
  }

  /// Read the current lock holder (or null if none).
  Future<String?> currentHolder(String matchCode) async {
    try {
      await _ensureAuth();
      final snap =
          await _db.ref('matches/$matchCode/activeScorer/deviceId').get();
      if (!snap.exists) return null;
      return snap.value as String?;
    } catch (_) {
      return null;
    }
  }

  /// Stream of ownership. Emits `true` while this device still holds
  /// the lock, `false` once it is taken by someone else (or cleared).
  ///
  /// The stream keeps emitting as state changes — caller typically acts
  /// on the first `false`.
  Stream<bool> watch(String matchCode) async* {
    if (matchCode.trim().isEmpty) {
      yield true;
      return;
    }
    final ownId = await deviceId();
    final ref = _db.ref('matches/$matchCode/activeScorer/deviceId');
    await for (final event in ref.onValue) {
      final remote = event.snapshot.value as String?;
      // If the node does not exist, nobody claims — treat as still ours
      // (we are about to write, or we just released). Only a *different*
      // remote id counts as a loss.
      if (remote == null) {
        yield true;
      } else {
        yield remote == ownId;
      }
    }
  }

  /// Release the lock if we still hold it. Safe to call redundantly.
  Future<void> release(String matchCode) async {
    if (matchCode.trim().isEmpty) return;
    try {
      final ownId = await deviceId();
      final holder = await currentHolder(matchCode);
      if (holder == ownId) {
        await _db.ref('matches/$matchCode/activeScorer').remove();
      }
    } catch (_) {}
  }
}
