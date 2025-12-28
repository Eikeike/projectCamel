import 'package:flutter/material.dart';

class TrichternScreen extends StatefulWidget {
  const TrichternScreen({super.key});

  @override
  State<TrichternScreen> createState() => _TrichternScreenState();
}

class _TrichternScreenState extends State<TrichternScreen> {
  bool isBluetoothEnabled = true;
  bool isConnected = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/test');  // Navigation zum Test-Screen
        },
        backgroundColor: const Color(0xFFFF9500),  // Passt zu deinem Theme
        child: const Icon(Icons.bug_report, color: Colors.white),  // Test-Icon (Käfer für "Debug")
        tooltip: 'DB Test öffnen',  // Tooltip für Accessibility
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header (unverändert)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'BIERORGL',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF9500),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isConnected
                        ? 'Trichter verbunden - Bereit!'
                        : 'Warte auf Trichter-Signal...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Bluetooth Toggle Bar (unverändert)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bluetooth,
                            color: isBluetoothEnabled
                                ? const Color(0xFF2196F3)
                                : Colors.grey[400],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Bluetooth',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isBluetoothEnabled
                                  ? Colors.black87
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: isBluetoothEnabled,
                        onChanged: (value) {
                          setState(() {
                            isBluetoothEnabled = value;
                            if (!value) {
                              isConnected = false;
                            }
                          });
                        },
                        activeColor: const Color(0xFF2196F3),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Main Circle with Beer Icon (unverändert)
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    if (isBluetoothEnabled) {
                      setState(() {
                        isConnected = !isConnected;
                      });
                    }
                  },
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: (isBluetoothEnabled && isConnected)
                              ? const Color(0xFF4CAF50).withOpacity(0.4)
                              : const Color(0xFFFF5252).withOpacity(0.4),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                      border: Border.all(
                        color: (isBluetoothEnabled && isConnected)
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFFF5252),
                        width: 4,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sports_bar,
                          size: 120,
                          color: (isBluetoothEnabled && isConnected)
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF5252),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          (isBluetoothEnabled && isConnected)
                              ? 'VERBUNDEN'
                              : !isBluetoothEnabled
                              ? 'BLUETOOTH AUS'
                              : 'GETRENNT',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: (isBluetoothEnabled && isConnected)
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFFF5252),
                          ),
                        ),
                        if (isBluetoothEnabled && isConnected) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Trichter #001',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Info (unverändert)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isBluetoothEnabled
                            ? 'Tippe auf den Kreis, um die Verbindung zu simulieren.'
                            : 'Aktiviere Bluetooth, um eine Verbindung herzustellen.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[900],
                        ),
                      ),
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