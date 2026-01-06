import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/bluetooth_service.dart';
import 'session_screen.dart';
import '../services/sync_service.dart';
import '../repositories/auth_repository.dart';
import '../widgets/bluetooth_settings_tile.dart';

class TrichternScreen extends ConsumerStatefulWidget {
  const TrichternScreen({super.key});

  @override
  ConsumerState<TrichternScreen> createState() => _TrichternScreenState();
}

class _TrichternScreenState extends ConsumerState<TrichternScreen> {
  late final SyncService _syncService;
  Timer? _connectionCheckTimer;

  @override
  void initState() {
    super.initState();
    final authRepo = AuthRepository();
    _syncService = SyncService(authRepository: authRepo);

    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      final device = ref.read(bluetoothServiceProvider).connectedDevice;
      if (device != null) {
        device.connectionState.first.then((currentState) {
          if (currentState == BluetoothConnectionState.disconnected &&
              mounted) {
            ref.read(bluetoothServiceProvider.notifier).forceResetState();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    super.dispose();
  }

  List<int> _processBytesTo32Bit(List<int> bytes, double factor) {
    if (bytes.length < 4) return [];
    List<int> result = [];
    for (int i = 0; i <= bytes.length - 4; i += 4) {
      int ticks = bytes[i] |
          (bytes[i + 1] << 8) |
          (bytes[i + 2] << 16) |
          (bytes[i + 3] << 24);
      int ms = ((ticks * factor) ~/ 1000);
      result.add(ms);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothState = ref.watch(bluetoothServiceProvider);
    //final isConnected = bluetoothState.connectedDevice != null;
    final isConnected = true;

    ref.listen(bluetoothServiceProvider, (previous, next) {
      final bool wasJustFinished = (previous?.isSessionFinished == false &&
          next.isSessionFinished == true);

      if (wasJustFinished && next.lastDurationMS > 0) {
        final rawBytes = next.receivedData.last.timeValues;
        final timeCalibrationFactor = next.calibrationFactor ?? 1.0;
        final processed = _processBytesTo32Bit(rawBytes, timeCalibrationFactor);
        final volumeCalibrationFactor = next.volumeCalibrationFactor;

        // ### NEU: Berechne das Volumen direkt hier ###
        int? calculatedVolumeML;
        if (volumeCalibrationFactor != null && volumeCalibrationFactor > 0) {
          final double calculatedVolume =
              (processed.length / (2 * volumeCalibrationFactor)) * 1000;
          calculatedVolumeML = calculatedVolume.round();
        }

        if (mounted) {
          print("DEBUG_ML (trichtern_screen): Navigiere zu SessionScreen mit:");
          print("  -> durationMS: ${next.lastDurationMS}");
          print("  -> allValues (Anzahl): ${processed.length}");
          print("  -> timeCalibrationFactor: $timeCalibrationFactor");
          print(
              "  -> KORREKT übergebener volumeCalibrationFactor: $volumeCalibrationFactor");
          print("  -> Berechnetes Volumen: $calculatedVolumeML ml");

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionScreen(
                durationMS: next.lastDurationMS,
                allValues: processed,
                calibrationFactor: volumeCalibrationFactor?.toDouble(),
                // ### NEU: Gib das berechnete Volumen weiter ###
                calculatedVolumeML: calculatedVolumeML,
              ),
            ),
          ).then((_) {
            if (mounted) {
              ref.read(bluetoothServiceProvider.notifier).resetData();
            }
          });
        }
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- OBERER BEREICH (Bleibt oben) ---
            Padding(
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
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                ],
              ),
            ),

            // Bluetooth-Schaltfläche (Direkt unter dem Header)
            const BluetoothSettingsTile(),
            // --- MITTLERER BEREICH (Nimmt den restlichen Platz ein und zentriert den Kreis) ---
            Expanded(
              child: Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    boxShadow: [
                      BoxShadow(
                        color: (isConnected
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2)
                            : Theme.of(context)
                                .colorScheme
                                .error
                                .withOpacity(0.2)),
                        blurRadius: 20,
                        spreadRadius: 10,
                      ),
                    ],
                    border: Border.all(
                      color: (isConnected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error),
                      width: 8,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isConnected
                            ? Icons.sports_bar
                            : Icons.bluetooth_disabled,
                        size: 80,
                        color: isConnected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        bluetoothState.isSessionActive
                            ? 'Bereit'
                            : 'Keine Verbindung',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- UNTERER BEREICH (Footer Text) ---
            Padding(
              padding: const EdgeInsets.only(bottom: 40, left: 30, right: 30),
              child: Text(
                bluetoothState.isSessionActive
                    ? "Nicht vom Schlauch gehen!"
                    : "Warte auf ersten Schluck...",
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
