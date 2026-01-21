import 'package:flutter/material.dart';
import '../../models/session.dart';
import 'leaderboard_formatters.dart';

/// Generic leaderboard item widget for ranked entries (Session or Aggregated)
class LeaderboardItem<T> extends StatelessWidget {
  final int rank;
  final T entry;

  final String Function(T) getTitle;
  final String Function(T) getSubtitle;
  final String Function(T) getTrailing;
  final String Function(T) getInitial;
  final void Function(T entry)? onTap;

  const LeaderboardItem({
    super.key,
    required this.rank,
    required this.entry,
    required this.getTitle,
    required this.getSubtitle,
    required this.getTrailing,
    required this.getInitial,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final name = getTitle(entry);
    final initial = getInitial(entry);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      onTap: onTap == null ? null : () => onTap!(entry),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.secondaryContainer,
            child: Text(
              initial,
              style: TextStyle(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      title: Text(
        name,
        style:
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        getSubtitle(entry),
        style: theme.textTheme.bodySmall
            ?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      trailing: Text(
        getTrailing(entry),
        style: theme.textTheme.titleMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// --- Concrete implementations for convenience ---

/// Session-specific leaderboard item (for Runs tab)
class LeaderboardItemSession extends StatelessWidget {
  final int rank;
  final Session session;
  final void Function(Session session)? onTap;

  const LeaderboardItemSession({
    super.key,
    required this.rank,
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LeaderboardItem<Session>(
      rank: rank,
      entry: session,
      onTap: onTap,
      getTitle: (s) => s.username ?? s.userRealName ?? 'Unbekannt',
      getSubtitle: (s) => LeaderboardFormatter.formatRunsSubtitle(s),
      getTrailing: (s) => LeaderboardFormatter.formatDurationMS(s.durationMS),
      getInitial: (s) {
        final name = s.username ?? s.userRealName ?? 'Unbekannt';
        return name.isNotEmpty ? name[0].toUpperCase() : '?';
      },
    );
  }
}
