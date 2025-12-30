import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Repräsentiert die Daten von einem Trichtervorgang
class TrichterData {
  final List<int> timeValues; // Zeitwerte in Millisekunden (jetzt berechnet)
  final DateTime timestamp;
  final int totalTime;

  TrichterData({
    required this.timeValues,
    required this.timestamp,
  }) : totalTime = timeValues.fold(0, (sum, value) => sum + value);

  double get averageTime =>
      timeValues.isEmpty ? 0 : totalTime / timeValues.length;
}

/// Status der Bluetooth-Verbindung
enum BluetoothConnectionStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

/// State für den Bluetooth Service
class TrichterBluetoothState {
  final bool isEnabled;
  final bool isScanning;
  final List<ScanResult> availableDevices;
  final BluetoothDevice? connectedDevice;
  final BluetoothConnectionStatus connectionStatus;
  final List<TrichterData> receivedData;
  final String? error;

  // Kalibrierungsfaktor vom ESP32
  final double calibrationFactor;

  // NEU: Speichert die Bytes 7 & 8 vom 8-Byte Start-Paket
  final List<int> startConfigBytes;

  const TrichterBluetoothState({
    this.isEnabled = false,
    this.isScanning = false,
    this.availableDevices = const [],
    this.connectedDevice,
    this.connectionStatus = BluetoothConnectionStatus.disconnected,
    this.receivedData = const [],
    this.error,
    this.calibrationFactor = 1.0,
    this.startConfigBytes = const [], // Standardmäßig leer
  });

  TrichterBluetoothState copyWith({
    bool? isEnabled,
    bool? isScanning,
    List<ScanResult>? availableDevices,
    BluetoothDevice? connectedDevice,
    BluetoothConnectionStatus? connectionStatus,
    List<TrichterData>? receivedData,
    String? error,
    double? calibrationFactor,
    List<int>? startConfigBytes, // Hinzugefügt für copyWith
  }) {
    return TrichterBluetoothState(
      isEnabled: isEnabled ?? this.isEnabled,
      isScanning: isScanning ?? this.isScanning,
      availableDevices: availableDevices ?? this.availableDevices,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      receivedData: receivedData ?? this.receivedData,
      error: error ?? this.error,
      calibrationFactor: calibrationFactor ?? this.calibrationFactor,
      startConfigBytes: startConfigBytes ?? this.startConfigBytes,
    );
  }

  bool get isConnected =>
      connectionStatus == BluetoothConnectionStatus.connected;
}