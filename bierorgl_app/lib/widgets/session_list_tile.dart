// lib/widgets/session_list_tile.dart

import 'package:flutter/material.dart';
import 'package:project_camel/models/session.dart';

enum SessionTileInfo {
  volume,
  date,
  event,
}

class SessionListTile extends StatelessWidget {
  const SessionListTile({
    super.key,
    required this.session,
    this.onTap,
    this.showAvatar = true,
    this.avatarUrl,
    this.avatarInitials,
    this.info = const [
      SessionTileInfo.volume,
      SessionTileInfo.date,
    ],
  });

  final Session session;
  final VoidCallback? onTap;

  /// --- Avatar ---
  final bool showAvatar;
  final String? avatarUrl;
  final String? avatarInitials;

  /// --- Which metadata lines to show under title ---
  final List<SessionTileInfo> info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    final title = session.displayName;

    final startedAtLocal = session.startedAt.toLocal();
    final dateLabel = '${startedAtLocal.day.toString().padLeft(2, '0')}.'
        '${startedAtLocal.month.toString().padLeft(2, '0')} '
        '${startedAtLocal.hour.toString().padLeft(2, '0')}:'
        '${startedAtLocal.minute.toString().padLeft(2, '0')}';

    final volumeLabel = '${session.volumeLiters.toStringAsFixed(2)} L';
    final eventLabel = session.eventName ?? 'Privat';

    final durationLabel =
        '${(session.duration.inMilliseconds / 1000).toStringAsFixed(2)} s';

    final List<String> subtitleParts = [];

    for (final i in info) {
      switch (i) {
        case SessionTileInfo.volume:
          subtitleParts.add(volumeLabel);
          break;
        case SessionTileInfo.date:
          subtitleParts.add(dateLabel);
          break;
        case SessionTileInfo.event:
          subtitleParts.add(eventLabel);
          break;
      }
    }

    final subtitleText = subtitleParts.join(' • ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ---------- Avatar ----------
            if (showAvatar) ...[
              _buildAvatar(cs),
              const SizedBox(width: 12),
            ],

            // ---------- Title & Metadata ----------
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),

                  // Subtitle metadata row
                  if (subtitleText.isNotEmpty)
                    Text(
                      subtitleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // ---------- Duration Right Side ----------
            Text(
              durationLabel,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ColorScheme cs) {
    if (!showAvatar) return const SizedBox.shrink();

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(avatarUrl!),
      );
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: cs.primaryContainer,
      child: Text(
        (avatarInitials ??
                session.userRealName?.characters.first ??
                session.username?.characters.first ??
                '?')
            .toUpperCase(),
      ),
    );
  }
}
