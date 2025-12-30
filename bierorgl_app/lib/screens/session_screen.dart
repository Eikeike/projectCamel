import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/bluetooth_service.dart';
import '../services/database_helper.dart';

class SessionScreen extends ConsumerStatefulWidget {
  final int durationMS;
  final List<int> allValues;

  const SessionScreen({
    super.key,
    required this.durationMS,
    required this.allValues,
  });

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late TextEditingController _nameController;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _events = [];

  String? _selectedUserID;
  String? _selectedEventID;
  int _selectedVolumeML = 500;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    String formattedDate =
    DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());
    _nameController =
        TextEditingController(text: "Session von: $formattedDate");
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    // Setzt den Bluetooth-Status zurück, wenn der Bildschirm verlassen wird.
    // Dies stellt sicher, dass der TrichternScreen wieder auf "Bereit" steht.
    ref.read(bluetoothServiceProvider.notifier).resetData();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final users = await _dbHelper.getUsers();
    final events = await _dbHelper.getEvents();
    setState(() {
      _users = users;
      _events = events;
    });
  }

  void _addGuestUser() {
    final guestController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gast hinzufügen'),
        content: TextField(
          controller: guestController,
          decoration: const InputDecoration(labelText: 'Name des Gastes'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              if (guestController.text.isNotEmpty) {
                final newId = const Uuid().v4();
                await _dbHelper.insertUser({
                  'userID': newId,
                  'name': guestController.text,
                  'username':
                  'gast_${guestController.text.toLowerCase().replaceAll(' ', '_')}',
                  'eMail': 'gast@bierorgl.de',
                });
                await _loadInitialData();
                setState(() => _selectedUserID = newId);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  Future<void> _processSave() async {
    if (_selectedUserID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Fehler: Wer hat getrichtert? (Pflichtfeld)'),
            backgroundColor: Colors.red),
      );
      return;
    }

    if (_nameController.text.isEmpty || _selectedEventID == null) {
      bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Angaben unvollständig'),
          content: const Text(
              'Session-Name oder Event fehlen. Trotzdem speichern?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Zurück')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ja, egal')),
          ],
        ),
      ) ??
          false;
      if (!confirm) return;
    }

    _executeFinalSave();
  }

  Future<void> _executeFinalSave() async {
    setState(() => _isSaving = true);
    try {
      final sessionData = {
        'sessionID': const Uuid().v4(),
        'startedAt': DateTime.now().toIso8601String(),
        'userID': _selectedUserID,
        'volumeML': _selectedVolumeML,
        'durationMS': widget.durationMS,
        'eventID': _selectedEventID,
        'name': _nameController.text,
        'description': 'Messung: ${widget.allValues.length} Schlucke',
        'latitude': 0.0,
        'longitude': 0.0,
      };

      await _dbHelper.insertSession(sessionData);
      if (mounted) {
        // Die pop-Aktion löst `dispose()` aus, was den Reset durchführt.
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Gespeichert!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text('Ergebnis speichern',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFF9500),
        foregroundColor: Colors.white,
        // WICHTIG: Erlaubt dem User, per "Zurück"-Geste zu navigieren.
        // `dispose` fängt auch diesen Fall ab.
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    '${(widget.durationMS / 1000).toStringAsFixed(2)}s',
                    style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF9500)),
                  ),
                  const Text('ENDZEIT',
                      style: TextStyle(
                          letterSpacing: 2,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('WER HAT GETRICHTERT? *',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedUserID,
                    hint: const Text('User wählen'),
                    items: _users
                        .map((u) => DropdownMenuItem(
                      value: u['userID'] as String,
                      child: Text(u['username'] ??
                          u['name'] ??
                          'Unbekannter User'),
                    ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedUserID = val),
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        fillColor: Colors.white,
                        filled: true),
                  ),
                )
                // Hier könnte ein Button sein, um einen Gast-User hinzuzufügen
              ],
            ),
            const SizedBox(height: 20),
            const Text('NAME DER SESSION',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  fillColor: Colors.white,
                  filled: true),
            ),
            const SizedBox(height: 20),
            const Text('EVENT', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedEventID,
              hint: const Text('Optional: Event zuordnen'),
              items: _events
                  .map((e) => DropdownMenuItem(
                value: e['eventID'] as String,
                child: Text(e['name'] ?? 'Event'),
              ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedEventID = val),
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  fillColor: Colors.white,
                  filled: true),
            ),
            const SizedBox(height: 20),
            const Text('VOLUMEN',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _volChip('0,33L', 330),
                _volChip('0,5L', 500),
                _volChip('Custom', 0, custom: true),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _processSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9500),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('FERTIG & SPEICHERN',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('VERWERFEN',
                    style: TextStyle(
                        color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _volChip(String label, int ml, {bool custom = false}) {
    bool selected = !custom && _selectedVolumeML == ml;
    bool isCustomSelected = custom && ![330, 500].contains(_selectedVolumeML);

    return ChoiceChip(
      label: Text(label),
      selected: selected || isCustomSelected,
      onSelected: (s) {
        if (custom) {
          _showCustomVol();
        } else {
          setState(() => _selectedVolumeML = ml);
        }
      },
      selectedColor: const Color(0xFFFF9500),
      labelStyle: TextStyle(
          color: (selected || isCustomSelected) ? Colors.white : Colors.black),
    );
  }

  void _showCustomVol() {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eigene Menge (ml)'),
        content: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(hintText: "z.B. 1000 für 1L")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          TextButton(
            onPressed: () {
              final int? customVolume = int.tryParse(c.text);
              if (customVolume != null && customVolume > 0) {
                setState(() => _selectedVolumeML = customVolume);
              }
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
