// 'import 'dart:async';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide BluetoothState;
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../models/trichter_data.dart';
//
// class BluetoothService extends StateNotifier<TrichterBluetoothState> {
//   BluetoothService() : super(TrichterBluetoothState()) {
//     _init();
//   }
//
//   StreamSubscription? _scanSubscription;
//   StreamSubscription? _connectionSubscription;
//   StreamSubscription? _characteristicSubscription;
//
//   Future<void> _init() async {
//     // Bluetooth Status überwachen
//     FlutterBluePlus.adapterState.listen((adapterState) {
//       state = state.copyWith(
//         isEnabled: adapterState == BluetoothAdapterState.on,
//       );
//     });
//
//     // Initial Status checken
//     final adapterState = await FlutterBluePlus.adapterState.first;
//     state = state.copyWith(
//       isEnabled: adapterState == BluetoothAdapterState.on,
//     );
//   }
//
//   /// Bluetooth einschalten (öffnet System-Dialog)
//   Future<void> turnOnBluetooth() async {
//     try {
//       if (await FlutterBluePlus.isSupported == false) {
//         state = state.copyWith(error: 'Bluetooth wird nicht unterstützt');
//         return;
//       }
//
//       await FlutterBluePlus.turnOn();
//     } catch (e) {
//       state = state.copyWith(error: 'Fehler beim Einschalten: $e');
//     }
//   }
//
//   /// Permissions prüfen und anfragen
//   Future<bool> checkPermissions() async {
//     if (await Permission.bluetoothScan.isDenied) {
//       final status = await Permission.bluetoothScan.request();
//       if (!status.isGranted) return false;
//     }
//
//     if (await Permission.bluetoothConnect.isDenied) {
//       final status = await Permission.bluetoothConnect.request();
//       if (!status.isGranted) return false;
//     }
//
//     if (await Permission.location.isDenied) {
//       final status = await Permission.location.request();
//       if (!status.isGranted) return false;
//     }
//
//     return true;
//   }
//
//   /// Startet den Scan nach BLE-Geräten
//   Future<void> startScan() async {
//     if (!state.isEnabled) {
//       state = state.copyWith(error: 'Bluetooth ist ausgeschaltet');
//       return;
//     }
//
//     if (!await checkPermissions()) {
//       state = state.copyWith(error: 'Bluetooth-Berechtigungen fehlen');
//       return;
//     }
//
//     try {
//       state = state.copyWith(isScanning: true, availableDevices: [], error: null);
//
//       // Scan für 5 Sekunden
//       await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
//
//       // Scan-Ergebnisse sammeln
//       _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
//         // Duplikate entfernen basierend auf Device ID
//         final uniqueDevices = <String, ScanResult>{};
//         for (var result in results) {
//           uniqueDevices[result.device.remoteId.toString()] = result;
//         }
//         state = state.copyWith(
//           availableDevices: uniqueDevices.values.toList(),
//         );
//       });
//
//       // Nach 5 Sekunden Scan stoppen
//       await Future.delayed(const Duration(seconds: 5));
//       await stopScan();
//     } catch (e) {
//       state = state.copyWith(
//         isScanning: false,
//         error: 'Scan-Fehler: $e',
//       );
//     }
//   }
//
//   /// Stoppt den Scan
//   Future<void> stopScan() async {
//     await FlutterBluePlus.stopScan();
//     await _scanSubscription?.cancel();
//     state = state.copyWith(isScanning: false);
//   }
//
//   /// Verbindet mit einem Gerät
//   Future<void> connectToDevice(BluetoothDevice device) async {
//     try {
//       state = state.copyWith(
//         connectionStatus: BluetoothConnectionStatus.connecting,
//         error: null,
//       );
//
//       // Verbindung aufbauen
//       await device.connect(timeout: const Duration(seconds: 15));
//
//       // Connection State überwachen
//       _connectionSubscription = device.connectionState.listen((connectionState) {
//         if (connectionState == BluetoothConnectionState.connected) {
//           state = state.copyWith(
//             connectedDevice: device,
//             connectionStatus: BluetoothConnectionStatus.connected,
//           );
//           _discoverServices(device);
//         } else if (connectionState == BluetoothConnectionState.disconnected) {
//           state = state.copyWith(
//             connectedDevice: null,
//             connectionStatus: BluetoothConnectionStatus.disconnected,
//           );
//         }
//       });
//
//     } catch (e) {
//       state = state.copyWith(
//         connectionStatus: BluetoothConnectionStatus.disconnected,
//         error: 'Verbindungsfehler: $e',
//       );
//     }
//   }
//
//   /// Services und Characteristics entdecken
//   Future<void> _discoverServices(BluetoothDevice device) async {
//     try {
//       final services = await device.discoverServices();
//
//       // Hier später: Spezifische Service UUID filtern
//       // Für jetzt: Alle Characteristics mit Notify-Property subscriben
//       for (var service in services) {
//         for (var characteristic in service.characteristics) {
//           if (characteristic.properties.notify) {
//             await _subscribeToCharacteristic(characteristic);
//           }
//         }
//       }
//     } catch (e) {
//       print('Service Discovery Fehler: $e');
//     }
//   }
//
//   /// Subscribe zu einer Characteristic für Datenempfang
//   Future<void> _subscribeToCharacteristic(BluetoothCharacteristic characteristic) async {
//     try {
//       await characteristic.setNotifyValue(true);
//
//       _characteristicSubscription = characteristic.lastValueStream.listen((value) {
//         if (value.isNotEmpty) {
//           _handleReceivedData(value);
//         }
//       });
//     } catch (e) {
//       print('Subscription Fehler: $e');
//     }
//   }
//
//   /// Verarbeitet empfangene Daten vom Trichter
//   void _handleReceivedData(List<int> rawData) {
//     try {
//       // TODO: Hier musst du später das richtige Parsing implementieren
//       // Je nachdem ob 8-bit oder 16-bit Werte
//
//       // Beispiel für 16-bit Werte (2 Bytes pro Wert)
//       List<int> timeValues = [];
//       for (int i = 0; i < rawData.length - 1; i += 2) {
//         // Little-Endian: niedrigstes Byte zuerst
//         int value = rawData[i] | (rawData[i + 1] << 8);
//         timeValues.add(value);
//       }
//
//       final trichterData = TrichterData(
//         timeValues: timeValues,
//         timestamp: DateTime.now(),
//       );
//
//       final updatedData = [...state.receivedData, trichterData];
//       state = state.copyWith(receivedData: updatedData);
//
//       print('Trichter-Daten empfangen: $timeValues');
//       print('Gesamtzeit: ${trichterData.totalTime}ms');
//     } catch (e) {
//       print('Daten-Parsing Fehler: $e');
//     }
//   }
//
//   /// Trennt die Verbindung
//   Future<void> disconnect() async {
//     if (state.connectedDevice == null) return;
//
//     try {
//       state = state.copyWith(
//         connectionStatus: BluetoothConnectionStatus.disconnecting,
//       );
//
//       await _characteristicSubscription?.cancel();
//       await _connectionSubscription?.cancel();
//       await state.connectedDevice!.disconnect();
//
//       state = state.copyWith(
//         connectedDevice: null,
//         connectionStatus: BluetoothConnectionStatus.disconnected,
//       );
//     } catch (e) {
//       state = state.copyWith(error: 'Trennfehler: $e');
//     }
//   }
//
//   @override
//   void dispose() {
//     _scanSubscription?.cancel();
//     _connectionSubscription?.cancel();
//     _characteristicSubscription?.cancel();
//     super.dispose();
//   }
// }
//
// // Provider
// final bluetoothServiceProvider = StateNotifierProvider<BluetoothService, TrichterBluetoothState>((ref) {
//   return BluetoothService();
// });'