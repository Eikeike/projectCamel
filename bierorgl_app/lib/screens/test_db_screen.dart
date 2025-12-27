import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';  // Für UUID-Generierung
import '../services/database_helper.dart';

class TestDbScreen extends StatefulWidget {
  @override
  _TestDbScreenState createState() => _TestDbScreenState();
}

class _TestDbScreenState extends State<TestDbScreen> {
  final dbHelper = DatabaseHelper();
  final Uuid uuid = Uuid();  // Für IDs
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _sessions = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('DB Test')),
      body: Column(
        children: [
          // Buttons für Hinzufügen
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => _showAddUserDialog(),
                child: Text('User hinzufügen'),
              ),
              ElevatedButton(
                onPressed: () => _showAddEventDialog(),
                child: Text('Event hinzufügen'),
              ),
              ElevatedButton(
                onPressed: () => _showAddSessionDialog(),
                child: Text('Session hinzufügen'),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _loadData,
            child: Text('Daten laden und anzeigen'),
          ),
          Expanded(
            child: ListView(
              children: [
                Text('Users: ${_users.length}'),
                ..._users.map((u) => Text('ID: ${u['userID']}, Name: ${u['name']} ${u['surname']}, Email: ${u['eMail']}')),
                Text('Events: ${_events.length}'),
                ..._events.map((e) => Text('ID: ${e['eventID']}, Name: ${e['name']}, DateFrom: ${e['dateFrom']}')),
                Text('Sessions: ${_sessions.length}'),
                ..._sessions.map((s) => Text('ID: ${s['sessionID']}, Name: ${s['name']}, UserID: ${s['userID']}, EventID: ${s['eventID']}')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Dialog für User hinzufügen
  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final surnameController = TextEditingController();
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final bioController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User hinzufügen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: 'Name')),
            TextField(controller: surnameController, decoration: InputDecoration(labelText: 'Surname')),
            TextField(controller: usernameController, decoration: InputDecoration(labelText: 'Username')),
            TextField(controller: emailController, decoration: InputDecoration(labelText: 'Email')),
            TextField(controller: bioController, decoration: InputDecoration(labelText: 'Bio')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || emailController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Name und Email erforderlich!')));
                return;
              }
              await dbHelper.insertUser({
                'userID': uuid.v4(),
                'name': nameController.text,
                'surname': surnameController.text,
                'username': usernameController.text,
                'eMail': emailController.text,
                'bio': bioController.text,
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User hinzugefügt!')));
            },
            child: Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  // Dialog für Event hinzufügen
  void _showAddEventDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    DateTime? dateFrom;
    DateTime? dateTo;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Event hinzufügen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: 'Name')),
            TextField(controller: descriptionController, decoration: InputDecoration(labelText: 'Description')),
            TextField(controller: latController, decoration: InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.number),
            TextField(controller: lngController, decoration: InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.number),
            Row(
              children: [
                Text('DateFrom: ${dateFrom?.toLocal() ?? 'Nicht gesetzt'}'),
                TextButton(
                  onPressed: () async {
                    dateFrom = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    setState(() {});
                  },
                  child: Text('Wählen'),
                ),
              ],
            ),
            Row(
              children: [
                Text('DateTo: ${dateTo?.toLocal() ?? 'Nicht gesetzt'}'),
                TextButton(
                  onPressed: () async {
                    dateTo = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    setState(() {});
                  },
                  child: Text('Wählen'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || dateFrom == null || dateTo == null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Name und Daten erforderlich!')));
                return;
              }
              await dbHelper.insertEvent({
                'eventID': uuid.v4(),
                'name': nameController.text,
                'description': descriptionController.text,
                'dateFrom': dateFrom!.toIso8601String(),
                'dateTo': dateTo!.toIso8601String(),
                'latitude': double.tryParse(latController.text) ?? 0.0,
                'longitude': double.tryParse(lngController.text) ?? 0.0,
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Event hinzugefügt!')));
            },
            child: Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  // Dialog für Session hinzufügen
// Dialog für Session hinzufügen
  void _showAddSessionDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final volumeController = TextEditingController();
    final durationController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    String? selectedUserID;
    String? selectedEventID;
    DateTime? startedAt;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Session hinzufügen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: 'Name')),
            TextField(controller: descriptionController, decoration: InputDecoration(labelText: 'Description')),
            TextField(controller: volumeController, decoration: InputDecoration(labelText: 'Volume ML'), keyboardType: TextInputType.number),
            TextField(controller: durationController, decoration: InputDecoration(labelText: 'Duration MS'), keyboardType: TextInputType.number),
            TextField(controller: latController, decoration: InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.number),
            TextField(controller: lngController, decoration: InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.number),
            DropdownButton<String>(
              value: selectedUserID,
              hint: Text('User auswählen'),
              items: _users.map((u) => DropdownMenuItem<String>(
                value: u['userID'] as String,
                child: Text(u['name'] as String),
              )).toList(),
              onChanged: (value) => setState(() => selectedUserID = value),
            ),
            DropdownButton<String>(
              value: selectedEventID,
              hint: Text('Event auswählen'),
              items: _events.map((e) => DropdownMenuItem<String>(
                value: e['eventID'] as String,
                child: Text(e['name'] as String),
              )).toList(),
              onChanged: (value) => setState(() => selectedEventID = value),
            ),
            Row(
              children: [
                Text('StartedAt: ${startedAt?.toLocal() ?? 'Nicht gesetzt'}'),
                TextButton(
                  onPressed: () async {
                    startedAt = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    setState(() {});
                  },
                  child: Text('Wählen'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || selectedUserID == null || selectedEventID == null || startedAt == null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Alle Felder erforderlich!')));
                return;
              }
              await dbHelper.insertSession({
                'sessionID': uuid.v4(),
                'startedAt': startedAt!.toIso8601String(),
                'userID': selectedUserID,
                'volumeML': int.tryParse(volumeController.text) ?? 0,
                'durationMS': int.tryParse(durationController.text) ?? 0,
                'eventID': selectedEventID,
                'name': nameController.text,
                'description': descriptionController.text,
                'latitude': double.tryParse(latController.text) ?? 0.0,
                'longitude': double.tryParse(lngController.text) ?? 0.0,
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Session hinzugefügt!')));
            },
            child: Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }


  Future<void> _loadData() async {
    try {
      _users = await dbHelper.getUsers();
      _events = await dbHelper.getEvents();
      _sessions = await dbHelper.getSessions();
      setState(() {});
      print('Users: $_users');
      print('Events: $_events');
      print('Sessions: $_sessions');
    } catch (e) {
      print('Fehler beim Laden: $e');
    }
  }
}