// lib/widgets/session_list.dart
import 'package:flutter/material.dart';
import 'package:project_camel/models/session.dart';
import 'package:project_camel/widgets/session_list_tile.dart';

class SessionList extends StatelessWidget {
  const SessionList({
    super.key,
    required this.sessions,
    required this.onSessionTap,
    this.showAvatar = true,
    this.embedded = false,
  });

  final List<Session> sessions;
  final void Function(Session) onSessionTap;

  /// If true, the list is rendered without Align/FractionallySizedBox and with
  /// shrinkWrap, so it can be embedded in a Column / SingleChildScrollView.
  final bool embedded;

  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (sessions.isEmpty) {
      return const Center(
        child: Text('Keine Sessions vorhanden'),
      );
    }

    // The core list widget – reused in both modes
    Widget list = ListView.separated(
      padding: const EdgeInsets.all(0),
      itemCount: sessions.length,
      shrinkWrap: embedded,
      physics: embedded
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final session = sessions[index];

        final isFirst = index == 0;
        final isLast = index == sessions.length - 1;

        final borderRadius = BorderRadius.vertical(
          top: isFirst ? const Radius.circular(14) : Radius.zero,
          bottom: isLast ? const Radius.circular(14) : Radius.zero,
        );

        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: borderRadius,
          ),
          child: SessionListTile(
            showAvatar: showAvatar,
            session: session,
            onTap: () => onSessionTap(session),
          ),
        );
      },
    );

    // Embedded mode: just return the list, no fancy sizing
    if (embedded) {
      return list;
    }

    // Original bottom-sheet style (full-screen usage)
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: 0.8,
        child: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: list,
          ),
        ),
      ),
    );
  }
}
