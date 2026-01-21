import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/auth/auth_providers.dart';
import 'package:project_camel/providers.dart';
// import 'package:project_camel/screens/debug_screen.dart'; // Unbenutzter Import entfernt
import 'package:project_camel/screens/event_edit_screen.dart';
// import 'package:project_camel/theme/app_theme.dart'; // Falls nicht direkt genutzt, entfernt, ansonsten beibehalten.
import 'package:project_camel/widgets/event_list_tile.dart';

class NewEventScreen extends ConsumerStatefulWidget {
  const NewEventScreen({super.key});

  @override
  ConsumerState<NewEventScreen> createState() => _NewEventScreenState();
}

class _NewEventScreenState extends ConsumerState<NewEventScreen> {
  // OPTIMIERUNG: Der manuelle _searchController wurde entfernt.
  // Im Originalcode wurde er erstellt, aber nie an die SearchBar übergeben
  // (diese nutzte den Controller vom SearchAnchor). Das war toter Code und Speicherverschwendung.

  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // OPTIMIERUNG: 'select' verhindert unnötige Rebuilds.
    // Wir bauen nur neu, wenn sich 'isLoading' ändert, nicht bei anderen Auth-Properties.
    final bool isAuthLoading = ref.watch(
      authControllerProvider.select((value) => value.isLoading),
    );

    // OPTIMIERUNG: Scaffold ist nun das Root-Widget.
    // Verhindert das "Springen" der UI beim Wechsel von Loading zu Content.
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Events',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            // OPTIMIERUNG: Theme Lookup optimiert, um sicherzustellen, dass es nicht null ist
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        // OPTIMIERUNG: Lambda extrahiert, um Lesbarkeit zu erhöhen
        onPressed: () => _navigateToEditScreen(context),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // Logik-Entscheidung im Body statt Scaffold-Tausch
      body: isAuthLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context),
    );
  }

  /// Extrahiert die Navigationslogik
  void _navigateToEditScreen(BuildContext context, [dynamic event]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventEditScreen(event: event),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    // OPTIMIERUNG: AsyncValue Handling.
    // Wir holen die Daten. Dank Riverpod wird dies gecacht, solange der Provider nicht invalidiert wird.
    final eventsAsync = ref.watch(allEventsProvider);

    // OPTIMIERUNG: Zugriff auf UserID sicherstellen.
    // Statt 'userId!' prüfen wir sicherheitshalber, ob der User da ist.
    // Wenn 'allEventsProvider' vom User abhängt, wird dies dort meist eh schon geregelt,
    // aber hier vermeiden wir NullPointerExceptions in der UI.
    final userState = ref.read(authControllerProvider);
    if (userState.userId == null && !userState.isLoading) {
      return const Center(child: Text('Kein Benutzer angemeldet.'));
    }

    return eventsAsync.when(
      // OPTIMIERUNG: Konstante Widgets wo möglich
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (events) {
        if (events.isEmpty) {
          return const Center(child: Text('Nix los hier'));
        }

        // OPTIMIERUNG: Sucheffizienz
        // 1. toLowerCase() nur EINMAL aufrufen, nicht pro Item.
        // 2. Trimmen, um Leerraum-Fehler zu vermeiden.
        final query = _searchQuery.trim().toLowerCase();

        // Filterung
        final filtered = query.isEmpty
            ? events
            : events.where((e) {
                // Null-Safety Check für description, falls null
                final nameMatch = e.name.toLowerCase().contains(query);
                final descMatch =
                    (e.description ?? '').toLowerCase().contains(query);
                return nameMatch || descMatch;
              }).toList();

        // OPTIMIERUNG: Layout-Struktur
        // Verwendung von 'const' bei BoxDecoration wo keine dynamischen Werte sind.
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
              // OPTIMIERUNG: ClipRRect ist teuer im Rendering.
              // Da der Container bereits abgerundet ist, ist ClipRRect nur nötig,
              // wenn Kinder überlappen. Wir behalten es für Feature-Parity,
              // aber es ist hier der primäre Clipper.
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Column(
                  children: [
                    // Search Bar Bereich
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                      child: SearchAnchor(
                        builder: (BuildContext context,
                            SearchController controller) {
                          // Der Controller kommt vom SearchAnchor, wir müssen ihn nicht managen.
                          return SearchBar(
                            controller: controller,
                            padding: const WidgetStatePropertyAll<EdgeInsets>(
                              EdgeInsets.symmetric(horizontal: 16.0),
                            ),
                            hintText: 'Events suchen...',
                            // WICHTIG: State Update nur hier, löst Rebuild aus.
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
                          return []; // Feature: Keine Vorschläge, nur Filterung der Liste
                        },
                      ),
                    ),

                    // Listen Bereich
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final event = filtered[index];
                          final isFirst = index == 0;
                          final isLast = index == filtered.length - 1;

                          // OPTIMIERUNG: Radius-Logik
                          // Berechnung ist korrekt, aber wir extrahieren das Styling
                          // in lokale Variablen für bessere Lesbarkeit.
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
                            // Navigation entkoppelt
                            child: EventListTile(
                              event: event,
                              onTap: () =>
                                  _navigateToEditScreen(context, event),
                            ),
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
    );
  }
}
