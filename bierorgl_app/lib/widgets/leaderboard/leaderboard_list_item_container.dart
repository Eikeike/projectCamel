import 'package:flutter/material.dart';

/// Reusable container widget for leaderboard list items with dynamic border radius
/// Handles rounded corners: top for first item, bottom for last item, none for middle items
class LeaderboardListItemContainer extends StatelessWidget {
  final int index;
  final int totalCount;
  final Widget child;

  const LeaderboardListItemContainer({
    super.key,
    required this.index,
    required this.totalCount,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isFirst = index == 0;
    final isLast = index == totalCount - 1;

    final borderRadius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(12) : Radius.zero,
      bottom: isLast ? const Radius.circular(12) : Radius.zero,
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: borderRadius,
      ),
      margin: isFirst ? EdgeInsets.zero : const EdgeInsets.only(top: 4),
      child: child,
    );
  }
}
