import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide BluetoothState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trichter_data.dart';

class BluetoothService extends Notifier<TrichterBluetoothState> {
  static const String trichterServiceUuid = "af56d6dd-3c39-4d67-9bbe-4fb04fa327cc";
  static const String sessionCharacteristicUuid = "f9d76937-bd70-4e4f-a4da-0b718d5f5b6d";
  static const String calibrationCharacteristicUuid = "23de2cad-0fc8-49f4-bbcc-5eb2c9fdb91b";

  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _characteristicSubscription;

  @override
  TrichterBluetoothState build() {
    ref.onDispose(() {
      _scanSubscription?.cancel();
      _connectionSubscription?.cancel();
      _characteristicSubscription?.cancel();
    });

    Future.microtask(() => _init());
    return const TrichterBluetoothState();
  }

  void resetData() {
    state = state.copyWith(receivedData: []);
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

            // 1. Kalibrierungswert einmalig lesen
            if (charUuid == calibrationCharacteristicUuid) {
              List<int> value = await characteristic.read();
                int factorInt = value[0];
                state = state.copyWith(calibrationFactor: factorInt.toDouble());
                print("DEBUG: Calibration Factor empfangen: ${state.calibrationFactor}");
            }

            // 2. Session Notification einrichten
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
      );
      return;
    }

    // 2. END-PAKET (4 Bytes)
    if (_isEndSequence(rawData)) {
      final rawBytePool = state.receivedData.isNotEmpty
          ? state.receivedData.last.timeValues
          : <int>[];

      // WICHTIG: Wir lassen den rawBytePool im State, wie er ist!
      // Die Berechnung machen wir hier nur für die Konsole:
      List<int> ticks = _parseTo32Bit(rawBytePool);
      List<int> msValues = ticks.map((t) => ((t * state.calibrationFactor) / 1000).round()).toList();

      print("=======================================");
      print("FINALE WERTE IN MILLISEKUNDEN:");
      print(msValues);
      print("=======================================");

      // Wir aktualisieren den State NICHT mit den msValues,
      // sondern behalten die Bytes, damit dein Screen-Parser funktioniert.
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

  /// Hilfsfunktion zum Prüfen der End-Sequenz
  /// Erwartet das Muster [204, 0, 0, 0] (0xCC in Dezimal ist 204)
  bool _isEndSequence(List<int> data) {
    // Das End-Paket muss exakt 4 Bytes lang sein
    if (data.length != 4) return false;

    // Prüfung auf 0xCC 0x00 0x00 0x00
    return data[0] == 0xCC &&
        data[1] == 0x00 &&
        data[2] == 0x00 &&
        data[3] == 0x00;
  }
}

final bluetoothServiceProvider = NotifierProvider<BluetoothService, TrichterBluetoothState>(() => BluetoothService());