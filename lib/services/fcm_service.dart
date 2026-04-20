// ─────────────────────────────────────────────────────────────────────────────
// lib/services/fcm_service.dart
//
// Handles Firebase Cloud Messaging:
//   - Permission request (Android 13+ POST_NOTIFICATIONS, iOS alerts)
//   - FCM token generation + save to Firestore
//   - Token refresh listener
//   - Foreground message handler (in-app banner via GetX snackbar)
//   - Background tap handler (deep link to toss page)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/constants/app_routes.dart';
import '../core/theme/app_theme.dart';

/// Top-level background message handler.
/// Must be a top-level function (not a class method) per FCM requirements.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // When the app is killed / background, FCM auto-displays notification
  // from the `notification` payload. No action needed here unless we want
  // custom logic (e.g. sync to local DB).
  print('📬 FCM bg message: ${message.messageId} → ${message.data}');
}

class FcmService {
  static final FcmService _i = FcmService._();
  factory FcmService() => _i;
  FcmService._();

  final _messaging = FirebaseMessaging.instance;
  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;

  bool _initialized = false;

  /// Call once at app startup, after Firebase.initializeApp.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Request permission (silent if already granted)
    await _requestPermission();

    // 3. Get + save current token
    await _saveCurrentToken();

    // 4. Listen for token refresh (e.g. app reinstall)
    _messaging.onTokenRefresh.listen((newToken) {
      _saveTokenToFirestore(newToken);
    });

    // 5. Foreground messages → show snackbar
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 6. App opened from a background notification tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 7. Check if app was opened from a terminated state by a notification
    final initialMsg = await _messaging.getInitialMessage();
    if (initialMsg != null) {
      // Delay so routes are registered
      Future.delayed(const Duration(seconds: 1),
              () => _handleNotificationTap(initialMsg));
    }
  }

  // ── Permissions ──────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    print('🔔 FCM permission: ${settings.authorizationStatus}');
  }

  // ── Token management ─────────────────────────────────────────────────────

  Future<void> _saveCurrentToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      print('⚠️ FCM token fetch failed: $e');
    }
  }

  /// Saves the FCM token under users/{userId}/fcmTokens array.
  /// Uses phoneNumber if available, else UID.
  Future<void> _saveTokenToFirestore(String token) async {
    final user = _auth.currentUser;
    if (user == null) {
      print('⚠️ FCM: no logged-in user, skipping token save');
      return;
    }

    final userId = (user.phoneNumber?.isNotEmpty ?? false)
        ? user.phoneNumber!
        : user.uid;

    try {
      final doc = _firestore.collection('users').doc(userId);
      await doc.set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
        'userId': userId,
      }, SetOptions(merge: true));

      print('✅ FCM token saved for $userId');
    } catch (e) {
      print('❌ FCM token save failed: $e');
    }
  }

  /// Remove this device's token from Firestore on logout.
  Future<void> removeCurrentToken() async {
    try {
      final token = await _messaging.getToken();
      final user = _auth.currentUser;
      if (token == null || user == null) return;

      final userId = (user.phoneNumber?.isNotEmpty ?? false)
          ? user.phoneNumber!
          : user.uid;

      await _firestore.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    } catch (e) {
      print('⚠️ FCM token removal failed: $e');
    }
  }

  // ── Message handlers ─────────────────────────────────────────────────────

  /// Foreground: app is open and active.
  void _handleForegroundMessage(RemoteMessage message) {
    print('📬 FCM fg message: ${message.notification?.title}');

    final title = message.notification?.title ?? 'Match reminder';
    final body  = message.notification?.body  ?? '';

    Get.snackbar(
      title,
      body,
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppTheme.primary,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 10,
      duration: const Duration(seconds: 5),
      icon: const Icon(Icons.notifications_active_rounded,
          color: Colors.white),
      onTap: (_) => _handleNotificationTap(message),
    );
  }

  /// Notification tap → deep link to toss page if payload is a match reminder.
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    print('🎯 FCM tap: $data');

    final type = data['type'];
    if (type == 'match_reminder') {
      final tournamentId = data['tournamentId'] as String?;
      final matchId      = data['matchId']      as String?;
      if (tournamentId != null && matchId != null) {
        Get.toNamed(AppRoutes.tournamentToss, arguments: {
          'tournamentId': tournamentId,
          'matchId':      matchId,
        });
      }
    }
  }
}