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
  bool _needsStateRefresh = true;
  bool _shouldForceReadyOnReturn = false;

  @override
  Widget build(BuildContext context) {
    // --- PROVIDER WATCHERS ---
    // Beobachte den Verbindungsstatus & die Daten-Eingänge separat
    // Nutzt Riverpod's Reaktivität statt manueller Timer
    final connection = ref.watch(trichterConnectionProvider);
    final dataState = ref.watch(trichterDataHandlerProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_needsStateRefresh) {
      _needsStateRefresh = false;

      ref.read(trichterConnectionProvider.notifier)
          .queryCurrentDeviceState();
    }
    
    if (_shouldForceReadyOnReturn) {
      _shouldForceReadyOnReturn = false;
        final notifier = ref.read(trichterConnectionProvider.notifier);
        final state = ref.read(trichterConnectionProvider);

        //Force ready when still in sending
        if (state.deviceStatus == TrichterDeviceStatus.sending ||
            state.deviceStatus == TrichterDeviceStatus.running) {
          notifier.requestState(TrichterDeviceStatus.ready);
        }

    }
    });

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
              _needsStateRefresh = true;
              _shouldForceReadyOnReturn = true;
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
  Widget _buildStatusCircle(
      BuildContext context,
      TrichterConnectionState connState, // <-- ÄNDERUNG: Ganzes State-Objekt
      TrichterDataState data) {
    final theme = Theme.of(context);
    final status = connState.deviceStatus;
    final isConnected = connState.status == TrichterConnectionStatus.connected;

    // --- 1. Farben & Icons & Text basierend auf State definieren ---
    Color color;
    IconData icon;
    String text;
    bool showSpinner = false; // Für "Running" oder "Calibrating" ohne Progress

    if (!isConnected) {
      color = theme.colorScheme.error;
      icon = Icons.bluetooth_disabled;
      text = 'Keine Verbindung';
    } else {
      switch (status) {
        case TrichterDeviceStatus.idle:
          color = Colors.blueGrey;
          icon = Icons.hourglass_empty;
          text = 'Warte auf Setup';
          break;
        case TrichterDeviceStatus.ready:
          color = Colors.green;
          icon = Icons.sports_bar; // Das Bier-Icon!
          text = 'BEREIT!';
          break;
        case TrichterDeviceStatus.running:
          color = Colors.orange;
          icon = Icons.timer;
          text = 'Läuft...';
          showSpinner = true; // Unbestimmte Wartezeit
          break;
        case TrichterDeviceStatus.sending:
          color = Colors.purple;
          icon = Icons.cloud_upload;
          text = 'Empfange Daten...';
          // Spinner wird unten durch den echten Progress-Bar ersetzt,
          // wenn data.progress > 0 ist.
          break;
        case TrichterDeviceStatus.calibrating:
          color = Colors.amber;
          icon = Icons.build;
          text = 'Kalibriert...';
          showSpinner = true;
          break;
        case TrichterDeviceStatus.error:
          color = theme.colorScheme.error;
          icon = Icons.error_outline;
          text = 'Geräte-Fehler';
          break;
        default:
          color = Colors.grey;
          icon = Icons.question_mark;
          text = 'Unbekannt';
      }
    }

// Hat der Data-Handler schon Fortschritt gemeldet? (Überschreibt Spinner)
    final bool isTransferringWithProgress =
        data.progress > 0 && data.progress < 1;

    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            theme.colorScheme.surfaceContainer, // oder surfaceContainerHighest
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3), // Schein in der Status-Farbe
            blurRadius: 25,
            spreadRadius: 5,
          ),
        ],
        border: Border.all(color: color, width: 8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // A: Echter Daten-Fortschritt (Ladekreis mit %)
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
          // B: Unbestimmter Ladekreis (z.B. bei Running/Calibrating)
          else if (showSpinner)
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                color: color,
                strokeWidth: 6,
              ),
            )
          // C: Statisches Icon (Idle, Ready, Error...)
          else
            Icon(
              icon,
              size: 80,
              color: color,
            ),

          const SizedBox(height: 20),

          // Text-Anzeige
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          // Optional: Prozentanzeige als Text drunter
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
    // 1. Wenn nicht verbunden: Nichts oder Platzhalter anzeigen
    if (state.status != TrichterConnectionStatus.connected) {
      // Optional: Ein kleiner Hinweis, falls du den Platz füllen willst
      return const SizedBox(
          height: 120,
          child: Center(
            child: Text(
              "Bitte verbinden, um zu starten",
              style: TextStyle(color: Colors.grey),
            ),
          ));
    }

    final notifier = ref.read(trichterConnectionProvider.notifier);
    final status = state.deviceStatus;

    // Wir nutzen AnimatedSwitcher für schöne Übergänge zwischen den Buttons
    return SizedBox(
      height: 140, // Genug Platz für Buttons
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildButtonsForStatus(context, status, notifier),
      ),
    );
  }

  Widget _buildButtonsForStatus(BuildContext context,
      TrichterDeviceStatus status, TrichterConnectionService notifier) {
    // Key ist wichtig für die Animation des AnimatedSwitcher
    switch (status) {
      // --- FALL A: IDLE (Hauptmenü) ---
      case TrichterDeviceStatus.idle:
        return Column(
          key: const ValueKey('idleButtons'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Die Haupt-Aktion: FETTER BUTTON
            SizedBox(
              width: 250,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () =>
                    notifier.requestState(TrichterDeviceStatus.ready),
                icon: const Icon(Icons.sports_bar, size: 28),
                label: const Text(
                  "SCHARF SCHALTEN",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Signalfarbe
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Die Neben-Aktion: Dezenter Button
            TextButton.icon(
              onPressed: () =>
                  notifier.requestState(TrichterDeviceStatus.calibrating),
              icon: Icon(Icons.build_circle_outlined,
                  size: 16, color: Theme.of(context).colorScheme.outline),
              label: Text(
                "Sensoren kalibrieren",
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
          ],
        );

      // --- FALL B: READY (Abbruch möglich) ---
      case TrichterDeviceStatus.ready:
        return Column(
          key: const ValueKey('readyButtons'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Warte auf Bierfluss...",
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => notifier.requestState(TrichterDeviceStatus.idle),
              icon: const Icon(Icons.close),
              label: const Text("ABBRECHEN"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ],
        );

      // --- FALL C: ERROR (Reset möglich) ---
      case TrichterDeviceStatus.error:
        return Center(
          key: const ValueKey('errorButtons'),
          child: ElevatedButton.icon(
            onPressed: () => notifier.requestState(TrichterDeviceStatus.idle),
            icon: const Icon(Icons.refresh),
            label: const Text("Fehler zurücksetzen"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
          ),
        );

      // --- FALL D: RUNNING / SENDING / CALIBRATING (Keine Interaktion) ---
      default:
        // Hier zeigen wir keine Buttons, da der User warten muss.
        // Der Status-Circle in der Mitte gibt genug Feedback.
        return const SizedBox.shrink(key: ValueKey('empty'));
    }
  }
}
