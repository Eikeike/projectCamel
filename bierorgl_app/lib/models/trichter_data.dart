import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide BluetoothState;

/// Repräsentiert die Daten von einem Trichtervorgang
class TrichterData {
  final List<int> timeValues; // Zeitwerte in Millisekunden
  final DateTime timestamp;
  final int totalTime; // Berechnete Gesamtzeit

  TrichterData({
    required this.timeValues,
    required this.timestamp,
  }) : totalTime = timeValues.fold(0, (sum, value) => sum + value);

  /// Berechnet die Durchschnittszeit
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

  /// ✅ RICHTIGER Konstruktor (Name = Klassenname)
  const TrichterBluetoothState({
    this.isEnabled = false,
    this.isScanning = false,
    this.availableDevices = const [],
    this.connectedDevice,
    this.connectionStatus = BluetoothConnectionStatus.disconnected,
    this.receivedData = const [],
    this.error,
  });

  TrichterBluetoothState copyWith({
    bool? isEnabled,
    bool? isScanning,
    List<ScanResult>? availableDevices,
    BluetoothDevice? connectedDevice,
    BluetoothConnectionStatus? connectionStatus,
    List<TrichterData>? receivedData,
    String? error,
  }) {
    return TrichterBluetoothState(
      isEnabled: isEnabled ?? this.isEnabled,
      isScanning: isScanning ?? this.isScanning,
      availableDevices: availableDevices ?? this.availableDevices,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      receivedData: receivedData ?? this.receivedData,
      error: error ?? this.error,
    );
  }

  bool get isConnected =>
      connectionStatus == BluetoothConnectionStatus.connected;
}
