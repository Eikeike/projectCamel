import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'trichter_connection_service.dart'; // Dein Pfad
import '../core/constants.dart'; // Dein Pfad

// ==========================================
// STATE
// ==========================================

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

  double get progress {
    if (expectedTickCount <= 0) return 0.0;
    return (rawTicks.length / expectedTickCount).clamp(0.0, 1.0);
  }
}

// ==========================================
// HANDLER (LOGIK)
// ==========================================

class TrichterDataHandler extends Notifier<TrichterDataState> {
  StreamSubscription? _dataSubscription;
  
  // Um zu verhindern, dass wir streams doppelt aufsetzen, wenn doch mal ein Rebuild passiert
  String? _currentlyConnectedDeviceId; 

  @override
  TrichterDataState build() {
    // FIX 1: SELECT VERWENDEN
    // Wir hören nur auf Änderungen der Verbindung oder des Geräts selbst.
    // Status-Änderungen (z.B. "Running", "Sending") lösen jetzt KEINEN Rebuild mehr aus.
    final connectionState = ref.watch(
      trichterConnectionProvider.select((s) => (s.status, s.connectedDevice)),
    );

    final status = connectionState.$1;
    final device = connectionState.$2;

    if (status == TrichterConnectionStatus.connected && device != null) {
      // Sicherheitscheck: Nur initialisieren, wenn es ein neues Gerät ist
      if (_currentlyConnectedDeviceId != device.remoteId.toString()) {
         _setupDataStreams(device);
         _currentlyConnectedDeviceId = device.remoteId.toString();
      }
    } else {
      _cleanup();
    }

    ref.onDispose(_cleanup);
    return TrichterDataState();
  }

  void _cleanup() {
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _currentlyConnectedDeviceId = null;
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
      // Hinweis: FBP cacht services, daher ist discoverServices hier meist schnell/sicher
      final services = await device.discoverServices();
      
      for (var service in services) {
        for (var char in service.characteristics) {
          final uuid = char.uuid.toString().toLowerCase();

          // 1. Zeit-Kalibrierung lesen (Read Property)
          if (uuid == BleConstants.calibUuid) {
            try {
              final val = await char.read().timeout(const Duration(seconds: 5));
              if (val.isNotEmpty) {
                state = state.copyWith(timeCalibrationFactor: val[0].toDouble());
              }
            } catch (e) {
              print("Fehler beim Lesen der Kalibrierung: $e");
            }
          }

          // 2. Daten-Indication abonnieren (Notify/Indicate Property)
          if (uuid == BleConstants.sessionUuid) {
            
            // FIX 2: REIHENFOLGE TAUSCHEN & STREAM WECHSELN
            
            // A) Erst aufräumen
            await _dataSubscription?.cancel();

            // B) ZUERST ZUHÖREN (onValueReceived statt lastValueStream!)
            // onValueReceived feuert nur bei wirklich neuen Daten-Events.
            _dataSubscription = char.onValueReceived.listen((data) {
                _handleIncomingRawData(data);
            });
            
            // Sicherheitsnetz: Stream killen, wenn Device disconnected
            device.cancelWhenDisconnected(_dataSubscription!);

            // C) DANACH NOTIFICATIONS AKTIVIEREN
            // Jetzt sind wir bereit, Daten zu empfangen.
            await char.setNotifyValue(true);
            
            print("Data Stream erfolgreich registriert für ${char.uuid}");
          }
        }
      }
    } catch (e) {
      // Nur loggen, State Error würde UI evtl. verwirren, wenn es nur ein kleiner Glitch ist
      print("Stream Setup Fehler: $e");
      state = state.copyWith(error: "Initialisierung fehlgeschlagen: $e");
    }
  }

  void _handleIncomingRawData(List<int> rawData) {
    if (rawData.isEmpty) return;

    final int flag = rawData[0];

    switch (flag) {
      case BleConstants.flagStart:
        print("Protocol: START Flag empfangen. Payload: ${rawData.length}");
        
        // Struktur: [Flag(1), Index(2), SDU(1), Count(2), RamCounter(2)]
        // Insgesamt min. 8 Bytes
        if (rawData.length < 8) {
             print("Fehler: Start-Paket zu kurz!");
             return;
        }

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

        // Payload Daten ausschneiden
        final payload = rawData.sublist(
            BleConstants.headerSize, BleConstants.headerSize + reportedSize);

        if (payload.length == reportedSize) {
          if (payload.isNotEmpty && payload.length % 4 == 0) {
            final incomingTicks = _parseTo32Bit(Uint8List.fromList(payload));

            state = state.copyWith(
              rawTicks: [...state.rawTicks, ...incomingTicks],
            );
            print(
                "Chunk $chunkIndex: ${incomingTicks.length} Ticks extrahiert. (Total: ${state.rawTicks.length}/${state.expectedTickCount})");
          }
        } else {
          print(
              "Fehler: Paket unvollständig. Erwartet: $reportedSize, vorhanden: ${payload.length}");
        }
        break;

      case BleConstants.flagEnd:
        print("Protocol: END Flag empfangen.");
        _checkAndFinalize();
        break;

      default:
        print("Unbekanntes Protokoll-Flag: 0x${flag.toRadixString(16)}");
    }
  }

  void _checkAndFinalize() {
    if (state.rawTicks.length == state.expectedTickCount) {
      final sortedTicks = List<int>.from(state.rawTicks)..sort();
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
      print("Session erfolgreich beendet. Dauer: ${totalDuration}ms");
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