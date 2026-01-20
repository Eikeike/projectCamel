import 'dart:convert';
import 'package:flutter/foundation.dart'; // Für compute
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:project_camel/models/session.dart';
import 'package:project_camel/models/event.dart';
import 'package:uuid/uuid.dart';
import 'package:project_camel/core/constants.dart';
import 'package:project_camel/providers.dart';
// Angenommene Importe basierend auf dem Originalcode
import '../widgets/selection_list.dart';
import '../widgets/speed_graph.dart';

class SessionScreen extends ConsumerStatefulWidget {
  final Session? session;
  final int? durationMS;
  final List<int>? allValues;
  final double? calibrationFactor;
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
  // Controller wird final definiert und in dispose aufgeräumt
  late final TextEditingController _nameController;

  // Statische UUID Instanz spart Speicher bei mehrfachem Aufruf
  static const _uuid = Uuid();

  String? _selectedUserID;
  String? _selectedEventID;
  int _selectedVolumeML = 500;
  bool _isSaving = false;
  Position? _currentPosition;

  bool get _isEditing => widget.session != null;

  @override
  void initState() {
    super.initState();
    _initializeState();
    // Standortabfrage starten (Fire-and-forget, aber sicher)
    _getCurrentLocation();
  }

  void _initializeState() {
    if (_isEditing) {
      final s = widget.session!;
      _nameController = TextEditingController(text: s.name);
      _selectedUserID = s.userID;
      _selectedEventID = s.eventID;
      _selectedVolumeML = s.volumeML;
    } else {
      final now = DateTime.now();
      // DateFormat lokal erstellen ist ok, da es nur einmalig bei Init passiert.
      // Formatierung direkt in den String interpoliert.
      _nameController = TextEditingController(
          text:
              "Trichterung vom ${DateFormat('dd.MM.yyyy HH:mm').format(now)}");

      // Optimierte Volumen-Logik
      final measured = widget.calculatedVolumeML;
      if (measured != null && measured > 0) {
        if ((measured - 330).abs() <= 75) {
          _selectedVolumeML = 330;
        } else if ((measured - 500).abs() <= 75) {
          _selectedVolumeML = 500;
        } else {
          _selectedVolumeML = measured;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();

      // Sicherheitscheck: Ist das Widget noch im Tree?
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    } catch (e) {
      debugPrint("Fehler beim Abrufen des Standorts: $e");
    }
  }

  Future<void> _addGuestUser() async {
    // Controller lokal halten, da er nur für den Dialog gebraucht wird
    final guestController = TextEditingController();

    final String? guestName = await showDialog<String>(
      context: context,
      barrierDismissible: false, // UX: Verhindert versehentliches Schließen
      builder: (context) => AlertDialog(
        title: const Text('Gast hinzufügen'),
        content: TextField(
          controller: guestController,
          decoration: const InputDecoration(labelText: 'Name des Gastes'),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, guestController.text),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );

    guestController.dispose();

    // Check auf mounted und validen Input
    if (guestName != null && guestName.trim().isNotEmpty && mounted) {
      final newId = _uuid.v4();
      final cleanName = guestName.trim();

      try {
        await ref.read(databaseHelperProvider).insertUser({
          'userID': newId,
          'name': cleanName,
          'username': 'gast_${cleanName.toLowerCase().replaceAll(' ', '_')}',
          'eMail': 'gast@bierorgl.de',
        });

        if (mounted) {
          setState(() => _selectedUserID = newId);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Fehler beim Erstellen: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _processSave() async {
    // Validierung der UI-Inputs
    if (_selectedUserID == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Fehler: Wer hat getrichtert? (Pflichtfeld)'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
      return;
    }

    if (_nameController.text.isEmpty || _selectedEventID == null) {
      final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => const _IncompleteDataDialog(),
          ) ??
          false;
      if (!confirm) return;
    }

    await _executeFinalSave();
  }

  Future<void> _executeFinalSave() async {
    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      // PERFORMANCE: JSON Encoding in Isolate auslagern, um Main Thread nicht zu blockieren
      // bei großen Datenmengen (widget.allValues)
      String? valuesJsonString;
      if (_isEditing) {
        valuesJsonString = widget.session!.valuesJSON;
      } else if (widget.allValues != null) {
        // compute führt jsonEncode im Hintergrund-Isolate aus
        valuesJsonString = await compute(jsonEncode, widget.allValues);
      }

      final session = Session(
        id: _isEditing ? widget.session!.id : '',
        volumeML: _selectedVolumeML,
        name: _nameController.text.isNotEmpty ? _nameController.text : null,
        description: _isEditing ? widget.session!.description : null,
        latitude: _isEditing
            ? widget.session!.latitude
            : (_currentPosition?.latitude ?? 0.0),
        longitude: _isEditing
            ? widget.session!.longitude
            : (_currentPosition?.longitude ?? 0.0),
        startedAt: _isEditing ? widget.session!.startedAt : DateTime.now(),
        userID: _selectedUserID ?? '',
        eventID: _selectedEventID,
        durationMS:
            _isEditing ? widget.session!.durationMS : (widget.durationMS ?? 0),
        valuesJSON: valuesJsonString,
        calibrationFactor: _isEditing
            ? widget.session!.calibrationFactor
            : widget.calibrationFactor?.toInt(),
      );

      // Async DB Call
      await ref
          .read(sessionRepositoryProvider)
          .saveSessionForSync(session, isEditing: _isEditing);

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
      debugPrint("Save Error: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $e')));
      }
    }
  }

  void _onVolumeChanged(int ml) {
    setState(() => _selectedVolumeML = ml);
  }

  @override
  Widget build(BuildContext context) {
    // Nur das Nötigste hier watchen.
    // Wenn sich users/events ändern, wollen wir nur die Dropdowns neu bauen,
    // aber da Scaffold so weit oben ist, ist ein Rebuild hier akzeptabel,
    // SOLANGE die Sub-Widgets const sind.
    final usersAsync = ref.watch(usersProvider);
    final eventsAsync = ref.watch(allEventsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
            _isEditing ? 'Trichterung Bearbeiten' : 'Ergebnis speichern',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Extrahiertes Widget vermeidet Rebuilds
            if (!_isEditing) _TimeHeader(durationMS: widget.durationMS ?? 0),

            const SizedBox(height: 24),

            // RepaintBoundary behalten: Wichtig für Performance bei Diagrammen
            if (widget.allValues != null && widget.allValues!.isNotEmpty)
              RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: SessionChart(
                    allValues: widget.allValues!,
                    volumeCalibrationValue: widget.calibrationFactor ?? 1.0,
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // User Selection Logic
            usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Fehler: $e',
                  style: TextStyle(color: theme.colorScheme.error)),
              data: (users) => UserSelectionField(
                users: users,
                selectedUserID: _selectedUserID,
                onChanged: (val) {
                  if (val != null) setState(() => _selectedUserID = val);
                },
                onAddGuest: _addGuestUser,
              ),
            ),

            const SizedBox(height: 24),

            // Form Fields ausgelagert
            _SessionTextFields(
              nameController: _nameController,
              eventsAsync: eventsAsync,
              selectedEventID: _selectedEventID,
              onEventChanged: (val) => setState(() => _selectedEventID = val),
            ),

            const SizedBox(height: 20),

            _VolumeSectionHeader(
              isEditing: _isEditing,
              calculatedVolumeML: widget.calculatedVolumeML,
            ),

            // Volume Selector ausgelagert
            _VolumeSelector(
              selectedVolumeML: _selectedVolumeML,
              onVolumeChanged: _onVolumeChanged,
            ),

            const SizedBox(height: 40),

            // Action Buttons ausgelagert
            _ActionButtons(
              isSaving: _isSaving,
              isEditing: _isEditing,
              onSave: _processSave,
              onCancel: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// STANDALONE WIDGETS
// Durch das Auslagern in eigene Klassen (statt Methoden) kann Flutter
// effektiver cachen und unnötige Rebuilds vermeiden (const optimization).
// -----------------------------------------------------------------------------

class _TimeHeader extends StatelessWidget {
  final int durationMS;

  const _TimeHeader({required this.durationMS});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          Text(
            '${(durationMS / 1000).toStringAsFixed(2)}s',
            style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary),
          ),
          Text('ENDZEIT',
              style: TextStyle(
                  letterSpacing: 2,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _SessionTextFields extends StatelessWidget {
  final TextEditingController nameController;
  final AsyncValue<List<Event>> eventsAsync;
  final String? selectedEventID;
  final ValueChanged<String?> onEventChanged;

  const _SessionTextFields({
    required this.nameController,
    required this.eventsAsync,
    required this.selectedEventID,
    required this.onEventChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 4),
          child: Text(
            'Titel der Trichterung',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        TextField(
          controller: nameController,
          style: theme.textTheme.bodyLarge,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            hintText: 'Name eingeben...',
          ),
        ),
        const SizedBox(height: 24),
        EventSelectionField(
          events: eventsAsync.asData?.value
                  ?.map((e) => {'eventID': e.id, 'name': e.name})
                  .toList() ??
              [],
          selectedEventID: selectedEventID,
          onChanged: onEventChanged,
        ),
      ],
    );
  }
}

class _VolumeSectionHeader extends StatelessWidget {
  final bool isEditing;
  final int? calculatedVolumeML;

  const _VolumeSectionHeader(
      {required this.isEditing, this.calculatedVolumeML});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(
            width: double.infinity,
            child:
                Text('Volumen', style: TextStyle(fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        if (!isEditing && calculatedVolumeML != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Messung: $calculatedVolumeML ml',
                style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontStyle: FontStyle.italic),
              ),
            ),
          ),
      ],
    );
  }
}

class _VolumeSelector extends StatelessWidget {
  final int selectedVolumeML;
  final ValueChanged<int> onVolumeChanged;

  const _VolumeSelector({
    required this.selectedVolumeML,
    required this.onVolumeChanged,
  });

  void _showCustomVol(BuildContext context) {
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
                onVolumeChanged(customVolume);
              }
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _VolumeChip(
          label: '0,33L',
          isSelected: selectedVolumeML == 330,
          onTap: () => onVolumeChanged(330),
        ),
        _VolumeChip(
          label: '0,5L',
          isSelected: selectedVolumeML == 500,
          onTap: () => onVolumeChanged(500),
        ),
        _VolumeChip(
          label: ![330, 500].contains(selectedVolumeML)
              ? '${selectedVolumeML}ml'
              : 'Custom',
          isSelected: ![330, 500].contains(selectedVolumeML),
          onTap: () => _showCustomVol(context),
        ),
      ],
    );
  }
}

class _VolumeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _VolumeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primary,
      // Performance: LabelStyle explizit definieren verhindert Lookups
      labelStyle: TextStyle(
        color: isSelected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool isSaving;
  final bool isEditing;
  final VoidCallback? onSave; // Nullable für deaktivierten Zustand
  final VoidCallback onCancel;

  const _ActionButtons({
    required this.isSaving,
    required this.isEditing,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: isSaving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: isSaving
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    isEditing ? 'ÄNDERUNGEN SPEICHERN' : 'FERTIG & SPEICHERN',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: onCancel,
            child: Text('VERWERFEN',
                style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

// Dialog als konstantes Widget extrahiert
class _IncompleteDataDialog extends StatelessWidget {
  const _IncompleteDataDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
    );
  }
}
