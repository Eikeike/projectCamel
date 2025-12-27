import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../repositories/auth_repository.dart'; // dein AuthRepository importieren

class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final AuthRepository _authRepo = AuthRepository();

  List<Map<String, dynamic>> events = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() => isLoading = true);

    try {
      // AccessToken über AuthRepository holen
      final accessToken = await _authRepo.getAccessToken();
      debugPrint('DEBUG: AccessToken aus AuthRepository: $accessToken');

      if (accessToken == null) {
        debugPrint('DEBUG: Kein AccessToken vorhanden!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kein AccessToken vorhanden')),
        );
        setState(() => isLoading = false);
        return;
      }

      debugPrint('DEBUG: Sende GET Request über AuthRepository...');
      final response = await _authRepo.get('/api/events/');
      debugPrint('DEBUG: Response StatusCode: ${response.statusCode}');
      debugPrint('DEBUG: Response Data: ${response.data}');

      setState(() {
        events = List<Map<String, dynamic>>.from(response.data);
        debugPrint('DEBUG: ${events.length} Events geladen');
      });
    } catch (e, stackTrace) {
      debugPrint('DEBUG: Fehler beim Laden der Events: $e');
      debugPrint('DEBUG: StackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Laden der Events')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _addEvent() {
    debugPrint('DEBUG: Navigiere zu EventEditScreen (Hinzufügen)');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EventEditScreen()),
    ).then((_) {
      debugPrint('DEBUG: Rückkehr von EventEditScreen, lade Events neu');
      _fetchEvents();
    });
  }

  void _editEvent(Map<String, dynamic> event) {
    debugPrint('DEBUG: Navigiere zu EventEditScreen (Bearbeiten) für Event: ${event['name']}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventEditScreen(event: event),
      ),
    ).then((_) {
      debugPrint('DEBUG: Rückkehr von EventEditScreen, lade Events neu');
      _fetchEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        backgroundColor: const Color(0xFFFF9500),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEvent,
        backgroundColor: const Color(0xFFFF9500),
        child: const Icon(Icons.add),
        tooltip: 'Neues Event hinzufügen',
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : events.isEmpty
          ? const Center(child: Text('Keine Events vorhanden'))
          : ListView.builder(
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(event['name'] ?? 'Unbekannt'),
              subtitle: Text(event['description'] ?? ''),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editEvent(event),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Placeholder für EventEditScreen (Neues Event hinzufügen oder bearbeiten)
class EventEditScreen extends StatelessWidget {
  final Map<String, dynamic>? event;
  const EventEditScreen({super.key, this.event});

  @override
  Widget build(BuildContext context) {
    final isEditing = event != null;
    debugPrint('DEBUG: EventEditScreen geöffnet, isEditing: $isEditing');

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Event bearbeiten' : 'Neues Event'),
        backgroundColor: const Color(0xFFFF9500),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Event Name'),
              controller: TextEditingController(text: event?['name'] ?? ''),
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Beschreibung'),
              controller: TextEditingController(text: event?['description'] ?? ''),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                debugPrint('DEBUG: Speichern/Erstellen Button gedrückt (noch keine API Call implementiert)');
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9500)),
              child: Text(isEditing ? 'Speichern' : 'Erstellen'),
            ),
          ],
        ),
      ),
    );
  }
}
