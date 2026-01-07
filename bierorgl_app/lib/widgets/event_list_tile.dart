import 'package:flutter/material.dart';
import 'package:project_camel/models/event.dart';

class EventListTile extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;

  const EventListTile({
    super.key,
    required this.event,
    this.onTap,
  });

  bool get isActive {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final from = event.dateFrom;
    final to = event.dateTo;

    DateTime? start =
        from == null ? null : DateTime(from.year, from.month, from.day);
    DateTime? end = to == null ? null : DateTime(to.year, to.month, to.day);

    // both exist
    if (start != null && end != null) {
      return today.isAtSameMomentAs(start) ||
          today.isAtSameMomentAs(end) ||
          (today.isAfter(start) && today.isBefore(end));
    }

    // only start → already started
    if (start != null) {
      return today.isAtSameMomentAs(start) || today.isAfter(start);
    }

    // only end → still ongoing until that day
    if (end != null) {
      return today.isAtSameMomentAs(end) || today.isBefore(end);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: _ActiveIndicator(isActive: isActive),
      title: Text(
        event.name,
          style: theme.textTheme.titleMedium?.copyWith(
    color: Theme.of(context).colorScheme.onSurface,
  ),

      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.description != null && event.description!.isNotEmpty)
            Text(
              event.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
          Text(_formattedDateRange(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    );
  }

  String _formattedDateRange() {
    final from = event.dateFrom;
    final to = event.dateTo;

    if (from == null && to == null) return "No date";

    String fmt(DateTime d) =>
        "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";

    if (from != null && to != null) return "${fmt(from)} - ${fmt(to)}";
    if (from != null) return "From ${fmt(from)}";
    return "Until ${fmt(to!)}";
  }
}

class _ActiveIndicator extends StatelessWidget {
  final bool isActive;

  const _ActiveIndicator({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.green : Colors.grey,
      ),
    );
  }
}
