import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants.dart';

class TrichterScanState {
  final bool isBluetoothEnabled;
  final bool isScanning;
  final List<ScanResult> discoveredDevices;
  final String? error;

  TrichterScanState({
    this.isBluetoothEnabled = false,
    this.isScanning = false,
    this.discoveredDevices = const [],
    this.error,
  });

  TrichterScanState copyWith({
    bool? isBluetoothEnabled,
    bool? isScanning,
    List<ScanResult>? discoveredDevices,
    String? error,
  }) {
    return TrichterScanState(
      isBluetoothEnabled: isBluetoothEnabled ?? this.isBluetoothEnabled,
      isScanning: isScanning ?? this.isScanning,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      error: error,
    );
  }
}

class TrichterScannerService extends Notifier<TrichterScanState> {
  StreamSubscription? _scanResultsSubscription;
  StreamSubscription? _adapterStateSubscription;

  @override
  TrichterScanState build() {
    // Wenn der Provider entsorgt wird, stoppen wir alles sofort
    ref.onDispose(() {
      _scanResultsSubscription?.cancel();
      _adapterStateSubscription?.cancel();
      // Verhindert, dass die Hardware im Hintergrund weiter scannt
      FlutterBluePlus.stopScan().catchError((_) {});
    });

    _initAdapterState();

    return TrichterScanState(
      isBluetoothEnabled:
          FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on,
    );
  }

  void _initAdapterState() {
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((s) {
      if (ref.mounted) {
        state =
            state.copyWith(isBluetoothEnabled: s == BluetoothAdapterState.on);
      }
    });
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    if (ref.mounted) {
      state = state.copyWith(isScanning: false);
    }
  }

  Future<void> startScan() async {
    if (state.isScanning) return;

    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      if (statuses.values.any((s) => !s.isGranted)) {
        state = state.copyWith(error: "Berechtigungen fehlen");
        return;
      }
    } else if (Platform.isIOS) {
      // On iOS, we check the adapter state rather than manual permission requesting
      // FlutterBluePlus handles the internal Bluetooth permission prompt when startScan is called.
      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState == BluetoothAdapterState.unauthorized) {
        state = state.copyWith(error: "Bluetooth-Berechtigung abgelehnt");
        return;
      }
    }

    state =
        state.copyWith(isScanning: true, discoveredDevices: [], error: null);

    try {
      _scanResultsSubscription?.cancel();
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (ref.mounted) state = state.copyWith(discoveredDevices: results);
      });

      await FlutterBluePlus.startScan(
        withServices: [Guid(BleConstants.serviceUuid)],
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );

      // Listener für das Ende des Scans
      await FlutterBluePlus.isScanning
          .where((scanning) => scanning == false)
          .first;
      if (ref.mounted) state = state.copyWith(isScanning: false);
    } catch (e) {
      if (ref.mounted)
        state = state.copyWith(isScanning: false, error: e.toString());
    }
  }
}

// Hier wird die automatische Entsorgung (Müllabfuhr) definiert
final trichterScanProvider =
    NotifierProvider.autoDispose<TrichterScannerService, TrichterScanState>(() {
  return TrichterScannerService();
});
