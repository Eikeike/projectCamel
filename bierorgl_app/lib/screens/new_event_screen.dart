import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/auth/auth_providers.dart';
import 'package:project_camel/providers.dart';
import 'package:project_camel/screens/event_edit_screen.dart';
import 'package:project_camel/widgets/event_list_tile.dart';
import 'package:project_camel/providers/event_filters_provider.dart';
import 'package:project_camel/models/event.dart';

class NewEventScreen extends ConsumerStatefulWidget {
  const NewEventScreen({super.key});

  @override
  ConsumerState<NewEventScreen> createState() => _NewEventScreenState();
}

class _NewEventScreenState extends ConsumerState<NewEventScreen> {
  @override
  Widget build(BuildContext context) {
    final bool isAuthLoading = ref.watch(
      authControllerProvider.select((value) => value.isLoading),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Events',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditScreen(context),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: isAuthLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context),
    );
  }

  void _navigateToEditScreen(BuildContext context, [dynamic event]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventEditScreen(event: event),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final filters = ref.watch(eventFiltersProvider);
    final filtersNotifier = ref.read(eventFiltersProvider.notifier);
    final eventsAsync = ref.watch(allEventsProvider);

    final userState = ref.read(authControllerProvider);
    if (userState.userId == null && !userState.isLoading) {
      return const Center(child: Text('Kein Benutzer angemeldet.'));
    }

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (events) {
        final filteredAndSorted = _applyFiltersAndSort(events, filters);

        return Column(
          children: [
            // --- FILTER BEREICH ---
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                children: [
                  // Suchzeile ohne Reset-Button
                  SearchBar(
                    hintText: 'Events suchen...',
                    elevation: const WidgetStatePropertyAll(0),
                    backgroundColor: WidgetStatePropertyAll(
                        Theme.of(context).colorScheme.surfaceContainerLow),
                    onChanged: (value) => filtersNotifier.setSearchQuery(value),
                    leading: const Icon(Icons.search),
                    trailing: [
                      if (filters.searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => filtersNotifier.setSearchQuery(''),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Horizontale Sortier-Chips
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: EventSortOrder.values.map((order) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(_getSortLabel(order)),
                            selected: filters.sortOrder == order,
                            onSelected: (selected) {
                              if (selected) filtersNotifier.setSortOrder(order);
                            },
                            showCheckmark: false, // Cleaner Look ohne Haken
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // --- LISTEN BEREICH ---
            Expanded(
              child: filteredAndSorted.isEmpty
                  ? const Center(child: Text('Nix los hier'))
                  : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: filteredAndSorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final event = filteredAndSorted[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: EventListTile(
                      event: event,
                      onTap: () => _navigateToEditScreen(context, event),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Label-Mapper für die Sortier-Chips
  String _getSortLabel(EventSortOrder order) {
    return switch (order) {
      EventSortOrder.alphabetical => 'A-Z',
      EventSortOrder.newest => 'Neueste',
      EventSortOrder.oldest => 'Älteste',
    };
  }

  List<Event> _applyFiltersAndSort(List<Event> events, EventFilters filters) {
    List<Event> result = List.from(events);

    // 1. Filtern
    if (filters.searchQuery.isNotEmpty) {
      final query = filters.searchQuery.trim().toLowerCase();
      result = result.where((e) {
        final nameMatch = e.name.toLowerCase().contains(query);
        final descMatch = (e.description ?? '').toLowerCase().contains(query);
        return nameMatch || descMatch;
      }).toList();
    }

    // 2. Sortieren
    switch (filters.sortOrder) {
      case EventSortOrder.alphabetical:
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case EventSortOrder.newest:
        result.sort((a, b) => (b.dateFrom ?? DateTime(0)).compareTo(a.dateFrom ?? DateTime(0)));
        break;
      case EventSortOrder.oldest:
        result.sort((a, b) => (a.dateFrom ?? DateTime(0)).compareTo(b.dateFrom ?? DateTime(0)));
        break;
    }

    return result;
  }
}