import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:project_camel/models/session.dart';
import 'package:project_camel/models/event.dart';
import 'package:uuid/uuid.dart';
import 'package:project_camel/core/constants.dart';
import 'package:project_camel/providers.dart';
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
  late final TextEditingController _nameController;

  String? _selectedUserID;
  String? _selectedEventID;
  int _selectedVolumeML = 500;
  bool _isSaving = false;
  Position? _currentPosition;

  // Getter für saubereren Code
  bool get _isEditing => widget.session != null;

  @override
  void initState() {
    super.initState();
    _initializeState();
    // Standort asynchron laden, ohne den UI-Aufbau zu blockieren
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
      // DateFormat cachen wir nicht global, da es locale-abhängig sein könnte,
      // aber wir erstellen es nur einmal hier.
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

      // Nur setState rufen, wenn Widget noch aktiv ist
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    } catch (e) {
      debugPrint("Fehler beim Abrufen des Standorts: $e");
    }
  }

  Future<void> _addGuestUser() async {
    final guestController = TextEditingController();
    final String? guestName = await showDialog<String>(
      context: context,
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

    if (guestName != null && guestName.isNotEmpty && mounted) {
      final newId = const Uuid().v4();
      // Asynchrone Operation abwarten
      await ref.read(databaseHelperProvider).insertUser({
        'userID': newId,
        'name': guestName,
        'username': 'gast_${guestName.toLowerCase().replaceAll(' ', '_')}',
        'eMail': 'gast@bierorgl.de',
      });

      if (mounted) {
        setState(() => _selectedUserID = newId);
      }
    }
  }

  Future<void> _processSave() async {
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

    await _executeFinalSave();
  }

  Future<void> _executeFinalSave() async {
    setState(() => _isSaving = true);

    try {
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
        valuesJSON: _isEditing
            ? widget.session!.valuesJSON
            : (widget.allValues != null ? jsonEncode(widget.allValues) : null),
        calibrationFactor: _isEditing
            ? widget.session!.calibrationFactor
            : widget.calibrationFactor?.toInt(),
      );

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
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Providers beobachten
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
            if (!_isEditing) _buildTimeHeader(theme),

            const SizedBox(height: 24),

            // Performance: RepaintBoundary verhindert, dass der Graph neu gemalt wird,
            // wenn sich Textfelder oder andere UI-Elemente ändern.
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

            // User Selection
            usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Fehler: $e'),
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

            // Form Fields
            _buildTextFields(theme, eventsAsync),

            const SizedBox(height: 20),

            // Volume Section
            const Text('Volumen',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (!_isEditing && widget.calculatedVolumeML != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Messung: ${widget.calculatedVolumeML} ml',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontStyle: FontStyle.italic),
                  ),
                ),
              ),

            _buildVolumeSelector(theme),

            const SizedBox(height: 40),

            // Action Buttons
            _buildActionButtons(theme),
          ],
        ),
      ),
    );
  }

  // --- Sub-Widgets zur Strukturierung & Performance ---

  Widget _buildTimeHeader(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          Text(
            '${((widget.durationMS ?? 0) / 1000).toStringAsFixed(2)}s',
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

  Widget _buildTextFields(
      ThemeData theme, AsyncValue<List<Event>> eventsAsync) {
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
          controller: _nameController,
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
          selectedEventID: _selectedEventID,
          onChanged: (val) => setState(() => _selectedEventID = val),
        ),
      ],
    );
  }

  Widget _buildVolumeSelector(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _VolumeChip(
          label: '0,33L',
          ml: 330,
          isSelected: _selectedVolumeML == 330,
          onTap: () => setState(() => _selectedVolumeML = 330),
        ),
        _VolumeChip(
          label: '0,5L',
          ml: 500,
          isSelected: _selectedVolumeML == 500,
          onTap: () => setState(() => _selectedVolumeML = 500),
        ),
        _VolumeChip(
          label: ![330, 500].contains(_selectedVolumeML)
              ? '${_selectedVolumeML}ml'
              : 'Custom',
          ml: _selectedVolumeML,
          isSelected: ![330, 500].contains(_selectedVolumeML),
          isCustom: true,
          onTap: _showCustomVol,
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _processSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    _isEditing ? 'ÄNDERUNGEN SPEICHERN' : 'FERTIG & SPEICHERN',
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
            onPressed: () => Navigator.pop(context),
            child: Text('VERWERFEN',
                style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ],
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

// Helper Widget für Chips, um Rebuilds zu minimieren und Code zu säubern
class _VolumeChip extends StatelessWidget {
  final String label;
  final int ml;
  final bool isSelected;
  final bool isCustom;
  final VoidCallback onTap;

  const _VolumeChip({
    required this.label,
    required this.ml,
    required this.isSelected,
    required this.onTap,
    this.isCustom = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
      ),
    );
  }
}
