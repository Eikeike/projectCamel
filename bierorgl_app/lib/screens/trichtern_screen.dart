import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/bluetooth_service.dart';
import 'session_screen.dart';
import '../services/sync_service.dart';
import '../repositories/auth_repository.dart';

class TrichternScreen extends ConsumerStatefulWidget {
  const TrichternScreen({super.key});

  @override
  ConsumerState<TrichternScreen> createState() => _TrichternScreenState();
}

class _TrichternScreenState extends ConsumerState<TrichternScreen> {
  late final SyncService _syncService;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  double _displayTime = 0.0;
  bool _isMeasuring = false;
  Timer? _connectionCheckTimer;

  @override
  void initState() {
    super.initState();
      final authRepo = AuthRepository();
      _syncService = SyncService(authRepository: authRepo);
      
    // Starte einen Timer, der alle 3 Sekunden den Verbindungsstatus prüft.
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      final device = ref.read(bluetoothServiceProvider).connectedDevice;
      if (device != null) {
        // Prüfe den aktuellen Status des Geräts
        device.connectionState.first.then((currentState) {
          if (currentState == BluetoothConnectionState.disconnected && mounted) {
            // Wenn das Gerät getrennt ist, setze den State in der App zurück.
            ref.read(bluetoothServiceProvider.notifier).forceResetState();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    // Timer stoppen, wenn der Screen verlassen wird.
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
    final isConnected = bluetoothState.connectedDevice != null;

    // Lauscht auf Statusänderungen für die Navigation
    ref.listen(bluetoothServiceProvider, (previous, next) {
      final bool wasJustFinished =
      (previous?.isSessionFinished == false && next.isSessionFinished == true);

      // --- START DER ÄNDERUNG ---
      if (wasJustFinished && next.lastDurationMS > 0) {
        final rawBytes = next.receivedData.last.timeValues;
        final processed =
        _processBytesTo32Bit(rawBytes, next.calibrationFactor ?? 1.0);
        // NEU: calibrationFactor wird explizit geholt
        final calibrationFactor = next.calibrationFactor ?? 1.0;

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionScreen(
                durationMS: next.lastDurationMS,
                allValues: processed,
                // NEU: Übergabe des calibrationFactor
                calibrationFactor: calibrationFactor,
              ),
            ),
          ).then((_) {
            // Dieser Code wird ausgeführt, wenn vom SessionScreen zurücknavigiert wird.
            // Er setzt den Bluetooth-Status zurück, um eine neue Messung zu ermöglichen.
            if (mounted) {
              ref.read(bluetoothServiceProvider.notifier).resetData();
            }
          });
        }
      }
      // --- ENDE DER ÄNDERUNG ---
    });

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _syncService.sync();
        },
        backgroundColor: const Color(0xFFFF9500),
        child: const Icon(Icons.bug_report, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'BIERORGL',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF9500)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isConnected
                        ? 'Bereit zum Ballern!'
                        : 'Trichter nicht verbunden',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // Bluetooth Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, '/bluetooth'),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bluetooth,
                                color: isConnected
                                    ? const Color(0xFF2196F3)
                                    : Colors.grey[400]),
                            const SizedBox(width: 12),
                            Text(isConnected
                                ? 'Verbunden: ${bluetoothState.connectedDevice?.platformName}'
                                : 'Trichter verbinden'),
                          ],
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Zentraler Kreis
            Expanded(
              child: Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: (isConnected
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2)),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                    border: Border.all(
                      color: (isConnected
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFF5252)),
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
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFFF5252),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        bluetoothState.isSessionActive ? 'LÄUFT...' : 'READY',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(30),
              child: Text(
                bluetoothState.isSessionActive
                    ? "Nicht vom Schlauch gehen!"
                    : "Warte auf ersten Schluck...",
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
