import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

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
  static const String trichterServiceUuid =
      "af56d6dd-3c39-4d67-9bbe-4fb04fa327cc";
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

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses.values.any((s) => !s.isGranted)) {
      state = state.copyWith(error: "Berechtigungen fehlen");
      return;
    }

    state =
        state.copyWith(isScanning: true, discoveredDevices: [], error: null);

    try {
      _scanResultsSubscription?.cancel();
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (ref.mounted) state = state.copyWith(discoveredDevices: results);
      });

      await FlutterBluePlus.startScan(
        withServices: [Guid(trichterServiceUuid)],
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
