import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide BluetoothState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trichter_data.dart';

// Erweiterung des States um ein Flag für die UI-Steuerung
class TrichterBluetoothStateExtended extends TrichterBluetoothState {
  final bool isSessionFinished;
  final int lastDurationMS;

  const TrichterBluetoothStateExtended({
    super.isEnabled,
    super.isScanning,
    super.availableDevices,
    super.connectedDevice,
    super.connectionStatus,
    super.receivedData,
    super.error,
    super.calibrationFactor,
    super.startConfigBytes,
    this.isSessionFinished = false,
    this.lastDurationMS = 0,
  });

  @override
  TrichterBluetoothStateExtended copyWith({
    bool? isEnabled,
    bool? isScanning,
    List<ScanResult>? availableDevices,
    BluetoothDevice? connectedDevice,
    BluetoothConnectionStatus? connectionStatus,
    List<TrichterData>? receivedData,
    String? error,
    double? calibrationFactor,
    List<int>? startConfigBytes,
    bool? isSessionFinished,
    int? lastDurationMS,
  }) {
    return TrichterBluetoothStateExtended(
      isEnabled: isEnabled ?? this.isEnabled,
      isScanning: isScanning ?? this.isScanning,
      availableDevices: availableDevices ?? this.availableDevices,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      receivedData: receivedData ?? this.receivedData,
      error: error ?? this.error,
      calibrationFactor: calibrationFactor ?? this.calibrationFactor,
      startConfigBytes: startConfigBytes ?? this.startConfigBytes,
      isSessionFinished: isSessionFinished ?? false, // Resetet sich normalerweise
      lastDurationMS: lastDurationMS ?? this.lastDurationMS,
    );
  }
}

class BluetoothService extends Notifier<TrichterBluetoothStateExtended> {
  static const String trichterServiceUuid = "af56d6dd-3c39-4d67-9bbe-4fb04fa327cc";
  static const String sessionCharacteristicUuid = "f9d76937-bd70-4e4f-a4da-0b718d5f5b6d";
  static const String calibrationCharacteristicUuid = "23de2cad-0fc8-49f4-bbcc-5eb2c9fdb91b";

  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _characteristicSubscription;

  @override
  TrichterBluetoothStateExtended build() {
    ref.onDispose(() {
      _scanSubscription?.cancel();
      _connectionSubscription?.cancel();
      _characteristicSubscription?.cancel();
    });

    Future.microtask(() => _init());
    return const TrichterBluetoothStateExtended();
  }

  void resetData() {
    state = state.copyWith(receivedData: [], isSessionFinished: false);
  }

  Future<void> _init() async {
    FlutterBluePlus.adapterState.listen((adapterState) {
      state = state.copyWith(
        isEnabled: adapterState == BluetoothAdapterState.on,
      );
    });
  }

  Future<void> turnOnBluetooth() async {
    try {
      if (Platform.isAndroid) await FlutterBluePlus.turnOn();
    } catch (e) {
      state = state.copyWith(error: 'Bluetooth Fehler: $e');
    }
  }

  Future<void> startScan() async {
    if (!state.isEnabled) return;
    state = state.copyWith(isScanning: true, availableDevices: [], error: null);
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [Guid(trichterServiceUuid)],
        androidUsesFineLocation: true,
      );
      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        state = state.copyWith(availableDevices: results);
      });
      await Future.delayed(const Duration(seconds: 10));
      state = state.copyWith(isScanning: false);
    } catch (e) {
      state = state.copyWith(isScanning: false, error: e.toString());
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    state = state.copyWith(connectionStatus: BluetoothConnectionStatus.connecting);
    try {
      await device.connect(timeout: const Duration(seconds: 15), autoConnect: false, license: License.free);
      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((connectionState) {
        if (connectionState == BluetoothConnectionState.connected) {
          state = state.copyWith(connectedDevice: device, connectionStatus: BluetoothConnectionStatus.connected);
          _setupSessionNotifications(device);
        } else {
          state = state.copyWith(connectedDevice: null, connectionStatus: BluetoothConnectionStatus.disconnected);
        }
      });
    } catch (e) {
      state = state.copyWith(error: e.toString(), connectionStatus: BluetoothConnectionStatus.disconnected);
    }
  }

  Future<void> _setupSessionNotifications(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == trichterServiceUuid) {
          for (var characteristic in service.characteristics) {
            String charUuid = characteristic.uuid.toString().toLowerCase();

            if (charUuid == calibrationCharacteristicUuid) {
              List<int> value = await characteristic.read();
              if (value.isNotEmpty) {
                state = state.copyWith(calibrationFactor: value[0].toDouble());
              }
            }

            if (charUuid == sessionCharacteristicUuid) {
              await characteristic.setNotifyValue(true);
              _characteristicSubscription?.cancel();
              _characteristicSubscription = characteristic.lastValueStream.listen((v) => _handleReceivedData(v));
            }
          }
        }
      }
    } catch (e) { print("DEBUG: Fehler beim Setup: $e"); }
  }

  void _handleReceivedData(List<int> rawData) {
    if (rawData.isEmpty) return;

    // 1. START-PAKET (8 Bytes)
    bool isFirstPacket = state.receivedData.isEmpty || (state.receivedData.last.timeValues.isEmpty);
    if (isFirstPacket && rawData.length == 8) {
      state = state.copyWith(
        startConfigBytes: [rawData[6], rawData[7]],
        receivedData: [TrichterData(timeValues: [], timestamp: DateTime.now())],
        isSessionFinished: false,
      );
      return;
    }

    // 2. END-PAKET (4 Bytes)
    if (_isEndSequence(rawData)) {
      final rawBytePool = state.receivedData.isNotEmpty ? state.receivedData.last.timeValues : <int>[];
      List<int> ticks = _parseTo32Bit(rawBytePool);
      List<int> msValues = ticks.map((t) => ((t * state.calibrationFactor) / 1000).round()).toList();

      int finalDuration = msValues.isNotEmpty ? msValues.last : 0;

      state = state.copyWith(
        isSessionFinished: true,
        lastDurationMS: finalDuration,
      );
      return;
    }

    // 3. DATEN SAMMELN
    List<int> currentPool = state.receivedData.isNotEmpty
        ? List<int>.from(state.receivedData.last.timeValues)
        : [];

    if (rawData.length > 4) {
      currentPool.addAll(rawData.sublist(4));
    } else {
      currentPool.addAll(rawData);
    }

    state = state.copyWith(receivedData: [
      TrichterData(timeValues: currentPool, timestamp: DateTime.now())
    ]);
  }

  List<int> _parseTo32Bit(List<int> bytes) {
    List<int> result = [];
    for (int i = 0; i <= bytes.length - 4; i += 4) {
      int value = bytes[i] | (bytes[i + 1] << 8) | (bytes[i + 2] << 16) | (bytes[i + 3] << 24);
      result.add(value);
    }
    return result;
  }

  bool _isEndSequence(List<int> data) {
    return data.length == 4 && data[0] == 0xCC && data[1] == 0x00 && data[2] == 0x00 && data[3] == 0x00;
  }
}

final bluetoothServiceProvider = NotifierProvider<BluetoothService, TrichterBluetoothStateExtended>(() => BluetoothService());