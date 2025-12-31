import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/bluetooth_service.dart';
import '../services/database_helper.dart';
import 'package:project_camel/core/constants.dart';

class SessionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? session;
  final int? durationMS;
  final List<int>? allValues;
  final double? calibrationFactor; // Das ist jetzt der volumeCalibrationFactor

  const SessionScreen({
    super.key,
    this.session,
    this.durationMS,
    this.allValues,
    this.calibrationFactor,
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
    print("DEBUG_ML (session_screen): initState gestartet. isEditing: $_isEditing");

    if (_isEditing) {
      final s = widget.session!;
      _nameController = TextEditingController(text: s['name'] ?? '');
      _selectedUserID = s['userID'];
      _selectedEventID = s['eventID'];
      _selectedVolumeML = s['volumeML'] ?? 500;
      // Der Kalibrierungsfaktor für die Bearbeitung wird aus der DB geladen
    } else {
      String formattedDate =
      DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());
      _nameController =
          TextEditingController(text: "Trichterung vom $formattedDate");

      print("DEBUG_ML (session_screen): Berechne initiales Volumen...");
      print("  -> volumeCalibrationFactor aus Start-Array: ${widget.calibrationFactor}");
      print("  -> allValues.length: ${widget.allValues?.length}");

      if (widget.calibrationFactor != null && widget.calibrationFactor! > 0) {
        // --- FINALE FORMEL HIER ANGEWENDET ---
        final volumeCalibrationFactor = widget.calibrationFactor!;
        final calculatedVolume = (widget.allValues?.length ?? 0) / (2 * volumeCalibrationFactor) * 1000;
        final roundedVolume = calculatedVolume.round();

        print("  -> FINALE Formel: (allValues.length / (2 * volumeCalibrationFactor)) * 1000");
        print("  -> Rechnung: (${widget.allValues?.length} / (2 * $volumeCalibrationFactor)) * 1000 = $calculatedVolume");
        print("  -> Gerundetes Ergebnis: $roundedVolume ml");

        if (roundedVolume > 0) {
          _selectedVolumeML = roundedVolume;
          print("DEBUG_ML (session_screen): Initiales Volumen gesetzt auf: $_selectedVolumeML ml.");
        } else {
          print("DEBUG_ML (session_screen): Berechnetes Volumen ist <= 0. Fallback auf 500ml.");
          _selectedVolumeML = 500;
        }
      } else {
        print("DEBUG_ML (session_screen): volumeCalibrationFactor ist null oder 0. Fallback auf 500ml.");
        _selectedVolumeML = 500;
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
      setState(() {});
    } catch (e) {
      print("Fehler beim Abrufen des Standorts: $e");
    }
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
        'sessionID': _isEditing ? widget.session!['sessionID'] : const Uuid().v4(),
        'startedAt': _isEditing ? widget.session!['startedAt'] : DateTime.now().toIso8601String(),
        'userID': _selectedUserID,
        'volumeML': _selectedVolumeML,
        'durationMS': _isEditing ? widget.session!['durationMS'] : widget.durationMS,
        'eventID': _selectedEventID,
        'name': _nameController.text.isNotEmpty ? _nameController.text : null,
        'description': _isEditing ? widget.session!['description'] : null,
        'latitude': _isEditing ? widget.session!['latitude'] : (_currentPosition?.latitude ?? 0.0),
        'longitude': _isEditing ? widget.session!['longitude'] : (_currentPosition?.longitude ?? 0.0),
        'valuesJSON': _isEditing ? widget.session!['valuesJSON'] : jsonEncode(widget.allValues),
        // Hier wird der Volume-Faktor in die DB geschrieben
        'calibrationFactor': _isEditing ? widget.session!['calibrationFactor'] : widget.calibrationFactor?.toInt(),
      };

      print("DEBUG_ML (session_screen): Speichere Session. Der 'calibrationFactor', der in die DB geht, ist ${sessionData['calibrationFactor']}");

      await _dbHelper.saveSessionForSync(sessionData, isEditing: _isEditing);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_isEditing ? 'Änderungen gespeichert!' : 'Gespeichert!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $e')));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: Text(_isEditing ? 'Trichterung Bearbeiten' : 'Ergebnis speichern',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFF9500),
        foregroundColor: Colors.white,
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
              ],
            ),
            const SizedBox(height: 20),
            const Text('NAME DER TRICHTERUNG',
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
                  backgroundColor: const Color(0xFFFF9500),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_isEditing ? 'ÄNDERUNGEN SPEICHERN' : 'FERTIG & SPEICHERN',
                    style: const TextStyle(
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
    bool isSelected = !custom && _selectedVolumeML == ml;
    bool isCustomActive = custom && ![330, 500].contains(_selectedVolumeML);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected || isCustomActive,
      onSelected: (s) {
        if (custom) {
          _showCustomVol();
        } else {
          print("DEBUG_ML (session_screen): Volumen manuell auf $ml ml geändert.");
          setState(() => _selectedVolumeML = ml);
        }
      },
      selectedColor: const Color(0xFFFF9500),
      labelStyle: TextStyle(
          color: (isSelected || isCustomActive) ? Colors.white : Colors.black),
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
                print("DEBUG_ML (session_screen): Eigenes Volumen '$customVolume ml' über Dialog gesetzt.");
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
