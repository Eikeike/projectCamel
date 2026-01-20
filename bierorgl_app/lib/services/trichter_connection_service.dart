import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';

// ==========================================
// STATE DEFINITIONS
// ==========================================

enum TrichterConnectionStatus { disconnected, connecting, connected, error }

enum TrichterDeviceStatus {
  unknown,
  idle,
  ready,
  running,
  sending,
  calibrating,
  error
}

class TrichterConnectionState {
  final BluetoothDevice? connectedDevice;
  final TrichterConnectionStatus status;
  final TrichterDeviceStatus deviceStatus;
  final String? error;
  final String? firmwareVersion;

  const TrichterConnectionState({
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

  static final Guid _serviceGuid = Guid(BleConstants.serviceUuid);
  static final Guid _statusGuid = Guid(BleConstants.statusUuid);

  @override
  TrichterConnectionState build() {
    ref.keepAlive();
    ref.onDispose(_disposeInternal);
    return const TrichterConnectionState();
  }

  void _disposeInternal() {
    _connectionStateSubscription?.cancel();
    _statusSubscription?.cancel();
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

  // ==========================================
  // CONNECTION CONTROL
  // ==========================================

  Future<void> connect(BluetoothDevice device) async {
    if (state.status == TrichterConnectionStatus.connecting ||
        state.status == TrichterConnectionStatus.connected) return;

    state = state.copyWith(
      status: TrichterConnectionStatus.connecting,
      error: null,
    );

    try {
      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
        license: License.free,
      );

      if (!ref.mounted) return;

      _connectionStateSubscription?.cancel();
      _connectionStateSubscription =
          device.connectionState.listen((connectionStatus) {
        if (connectionStatus == BluetoothConnectionState.disconnected) {
          _handleDisconnect();
        }
      });

      await _setupStateMachine(device);

      // 4. READ FIRMWARE VERSION
      final String? version = await _readFirmwareVersion(device);

      if (!ref.mounted) return;

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
    final device = state.connectedDevice;
    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    _handleDisconnect();
  }

  // ==========================================
  // DEVICE COMMANDS
  // ==========================================

  Future<void> requestState(TrichterDeviceStatus targetStatus) async {
    final characteristic = _statusCharacteristic;

    if (state.status != TrichterConnectionStatus.connected ||
        characteristic == null) {
      state = state.copyWith(
          error: "Nicht verbunden oder Status-Kanal nicht bereit.");
      return;
    }

    final int commandByte;

    switch (targetStatus) {
      case TrichterDeviceStatus.idle:
        commandByte = BleConstants.cmdSetIdle;
        break;
      case TrichterDeviceStatus.ready:
        commandByte = BleConstants.cmdSetReady;
        break;
      case TrichterDeviceStatus.calibrating:
        commandByte = BleConstants.cmdCalibrate;
        break;
      default:
        state = state.copyWith(
            error: "Dieser Status kann nicht angefordert werden.");
        return;
    }

    try {
      await characteristic.write(
        [commandByte],
        withoutResponse: false,
      );
    } catch (e) {
      state = state.copyWith(error: "Fehler beim Senden des Befehls: $e");
    }
  }

  // ==========================================
  // INTERNAL HANDLING
  // ==========================================

  void _handleDisconnect() {
    _connectionStateSubscription?.cancel();
    _statusSubscription?.cancel();
    _statusCharacteristic = null;
    _stateMachineInitialized = false;

    if (ref.mounted) {
      state = const TrichterConnectionState(
          status: TrichterConnectionStatus.disconnected);
    }
  }

  Future<void> _setupStateMachine(BluetoothDevice device) async {
    if (_stateMachineInitialized) return;
    _stateMachineInitialized = true;

    final services = await device.discoverServices();

    BluetoothService? targetService;
    for (final s in services) {
      if (s.uuid == _serviceGuid) {
        targetService = s;
        break;
      }
    }

    if (targetService == null) {
      throw "Service nicht gefunden";
    }

    BluetoothCharacteristic? statusChar;
    for (final c in targetService.characteristics) {
      if (c.uuid == _statusGuid) {
        statusChar = c;
        break;
      }
    }

    if (statusChar == null) {
      throw "Status Characteristic nicht gefunden";
    }

    _statusCharacteristic = statusChar;

    if (statusChar.properties.notify) {
      await statusChar.setNotifyValue(true);
      _statusSubscription =
          statusChar.lastValueStream.listen(_onDeviceStateChanged);
    }

    if (statusChar.properties.read) {
      try {
        final val = await statusChar.read();
        if (val.isNotEmpty) _onDeviceStateChanged(val);
      } catch (_) {}
    }
  }

  // ==========================================
  // STATE MAPPING
  // ==========================================

  void _onDeviceStateChanged(List<int> value) {
    if (value.isEmpty) return;

    final byte = value[0];
    final TrichterDeviceStatus newStatus;

    switch (byte) {
      case BleConstants.stateIdle:
        newStatus = TrichterDeviceStatus.idle;
        break;
      case BleConstants.stateReady:
        newStatus = TrichterDeviceStatus.ready;
        break;
      case BleConstants.stateRunning:
        newStatus = TrichterDeviceStatus.running;
        break;
      case BleConstants.stateSending:
        newStatus = TrichterDeviceStatus.sending;
        break;
      case BleConstants.stateCalibrating:
        newStatus = TrichterDeviceStatus.calibrating;
        break;
      case BleConstants.stateError:
        newStatus = TrichterDeviceStatus.error;
        break;
      default:
        newStatus = TrichterDeviceStatus.unknown;
    }

    if (state.deviceStatus != newStatus) {
      state = state.copyWith(deviceStatus: newStatus);
    }
  }

  // ==========================================
  // MANUAL QUERY
  // ==========================================

  Future<void> queryCurrentDeviceState() async {
    final characteristic = _statusCharacteristic;

    if (state.status != TrichterConnectionStatus.connected ||
        characteristic == null ||
        !characteristic.properties.read) {
      return;
    }

    try {
      final value = await characteristic.read();
      if (value.isNotEmpty) {
        _onDeviceStateChanged(value);
      }
    } catch (e) {
      state = state.copyWith(
        error: "Status konnte nicht gelesen werden: $e",
      );
    }
  }
}

// ==========================================
// PROVIDER
// ==========================================

final trichterConnectionProvider =
    NotifierProvider<TrichterConnectionService, TrichterConnectionState>(
        TrichterConnectionService.new);
