import 'package:intl/intl.dart';
import '../../models/session.dart';
import '../../screens/leaderboard_screen.dart';

/// Formatters for leaderboard displays
class LeaderboardFormatter {
  /// Format a Session duration in milliseconds to seconds string (e.g., "1.23s")
  static String formatDurationMS(int milliseconds) {
    return '${(milliseconds / 1000).toStringAsFixed(2)}s';
  }

  /// Format a Session for runs tab subtitle (e.g., "0.50 L • 12.01.")
  static String formatRunsSubtitle(Session session) {
    final vol = session.volumeLiters;
    final date = _formatDate(session.startedAt.toIso8601String());
    return '${vol.toStringAsFixed(2)} L • $date';
  }

  /// Format aggregated entry value based on metric type
  static String formatAggregatedValue(
    AggregatedLeaderboardEntry entry,
    LeaderboardMetric metric,
  ) {
    final value = entry.value;
    if (value == null) return '-';

    final numValue = (value is int) ? value : (value as double).toInt();

    return switch (metric) {
      LeaderboardMetric.avgTime =>
        '${(numValue / 1000).toStringAsFixed(2)}s', // avg seconds
      LeaderboardMetric.count => '${numValue}x', // count
      LeaderboardMetric.volume =>
        '${(numValue / 1000).toStringAsFixed(1)} L', // milliliters to liters
      LeaderboardMetric.sessions =>
        '', // N/A for aggregated, but required for switch
    };
  }

  /// Format aggregated entry subtitle based on metric type
  static String formatAggregatedSubtitle(LeaderboardMetric metric) {
    return switch (metric) {
      LeaderboardMetric.avgTime => 'Durchschnitt / Liter',
      LeaderboardMetric.count => 'Gesamtanzahl',
      LeaderboardMetric.volume => 'Gesamtvolumen',
      LeaderboardMetric.sessions => '',
    };
  }

  /// Helper to format ISO date to "dd.MM."
  static String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      return DateFormat('dd.MM.yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return '';
    }
  }
}
