import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late TextEditingController _latController;
  late TextEditingController _lonController;

  Position? _currentPosition;

  final _dateFmt = DateFormat('dd.MM.yyyy');

  late bool _isEditing;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.event == null; // create mode -> editing by default
    _resetFieldsFromEvent();
  }

  void _resetFieldsFromEvent() {
    final e = widget.event;

    _nameController = TextEditingController(text: e?.name ?? '');
    _descController = TextEditingController(text: e?.description ?? '');
    _dateFromController = TextEditingController(
        text: e?.dateFrom != null ? _dateFmt.format(e!.dateFrom!) : '');
    _dateToController = TextEditingController(
        text: e?.dateTo != null ? _dateFmt.format(e!.dateTo!) : '');
    _latController =
        TextEditingController(text: e?.latitude?.toStringAsFixed(6) ?? '');
    _lonController =
        TextEditingController(text: e?.longitude?.toStringAsFixed(6) ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    _latController.dispose();
    _lonController.dispose();
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
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      _currentPosition = await Geolocator.getCurrentPosition();
      if (_currentPosition != null && mounted) {
        setState(() {
          _latController.text = _currentPosition!.latitude.toStringAsFixed(6);
          _lonController.text = _currentPosition!.longitude.toStringAsFixed(6);
        });
      }
    } catch (e) {
      // ignore errors silently for now
      debugPrint('Location error: $e');
    }
  }

  void _enterEditMode() {
    setState(() => _isEditing = true);
  }

  void _cancelEdit() {
    if (widget.event == null) {
      // If creating, cancel means pop
      if (mounted) Navigator.pop(context);
      return;
    }

    // Reset fields back to event values and switch out of edit mode
    setState(() {
      final e = widget.event!;
      _nameController.text = e.name;
      _descController.text = e.description ?? '';
      _dateFromController.text =
          e.dateFrom != null ? _dateFmt.format(e.dateFrom!) : '';
      _dateToController.text =
          e.dateTo != null ? _dateFmt.format(e.dateTo!) : '';
      _latController.text = e.latitude?.toStringAsFixed(6) ?? '';
      _lonController.text = e.longitude?.toStringAsFixed(6) ?? '';
      _isEditing = false;
    });
  }

  DateTime? _parseDate(String text) {
    if (text.isEmpty) return null;
    try {
      return _dateFmt.parse(text);
    } catch (_) {
      return null;
    }
  }

  double? _parseDouble(String text) {
    if (text.isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '.'));
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
      latitude: _parseDouble(_latController.text),
      longitude: _parseDouble(_lonController.text),
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
            // Name
            TextField(
              controller: _nameController,
              readOnly: !_isEditing,
              enabled: _isEditing,
              decoration: InputDecoration(
                labelText: 'Event Name',
                hintText: 'Z.B. Sommerfest 2026',
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descController,
              readOnly: !_isEditing,
              enabled: _isEditing,
              maxLines: 4,
              minLines: 3,
              decoration: InputDecoration(
                labelText: 'Beschreibung',
                hintText: 'Kurze Beschreibung (optional)',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 16),

            // Date From / To
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

            const SizedBox(height: 16),

            // Latitude / Longitude
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    readOnly: !_isEditing,
                    enabled: _isEditing,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Latitude',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lonController,
                    readOnly: !_isEditing,
                    enabled: _isEditing,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Longitude',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            if (_isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Aktuellen Standort nutzen'),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Action buttons
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

            // Delete button (only in edit mode)
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

            // Close button (only in view mode)
            // if (!_isEditing)
            //   SizedBox(
            //     width: double.infinity,
            //     child: TextButton(
            //       onPressed: () => Navigator.pop(context),
            //       child: const Text('Schließen'),
            //     ),
            //   ),

            // Session history (only in display mode)
            if (!_isEditing && widget.event != null) ...[
              const SizedBox(height: 32),
              _buildSessionHistory(),
            ],
          ],
        ),
      ),
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
    Navigator.pop(context); // close screen after deletion
  }
}
