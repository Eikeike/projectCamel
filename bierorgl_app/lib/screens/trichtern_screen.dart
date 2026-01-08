import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/trichter_connection_service.dart';
import '../services/trichter_data_handler.dart';
import 'session_screen.dart';
import '../widgets/bluetooth_settings_tile.dart';

class TrichternScreen extends ConsumerStatefulWidget {
  const TrichternScreen({super.key});

  @override
  ConsumerState<TrichternScreen> createState() => _TrichternScreenState();
}

class _TrichternScreenState extends ConsumerState<TrichternScreen> {
  @override
  Widget build(BuildContext context) {
    // 1. Beobachte den Verbindungsstatus & die Daten-Eingänge separat
    // Nutzt Riverpod's Reaktivität statt manueller Timer
    final connection = ref.watch(trichterConnectionProvider);
    final dataState = ref.watch(trichterDataHandlerProvider);

    final bool isConnected =
        connection.status == TrichterConnectionStatus.connected;

    // 2. Navigation-Listener: Reagiert auf das Ende der Übertragung
    // Dies ist ein Side-Effect und gehört sauber in ref.listen
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
                child: _buildStatusCircle(context, isConnected, dataState),
              ),
            ),

            // Footer-Bereich: Dynamische Texte je nach Zustand
            _buildFooter(context, isConnected, dataState),
          ],
        ),
      ),
    );
  }

  // --- UI KOMPONENTEN ---

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

  Widget _buildStatusCircle(
      BuildContext context, bool isConnected, TrichterDataState data) {
    final theme = Theme.of(context);
    // Farbe wechselt zwischen Blau (Connected) und Rot (Disconnected)
    final Color statusColor =
        isConnected ? theme.colorScheme.primary : theme.colorScheme.error;

    // Fortschritt der Datenübertragung berechnen
    final bool isTransferring = data.progress > 0 && data.progress < 1;

    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainer,
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 10,
          ),
        ],
        border: Border.all(color: statusColor, width: 8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isTransferring)
            // Zeigt einen kreisförmigen Fortschritt während die Ticks reinkommen
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: data.progress,
                strokeWidth: 8,
                color: statusColor,
              ),
            )
          else
            Icon(
              isConnected ? Icons.sports_bar : Icons.bluetooth_disabled,
              size: 80,
              color: statusColor,
            ),
          const SizedBox(height: 20),
          Text(
            !isConnected
                ? 'Keine Verbindung'
                : (isTransferring
                    ? '${(data.progress * 100).toInt()}%'
                    : 'Bereit'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
      BuildContext context, bool isConnected, TrichterDataState data) {
    String footerText = "Warte auf ersten Schluck...";
    if (isConnected) {
      if (data.progress > 0) {
        footerText = "Übertrage Messdaten...";
      } else {
        footerText = "Nicht vom Schlauch gehen!";
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 40, left: 30, right: 30),
      child: Text(
        footerText,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ),
    );
  }
}
