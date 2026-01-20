import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';

// ==========================================
// STATE DEFINITIONS
// ==========================================

/// Status der Bluetooth-Verbindung (Physisch)
enum TrichterConnectionStatus { disconnected, connecting, connected, error }

/// Logischer Status des Geräts (Fachlich)
enum TrichterDeviceStatus {
  unknown,
  idle, // 0x00
  ready, // 0x01
  running, // 0x02
  sending, // 0x03
  calibrating, // 0x04
  error // 0x05
}

class TrichterConnectionState {
  final BluetoothDevice? connectedDevice;
  final TrichterConnectionStatus status;
  final TrichterDeviceStatus deviceStatus;
  final String? error;
  final String? firmwareVersion;

  TrichterConnectionState({
    this.connectedDevice,
    this.status = TrichterConnectionStatus.disconnected,
    this.deviceStatus = TrichterDeviceStatus.unknown,
    this.error,
    this.firmwareVersion,
  });

  TrichterConnectionState copyWith({
    BluetoothDevice? connectedDevice,
    TrichterConnectionStatus? status,
    TrichterDeviceStatus? deviceStatus,
    String? error,
    String? firmwareVersion,
  }) {
    return TrichterConnectionState(
      connectedDevice: connectedDevice ?? this.connectedDevice,
      status: status ?? this.status,
      deviceStatus: deviceStatus ?? this.deviceStatus,
      error: error,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
    );
  }
}

// ==========================================
// SERVICE IMPLEMENTATION
// ==========================================

class TrichterConnectionService extends Notifier<TrichterConnectionState> {
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _statusSubscription;
  BluetoothCharacteristic? _statusCharacteristic;

  bool _stateMachineInitialized = false;

  @override
  TrichterConnectionState build() {
    ref.keepAlive();
    ref.onDispose(() {
      _connectionStateSubscription?.cancel();
      _statusSubscription?.cancel();
    });
    return TrichterConnectionState();
  }

  Future<String?> _readFirmwareVersion(BluetoothDevice device) async {
  try {
    List<BluetoothService> services = await device.discoverServices();
    
    final deviceInfoService = services.firstWhere(
      (s) => s.uuid.toString().toLowerCase() == BleConstants.deviceInfoServiceUuid,
      orElse: () => throw Exception('Device Information Service nicht gefunden'),
    );

    final firmwareCharacteristic = deviceInfoService.characteristics.firstWhere(
      (c) => c.uuid.toString().toLowerCase() == BleConstants.firmwareRevisionUuid,
      orElse: () => throw Exception('Firmware Revision Characteristic nicht gefunden'),
    );

    // Read the firmware version
    final value = await firmwareCharacteristic.read();
    final version = String.fromCharCodes(value).trim();
    
    return version;

  } catch (e) {
    // Non-fatal: just log the error, don't break the connection
    if (ref.mounted) {
      state = state.copyWith(
        error: "Firmware-Version konnte nicht gelesen werden: $e",
      );
    }
    return null;
  }
}

  /// Startet den Verbindungsaufbau
  Future<void> connect(BluetoothDevice device) async {
    if (state.status == TrichterConnectionStatus.connecting ||
        state.status == TrichterConnectionStatus.connected) return;

    state = state.copyWith(
        status: TrichterConnectionStatus.connecting, error: null);

    try {
      // 1. Physisch verbinden
      await device.connect(
          timeout: const Duration(seconds: 10),
          autoConnect: false,
          license: License.free);

      if (!ref.mounted) return;

      // 2. Listener für Disconnects
      _connectionStateSubscription?.cancel();
      _connectionStateSubscription =
          device.connectionState.listen((connectionStatus) {
        if (connectionStatus == BluetoothConnectionState.disconnected) {
          _handleDisconnect();
        }
      });

      // 3. Setup State Machine (Services & Characteristics)
      await _setupStateMachine(device);

      // 4. READ FIRMWARE VERSION
      final String? version = await _readFirmwareVersion(device);

      state = state.copyWith(
        connectedDevice: device,
        status: TrichterConnectionStatus.connected,
        firmwareVersion: version
      );
    } catch (e) {
      state = state.copyWith(
        status: TrichterConnectionStatus.error,
        error: "Verbindung fehlgeschlagen: $e",
      );
      // Clean disconnect attempt
      try {
        await device.disconnect();
      } catch (_) {}
    }
  }


