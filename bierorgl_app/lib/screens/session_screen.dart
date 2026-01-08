import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/bluetooth_service.dart';
import '../services/database_helper.dart';
import 'package:project_camel/core/constants.dart';
import '../widgets/selection_list.dart';

class SessionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? session;
  final int? durationMS;
  final List<int>? allValues;
  final double? calibrationFactor;
  // ### NEU: Der berechnete Wert vom TrichternScreen ###
  final int? calculatedVolumeML;

  const SessionScreen({
    super.key,
    this.session,
    this.durationMS,
    this.allValues,
    this.calibrationFactor,
    this.calculatedVolumeML,
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
  Position? _currentPosition;
  bool get _isEditing => widget.session != null;

  @override
  void initState() {
    super.initState();
    print(
        "DEBUG_ML (session_screen): initState gestartet. isEditing: $_isEditing");

    if (_isEditing) {
      final s = widget.session!;
      _nameController = TextEditingController(text: s['name'] ?? '');
      _selectedUserID = s['userID'];
      _selectedEventID = s['eventID'];
      _selectedVolumeML = s['volumeML'] ?? 500;
    } else {
      String formattedDate =
          DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());
      _nameController =
          TextEditingController(text: "Trichterung vom $formattedDate");

      // ### NEUE LOGIK zur Vorauswahl basierend auf der Messung ###
      final measuredVolume = widget.calculatedVolumeML;
      if (measuredVolume != null && measuredVolume > 0) {
        // Toleranz von 75ml
        if ((measuredVolume - 330).abs() <= 75) {
          _selectedVolumeML = 330; // Wähle 0,33L vor
          print(
              "DEBUG_ML (session_screen): Messung ($measuredVolume ml) ist nah an 330ml. Wähle 0,33L vor.");
        } else if ((measuredVolume - 500).abs() <= 75) {
          _selectedVolumeML = 500; // Wähle 0,5L vor
          print(
              "DEBUG_ML (session_screen): Messung ($measuredVolume ml) ist nah an 500ml. Wähle 0,5L vor.");
        } else {
          _selectedVolumeML = measuredVolume; // Setze den exakten Custom-Wert
          print(
              "DEBUG_ML (session_screen): Messung ($measuredVolume ml) außerhalb der Toleranz. Wähle Custom-Wert vor.");
        }
      } else {
        _selectedVolumeML = 500; // Fallback
        print(
            "DEBUG_ML (session_screen): Kein gültiges Volumen gemessen. Fallback auf 500ml.");
      }
    }

    _loadInitialData();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    // Check if the widget is still mounted before calling setState.
    if (!mounted) return;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print("Fehler beim Abrufen des Standorts: $e");
    }
  }

  Future<void> _loadInitialData() async {
    final users = await _dbHelper.getUsers();
    final events = await _dbHelper.getEvents();
    if (mounted) {
      setState(() {
        _users = users;
        _events = events;
      });
    }
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
                if (mounted) {
                  setState(() => _selectedUserID = newId);
                  Navigator.pop(context);
                }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Fehler: Wer hat getrichtert? (Pflichtfeld)'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (_nameController.text.isEmpty || _selectedEventID == null) {
      bool confirm = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Angaben unvollständig'),
              content: const Text(
                  'Titel der Trichterung oder Event fehlen. Trotzdem speichern?'),
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
        'sessionID':
            _isEditing ? widget.session!['sessionID'] : const Uuid().v4(),
        'startedAt': _isEditing
            ? widget.session!['startedAt']
            : DateTime.now().toIso8601String(),
        'userID': _selectedUserID,
        'volumeML': _selectedVolumeML,
        'durationMS':
            _isEditing ? widget.session!['durationMS'] : widget.durationMS,
        'eventID': _selectedEventID,
        'name': _nameController.text.isNotEmpty ? _nameController.text : null,
        'description': _isEditing ? widget.session!['description'] : null,
        'latitude': _isEditing
            ? widget.session!['latitude']
            : (_currentPosition?.latitude ?? 0.0),
        'longitude': _isEditing
            ? widget.session!['longitude']
            : (_currentPosition?.longitude ?? 0.0),
        'valuesJSON': _isEditing
            ? widget.session!['valuesJSON']
            : jsonEncode(widget.allValues),
        'calibrationFactor': _isEditing
            ? widget.session!['calibrationFactor']
            : widget.calibrationFactor?.toInt(),
      };

      print(
          "DEBUG_ML (session_screen): Speichere Session. Der 'calibrationFactor', der in die DB geht, ist ${sessionData['calibrationFactor']}");

      await _dbHelper.saveSessionForSync(sessionData, isEditing: _isEditing);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(_isEditing ? 'Änderungen gespeichert!' : 'Gespeichert!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
            _isEditing ? 'Trichterung Bearbeiten' : 'Ergebnis speichern',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isEditing)
              Center(
                child: Column(
                  children: [
                    Text(
                      '${((widget.durationMS ?? 0) / 1000).toStringAsFixed(2)}s',
                      style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    Text('ENDZEIT',
                        style: TextStyle(
                            letterSpacing: 2,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            UserSelectionField(
              users: _users,
              selectedUserID: _selectedUserID,
              onChanged: (val) {
                if (val != null) setState(() => _selectedUserID = val);
              },
              onAddGuest: _addGuestUser,
            ),
            const SizedBox(height: 24),
// Linksbündiges Label im M3-Stil
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 4),
              child: Text(
                'Titel der Trichterung',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ),
            TextField(
              controller: _nameController,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                filled: true,
                // Nutzt die dezente Hintergrundfarbe von Material 3
                fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                // Weiche Rundungen ohne Rahmenlinie
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                // Blauer (Primary) Rahmen nur, wenn das Feld aktiv ist
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                hintText: 'Name eingeben...',
              ),
            ),
            EventSelectionField(
              events: _events,
              selectedEventID: _selectedEventID,
              onChanged: (val) => setState(() => _selectedEventID = val),
            ),
            const SizedBox(height: 20),
            const Text('Volumen',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            // ### NEU: Anzeige des gemessenen Volumens ###
            if (!_isEditing && widget.calculatedVolumeML != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Center(
                  child: Text(
                    'Messung: ${widget.calculatedVolumeML} ml',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontStyle: FontStyle.italic),
                  ),
                ),
              ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _volChip('0,33L', 330),
                _volChip('0,5L', 500),
                _volChip(
                  ![330, 500].contains(_selectedVolumeML)
                      ? '${_selectedVolumeML}ml'
                      : 'Custom',
                  _selectedVolumeML,
                  custom: true,
                ),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _processSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isEditing
                            ? 'ÄNDERUNGEN SPEICHERN'
                            : 'FERTIG & SPEICHERN',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('VERWERFEN',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _volChip(String label, int ml, {bool custom = false}) {
    bool isSelected = !custom && _selectedVolumeML == ml;
    bool isCustomActive = custom && ![330, 500].contains(_selectedVolumeML);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected || isCustomActive,
      onSelected: (s) {
        if (custom) {
          _showCustomVol();
        } else {
          print(
              "DEBUG_ML (session_screen): Volumen manuell auf $ml ml geändert.");
          setState(() => _selectedVolumeML = ml);
        }
      },
      selectedColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
          color: (isSelected || isCustomActive)
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface),
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
                print(
                    "DEBUG_ML (session_screen): Eigenes Volumen '$customVolume ml' über Dialog gesetzt.");
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
