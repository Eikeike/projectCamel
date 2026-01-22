import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:project_camel/providers.dart';
import 'package:uuid/uuid.dart';
import 'package:project_camel/models/session.dart';

import '../services/session_calculator_service.dart';
import '../services/session_state_provider.dart';
import '../widgets/speed_graph.dart';
import '../widgets/selection_list.dart'; // Stelle sicher, dass hier deine angepasste SelectionList liegt

class SessionScreen extends ConsumerStatefulWidget {
  final Session? session;

  // Parameter für neue Session (Ergebnis speichern)
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
  final MapController _mapController = MapController();

  // State variables
  late bool _isEditing;
  LatLng? _selectedLocation;
  bool _isLoadingLocation = false;

  // Getter für effektive Werte (Fallback auf Session oder übergebene Parameter)
  int get _effectiveDurationMS =>
      widget.session?.durationMS ?? widget.durationMS ?? 0;

  List<int> get _effectiveAllValues {
    if (widget.session?.valuesJSON != null) {
      try {
        final decoded = jsonDecode(widget.session!.valuesJSON!);
        if (decoded is List) return List<int>.from(decoded);
      } catch (e) {
        debugPrint('Error decoding valuesJSON: $e');
      }
    }
    return widget.allValues ?? [];
  }

  double get _effectiveCalibrationFactor =>
      widget.session?.calibrationFactor?.toDouble() ??
      widget.calibrationFactor ??
      200.0;

  @override
  void initState() {
    super.initState();
    // Wenn Session null ist, erstellen wir gerade neu -> Edit Modus an.
    // Wenn Session existiert, schauen wir nur an -> Edit Modus aus.
    _isEditing = widget.session == null;

    _nameController = TextEditingController();

    // Daten initialisieren
    _resetFieldsFromSessionOrParams();
  }

