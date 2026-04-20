class AppUtils {
  /// Format overs: balls → "X.Y" string  (e.g. 37 balls → "6.1")
  static String formatOvers(int totalBalls) {
    final overs = totalBalls ~/ 6;
    final balls = totalBalls % 6;
    return '$overs.$balls';
  }

  /// Parse overs string "X.Y" → total balls
  static int oversToTotalBalls(String overs) {
    final parts = overs.split('.');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 6 + (int.tryParse(parts[1]) ?? 0);
  }

  /// Calculate run rate
  static double calculateRunRate(int runs, int totalBalls) {
    if (totalBalls == 0) return 0.0;
    return (runs / totalBalls) * 6;
  }

  /// Calculate required run rate
  static double calculateRequiredRunRate(int runsNeeded, int ballsRemaining) {
    if (ballsRemaining == 0) return 0.0;
    return (runsNeeded / ballsRemaining) * 6;
  }

  /// Calculate strike rate
  static double calculateStrikeRate(int runs, int balls) {
    if (balls == 0) return 0.0;
    return (runs / balls) * 100;
  }

  /// Calculate economy
  static double calculateEconomy(int runs, int totalBalls) {
    if (totalBalls == 0) return 0.0;
    return (runs / totalBalls) * 6;
  }

  /// Format double to 2 decimal places
  static String formatDouble(double value) {
    return value.toStringAsFixed(2);
  }

  /// Format date
  static String formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Format datetime with time
  static String formatDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${formatDate(date)}, $hour:$minute';
  }

  /// Over text e.g. "6.3 ov"
  static String oversText(int balls) => '${formatOvers(balls)} ov';

  /// Score text e.g. "145/3"
  static String scoreText(int runs, int wickets) => '$runs/$wickets';
}
