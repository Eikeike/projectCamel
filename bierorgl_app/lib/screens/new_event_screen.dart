import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/auth/auth_providers.dart';
import 'package:project_camel/providers.dart';
import 'package:project_camel/screens/debug_screen.dart';
import 'package:project_camel/theme/app_theme.dart';
import 'package:project_camel/widgets/event_list_tile.dart';

class NewEventScreen extends ConsumerWidget {
  const NewEventScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    if (authState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final eventsAsync = ref.watch(allEventsProvider);
    final userId = authState.userId!;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
      ),
      body: eventsAsync.when(
        
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (events) {
          if (events.isEmpty) {
            return const Center(child: Text('Nix los hier'));
          }

          return Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.8,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final event = events[index];

                      final isFirst = index == 0;
                      final isLast = index == events.length - 1;

                      final borderRadius = BorderRadius.vertical(
                        top: isFirst ? const Radius.circular(14) : Radius.zero,
                        bottom: isLast ? const Radius.circular(14) : Radius.zero,
                      );

                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLow, // or any bg color
                          borderRadius: borderRadius,
                        ),
                        child: EventListTile(event: event),
                      );
                    },
                  )
                ),
              ),
            ),
          );



        },
      ),
    );
  }
}
