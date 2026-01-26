import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/trichter_connection_service.dart';
import '../services/trichter_data_handler.dart';
import 'new_session_screen.dart';
import '../widgets/bluetooth_settings_tile.dart';

class TrichternScreen extends ConsumerStatefulWidget {
  const TrichternScreen({super.key});

  @override
  ConsumerState<TrichternScreen> createState() => _TrichternScreenState();
}

class _TrichternScreenState extends ConsumerState<TrichternScreen> {
  // ===========================================================================
  // 1. LIFECYCLE & LOGIC
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    // Initialer State-Refresh nur einmal beim Laden, nicht via Polling im Build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trichterConnectionProvider.notifier).queryCurrentDeviceState();
    });
  }

  void _handleSessionFinished(TrichterDataState next) {
    // Volumen-Berechnung auslagern, um UI-Thread nicht zu blockieren (falls komplex)
    // Hier simpel gehalten, da Berechnung trivial ist.
    int? calculatedVolumeML;
    if (next.volumeCalibrationFactor != null &&
        next.volumeCalibrationFactor! > 0) {
      final double ratio = next.msValues.length / next.volumeCalibrationFactor!;
      calculatedVolumeML = (ratio * 500).round();
    }

    if (mounted) {
      // Debug-Ausgaben (könnten in Production entfernt werden)
      debugPrint("--- SESSION FINISHED ---");
      debugPrint(
          "Dauer: ${next.lastDurationMS}ms | Ticks: ${next.msValues.length}");

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SessionScreen(
            durationMS: next.lastDurationMS,
            allValues: next.msValues,
            calibrationFactor: next.volumeCalibrationFactor?.toDouble(),
            calculatedVolumeML: calculatedVolumeML,
          ),
        ),
      ).then((_) => _onReturnFromSession());
    }
  }

  void _onReturnFromSession() {
    if (!mounted) return;

    // Reset Logic direkt hier, statt via Flags im Build-Cycle
    final connNotifier = ref.read(trichterConnectionProvider.notifier);
    final dataNotifier = ref.read(trichterDataHandlerProvider.notifier);
    final connState = ref.read(trichterConnectionProvider);

    dataNotifier.resetSession();

    // Force Ready falls nötig
    if (connState.deviceStatus == TrichterDeviceStatus.sending ||
        connState.deviceStatus == TrichterDeviceStatus.running) {
      connNotifier.requestState(TrichterDeviceStatus.ready);
    }

    // State Refresh
    connNotifier.queryCurrentDeviceState();
  }

  @override
  Widget build(BuildContext context) {

    ref.listen<TrichterConnectionState>(trichterConnectionProvider, (previous, next) {
      // 1. Handle Success (using the trigger flag from the service)
      if (next.calibrationSuccessTrigger) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kalibrierung erfolgreich!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // 2. Handle Failure (transition from calibrating directly to error)
      if (previous?.deviceStatus == TrichterDeviceStatus.calibrating && 
          next.deviceStatus == TrichterDeviceStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kalibrierung fehlgeschlagen!'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });
    
    // --- LISTENER (Navigation & Fehler) ---
    // Wir hören hier nur auf spezifische Änderungen für Events
    ref.listen<TrichterDataState>(trichterDataHandlerProvider,
        (previous, next) {
      // Navigation
      final wasJustFinished = (previous?.isSessionFinished == false &&
          next.isSessionFinished == true);
      if (wasJustFinished && next.lastDurationMS > 0) {
        _handleSessionFinished(next);
      }

      // Fehlerbehandlung
      if (next.error != null && previous?.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    // ===========================================================================
    // 2. UI LAYOUT
    // ===========================================================================
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Statischer Header (kein Rebuild nötig)
            const _HeaderSection(),

            // Bluetooth Status Tile (Self-contained widget)
            const BluetoothSettingsTile(),

            // Status Circle
            // Isoliert in Expanded, damit der Rest der Column statisch bleiben kann
            const Expanded(
              child: Center(
                // RepaintBoundary für Performance bei Animationen (Progress Spinner)
                child: RepaintBoundary(
                  child: _StatusCircle(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 3. OPTIMIZED SUB-WIDGETS
// ===========================================================================

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'BIERORGL',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            'Bereit zum Ballern!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

class _StatusCircle extends ConsumerWidget {
  const _StatusCircle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connState = ref.watch(trichterConnectionProvider);
    final progress =
        ref.watch(trichterDataHandlerProvider.select((d) => d.progress));

    final theme = Theme.of(context);
    final status = connState.deviceStatus;
    final isConnected = connState.status == TrichterConnectionStatus.connected;

    // Visuals bestimmen
    final (Color color, IconData icon, String text) =
        _getStatusVisuals(isConnected, status, theme.colorScheme);

    final bool isTransferringWithProgress = progress > 0 && progress < 1;

    // Zugriff auf den Notifier für Aktionen
    final notifier = ref.read(trichterConnectionProvider.notifier);

    return GestureDetector(
      onTap: () {
        // Nur wenn verbunden UND idle -> Wakeup senden
        if (isConnected && status == TrichterDeviceStatus.idle) {
          notifier.requestState(TrichterDeviceStatus.ready);
        }
      },
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surfaceContainer,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 25,
              spreadRadius: 5,
            ),
          ],
          border: Border.all(color: color, width: 8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isTransferringWithProgress)
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  color: color,
                  backgroundColor: color.withOpacity(0.2),
                ),
              )
            else
              Icon(
                // Wenn idle -> Power-Icon anzeigen, um Wakeup zu symbolisieren
                status == TrichterDeviceStatus.idle
                    ? Icons.power_settings_new
                    : icon,
                size: 80,
                color: color,
              ),
            const SizedBox(height: 20),
            Text(
              status == TrichterDeviceStatus.idle
                  ? "Tippen zum \n Aufwecken"
                  : text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (isTransferringWithProgress)
              Text(
                "${(progress * 100).toInt()}%",
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 16),
              )
          ],
        ),
      ),
    );
  }

  (Color, IconData, String) _getStatusVisuals(
      bool isConnected, TrichterDeviceStatus status, ColorScheme colors) {
    if (!isConnected) {
      return (colors.error, Icons.bluetooth_disabled, 'Keine Verbindung');
    }

    switch (status) {
      case TrichterDeviceStatus.idle:
        return (
          colors.secondary,
          Icons.nights_stay_rounded,
          'Warte auf Wakeup'
        );
      case TrichterDeviceStatus.ready:
        return (colors.primary, Icons.sports_bar, 'Bereit!');
      case TrichterDeviceStatus.running:
        return (colors.tertiary, Icons.timer, 'Läuft...');
      case TrichterDeviceStatus.sending:
        return (
          colors.tertiary,
          Icons.move_to_inbox_rounded,
          'Empfange Daten...'
        );
      case TrichterDeviceStatus.calibrating:
        return (colors.tertiary, Icons.build_rounded, 'Kalibrieren');
      case TrichterDeviceStatus.error:
        return (colors.error, Icons.warning_amber_rounded, 'Gerätefehler');
      default:
        return (colors.outline, Icons.question_mark, 'Unbekannt');
    }
  }
}
