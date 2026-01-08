import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'trichter_connection_service.dart';
import '../core/constants.dart';

class TrichterDataState {
  final List<int> rawTicks;
  final List<int> msValues;
  final int expectedTickCount;
  final int? volumeCalibrationFactor;
  final double? timeCalibrationFactor;
  final bool isSessionFinished;
  final int lastDurationMS;
  final String? error;

  TrichterDataState({
    this.rawTicks = const [],
    this.msValues = const [],
    this.expectedTickCount = 0,
    this.volumeCalibrationFactor,
    this.timeCalibrationFactor,
    this.isSessionFinished = false,
    this.lastDurationMS = 0,
    this.error,
  });

  TrichterDataState copyWith({
    List<int>? rawTicks,
    List<int>? msValues,
    int? expectedTickCount,
    int? volumeCalibrationFactor,
    double? timeCalibrationFactor,
    bool? isSessionFinished,
    int? lastDurationMS,
    String? error,
  }) {
    return TrichterDataState(
      rawTicks: rawTicks ?? this.rawTicks,
      msValues: msValues ?? this.msValues,
      expectedTickCount: expectedTickCount ?? this.expectedTickCount,
      volumeCalibrationFactor:
          volumeCalibrationFactor ?? this.volumeCalibrationFactor,
      timeCalibrationFactor:
          timeCalibrationFactor ?? this.timeCalibrationFactor,
      isSessionFinished: isSessionFinished ?? this.isSessionFinished,
      lastDurationMS: lastDurationMS ?? this.lastDurationMS,
      error: error,
    );
  }

  /// Berechnet den aktuellen Fortschritt der Übertragung (0.0 bis 1.0)
  double get progress {
    if (expectedTickCount <= 0) return 0.0;
    return (rawTicks.length / expectedTickCount).clamp(0.0, 1.0);
  }
}

class TrichterDataHandler extends Notifier<TrichterDataState> {
  StreamSubscription? _dataSubscription;

  @override
  TrichterDataState build() {
    final connectionState = ref.watch(trichterConnectionProvider);

    if (connectionState.status == TrichterConnectionStatus.connected &&
        connectionState.connectedDevice != null) {
      _setupDataStreams(connectionState.connectedDevice!);
    } else {
      _cleanup();
    }

    ref.onDispose(_cleanup);
    return TrichterDataState();
  }

  void _cleanup() {
    _dataSubscription?.cancel();
    _dataSubscription = null;
  }

  void resetSession() {
    state = state.copyWith(
      rawTicks: [],
      msValues: [],
      expectedTickCount: 0,
      isSessionFinished: false,
      lastDurationMS: 0,
      error: null,
    );
  }

  Future<void> _setupDataStreams(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      for (var service in services) {
        for (var char in service.characteristics) {
          final uuid = char.uuid.toString().toLowerCase();

          // 1. Zeit-Kalibrierung lesen
          if (uuid == BleConstants.calibUuid) {
            final val = await char.read().timeout(const Duration(seconds: 5));
            if (val.isNotEmpty) {
              state = state.copyWith(timeCalibrationFactor: val[0].toDouble());
            }
          }

          // 2. Daten-Indication abonnieren
          if (uuid == BleConstants.sessionUuid) {
            await char.setNotifyValue(true);
            _dataSubscription?.cancel();
            _dataSubscription =
                char.lastValueStream.listen(_handleIncomingRawData);
          }
        }
      }
    } catch (e) {
      state = state.copyWith(error: "Initialisierung fehlgeschlagen: $e");
    }
  }

  void _handleIncomingRawData(List<int> rawData) {
    if (rawData.isEmpty) return;

    final int flag = rawData[0];

    switch (flag) {
      case BleConstants.flagStart:
        // Struktur: [Flag(1), Index(2), SDU(1), Count(2), RamCounter(2)]
        final bd = ByteData.sublistView(Uint8List.fromList(rawData));
        final int count = bd.getUint16(BleConstants.offsetCount, Endian.little);
        final int volFactor =
            bd.getUint16(BleConstants.offsetVolFactor, Endian.little);

        state = state.copyWith(
          expectedTickCount: count,
          volumeCalibrationFactor: volFactor,
          isSessionFinished: false,
          rawTicks: [],
          msValues: [],
          error: null,
        );
        break;

      case BleConstants.flagData:
        final bd = ByteData.sublistView(Uint8List.fromList(rawData));

        // Header auslesen (Byte 0: Flag, 1-2: Index, 3: Size)
        final int chunkIndex = bd.getUint16(1, Endian.little);
        final int reportedSize = bd.getUint8(3);

        // Payload Daten ausschneiden (Header vorne weg und mögliches padding am ende durch Längenübertragung)
        final payload = rawData.sublist(
            BleConstants.headerSize, BleConstants.headerSize + reportedSize);

        // Passt die länge jetzt (falls Paket zu kurz war)
        if (payload.length == reportedSize) {
          // Noch ne Sicherheitsstufe, dass es auch wirklich immer 4 Bytes sind
          if (payload.isNotEmpty && payload.length % 4 == 0) {
            final incomingTicks = _parseTo32Bit(Uint8List.fromList(payload));

            state = state.copyWith(
              rawTicks: [...state.rawTicks, ...incomingTicks],
            );
            print(
                "Chunk $chunkIndex: ${incomingTicks.length} Ticks erfolgreich extrahiert.");
          }
        } else {
          print(
              "Fehler: Paket unvollständig. Erwartet: $reportedSize, vorhanden: ${payload.length}");
          // Hier könnte man ggf. einen Fehler-State setzen
        }
        break;

      case BleConstants.flagEnd:
        _checkAndFinalize();
        break;

      default:
        print("Unbekanntes Protokoll-Flag: 0x${flag.toRadixString(16)}");
    }
  }

  void _checkAndFinalize() {
    if (state.rawTicks.length == state.expectedTickCount) {
      final sortedTicks = List<int>.from(state.rawTicks)
        ..sort(); //eigentlich nicht nötig aber notfalls noch einmal sortieren
      final factor = state.timeCalibrationFactor ?? 1.0;

      final msList =
          sortedTicks.map((t) => ((t * factor) / 1000).round()).toList();

      final totalDuration = msList.isNotEmpty ? msList.last : 0;

      state = state.copyWith(
        msValues: msList,
        isSessionFinished: true,
        lastDurationMS: totalDuration,
        error: null,
      );
    } else {
      state = state.copyWith(
        error:
            "Übertragungsfehler: ${state.rawTicks.length} von ${state.expectedTickCount} Ticks erhalten.",
        isSessionFinished: false,
      );
    }
  }

  List<int> _parseTo32Bit(Uint8List bytes) {
    final List<int> result = [];
    final byteData = ByteData.sublistView(bytes);
    for (int i = 0; i < bytes.length; i += 4) {
      result.add(byteData.getUint32(i, Endian.little));
    }
    return result;
  }
}

final trichterDataHandlerProvider =
    NotifierProvider<TrichterDataHandler, TrichterDataState>(
        () => TrichterDataHandler());
