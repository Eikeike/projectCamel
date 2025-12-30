import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bluetooth_service.dart';
import 'session_screen.dart';

class TrichternScreen extends ConsumerStatefulWidget {
  const TrichternScreen({super.key});

  @override
  ConsumerState<TrichternScreen> createState() => _TrichternScreenState();
}

class _TrichternScreenState extends ConsumerState<TrichternScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  double _displayTime = 0.0;
  bool _isMeasuring = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Startet den lokalen Timer für die flüssige UI-Anzeige
  void _startLocalTimer() {
    if (_isMeasuring) return;
    setState(() {
      _isMeasuring = true;
      _displayTime = 0.0;
    });
    _stopwatch.reset();
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      setState(() {
        _displayTime = _stopwatch.elapsedMilliseconds / 1000.0;
      });
    });
  }

  /// Stoppt den Timer und setzt den exakten Wert vom ESP32
  void _stopAndFixTimer(int finalMs) {
    _timer?.cancel();
    _stopwatch.stop();
    setState(() {
      _isMeasuring = false;
      _displayTime = finalMs / 1000.0;
    });
  }

  List<int> _processBytesTo32Bit(List<int> bytes, double factor) {
    if (bytes.length < 4) return [];
    List<int> result = [];
    for (int i = 0; i <= bytes.length - 4; i += 4) {
      int ticks = bytes[i] | (bytes[i + 1] << 8) | (bytes[i + 2] << 16) | (bytes[i + 3] << 24);
      int ms = ((ticks * factor) / 1000).round();
      result.add(ms);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothState = ref.watch(bluetoothServiceProvider);
    final isConnected = bluetoothState.connectedDevice != null;

    // Lauscht auf Statusänderungen des Bluetooth Services
    ref.listen(bluetoothServiceProvider, (previous, next) {
      // Trigger: Erste Daten kommen an -> Timer starten
      if (next.receivedData.isNotEmpty &&
          next.receivedData.last.timeValues.isNotEmpty &&
          !_isMeasuring &&
          !next.isSessionFinished) {
        _startLocalTimer();
      }

      // Trigger: End-Sequenz erkannt -> Korrektur und Wechsel
      if (next.isSessionFinished && next.lastDurationMS > 0) {
        _stopAndFixTimer(next.lastDurationMS);

        final rawBytes = next.receivedData.last.timeValues;
        final processed = _processBytesTo32Bit(rawBytes, next.calibrationFactor);

        // Kurze Pause, um den finalen Wert zu bestaunen
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionScreen(
                durationMS: next.lastDurationMS,
                allValues: processed,
              ),
            ),
          ).then((_) {
            // Nach Rückkehr alles auf Null
            ref.read(bluetoothServiceProvider.notifier).resetData();
            setState(() {
              _displayTime = 0.0;
              _stopwatch.reset();
            });
          });
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/test'),
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
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFFF9500)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isConnected ? 'Bereit zum Ballern!' : 'Trichter nicht verbunden',
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bluetooth, color: isConnected ? const Color(0xFF2196F3) : Colors.grey[400]),
                            const SizedBox(width: 12),
                            Text(isConnected ? 'Verbunden: ${bluetoothState.connectedDevice?.platformName}' : 'Trichter verbinden'),
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

            // Zentraler Timer-Kreis
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
                        color: _isMeasuring
                            ? const Color(0xFFFF9500).withOpacity(0.4)
                            : (isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                    border: Border.all(
                      color: _isMeasuring
                          ? const Color(0xFFFF9500)
                          : (isConnected ? const Color(0xFF4CAF50) : const Color(0xFFFF5252)),
                      width: 8,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_isMeasuring && _displayTime == 0) ...[
                        Icon(
                          isConnected ? Icons.sports_bar : Icons.bluetooth_disabled,
                          size: 80,
                          color: isConnected ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'READY',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ] else ...[
                        const Text(
                          "LIVE ZEIT",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey),
                        ),
                        Text(
                          "${_displayTime.toStringAsFixed(2)}s",
                          style: const TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.w900, // Hier w900 statt .black
                            color: Color(0xFFFF9500),
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (bluetoothState.receivedData.isNotEmpty)
                          Text(
                            "${_processBytesTo32Bit(bluetoothState.receivedData.last.timeValues, bluetoothState.calibrationFactor).length} Schlucke",
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(30),
              child: Text(
                _isMeasuring ? "Laufen lassen!" : "Warte auf ersten Schluck...",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}