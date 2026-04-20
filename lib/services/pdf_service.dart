import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../core/utils/app_utils.dart';

class PdfService {
  // ── Color Palette ─────────────────────────────────────────────────────────
  static const PdfColor _green = PdfColor.fromInt(0xFF1B5E20);
  static const PdfColor _greenLight = PdfColor.fromInt(0xFF4CAF50);
  static const PdfColor _gold = PdfColor.fromInt(0xFFFFC107);
  static const PdfColor _bg = PdfColor.fromInt(0xFFF5F5F5);
  static const PdfColor _white = PdfColors.white;
  static const PdfColor _darkText = PdfColor.fromInt(0xFF212121);
  static const PdfColor _greyText = PdfColor.fromInt(0xFF757575);
  static const PdfColor _border = PdfColor.fromInt(0xFFE0E0E0);
  static const PdfColor _headerRow = PdfColor.fromInt(0xFF1B5E20);
  static const PdfColor _altRow = PdfColor.fromInt(0xFFE8F5E9);

  Future<File> generateMatchReport({
    required MatchModel match,
    required InningsModel innings1,
    required InningsModel innings2,
    required List<PlayerModel> teamAPlayers,
    required List<PlayerModel> teamBPlayers,
    required List<BallModel> innings1Balls,
    required List<BallModel> innings2Balls,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          _buildHeader(match),
          pw.SizedBox(height: 16),
          _buildMatchInfo(match),
          pw.SizedBox(height: 16),
          _buildResultBanner(match),
          pw.SizedBox(height: 20),

          // Innings 1
          _buildInningsHeader(innings1, match),
          pw.SizedBox(height: 8),
          _buildBattingTable(
            teamAPlayers.where((p) => p.didBat || p.runsScored > 0 || p.ballsFaced > 0).toList(),
            innings1,
          ),
          pw.SizedBox(height: 8),
          _buildBowlingTable(
            teamBPlayers.where((p) => p.ballsBowled > 0).toList(),
          ),
          pw.SizedBox(height: 8),
          _buildExtrasRow(innings1),
          pw.SizedBox(height: 8),
          _buildInningsTotals(innings1),
          pw.SizedBox(height: 20),

          // Innings 2
          _buildInningsHeader(innings2, match),
          pw.SizedBox(height: 8),
          _buildBattingTable(
            teamBPlayers.where((p) => p.didBat || p.runsScored > 0 || p.ballsFaced > 0).toList(),
            innings2,
          ),
          pw.SizedBox(height: 8),
          _buildBowlingTable(
            teamAPlayers.where((p) => p.ballsBowled > 0).toList(),
          ),
          pw.SizedBox(height: 8),
          _buildExtrasRow(innings2),
          pw.SizedBox(height: 8),
          _buildInningsTotals(innings2),

          if (match.manOfTheMatch != null) ...[
            pw.SizedBox(height: 20),
            _buildMotmBanner(match.manOfTheMatch!),
          ],

          pw.SizedBox(height: 20),
          _buildFooter(),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/match_report_${match.id}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _buildHeader(MatchModel match) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [_green, _greenLight],
        ),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            '🏏 CRICKET MATCH REPORT',
            style: pw.TextStyle(
              color: _white,
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '${match.teamAName}  vs  ${match.teamBName}',
            style: pw.TextStyle(color: _gold, fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            AppUtils.formatDateTime(match.matchDate),
            style: const pw.TextStyle(color: _white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMatchInfo(MatchModel match) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _bg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _infoItem('Format', '${match.totalOvers} Overs'),
          _infoItem('Toss', '${match.tossWinner} won'),
          _infoItem('Batted First', match.battingFirst),
        ],
      ),
    );
  }

