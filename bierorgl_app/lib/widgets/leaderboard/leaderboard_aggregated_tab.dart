import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/session.dart';
import '../../providers.dart';
import '../../screens/leaderboard_screen.dart';
import 'leaderboard_formatters.dart';
import 'leaderboard_item.dart';
import 'leaderboard_list_item_container.dart';
import 'podium_widget.dart';

/// Reusable tab widget for aggregated leaderboard entries (avgTime, count, volume)
/// Uses Riverpod providers and displays top 3 in podium
class LeaderboardAggregatedTab extends ConsumerWidget {
  final LeaderboardParams params;
  final LeaderboardMetric metric;

  /// Provider family to watch - function that takes params and returns AsyncValue
  final AsyncValue<List<AggregatedLeaderboardEntry>> Function(WidgetRef)
      getAsyncData;

  const LeaderboardAggregatedTab({
    super.key,
    required this.params,
    required this.metric,
    required this.getAsyncData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = getAsyncData(ref);
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text("Fehler beim Laden",
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_list_off,
                    size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text("Keine Ergebnisse",
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          );
        }

        final top3 = entries.take(3).toList();

        return CustomScrollView(
          key: PageStorageKey(metric.toString()),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: PodiumWidget<AggregatedLeaderboardEntry>(
                  entries: top3,
                  getTitle: (e) => e.username ?? 'Unbekannt',
                  getValueText: (e) =>
                      LeaderboardFormatter.formatAggregatedValue(e, metric),
                  getSubtitle: (e) =>
                      LeaderboardFormatter.formatAggregatedSubtitle(metric),
                  getInitial: (e) {
                    final name = e.username ?? 'Unbekannt';
                    return name.isNotEmpty ? name[0].toUpperCase() : '?';
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => LeaderboardListItemContainer(
                    index: index,
                    totalCount: entries.length,
                    child: LeaderboardItem<AggregatedLeaderboardEntry>(
                      rank: index + 1,
                      entry: entries[index],
                      getTitle: (e) => e.username ?? 'Unbekannt',
                      getSubtitle: (e) =>
                          LeaderboardFormatter.formatAggregatedSubtitle(metric),
                      getTrailing: (e) =>
                          LeaderboardFormatter.formatAggregatedValue(e, metric),
                      getInitial: (e) {
                        final name = e.username ?? 'Unbekannt';
                        return name.isNotEmpty ? name[0].toUpperCase() : '?';
                      },
                    ),
                  ),
                  childCount: entries.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
