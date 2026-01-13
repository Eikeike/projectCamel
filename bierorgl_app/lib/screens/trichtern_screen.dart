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
  // 1. STATE & LISTENER LOGIC
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    // --- PROVIDER WATCHERS ---
    // Beobachte den Verbindungsstatus & die Daten-Eingänge separat
    // Nutzt Riverpod's Reaktivität statt manueller Timer
    final connection = ref.watch(trichterConnectionProvider);
    final dataState = ref.watch(trichterDataHandlerProvider);

    final bool isConnected =
        connection.status == TrichterConnectionStatus.connected;

    // --- NAVIGATION LISTENER ---
    // Reagiert auf das Ende der Übertragung (Side-Effect)
    ref.listen<TrichterDataState>(trichterDataHandlerProvider,
        (previous, next) {
      // Navigation auslösen, wenn isSessionFinished von false auf true springt
      final bool wasJustFinished = (previous?.isSessionFinished == false &&
          next.isSessionFinished == true);

      if (wasJustFinished && next.lastDurationMS > 0) {
        // Volumen-Schätzung basierend auf der Hardware-Kalibrierung
        int? calculatedVolumeML;
        if (next.volumeCalibrationFactor != null &&
            next.volumeCalibrationFactor! > 0) {
          // Jeder Eintrag in msValues entspricht einem physischen Tick
          // Formel: (Gemessene Ticks / Kalibrierungs-Ticks für 0.5L) * 500
          final double ratio =
              next.msValues.length / next.volumeCalibrationFactor!;
          calculatedVolumeML = (ratio * 500).round();
        }

        if (mounted) {
          // Debug-Log für die Hardware-Abstimmung
          debugPrint("--- SESSION FINISHED ---");
          debugPrint("Dauer: ${next.lastDurationMS}ms");
          debugPrint("Ticks: ${next.msValues.length}");
          debugPrint("V-Factor: ${next.volumeCalibrationFactor}");
          debugPrint("Schätzung: $calculatedVolumeML ml");

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionScreen(
                durationMS: next.lastDurationMS,
                allValues:
                    next.msValues, // msValues sind bereits skaliert & geparst
                calibrationFactor: next.volumeCalibrationFactor?.toDouble(),
                calculatedVolumeML: calculatedVolumeML,
              ),
            ),
          ).then((_) {
            // WICHTIG: Wenn der User zurückkommt, den State für die nächste Messung leeren
            if (mounted) {
              ref.read(trichterDataHandlerProvider.notifier).resetSession();
            }
          });
        }
      }

      // Fehlerbehandlung: Zeige Übertragungsfehler als SnackBar
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
    // 2. UI LAYOUT BUILD
    // ===========================================================================

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header-Bereich
            _buildHeader(context),

            // Bluetooth-Status Kachel (Modular eingebunden)
            const BluetoothSettingsTile(),

            // Mittlerer Bereich: Dynamische Status-Anzeige
            Expanded(
              child: Center(
                child: _buildStatusCircle(context, connection, dataState),
              ),
            ),

            // Footer-Bereich: Dynamische Texte je nach Zustand
            _buildFooter(
              context,
              connection,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. HELPER WIDGETS
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // Header: Titel und Slogan
  // ---------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context) {
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
                color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            'Bereit zum Ballern!',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status Circle: Visualisiert alle Hardware-States (Idle, Ready, Running...)
// ---------------------------------------------------------------------------
  Widget _buildStatusCircle(BuildContext context,
      TrichterConnectionState connState, TrichterDataState data) {
    final theme = Theme.of(context);

    // Zum Testen hier hardcoden, später wieder state.deviceStatus nutzen
    //final status = TrichterDeviceStatus.error;
    final status = connState.deviceStatus;

    // Zum Testen hier hardcoden, später wieder connState.status == TrichterConnectionStatus.connected nutzen
    //final isConnected = true;
    final isConnected = connState.status == TrichterConnectionStatus.connected;

    Color color;
    IconData icon;
    String text;

    if (!isConnected) {
      color = theme.colorScheme.error;
      icon = Icons.bluetooth_disabled;
      text = 'Keine Verbindung';
    } else {
      switch (status) {
        case TrichterDeviceStatus.idle:
          color = theme.colorScheme.secondary;
          icon = Icons.nights_stay_rounded;
          text = 'Warte auf Wakeup';
          break;
        case TrichterDeviceStatus.ready:
          color = theme.colorScheme.primary;
          icon = Icons.sports_bar;
          text = 'Bereit!';
          break;
        case TrichterDeviceStatus.running:
          color = theme.colorScheme.tertiary;
          icon = Icons.timer;
          text = 'Läuft...';
          break;
        case TrichterDeviceStatus.sending:
          color = theme.colorScheme.tertiary;
          icon = Icons.move_to_inbox_rounded;
          text = 'Empfange Daten...';
          break;
        case TrichterDeviceStatus.calibrating:
          color = theme.colorScheme.tertiary;
          icon = Icons.build_rounded;
          text = 'Kalibrieren';
          break;
        case TrichterDeviceStatus.error:
          color = theme.colorScheme.error;
          icon = Icons.warning_amber_rounded;
          text = 'Gerätefehler';
          break;
        default:
          color = theme.colorScheme.outline;
          icon = Icons.question_mark;
          text = 'Unbekannt';
      }
    }

    final bool isTransferringWithProgress =
        data.progress > 0 && data.progress < 1;

    return Container(
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
                value: data.progress,
                strokeWidth: 8,
                color: color,
                backgroundColor: color.withOpacity(0.2),
              ),
            )
          else
            Icon(
              icon,
              size: 80,
              color: color,
            ),
          const SizedBox(height: 20),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (isTransferringWithProgress)
            Text(
              "${(data.progress * 100).toInt()}%",
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 16),
            )
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
// Footer: Dynamische Buttons basierend auf dem Hardware-Status
  // ---------------------------------------------------------------------------
  Widget _buildFooter(BuildContext context, TrichterConnectionState state) {
    // if (state.status != TrichterConnectionStatus.connected) {
    //   return const SizedBox.shrink();
    // }

    final notifier = ref.read(trichterConnectionProvider.notifier);
    // Zum Testen hier hardcoden, später wieder state.deviceStatus nutzen:
    //final status = TrichterDeviceStatus.error;
    final status = state.deviceStatus;

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(16, 0, 16, 32), // Etwas mehr Platz unten
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        // Scale + Fade wirkt moderner und flüssiger
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: _buildButtonsForStatus(context, status, notifier),
      ),
    );
  }

  Widget _buildButtonsForStatus(BuildContext context,
      TrichterDeviceStatus status, TrichterConnectionService notifier) {
    // M3 Style Helper: Macht die Buttons höher (56dp) für bessere Haptik
    final buttonStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );

    // Helper für das Layout
    Widget buildRow({
      required Widget left,
      required Widget right,
      required Key key,
    }) {
      return Row(
        key: key,
        children: [
          Expanded(child: left),
          const SizedBox(width: 16), // 16dp ist Standard M3 Gap
          Expanded(child: right),
        ],
      );
    }

    switch (status) {
      // --- FALL A: IDLE (Energiesparmodus) ---
      case TrichterDeviceStatus.idle:
        return buildRow(
          key: const ValueKey('idle'),
          // Links: Kalibrieren
          left: FilledButton.tonalIcon(
            style: buttonStyle,
            onPressed: () =>
                notifier.requestState(TrichterDeviceStatus.calibrating),
            icon: const Icon(
                Icons.build_rounded), // Tune passt besser zu "Kalibrieren"
            label: const Text("Kalibrieren"),
          ),
          // Rechts: Aufwecken (Hauptaktion)
          right: FilledButton.icon(
            style: buttonStyle,
            onPressed: () => notifier.requestState(TrichterDeviceStatus.ready),
            icon: const Icon(Icons.power_settings_new),
            label: const Text("Aufwecken"),
          ),
        );

      // --- FALL B: CALIBRATE (Einstellen) ---
      case TrichterDeviceStatus.calibrating:
        return buildRow(
          key: const ValueKey('calib'),
          // Links: Abbruch -> Standby
          left: OutlinedButton.icon(
            style: buttonStyle, // Auch Outlined bekommt die Höhe
            onPressed: () => notifier.requestState(TrichterDeviceStatus.idle),
            icon: const Icon(Icons.nights_stay_rounded),
            label: const Text("Standby"),
          ),
          // Rechts: Übernehmen -> Starten
          right: FilledButton.icon(
            style: buttonStyle,
            onPressed: () => notifier.requestState(TrichterDeviceStatus.ready),
            icon: const Icon(Icons.check), // Haken für "Fertig/Übernehmen"
            label: const Text("Fertig"),
          ),
        );

      // --- FALL C: READY (Scharf geschaltet) ---
      case TrichterDeviceStatus.ready:
        return buildRow(
          key: const ValueKey('ready'),
          // Links: Standby
          left: OutlinedButton.icon(
            style: buttonStyle,
            onPressed: () => notifier.requestState(TrichterDeviceStatus.idle),
            icon: const Icon(Icons.nights_stay_rounded),
            label: const Text("Standby"),
          ),
          // Rechts: Kalibrieren
          right: FilledButton.tonalIcon(
            style: buttonStyle,
            onPressed: () =>
                notifier.requestState(TrichterDeviceStatus.calibrating),
            icon: const Icon(Icons.build_rounded),
            label: const Text("Kalibrieren"),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
