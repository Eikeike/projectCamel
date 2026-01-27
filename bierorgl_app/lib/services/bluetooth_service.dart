import 'dart:async';
import 'dart:io';
import 'dart:typed_data'; // Benötigt für ByteData
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide BluetoothState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trichter_data.dart';

// Stand: Die Version, mit der du dich verbinden konntest.
class TrichterBluetoothStateExtended extends TrichterBluetoothState {
  final bool isSessionFinished;
  final int lastDurationMS;
  final bool isSessionActive;
  final int? volumeCalibrationFactor; // NEU: Für den Faktor aus dem Start-Array

  const TrichterBluetoothStateExtended({
    super.isEnabled,
    super.isScanning,
    super.availableDevices,
    super.connectedDevice,
    super.connectionStatus,
    super.receivedData,
    super.error,
    super.calibrationFactor, // Das ist der 'Time' Faktor
    super.startConfigBytes,
    this.isSessionFinished = false,
    this.lastDurationMS = 0,
    this.isSessionActive = false,
    this.volumeCalibrationFactor, // NEU
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
    bool? isSessionActive,
    int? volumeCalibrationFactor, // NEU
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
      isSessionFinished: isSessionFinished ?? this.isSessionFinished,
      lastDurationMS: lastDurationMS ?? this.lastDurationMS,
      isSessionActive: isSessionActive ?? this.isSessionActive,
      volumeCalibrationFactor:
          volumeCalibrationFactor ?? this.volumeCalibrationFactor, // NEU
    );
  }
}

