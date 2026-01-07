import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Status der Bluetooth-Verbindung für das UI
enum TrichterConnectionStatus { disconnected, connecting, connected, error }

class TrichterConnectionState {
  final BluetoothDevice? connectedDevice;
  final TrichterConnectionStatus status;
  final String? error;

  TrichterConnectionState({
    this.connectedDevice,
    this.status = TrichterConnectionStatus.disconnected,
    this.error,
  });

  TrichterConnectionState copyWith({
    BluetoothDevice? connectedDevice,
    TrichterConnectionStatus? status,
    String? error,
  }) {
    return TrichterConnectionState(
      connectedDevice: connectedDevice ?? this.connectedDevice,
      status: status ?? this.status,
      error: error, // Error wird bei Bedarf überschrieben
    );
  }
}

class TrichterConnectionService extends Notifier<TrichterConnectionState> {
  StreamSubscription? _connectionStateSubscription;

  @override
  TrichterConnectionState build() {
    // Cleanup wenn der Provider nicht mehr gebraucht wird
    ref.onDispose(() {
      _connectionStateSubscription?.cancel();
    });

    return TrichterConnectionState();
  }

  /// Startet den Verbindungsaufbau zu einem Trichter
  Future<void> connect(BluetoothDevice device) async {
    // Verhindere mehrfache Klicks während bereits verbunden wird
    if (state.status == TrichterConnectionStatus.connecting ||
        state.status == TrichterConnectionStatus.connected) return;

    state = state.copyWith(
        status: TrichterConnectionStatus.connecting, error: null);

    try {
      // Verbindung zur Hardware aufbauen
      // autoConnect: false -> Schnellerer Timeout/Fehlermeldung
      await device.connect(
          timeout: const Duration(seconds: 10),
          autoConnect: false,
          license: License.free);

      // Status-Listener: Falls das Gerät außer Reichweite geht oder ausgeschaltet wird
      _connectionStateSubscription?.cancel();
      _connectionStateSubscription =
          device.connectionState.listen((connectionStatus) {
        if (connectionStatus == BluetoothConnectionState.disconnected) {
          _handleDisconnect();
        }
      });

      state = state.copyWith(
        connectedDevice: device,
        status: TrichterConnectionStatus.connected,
      );
    } catch (e) {
      state = state.copyWith(
        status: TrichterConnectionStatus.error,
        error: "Verbindung fehlgeschlagen: $e",
      );
    }
  }

  /// Trennt die Verbindung manuell
  Future<void> disconnect() async {
    if (state.connectedDevice != null) {
      try {
        await state.connectedDevice!.disconnect();
      } catch (_) {}
    }
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _connectionStateSubscription?.cancel();
    if (ref.mounted) {
      state = TrichterConnectionState(
          status: TrichterConnectionStatus.disconnected);
    }
  }
}

// Hier nutzen wir wieder autoDispose für die Müllabfuhr
final trichterConnectionProvider = NotifierProvider.autoDispose<
    TrichterConnectionService, TrichterConnectionState>(() {
  return TrichterConnectionService();
});
