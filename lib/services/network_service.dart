// ─────────────────────────────────────────────────────────────────────────────
// lib/services/network_service.dart
//
// Single source of truth for online / offline state across the app.
//
// Strategy:
//   1. Subscribe to Firebase Realtime Database's `.info/connected` node —
//      this is push-based and reflects whether the SDK currently has an
//      active websocket to Firebase (i.e. real internet, not just LAN).
//   2. Run a one-shot DNS probe at startup so we don't show a false
//      "online" flash before Firebase reconnects.
//
// Views read `NetworkService().isOnline` (Rx) via Obx and either disable
// network-dependent buttons or show retry UI. The global offline banner
// in main.dart's GetMaterialApp builder also reads this.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NetworkService {
  static final NetworkService _i = NetworkService._();
  factory NetworkService() => _i;
  NetworkService._();

  /// True when the app has working internet, false otherwise.
  /// Defaults to `true` so we don't flash an offline banner before the
  /// first probe completes.
  final RxBool isOnline = true.obs;

  StreamSubscription? _fbSub;
  bool _started = false;

  /// Call once from main() after Firebase.initializeApp.
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    // 1. One-shot DNS probe so the initial value reflects reality.
    //    Firebase RTDB's `.info/connected` can take a few seconds to
    //    settle; this gets us the right answer immediately.
    isOnline.value = await _dnsProbe();

    // 2. Subscribe to Firebase's authoritative connection signal.
    try {
      _fbSub = FirebaseDatabase.instance
          .ref('.info/connected')
          .onValue
          .listen((event) {
        final connected = (event.snapshot.value as bool?) ?? false;
        if (isOnline.value != connected) {
          debugPrint('[NetworkService] online → $connected');
          isOnline.value = connected;
        }
      }, onError: (e) {
        debugPrint('[NetworkService] firebase listener error: $e');
      });
    } catch (e) {
      debugPrint('[NetworkService] failed to subscribe: $e');
    }
  }

  Future<void> dispose() async {
    await _fbSub?.cancel();
    _fbSub = null;
    _started = false;
  }

  /// Force an immediate probe — useful before kicking off a network
  /// operation so we can short-circuit with a friendly message rather
  /// than waiting for a long socket timeout.
  Future<bool> recheck() async {
    final online = await _dnsProbe();
    isOnline.value = online;
    return online;
  }

  Future<bool> _dnsProbe() async {
    try {
      final result = await InternetAddress.lookup('firebase.google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Shorthand to be used inside view actions:
  ///
  ///   if (!await NetworkService().requireOnline()) return;
  ///   // ... safe to issue network call ...
  ///
  /// Shows a snackbar when offline so the user has feedback without
  /// every caller re-implementing it.
  Future<bool> requireOnline({String? action}) async {
    if (isOnline.value) return true;
    final ok = await recheck();
    if (ok) return true;
    Get.snackbar(
      'No internet',
      action == null
          ? 'Connect to the internet and try again.'
          : 'Connect to the internet to $action.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFB00020),
      colorText: const Color(0xFFFFFFFF),
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(12),
      borderRadius: 10,
      icon: const Icon(Icons.wifi_off_rounded, color: Color(0xFFFFFFFF)),
    );
    return false;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL OFFLINE BANNER
//
// Mounted once in main.dart's GetMaterialApp `builder`. Slides down from the
// top whenever `NetworkService().isOnline` flips to false, and slides back up
// once connectivity returns.
// ═══════════════════════════════════════════════════════════════════════════════
class GlobalOfflineBanner extends StatelessWidget {
  const GlobalOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Obx(() {
      final online = NetworkService().isOnline.value;
      return IgnorePointer(
        // When the banner is hidden it must not swallow taps near the
        // top edge of whatever screen is showing.
        ignoring: online,
        child: AnimatedSlide(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        offset: online ? const Offset(0, -1) : Offset.zero,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 240),
          opacity: online ? 0 : 1,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.only(
                top: topInset + 4,
                bottom: 8,
                left: 14,
                right: 14,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFB00020), Color(0xFF7F0011)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: Color(0xFFFFFFFF), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'No internet — some features are offline',
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => NetworkService().recheck(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.35), width: 1),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      );
    });
  }
}