  pw.Widget _infoItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(color: _greyText, fontSize: 10)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(color: _darkText, fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _buildResultBanner(MatchModel match) {
    if (match.result == null) return pw.SizedBox();
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: _gold,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Center(
        child: pw.Text(
          '🏆 ${match.result}',
          style: pw.TextStyle(
            color: _darkText,
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }

  pw.Widget _buildInningsHeader(InningsModel innings, MatchModel match) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: _green,
        borderRadius: const pw.BorderRadius.only(
          topLeft: pw.Radius.circular(6),
          topRight: pw.Radius.circular(6),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Innings ${innings.inningsNumber}: ${innings.battingTeam}',
            style: pw.TextStyle(
              color: _white,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            '${innings.totalRuns}/${innings.totalWickets}  (${innings.oversBowled} ov)',
            style: pw.TextStyle(color: _gold, fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildBattingTable(List<PlayerModel> players, InningsModel innings) {
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1),
        4: pw.FlexColumnWidth(1),
        5: pw.FlexColumnWidth(1),
        6: pw.FlexColumnWidth(1.5),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headerRow),
          children: [
            _tableHeader('Batsman'),
            _tableHeader('Dismissal'),
            _tableHeader('R'),
            _tableHeader('B'),
            _tableHeader('4s'),
            _tableHeader('6s'),
            _tableHeader('SR'),
          ],
        ),
        // Rows
        ...players.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? _white : _altRow,
            ),
            children: [
              _tableCell(p.name, bold: true),
              _tableCell(_dismissalText(p), small: true),
              _tableCell('${p.runsScored}', bold: true),
              _tableCell('${p.ballsFaced}'),
              _tableCell('${p.fours}'),
              _tableCell('${p.sixes}'),
              _tableCell(AppUtils.formatDouble(p.strikeRate)),
            ],
          );
        }),
        // DNB
        ...players.where((p) => !p.didBat && p.ballsFaced == 0).map(
              (p) => pw.TableRow(
                decoration: const pw.BoxDecoration(color: _white),
                children: [
                  _tableCell(p.name),
                  _tableCell('Did Not Bat', small: true),
                  _tableCell('-'),
                  _tableCell('-'),
                  _tableCell('-'),
                  _tableCell('-'),
                  _tableCell('-'),
                ],
              ),
            ),
      ],
    );
  }

  pw.Widget _buildBowlingTable(List<PlayerModel> bowlers) {
    if (bowlers.isEmpty) return pw.SizedBox();
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1),
        4: pw.FlexColumnWidth(1),
        5: pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey700),
          children: [
            _tableHeader('Bowler'),
            _tableHeader('O'),
            _tableHeader('R'),
            _tableHeader('W'),
            _tableHeader('WD'),
            _tableHeader('Econ'),
          ],
        ),
        ...bowlers.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: i.isEven ? _white : _altRow),
            children: [
              _tableCell(p.name, bold: true),
              _tableCell(p.oversBoled),
              _tableCell('${p.runsConceded}'),
              _tableCell('${p.wicketsTaken}', bold: true),
              _tableCell('${p.wides}'),
              _tableCell(AppUtils.formatDouble(p.economy)),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildExtrasRow(InningsModel innings) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      color: _bg,
      child: pw.Row(
        children: [
          pw.Text('Extras: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.Text(
            '${innings.extras}  (WD: ${innings.wides}, NB: ${innings.noBalls}, B: ${innings.byes}, LB: ${innings.legByes})',
            style: const pw.TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInningsTotals(InningsModel innings) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: _green.shade(0.9),
        borderRadius: const pw.BorderRadius.only(
          bottomLeft: pw.Radius.circular(6),
          bottomRight: pw.Radius.circular(6),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Total: ${innings.totalRuns}/${innings.totalWickets}',
            style: pw.TextStyle(color: _white, fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
          pw.Text(
            '${innings.oversBowled} Overs',
            style: const pw.TextStyle(color: _white, fontSize: 11),
          ),
          pw.Text(
            'RR: ${AppUtils.formatDouble(innings.runRate)}',
            style: const pw.TextStyle(color: _gold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMotmBanner(String name) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(colors: [_gold, PdfColor.fromInt(0xFFFFE082)]),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text('⭐ Man of the Match: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.Text(name,
              style: pw.TextStyle(
                  fontSize: 15, fontWeight: pw.FontWeight.bold, color: _green)),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border)),
      ),
      child: pw.Center(
        child: pw.Text(
          'Generated by Cricket Scorer App  •  ${AppUtils.formatDateTime(DateTime.now())}',
          style: const pw.TextStyle(color: _greyText, fontSize: 9),
        ),
      ),
    );
  }

  // ── Table Helpers ─────────────────────────────────────────────────────────

  pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          color: _white,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _tableCell(String text, {bool bold = false, bool small = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: small ? 9 : 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: _darkText,
        ),
      ),
    );
  }

  String _dismissalText(PlayerModel p) {
    if (!p.isOut) return 'not out';
    switch (p.wicketType) {
      case 'Bowled':
        return 'b ${p.bowlerName ?? ''}';
      case 'Caught':
        return 'c ${p.dismissedBy ?? ''} b ${p.bowlerName ?? ''}';
      case 'LBW':
        return 'lbw b ${p.bowlerName ?? ''}';
      case 'Run Out':
        return 'run out (${p.dismissedBy ?? ''})';
      case 'Stumped':
        return 'st ${p.dismissedBy ?? ''} b ${p.bowlerName ?? ''}';
      case 'Hit Wicket':
        return 'hit wkt b ${p.bowlerName ?? ''}';
      default:
        return p.wicketType ?? 'out';
    }
  }
}