  void _resetFieldsFromSessionOrParams() {
    final s = widget.session;

    // 1. Name
    if (s != null) {
      _nameController.text = s.name ?? '';
    } else {
      _nameController.text =
          "Trichterung vom ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}";
    }

    // 2. Location
    if (s != null &&
        s.latitude != null &&
        s.longitude != null &&
        s.latitude != 0) {
      _selectedLocation = LatLng(s.latitude!, s.longitude!);
    } else {
      _selectedLocation = null;
    }

    // 3. Provider State resetten und füllen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(sessionStateProvider.notifier);

      if (s != null) {
        // --- KORREKTUR START ---
        // Wir übergeben direkt das Volumen der Session an initData,
        // statt 0 zu übergeben und es später zu überschreiben.
        // Fallback auf 500 (oder 0), falls null.
        final int startVolume = s.volumeML ?? 500;
        notifier.initData(startVolume);

        if (s.userID != null) notifier.selectUser(s.userID!);
        if (s.eventID != null) notifier.selectEvent(s.eventID!);
        // setVolume ist hier nicht mehr nötig, da initData das schon erledigt hat
        // --- KORREKTUR ENDE ---
      } else {
        // Neue Session Werte
        final suggestedVol =
            SessionCalculatorService.suggestVolume(widget.calculatedVolumeML);
        notifier.initData(suggestedVol);
        _getCurrentLocation();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // --- LOCATION LOGIC ---

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();

        if (mounted) {
          setState(() {
            _selectedLocation = LatLng(position.latitude, position.longitude);
            _isLoadingLocation = false;
          });
          _mapController.move(_selectedLocation!, 15.0);
        }
      }
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  // --- MODES ---

  void _enterEditMode() {
    setState(() => _isEditing = true);
  }

  void _cancelEdit() {
    // Wenn wir gerade eine GANZ NEUE Session erstellen und abbrechen, gehen wir zurück
    if (widget.session == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    // Sonst resetten wir die Felder auf die alten Werte
    setState(() {
      _resetFieldsFromSessionOrParams();
      _isEditing = false;
    });
  }

  // --- SAVE ---

  Future<void> _handleSave() async {
    final state = ref.read(sessionStateProvider);
    final notifier = ref.read(sessionStateProvider.notifier);

    if (state.selectedUserID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Wer hat getrichtert? Bitte User wählen.'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
      return;
    }

    notifier.setSaving(true);

    try {
      final session = Session(
        id: widget.session?.id ?? const Uuid().v4(),
        volumeML: state.selectedVolumeML,
        name: _nameController.text.isNotEmpty ? _nameController.text : null,
        description: widget.session?.description,
        // Koordinaten vom lokalen State nehmen
        latitude: _selectedLocation?.latitude ?? 0.0,
        longitude: _selectedLocation?.longitude ?? 0.0,
        startedAt: widget.session?.startedAt ?? DateTime.now(),
        userID: state.selectedUserID ?? '',
        eventID: state.selectedEventID,
        durationMS: _effectiveDurationMS,
        valuesJSON: widget.session != null
            ? widget.session!.valuesJSON
            : (widget.allValues != null ? jsonEncode(widget.allValues) : null),
        calibrationFactor: widget.session != null
            ? widget.session!.calibrationFactor
            : widget.calibrationFactor?.toInt(),
      );

      await ref
          .read(sessionRepositoryProvider)
          .saveSessionForSync(session, isEditing: widget.session != null);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.session == null
              ? 'Ergebnis gespeichert!'
              : 'Änderungen gespeichert'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );

      // Wenn neu -> schließen. Wenn edit -> Modus beenden.
      if (widget.session == null) {
        Navigator.of(context).pop();
      } else {
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      notifier.setSaving(false);
    }
  }

  // --- DELETE ---

  Future<void> _handleDelete() async {
    if (widget.session == null) {
      // Wenn wir noch nicht gespeichert haben (neue Session), einfach zurück
      Navigator.pop(context);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trichterung löschen?'),
        content: const Text('Dieser Eintrag wird gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Löschen',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await ref
        .read(sessionRepositoryProvider)
        .markSessionAsDeleted(widget.session!.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Eintrag gelöscht.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionStateProvider);
    final theme = Theme.of(context);

    // Stats berechnen
    final avgFlow = SessionCalculatorService.calculateAverageFlow(
        _effectiveDurationMS, state.selectedVolumeML);
    final peakFlow = SessionCalculatorService.calculatePeakFlow(
        _effectiveAllValues, _effectiveCalibrationFactor);

    // Konsistente Abstände definieren
    const double sectionGap = 32.0; // Abstand zwischen Hauptbereichen
    const double fieldGap = 16.0; // Abstand zwischen Formularfeldern
    const double labelGap = 8.0; // Abstand zwischen Label und Inhalt

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.session == null
            ? 'Ergebnis speichern'
            : (_isEditing ? 'Bearbeiten' : 'Trichterung')),
        actions: [
          if (widget.session != null && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Bearbeiten',
              onPressed: _enterEditMode,
            ),
          if (widget.session != null && _isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Abbrechen',
              onPressed: _cancelEdit,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Graphen und Stats
            _buildStatCarousel(theme, avgFlow, peakFlow),
            const SizedBox(height: 16),
            SessionChart(
              allValues: _effectiveAllValues,
              volumeCalibrationValue: _effectiveCalibrationFactor,
            ),

            const SizedBox(height: sectionGap), // Großer Abstand

            // 2. Formularfelder

            // User Selection
            UserSelectionField(
              users: state.users,
              selectedUserID: state.selectedUserID,
              isEditing: _isEditing,
              onChanged: (id) =>
                  ref.read(sessionStateProvider.notifier).selectUser(id!),
              onAddGuest: () => _showAddGuestDialog(ref),
            ),

            const SizedBox(height: fieldGap), // Mittlerer Abstand

            // Titel
            TextField(
              controller: _nameController,
              readOnly: !_isEditing,
              enabled: _isEditing,
              decoration: const InputDecoration(
                labelText: 'Titel',
                hintText: 'Z.B. Festival Warmup',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: fieldGap), // Mittlerer Abstand

            // Event Selection
            EventSelectionField(
              events: state.events,
              selectedEventID: state.selectedEventID,
              isEditing: _isEditing,
              onChanged: (id) => ref
                  .read(sessionStateProvider.notifier)
                  .selectEvent(id ?? 'Kein Event ausgewählt'),
            ),

            const SizedBox(height: sectionGap), // Großer Abstand

            // 3. Karte
            Text('Ort',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: labelGap), // Kleiner Abstand zum Inhalt
            _buildLocationMap(theme),
            if (_selectedLocation != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),

            const SizedBox(height: sectionGap), // Großer Abstand

            // 4. Volumen
            Text('Menge',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: labelGap), // Kleiner Abstand zum Inhalt

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _volChip('Kölsch', 200, state),
                _volChip('0,33L', 330, state),
                _volChip('0,5L', 500, state),
                _volChip(
                  ![200, 330, 500].contains(state.selectedVolumeML)
                      ? '${state.selectedVolumeML}ml'
                      : 'Eigene',
                  state.selectedVolumeML,
                  state,
                  isCustom: true,
                ),
              ],
            ),

            // HIER IST DER WICHTIGE NEUE ABSTAND ZU DEN BUTTONS
            const SizedBox(height: sectionGap),

            // 5. Buttons (Nur sichtbar wenn Editing)
            if (_isEditing) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.isSaving ? null : _handleSave,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: state.isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(widget.session == null
                            ? 'Speichern'
                            : 'Änderungen speichern'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (widget.session != null)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _handleDelete,
                    child: Text('Eintrag löschen',
                        style: TextStyle(color: theme.colorScheme.error)),
                  ),
                ),
            ],

            // Verwerfen Button (bei neuer Session)
            if (widget.session == null)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _handleDelete,
                  child: Text('Verwerfen',
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
              ),

            // Extra Abstand am unteren Rand fürs Scrollen
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- MAP WIDGET ---
  Widget _buildLocationMap(ThemeData theme) {
    final center = _selectedLocation ?? const LatLng(51.1657, 10.4515);
    final isDarkMode = theme.brightness == Brightness.dark;

    // CartoDB URLs (Hell vs. Dunkel)
    final mapUrl = isDarkMode
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';

    return Column(
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 250,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: _selectedLocation != null ? 15.0 : 5.0,
                    interactionOptions: InteractionOptions(
                      // Interaktion nur erlauben wenn Editing!
                      flags: _isEditing
                          ? (InteractiveFlag.all & ~InteractiveFlag.rotate)
                          : InteractiveFlag.none,
                    ),
                    onTap: _isEditing
                        ? (tapPos, point) {
                            setState(() {
                              _selectedLocation = point;
                            });
                          }
                        : null,
                  ),
                  children: [
                    // TileLayer (Jetzt ohne ColorFiltered, dafür mit CartoDB URL)
                    TileLayer(
                      urlTemplate: mapUrl,
                      userAgentPackageName: 'com.example.project_camel',
                      subdomains: const ['a', 'b', 'c', 'd'],
                    ),

                    MarkerLayer(
                      markers: [
                        if (_selectedLocation != null)
                          Marker(
                            point: _selectedLocation!,
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.location_on,
                              color: theme.colorScheme.primary,
                              size: 40,
                            ),
                          ),
                      ],
                    ),

                    // Attribution angepasst inkl. Carto
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors',
                            onTap: () {}),
                        TextSourceAttribution('© CARTO', onTap: () {}),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // "Locate Me" Button - Nur sichtbar im Edit Modus
            if (_isEditing)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.2), blurRadius: 6)
                      ]),
                  child: IconButton(
                    onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                    icon: _isLoadingLocation
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary))
                        : Icon(Icons.my_location,
                            color: theme.colorScheme.primary),
                    tooltip: 'Mein Standort',
                  ),
                ),
              ),

            // Hinweis Overlay nur wenn Editing und noch kein Ort
            if (_isEditing && _selectedLocation == null)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Tippe auf die Karte, um den Ort zu setzen',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildStatCarousel(ThemeData theme, double avgFlow, double peakFlow) {
    final List<Map<String, String>> stats = [
      {
        'label': 'GESAMTZEIT',
        'value': '${(_effectiveDurationMS / 1000).toStringAsFixed(2)}s',
        'sub': 'Dauer der Session'
      },
      {
        'label': 'Ø FLOW',
        'value': '${avgFlow.toStringAsFixed(2)} L/s',
        'sub': 'Durchschnittliche Rate'
      },
      {
        'label': 'PEAK FLOW',
        'value': '${peakFlow.toStringAsFixed(2)} L/s',
        'sub': 'Maximale Saugkraft'
      },
    ];

    return SizedBox(
      height: 140,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.85),
        itemCount: stats.length,
        itemBuilder: (context, index) {
          final stat = stats[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(stat['label']!,
                    style: TextStyle(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    )),
                const SizedBox(height: 4),
                Text(stat['value']!,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                    )),
                Text(stat['sub']!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _volChip(String label, int ml, SessionState state,
      {bool isCustom = false}) {
    final bool selected = isCustom
        ? ![200, 330, 500].contains(state.selectedVolumeML)
        : state.selectedVolumeML == ml;

    final theme = Theme.of(context);

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      // WENN nicht editing -> null (deaktiviert Klick, behält aber Auswahl bei)
      onSelected: _isEditing
          ? (s) {
              if (isCustom) {
                _showCustomVolumeDialog(ref);
              } else {
                ref.read(sessionStateProvider.notifier).setVolume(ml);
              }
            }
          : null,

      // Styling für aktiven Zustand
      selectedColor: theme.colorScheme.primary,
      checkmarkColor: theme.colorScheme.onPrimary,

      labelStyle: TextStyle(
          // Textfarbe anpassen: Weiß wenn ausgewählt, sonst Standard
          color: selected
              ? theme.colorScheme.onPrimary
              : (_isEditing
                  ? null
                  : theme.colorScheme.onSurface.withOpacity(0.6)),
          fontWeight: FontWeight.bold),
    );
  }

  void _showAddGuestDialog(WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gast hinzufügen'),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Name eingeben')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await ref
                    .read(sessionStateProvider.notifier)
                    .addGuest(controller.text);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  void _showCustomVolumeDialog(WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eigene Menge (ml)'),
        content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(suffixText: 'ml')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null)
                ref.read(sessionStateProvider.notifier).setVolume(val);
              Navigator.pop(context);
            },
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
  }
}
