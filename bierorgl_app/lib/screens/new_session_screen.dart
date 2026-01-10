import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../services/session_calculator_service.dart';
import '../services/session_state_provider.dart';
import '../widgets/speed_graph.dart';
import '../widgets/selection_list.dart';

class SessionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? session;
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
  final _dbService = SessionDbService();
  Position? _currentPosition;

  bool get _isEditing => widget.session != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
        text: widget.session?['name'] ??
            "Trichterung vom ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}");

    // Initialisierung der Daten über den Notifier
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final suggestedVol =
          SessionCalculatorService.suggestVolume(widget.calculatedVolumeML);
      final notifier = ref.read(sessionStateProvider.notifier);

      notifier.initData(suggestedVol);

      if (_isEditing) {
        final s = widget.session!;
        if (s['userID'] != null) notifier.selectUser(s['userID']);
        if (s['eventID'] != null) notifier.selectEvent(s['eventID']);
        if (s['volumeML'] != null) notifier.setVolume(s['volumeML']);
      }
    });

    _determineLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _determineLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        _currentPosition = await Geolocator.getCurrentPosition();
      }
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  Future<void> _handleSave() async {
    final state = ref.read(sessionStateProvider);
    final notifier = ref.read(sessionStateProvider.notifier);

    if (state.selectedUserID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Wer hat getrichtert?'), backgroundColor: Colors.red),
      );
      return;
    }

    notifier.setSaving(true);

    try {
      final sessionData = {
        'sessionID': widget.session?['sessionID'] ?? const Uuid().v4(),
        'startedAt':
            widget.session?['startedAt'] ?? DateTime.now().toIso8601String(),
        'userID': state.selectedUserID,
        'volumeML': state.selectedVolumeML,
        'durationMS': widget.session?['durationMS'] ?? widget.durationMS,
        'eventID': state.selectedEventID,
        'name': _nameController.text,
        'latitude': _currentPosition?.latitude ?? 0.0,
        'longitude': _currentPosition?.longitude ?? 0.0,
        'valuesJSON':
            widget.session?['valuesJSON'] ?? jsonEncode(widget.allValues),
        'calibrationFactor': widget.calibrationFactor?.toInt(),
      };

      await _dbService.commitSession(sessionData, _isEditing);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erfolgreich gespeichert!'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      notifier.setSaving(false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionStateProvider);
    final theme = Theme.of(context);

    final avgFlow = SessionCalculatorService.calculateAverageFlow(
        widget.durationMS ?? 0, state.selectedVolumeML);
    final peakFlow = SessionCalculatorService.calculatePeakFlow(
        widget.allValues ?? [], widget.calibrationFactor ?? 200.0);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(_isEditing ? 'Bearbeiten' : 'Ergebnis speichern'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildStatCarousel(theme, avgFlow, peakFlow),
            const SizedBox(height: 16),
            SessionChart(
              allValues: widget.allValues ?? [],
              volumeCalibrationValue: widget.calibrationFactor ?? 1.0,
            ),
            const SizedBox(height: 32),
            UserSelectionField(
              users: state.users,
              selectedUserID: state.selectedUserID,
              onChanged: (id) =>
                  ref.read(sessionStateProvider.notifier).selectUser(id!),
              onAddGuest: () => _showAddGuestDialog(ref),
            ),
            const SizedBox(height: 24),
            _buildNameField(theme),
            const SizedBox(height: 24),
            EventSelectionField(
              events: state.events,
              selectedEventID: state.selectedEventID,
              onChanged: (id) =>
                  ref.read(sessionStateProvider.notifier).selectEvent(id!),
            ),
            const SizedBox(height: 32),
            _buildVolumeSection(theme, state),
            const SizedBox(height: 48),
            _buildSaveButton(theme, state),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('VERWERFEN',
                  style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCarousel(ThemeData theme, double avgFlow, double peakFlow) {
    final List<Map<String, String>> stats = [
      {
        'label': 'GESAMTZEIT',
        'value': '${((widget.durationMS ?? 0) / 1000).toStringAsFixed(2)}s',
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
                      fontSize: 12,
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

  Widget _buildTimeHeader(ThemeData theme) {
    return Column(
      children: [
        Text(
          '${((widget.durationMS ?? 0) / 1000).toStringAsFixed(2)}s',
          style: theme.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.primary,
          ),
        ),
        const Text('GESAMTZEIT',
            style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildNameField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Titel der Trichterung',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            hintText: 'Z.B. Festival Warmup...',
          ),
        ),
      ],
    );
  }

  Widget _buildVolumeSection(ThemeData theme, SessionState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Volumen', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
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
        )
      ],
    );
  }

  Widget _volChip(String label, int ml, SessionState state,
      {bool isCustom = false}) {
    final bool selected = isCustom
        ? ![200, 330, 500].contains(state.selectedVolumeML)
        : state.selectedVolumeML == ml;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (s) {
        if (isCustom) {
          _showCustomVolumeDialog(ref);
        } else {
          ref.read(sessionStateProvider.notifier).setVolume(ml);
        }
      },
      selectedColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
          color: selected ? Colors.white : null, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSaveButton(ThemeData theme, SessionState state) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: state.isSaving ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: state.isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('FERTIG & SPEICHERN',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
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
