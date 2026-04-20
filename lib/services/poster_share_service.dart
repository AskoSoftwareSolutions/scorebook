// ─────────────────────────────────────────────────────────────────────────────
// lib/services/poster_share_service.dart
//
// Captures a widget (via GlobalKey + RepaintBoundary) as a PNG image,
// saves to temp directory, and launches the OS share sheet.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PosterShareService {
  static final PosterShareService _i = PosterShareService._();
  factory PosterShareService() => _i;
  PosterShareService._();

  /// Capture the widget behind [key] as a PNG image.
  /// Uses device pixel ratio 3.0 for crisp output on high-DPI screens.
  Future<Uint8List?> capturePoster(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // High resolution for WhatsApp (720-1080 width typical)
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('❌ Poster capture failed: $e');
      return null;
    }
  }

  /// Save PNG bytes to temp directory and return the file path.
  Future<File?> savePosterToFile({
    required Uint8List pngBytes,
    required String tournamentName,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final safeName = tournamentName
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          .toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/poster_${safeName}_$timestamp.png');
      await file.writeAsBytes(pngBytes);
      return file;
    } catch (e) {
      print('❌ Poster save failed: $e');
      return null;
    }
  }

  /// One-shot: capture + save + share via OS share sheet.
  Future<bool> sharePoster({
    required GlobalKey posterKey,
    required String tournamentName,
    String? text,
  }) async {
    // 1. Capture
    final bytes = await capturePoster(posterKey);
    if (bytes == null) return false;

    // 2. Save
    final file = await savePosterToFile(
      pngBytes: bytes,
      tournamentName: tournamentName,
    );
    if (file == null) return false;

    // 3. Share (opens WhatsApp / any app via share sheet)
    try {
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: text ?? '🏏 $tournamentName — Match Schedule',
        subject: tournamentName,
      );
      return true;
    } catch (e) {
      print('❌ Share failed: $e');
      return false;
    }
  }
}