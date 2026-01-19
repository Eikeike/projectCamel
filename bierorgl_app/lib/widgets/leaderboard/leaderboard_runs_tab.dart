import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/screens/new_session_screen.dart';
import '../../models/session.dart';
import '../../providers.dart';
import 'leaderboard_item.dart';
import 'leaderboard_list_item_container.dart';
import 'podium_widget.dart';

/// Runs tab for leaderboard using Riverpod provider
class LeaderboardRunsTab extends ConsumerWidget {
  final LeaderboardParams params;

  const LeaderboardRunsTab({
    super.key,
    required this.params,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLeaderBoardData = ref.watch(leaderboardSessionsProvider(params));

    return asyncLeaderBoardData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) {
        debugPrint("Leaderboard error: $error");
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                "Fehler beim Laden des Leaderboards",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        );
      },
      data: (sessions) {
        if (sessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_list_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  "Keine Ergebnisse",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        final top3 = sessions.take(3).toList();

        return CustomScrollView(
          key: const PageStorageKey('leaderboard_runs'),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: PodiumSession(entries: top3),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => LeaderboardListItemContainer(
                    index: index,
                    totalCount: sessions.length,
                    child: LeaderboardItemSession(
                      rank: index + 1,
                      session: sessions[index],
                      onTap: (s) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SessionScreen(session: s),
                          ),
                        );
                      },
                    ),
                  ),
                  childCount: sessions.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