class BluetoothService extends Notifier<TrichterBluetoothStateExtended> {
  static const String trichterServiceUuid =
      "af56d6dd-3c39-4d67-9bbe-4fb04fa327cc";
  static const String sessionCharacteristicUuid =
      "f9d76937-bd70-4e4f-a4da-0b718d5f5b6d";
  static const String calibrationCharacteristicUuid =
      "23de2cad-0fc8-49f4-bbcc-5eb2c9fdb91b";

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
    state = state.copyWith(
      receivedData: [],
      isSessionFinished: false,
      isSessionActive: false,
      volumeCalibrationFactor: null, // Auch den neuen Faktor zurücksetzen
    );
  }

  void forceResetState() {
    state = const TrichterBluetoothStateExtended();
  }

  Future<void> _init() async {
    FlutterBluePlus.adapterState.listen((adapterState) {
      state =
          state.copyWith(isEnabled: adapterState == BluetoothAdapterState.on);
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
    state =
        state.copyWith(connectionStatus: BluetoothConnectionStatus.connecting);

    try {
      await FlutterBluePlus.stopScan(); // important on iOS

      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
        license: License.free,
      );

      state = state.copyWith(
        connectedDevice: device,
        connectionStatus: BluetoothConnectionStatus.connected,
      );

      await _setupSessionNotifications(device);
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        connectionStatus: BluetoothConnectionStatus.disconnected,
      );
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
                // DAS IST DER "calibrationFactorTime"
                print(
                    "DEBUG_ML (bluetooth_service): 'calibrationFactorTime' vom Gerät gelesen: ${value[0].toDouble()}");
                state = state.copyWith(calibrationFactor: value[0].toDouble());
              }
            }
            if (charUuid == sessionCharacteristicUuid) {
              await characteristic.setNotifyValue(true);
              _characteristicSubscription?.cancel();
              _characteristicSubscription = characteristic.lastValueStream
                  .listen((v) => _handleReceivedData(v));
            }
          }
        }
      }
    } catch (e) {
      print("DEBUG: Fehler beim Setup: $e");
    }
  }

  void _handleReceivedData(List<int> rawData) {
    if (rawData.isEmpty) return;

    bool isFirstPacket = state.receivedData.isEmpty ||
        (state.receivedData.last.timeValues.isEmpty);

    if (isFirstPacket && rawData.length == 8) {
      String hexString = rawData
          .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');

      // KORREKTUR: Bytes 6 und 7 als LITTLE-ENDIAN Uint16 interpretieren
      var byteData =
          ByteData.sublistView(Uint8List.fromList(rawData.sublist(6, 8)));
      int volumeFactor =
          byteData.getUint16(0, Endian.little); // <-- ZURÜCK ZU LITTLE

      print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
      print(
          "DEBUG_ML (bluetooth_service): ERSTES DATENPAKET (START-ARRAY) EMPFANGEN.");
      print("  -> Inhalt als HEX: $hexString");
      print("  -> Inhalt als DEZIMAL: $rawData");
      print(
          "  -> Die letzten beiden Bytes [${rawData[6]}, ${rawData[7]}] werden als Little-Endian Uint16 interpretiert.");
      print("  -> Extrahierter 'volumeCalibrationFactor': $volumeFactor");
      print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");

      state = state.copyWith(
        startConfigBytes: [rawData[6], rawData[7]],
        volumeCalibrationFactor: volumeFactor,
        receivedData: [TrichterData(timeValues: [], timestamp: DateTime.now())],
        isSessionFinished: false,
      );
      return;
    }

    if (_isEndSequence(rawData)) {
      final rawBytePool = state.receivedData.isNotEmpty
          ? state.receivedData.last.timeValues
          : <int>[];
      List<int> ticks = _parseTo32Bit(rawBytePool);

      if (ticks.isNotEmpty) {
        // --- DEBUG-PRINT FÜR ZEIT-ARRAY WIEDER HINZUGEFÜGT ---
        print("--------------------------------------------------------------");
        print("DEBUG_ML (bluetooth_service): Umrechnung der Zeit-Werte...");

        // NEU: Debug-Ausgabe für die rohen Tick-Werte
        List<int> rawTicksFirst = ticks.take(20).toList();
        List<int> rawTicksLast =
            ticks.skip(ticks.length > 20 ? ticks.length - 20 : 0).toList();
        print("  -> Erste 20 rohe Tick-Werte (DEZ): $rawTicksFirst");
        print("  -> Letzte 20 rohe Tick-Werte (DEZ): $rawTicksLast");

        List<int> msValues = ticks
            .map((t) => ((t * (state.calibrationFactor ?? 1.0)) / 1000).round())
            .toList();
        int finalDuration = msValues.isNotEmpty ? msValues.last : 0;

        // Millisekunden in DEZIMAL ausgeben
        List<int> msValuesFirst = msValues.take(10).toList();
        List<int> msValuesLast = msValues
            .skip(msValues.length > 10 ? msValues.length - 10 : 0)
            .toList();
        print("  -> Erste 10 ms-Werte (DEZ): $msValuesFirst");
        print("  -> Letzte 10 ms-Werte (DEZ): $msValuesLast");
        print("--------------------------------------------------------------");

        state = state.copyWith(
          isSessionFinished: true,
          lastDurationMS: finalDuration,
          isSessionActive: true,
        );
      } else {
        state = state.copyWith(
          isSessionFinished: true,
          lastDurationMS: 0,
          isSessionActive: true,
        );
      }
      return;
    }

    List<int> currentPool = state.receivedData.isNotEmpty
        ? List<int>.from(state.receivedData.last.timeValues)
        : [];
    currentPool.addAll(rawData);

    state = state.copyWith(receivedData: [
      TrichterData(timeValues: currentPool, timestamp: DateTime.now())
    ]);
  }

  List<int> _parseTo32Bit(List<int> bytes) {
    List<int> result = [];
    for (int i = 0; i <= bytes.length - 4; i += 4) {
      int value = bytes[i] |
          (bytes[i + 1] << 8) |
          (bytes[i + 2] << 16) |
          (bytes[i + 3] << 24);
      result.add(value);
    }
    return result;
  }

  bool _isEndSequence(List<int> data) {
    return data.length == 4 &&
        data[0] == 0xCC &&
        data[1] == 0x00 &&
        data[2] == 0x00 &&
        data[3] == 0x00;
  }
}

final bluetoothServiceProvider =
    NotifierProvider<BluetoothService, TrichterBluetoothStateExtended>(
        () => BluetoothService());