  /// Scans for a specific device ID and connects to it.
  /// Used for seamless reconnection after a firmware update.
  Future<void> connectById(String deviceId) async {
    // 1. Check if we are already doing something
    if (state.status == TrichterConnectionStatus.connecting ||
        state.status == TrichterConnectionStatus.connected) return;

    state = state.copyWith(
        status: TrichterConnectionStatus.connecting, 
        error: "Suche Trichter..."
    );

    try {
      BluetoothDevice? targetDevice;

      // 2. Start scanning
      // We look for the device in the results
      var subscription = FlutterBluePlus.onScanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.remoteId.toString() == deviceId) {
            targetDevice = r.device;
            FlutterBluePlus.stopScan(); // Found it, stop scanning
          }
        }
      });

      // Start the physical scan
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      
      // Wait for scan to finish or device to be found
      await FlutterBluePlus.isScanning.where((scanning) => scanning == false).first;
      await subscription.cancel();

      if (targetDevice != null) {
        // 3. Reuse your existing connect logic
        await connect(targetDevice!);
      } else {
        throw Exception("Trichter nicht gefunden. Bitte manuell verbinden.");
      }
    } catch (e) {
      state = state.copyWith(
        status: TrichterConnectionStatus.error,
        error: e.toString(),
      );
    }
  }


  /// Trennt die Verbindung manuell
  Future<void> disconnect() async {
    if (state.connectedDevice != null) {
      try {
        await state.connectedDevice!.disconnect();
      } catch (_) {
        print("Disconnect failed :(");
      }
    }
    _handleDisconnect();
  }

  /// Sendet einen Status-Wechsel-Wunsch an das Gerät
  /// Mappt den logischen Status auf das korrekte Command-Byte
  Future<void> requestState(TrichterDeviceStatus targetStatus) async {
    if (state.status != TrichterConnectionStatus.connected ||
        _statusCharacteristic == null) {
      state = state.copyWith(
          error: "Nicht verbunden oder Status-Kanal nicht bereit.");
      return;
    }

    int commandByte;

    // Asymmetrisches Mapping: Request -> Byte
    switch (targetStatus) {
      case TrichterDeviceStatus.idle:
        commandByte = BleConstants.cmdSetIdle; // 0x00
        break;
      case TrichterDeviceStatus.ready:
        commandByte = BleConstants.cmdSetReady; // 0x01
        break;
      case TrichterDeviceStatus.calibrating:
        commandByte = BleConstants.cmdCalibrate; // 0x02
        break;
      default:
        state = state.copyWith(
            error: "Dieser Status kann nicht angefordert werden.");
        return;
    }

    try {
      await _statusCharacteristic!.write([commandByte], withoutResponse: false);
    } catch (e) {
      state = state.copyWith(error: "Fehler beim Senden des Befehls: $e");
    }
  }

  // --- Private Helpers ---

  void _handleDisconnect() {
    _connectionStateSubscription?.cancel();
    _statusSubscription?.cancel();
    _statusCharacteristic = null;

    if (ref.mounted) {
      state = TrichterConnectionState(
          status: TrichterConnectionStatus.disconnected);
    }
  }

  Future<void> _setupStateMachine(BluetoothDevice device) async {

     if (_stateMachineInitialized) return;
    _stateMachineInitialized = true;

    // Services entdecken (wichtig für Android)
    List<BluetoothService> services = await device.discoverServices();

    // Service suchen
    final service = services.firstWhere(
      (s) => s.uuid.toString().toLowerCase() == BleConstants.serviceUuid,
      orElse: () => throw "Service nicht gefunden",
    );

    // Characteristic suchen
    // Annahme: Es gibt eine eigene Status-Char. Falls Status über "Session" läuft,
    // hier BleConstants.sessionUuid verwenden.
    _statusCharacteristic = service.characteristics.firstWhere(
      (c) => c.uuid.toString().toLowerCase() == BleConstants.statusUuid,
      orElse: () => throw "Status Characteristic nicht gefunden",
    );

    // Notifications aktivieren
    if (_statusCharacteristic!.properties.notify) {
      await _statusCharacteristic!.setNotifyValue(true);
      _statusSubscription =
          _statusCharacteristic!.lastValueStream.listen(_onDeviceStateChanged);
    }

    // Optional: Initialen Status lesen
    if (_statusCharacteristic!.properties.read) {
      try {
        List<int> val = await _statusCharacteristic!.read();
        if (val.isNotEmpty) _onDeviceStateChanged(val);
      } catch (_) {}
    }
  }

  /// Verarbeitet eingehende Bytes vom Gerät und setzt den UI Status
  void _onDeviceStateChanged(List<int> value) {
    if (value.isEmpty) return;

    int byte = value[0];
    TrichterDeviceStatus newStatus;

    // Mapping: Byte -> Status
    switch (byte) {
      case BleConstants.stateIdle: // 0x00
        newStatus = TrichterDeviceStatus.idle;
        break;
      case BleConstants.stateReady: // 0x01
        newStatus = TrichterDeviceStatus.ready;
        break;
      case BleConstants.stateRunning: // 0x02
        newStatus = TrichterDeviceStatus.running;
        break;
      case BleConstants.stateSending: // 0x03
        newStatus = TrichterDeviceStatus.sending;
        break;
      case BleConstants.stateCalibrating: // 0x04
        newStatus = TrichterDeviceStatus.calibrating;
        break;
      case BleConstants.stateError: // 0x05
        newStatus = TrichterDeviceStatus.error;
        break;
      default:
        newStatus = TrichterDeviceStatus.unknown;
    }

    state = state.copyWith(deviceStatus: newStatus);
  }

  /// Reads the current device state once from the status characteristic
  /// and updates the UI state immediately.
  ///
  /// Safe to call:
  /// - after returning to a screen
  /// - after reconnect
  /// - if notifications were missed
  Future<void> queryCurrentDeviceState() async {
    // Must be connected and characteristic must exist
    if (state.status != TrichterConnectionStatus.connected ||
        _statusCharacteristic == null) {
      return;
    }

    // Characteristic must support READ
    if (!_statusCharacteristic!.properties.read) {
      return;
    }

    try {
      final List<int> value = await _statusCharacteristic!.read();

      if (value.isNotEmpty) {
        _onDeviceStateChanged(value);
      }
    } catch (e) {
      // Non-fatal: UI will recover on next notify
      state = state.copyWith(
        error: "Status konnte nicht gelesen werden: $e",
      );
    }
  }
}

// Provider Definition
final trichterConnectionProvider =
    NotifierProvider<TrichterConnectionService, TrichterConnectionState>(() {
  return TrichterConnectionService();
});
