import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/auth/auth_providers.dart';
import 'package:project_camel/providers.dart';
import 'package:project_camel/screens/debug_screen.dart';
import 'package:project_camel/screens/event_edit_screen.dart';
import 'package:project_camel/theme/app_theme.dart';
import 'package:project_camel/widgets/event_list_tile.dart';

class NewEventScreen extends ConsumerStatefulWidget {
  const NewEventScreen({super.key});

  @override
  ConsumerState<NewEventScreen> createState() => _NewEventScreenState();
}

class _NewEventScreenState extends ConsumerState<NewEventScreen> {
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text('Events',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const EventEditScreen())),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (events) {
          if (events.isEmpty) {
            return const Center(child: Text('Nix los hier'));
          }

          final query = _searchQuery.trim().toLowerCase();
          final filtered = query.isEmpty
              ? events
              : events
                  .where((e) =>
                      e.name.toLowerCase().contains(query) ||
                      (e.description ?? '').toLowerCase().contains(query))
                  .toList();

          return Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.9,
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
                  child: Column(
                    children: [
                      // Material themed search bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                        child: SearchAnchor(
                          builder: (BuildContext context,
                              SearchController controller) {
                            return SearchBar(
                              controller: controller,
                              padding: const WidgetStatePropertyAll<EdgeInsets>(
                                EdgeInsets.symmetric(horizontal: 16.0),
                              ),
                              hintText: 'Events suchen...',
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                              leading: const Icon(Icons.search),
                              trailing: [
                                if (_searchQuery.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      controller.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  ),
                              ],
                            );
                          },
                          suggestionsBuilder: (BuildContext context,
                              SearchController controller) {
                            return [];
                          },
                        ),
                      ),

                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final event = filtered[index];

                            final isFirst = index == 0;
                            final isLast = index == filtered.length - 1;

                            final borderRadius = BorderRadius.vertical(
                              top: isFirst
                                  ? const Radius.circular(14)
                                  : Radius.zero,
                              bottom: isLast
                                  ? const Radius.circular(14)
                                  : Radius.zero,
                            );

                            return Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLow,
                                borderRadius: borderRadius,
                              ),
                              child: EventListTile(
                                  event: event,
                                  onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              EventEditScreen(event: event)))),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
