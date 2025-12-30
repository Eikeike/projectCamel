import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'event_edit_screen.dart'; // Import für den Edit-Screen

class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
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
      final data = await _dbHelper.getEvents();
      setState(() => events = data);
    } catch (e) {
      debugPrint('Fehler beim Laden: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _confirmDelete(String eventID, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Event löschen?'),
        content: Text('Möchtest du "$name" wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () async {
              await _dbHelper.markEventAsDeleted(eventID);
              if (mounted) Navigator.pop(context);
              _fetchEvents();
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text('Events', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFF9500),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EventEditScreen()),
        ).then((_) => _fetchEvents()),
        backgroundColor: const Color(0xFFFF9500),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF9500)))
          : events.isEmpty
          ? const Center(child: Text('Keine Events angelegt'))
          : ListView.builder(
        itemCount: events.length,
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemBuilder: (context, index) {
          final event = events[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.celebration, color: Color(0xFFFF9500)),
              title: Text(event['name'] ?? 'Unbekannt'),
              subtitle: Text(event['description'] ?? ''),
              trailing: PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EventEditScreen(event: event)),
                    ).then((_) => _fetchEvents());
                  } else if (val == 'delete') {
                    _confirmDelete(event['eventID'], event['name']);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                  const PopupMenuItem(value: 'delete', child: Text('Löschen', style: TextStyle(color: Colors.red))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}