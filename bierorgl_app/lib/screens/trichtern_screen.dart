import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bluetooth_service.dart';
import '../models/trichter_data.dart';

class TrichternScreen extends ConsumerStatefulWidget {
  const TrichternScreen({super.key});

  @override
  ConsumerState<TrichternScreen> createState() => _TrichternScreenState();
}

class _TrichternScreenState extends ConsumerState<TrichternScreen> {

  // Hilfsfunktion: Wandelt Byte-Liste in 32-Bit Integer um (Anforderung: 4er Verbund)
  List<int> _processBytesTo32Bit(List<int> bytes) {
    if (bytes.length < 4) return [];
    List<int> result = [];
    final factor = ref.read(bluetoothServiceProvider).calibrationFactor; // Faktor holen

    for (int i = 0; i <= bytes.length - 4; i += 4) {
      // 1. Rohwert (Ticks) berechnen
      int ticks = bytes[i] | (bytes[i + 1] << 8) | (bytes[i + 2] << 16) | (bytes[i + 3] << 24);

      // 2. Sofort in Millisekunden umrechnen
      int ms = ((ticks * factor) / 1000).round();
      result.add(ms);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothState = ref.watch(bluetoothServiceProvider);
    final isConnected = bluetoothState.connectedDevice != null;

    // Roh-Bytes aus dem State holen (Anforderung: Einzelwert Array)
    final rawBytes = bluetoothState.receivedData.isNotEmpty
        ? bluetoothState.receivedData.last.timeValues
        : <int>[];

    // Bytes zu 32-Bit Dezimalzahlen verarbeiten (Anforderung: 4er Verbund Array)
    final processedValues = _processBytesTo32Bit(rawBytes);

    // --- DEBUG AUSGABE IN DIE KONSOLE ---
    if (rawBytes.isNotEmpty) {
      print("--- [SCREEN] DATEN-UPDATE ---");
      print("EINZELWERT ARRAY (BYTES): $rawBytes");
      print("4er VERBUND ARRAY (32-BIT): $processedValues");
    }

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
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('BIERORGL', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFFF9500))),
                  const SizedBox(height: 8),
                  Text(isConnected ? 'Trichter verbunden - Bereit!' : 'Warte auf Signal...',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600])),
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
                            Text(isConnected ? 'Gerät: ${bluetoothState.connectedDevice?.platformName}' : 'Trichter wählen'),
                          ],
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Verarbeitete Daten Box (Anzeige der 32-Bit Werte)
            if (processedValues.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("MESSWERTE (DEZIMAL)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                        TextButton(
                          onPressed: () => ref.read(bluetoothServiceProvider.notifier).resetData(),
                          child: const Text("Löschen", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      height: 100,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.3)),
                      ),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: processedValues.map((val) => Chip(
                            label: Text(val.toString(), style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.orange.shade50,
                            visualDensity: VisualDensity.compact,
                          )).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Main Circle
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: () { if (!isConnected) Navigator.pushNamed(context, '/bluetooth'); },
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: isConnected ? const Color(0xFF4CAF50).withOpacity(0.3) : const Color(0xFFFF5252).withOpacity(0.3),
                          blurRadius: 30, spreadRadius: 5,
                        ),
                      ],
                      border: Border.all(color: isConnected ? const Color(0xFF4CAF50) : const Color(0xFFFF5252), width: 4),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isConnected ? Icons.sports_bar : Icons.bluetooth_disabled,
                            size: 80, color: isConnected ? const Color(0xFF4CAF50) : const Color(0xFFFF5252)),
                        const SizedBox(height: 10),
                        if (isConnected && processedValues.isNotEmpty)
                          Text(
                              "${processedValues.length}",
                              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Color(0xFF4CAF50))
                          )
                        else
                          Text(isConnected ? 'READY' : 'OFFLINE', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text("MESSUNGEN", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(isConnected ? Icons.bolt : Icons.info_outline, color: isConnected ? Colors.green : Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            isConnected
                                ? '32-Bit Parsing aktiv. ${processedValues.length} Werte erkannt.'
                                : 'Verbinde den Trichter über das Menü oben.'
                        )
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}