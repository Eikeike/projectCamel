import 'package:flutter/material.dart';
import '../../models/session.dart';
import 'leaderboard_formatters.dart';

/// Generic podium widget for displaying top 3 entries (Session or Aggregated)
class PodiumWidget<T> extends StatelessWidget {
  final List<T> entries;

  /// Function to get display name from entry
  final String Function(T) getTitle;

  /// Function to get primary value text from entry (large, centered)
  final String Function(T) getValueText;

  /// Function to get subtitle text from entry (small, in podium block)
  final String Function(T) getSubtitle;

  /// Function to get initial character from entry
  final String Function(T) getInitial;

  const PodiumWidget({
    super.key,
    required this.entries,
    required this.getTitle,
    required this.getValueText,
    required this.getSubtitle,
    required this.getInitial,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return SizedBox(
      height: 280,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: second != null
                ? _PodiumItemGeneric(
                    entry: second,
                    rank: 2,
                    blockHeight: 104,
                    getTitle: getTitle,
                    getValueText: getValueText,
                    getSubtitle: getSubtitle,
                    getInitial: getInitial,
                  )
                : const SizedBox(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: first != null
                ? _PodiumItemGeneric(
                    entry: first,
                    rank: 1,
                    blockHeight: 144,
                    getTitle: getTitle,
                    getValueText: getValueText,
                    getSubtitle: getSubtitle,
                    getInitial: getInitial,
                  )
                : const SizedBox(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: third != null
                ? _PodiumItemGeneric(
                    entry: third,
                    rank: 3,
                    blockHeight: 80,
                    getTitle: getTitle,
                    getValueText: getValueText,
                    getSubtitle: getSubtitle,
                    getInitial: getInitial,
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}

class _PodiumItemGeneric<T> extends StatelessWidget {
  final T entry;
  final int rank;
  final double blockHeight;
  final String Function(T) getTitle;
  final String Function(T) getValueText;
  final String Function(T) getSubtitle;
  final String Function(T) getInitial;

  const _PodiumItemGeneric({
    required this.entry,
    required this.rank,
    required this.blockHeight,
    required this.getTitle,
    required this.getValueText,
    required this.getSubtitle,
    required this.getInitial,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isFirst = rank == 1;

    final containerColor = switch (rank) {
      1 => cs.primaryContainer,
      2 => cs.secondaryContainer,
      _ => cs.tertiaryContainer,
    };
    final onContainer = switch (rank) {
      1 => cs.onPrimaryContainer,
      2 => cs.onSecondaryContainer,
      _ => cs.onTertiaryContainer,
    };

    final name = getTitle(entry);
    final initial = getInitial(entry);
    final valueText = getValueText(entry);
    final subValueText = getSubtitle(entry);

    final avatarRadius = isFirst ? 32.0 : 26.0;

    final podiumShape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: cs.surfaceContainerHighest,
              shape: const CircleBorder(),
              elevation: isFirst ? 2 : 0,
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundColor: cs.surfaceContainerHighest,
                child: Text(
                  initial,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -6,
              top: -6,
              child: Material(
                color: containerColor,
                shape: const CircleBorder(),
                elevation: 1,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: Text(
                      '$rank',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: onContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          valueText,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: containerColor,
          elevation: isFirst ? 2 : 0,
          shape: podiumShape,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: blockHeight,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    subValueText,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isFirst
                        ? Icons.emoji_events_outlined
                        : Icons.military_tech_outlined,
                    size: isFirst ? 36 : 24,
                    color: onContainer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- Concrete implementations for convenience ---

/// Session-specific podium (for Runs tab)
class PodiumSession extends StatelessWidget {
  final List<Session> entries;

  const PodiumSession({
    super.key,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    return PodiumWidget<Session>(
      entries: entries,
      getTitle: (s) => s.username ?? 'Unbekannt',
      getValueText: (s) => LeaderboardFormatter.formatDurationMS(s.durationMS),
      getSubtitle: (s) => LeaderboardFormatter.formatRunsSubtitle(s),
      getInitial: (s) {
        final name = s.username ?? 'Unbekannt';
        return name.isNotEmpty ? name[0].toUpperCase() : '?';
      },
    );
  }
}
