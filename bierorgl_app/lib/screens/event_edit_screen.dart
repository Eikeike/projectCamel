import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/database_helper.dart';

class EventEditScreen extends StatefulWidget {
  final Map<String, dynamic>? event;
  const EventEditScreen({super.key, this.event});

  @override
  State<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends State<EventEditScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late TextEditingController _nameController;
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.event?['name'] ?? '');
    _descController = TextEditingController(text: widget.event?['description'] ?? '');
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name fehlt!')));
      return;
    }

    final eventData = {
      'name': _nameController.text,
      'description': _descController.text,
      'dateFrom': widget.event?['dateFrom'] ?? DateTime.now().toIso8601String(),
      'dateTo': widget.event?['dateTo'] ?? DateTime.now().toIso8601String(),
      'latitude': 0.0,
      'longitude': 0.0,
    };

    final db = await _dbHelper.database;

    if (widget.event == null) {
      eventData['eventID'] = const Uuid().v4();
      await _dbHelper.insertEvent(eventData);
    } else {
      await db.update(
        'Event',
        eventData,
        where: 'eventID = ?',
        whereArgs: [widget.event!['eventID']],
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: Text(isEditing ? 'Event bearbeiten' : 'Neues Event'),
        backgroundColor: const Color(0xFFFF9500),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Event Name',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9500),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(isEditing ? 'ÄNDERUNGEN SPEICHERN' : 'EVENT ERSTELLEN',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}