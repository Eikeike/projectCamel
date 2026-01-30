import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:project_camel/models/event.dart';
import 'package:project_camel/models/session.dart';
import 'package:project_camel/providers.dart';
import 'package:project_camel/screens/new_session_screen.dart';
import 'package:project_camel/widgets/session_list.dart';

class EventEditScreen extends ConsumerStatefulWidget {
  final Event? event;
  const EventEditScreen({super.key, this.event});

  @override
  ConsumerState<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends ConsumerState<EventEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _dateFromController;
  late TextEditingController _dateToController;

  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  bool _isLoadingLocation = false;

  final _dateFmt = DateFormat('dd.MM.yyyy');

  late bool _isEditing;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.event == null;
    _resetFieldsFromEvent();
  }

  void _resetFieldsFromEvent() {
    final e = widget.event;

    _nameController = TextEditingController(text: e?.name ?? '');
    _descController = TextEditingController(text: e?.description ?? '');

    // FIX 1: .toLocal() hinzufügen für korrekte Anzeige
    _dateFromController = TextEditingController(
        text:
            e?.dateFrom != null ? _dateFmt.format(e!.dateFrom!.toLocal()) : '');
    _dateToController = TextEditingController(
        text: e?.dateTo != null ? _dateFmt.format(e!.dateTo!.toLocal()) : '');

    if (e?.latitude != null && e?.longitude != null) {
      _selectedLocation = LatLng(e!.latitude!, e.longitude!);
    } else {
      _selectedLocation = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime initial = DateTime.now();
    try {
      if (controller.text.isNotEmpty) {
        initial = _dateFmt.parse(controller.text);
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      controller.text = _dateFmt.format(picked);
    }
  }

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
      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition();

      if (mounted) {
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });

        _mapController.move(_selectedLocation!, 15.0);
      }
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _enterEditMode() {
    setState(() => _isEditing = true);
  }

  void _cancelEdit() {
    if (widget.event == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() {
      final e = widget.event!;
      _nameController.text = e.name;
      _descController.text = e.description ?? '';

      // FIX 2: Auch hier .toLocal() beim Abbrechen
      _dateFromController.text =
          e.dateFrom != null ? _dateFmt.format(e.dateFrom!.toLocal()) : '';
      _dateToController.text =
          e.dateTo != null ? _dateFmt.format(e.dateTo!.toLocal()) : '';

      if (e.latitude != null && e.longitude != null) {
        _selectedLocation = LatLng(e.latitude!, e.longitude!);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_selectedLocation != null) {
            _mapController.move(_selectedLocation!, 15);
          }
        });
      } else {
        _selectedLocation = null;
      }

      _isEditing = false;
    });
  }

  // FIX 3: Robustes Parsing mit 12:00 Uhr UTC Trick
  DateTime? _parseDate(String text) {
    if (text.isEmpty) return null;
    try {
      // Parse String zu lokalem Datum (00:00 Uhr)
      final localDate = _dateFmt.parse(text);

      // Erstelle UTC Datum um 12:00 Uhr mittags
      // Dies verhindert Datumsverschiebung durch Zeitzonen
      return DateTime.utc(
        localDate.year,
        localDate.month,
        localDate.day,
        12,
        0,
        0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    final theme = Theme.of(context);

    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Name fehlt!'),
        backgroundColor: theme.colorScheme.error,
      ));
      return;
    }

    final id = widget.event?.id ?? const Uuid().v4();

    final event = Event(
      id: id,
      name: _nameController.text,
      description:
          _descController.text.isNotEmpty ? _descController.text : null,
      dateFrom: _parseDate(_dateFromController.text),
      dateTo: _parseDate(_dateToController.text),
      latitude: _selectedLocation?.latitude,
      longitude: _selectedLocation?.longitude,
    );

    await ref.read(eventRepositoryProvider).saveEventForSync(event);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            widget.event == null ? 'Event erstellt' : 'Änderungen gespeichert'),
        backgroundColor: theme.colorScheme.primary,
      ));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null
            ? 'Neues Event'
            : (_isEditing ? 'Event bearbeiten' : 'Event ansehen')),
        actions: [
          if (widget.event != null && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Bearbeiten',
              onPressed: _enterEditMode,
            ),
          if (widget.event != null && _isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Abbrechen',
              onPressed: _cancelEdit,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              readOnly: !_isEditing,
              enabled: _isEditing,
              decoration: const InputDecoration(
                labelText: 'Event Name',
                hintText: 'Z.B. Sommerfest 2026',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              readOnly: !_isEditing,
              enabled: _isEditing,
              maxLines: 4,
              minLines: 3,
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                hintText: 'Kurze Beschreibung (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateFromController,
                    readOnly: true,
                    enabled: _isEditing,
                    onTap: _isEditing
                        ? () => _selectDate(_dateFromController)
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Von (Datum)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.date_range),
                        onPressed: _isEditing
                            ? () => _selectDate(_dateFromController)
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _dateToController,
                    readOnly: true,
                    enabled: _isEditing,
                    onTap: _isEditing
                        ? () => _selectDate(_dateToController)
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Bis (Datum)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.date_range),
                        onPressed: _isEditing
                            ? () => _selectDate(_dateToController)
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Veranstaltungsort',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
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
            const SizedBox(height: 24),
            if (_isEditing) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      widget.event == null ? 'Event erstellen' : 'Speichern',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (widget.event != null && _isEditing)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _delete,
                  child: Text(
                    'Löschen',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
            if (!_isEditing && widget.event != null) ...[
              const SizedBox(height: 32),
              _buildSessionHistory(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationMap(ThemeData theme) {
    final center = _selectedLocation ?? const LatLng(51.1657, 10.4515);
    final isDarkMode = theme.brightness == Brightness.dark;

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
                height: 300,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: _selectedLocation != null ? 15.0 : 5.0,
                    interactionOptions: InteractionOptions(
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
                    TileLayer(
                      urlTemplate: mapUrl,
                      userAgentPackageName: 'com.tim.bierorgl',
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

  Widget _buildSessionHistory() {
    final eventSessionsAsync =
        ref.watch(sessionsByEventIDProvider(widget.event!.id));
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Text(
            'Verlauf',
            style: TextStyle(
              fontSize: Theme.of(context).textTheme.titleMedium?.fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        eventSessionsAsync.when(
          loading: () => SizedBox(
            width: double.infinity,
            child: Center(
              child: CircularProgressIndicator(color: cs.primary),
            ),
          ),
          error: (err, stack) => Text(
            'Fehler beim Laden der Sessions',
            style: TextStyle(color: cs.error),
          ),
          data: (sessions) {
            if (sessions.isEmpty) {
              return Text(
                'Keine Sessions für dieses Event',
                style: TextStyle(color: cs.onSurfaceVariant),
              );
            }

            return SizedBox(
              width: double.infinity,
              child: SessionList(
                key: const PageStorageKey('sessionsByEventList'),
                sessions: sessions,
                embedded: true,
                showEvent: false,
                onSessionTap: (session) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SessionScreen(session: session),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _delete() async {
    if (widget.event == null) return;

    final theme = Theme.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Event löschen?'),
        content: const Text('Dieses Event wird gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Löschen',
                style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await ref
        .read(eventRepositoryProvider)
        .markEventAsDeleted(widget.event!.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Event gelöscht'),
      backgroundColor: theme.colorScheme.primary,
    ));
    Navigator.pop(context);
  }
}
