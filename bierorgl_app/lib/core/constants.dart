import 'package:flutter/material.dart';
import 'color_constants.dart'; // Import der neuen Datei

class AppConstants {
  static const apiBaseUrl = 'https://dev.trichter.biertrinkenistgesund.de';
  static const loginPath = '/api/auth/login/';
  static const registerPath = '/api/auth/registration/';
  static const tokenRefreshPath = '/api/auth/token/refresh/';
  static const String passwordResetPath = '/api/auth/password/reset/';
  static const String privacyURL =
      'https://github.com/Eikeike/projectCamel/blob/2c67af259de0bc9ba2f45554471a0f58d585b35f/PRIVACY.md';
  static const bleDeviceId = 'ABC-123';
  static const autoSyncDebounceIntervalSeconds = 7;

  // --- UI KONFIGURATION ---
  // Wir definieren die Liste hier, damit sie nicht im UI-Code liegt.
  // Das macht den SettingsScreen viel schlanker.
  static const List<Map<String, dynamic>> themeOptions = [
    {'name': 'Ocean', 'seed': AppColorConstants.ocean},
    {'name': 'Nature', 'seed': AppColorConstants.nature},
    {'name': 'Cherry', 'seed': AppColorConstants.cherry},
    {'name': 'Royal', 'seed': AppColorConstants.royal},
    {'name': 'Sunset', 'seed': AppColorConstants.sunset},
    {'name': 'Coffee', 'seed': AppColorConstants.coffee},
  ];
}

enum SyncStatus {
  synced('SYNCED'),
  pendingCreate('PENDING_CREATE'),
  pendingUpdate('PENDING_UPDATE'),
  pendingDelete('PENDING_DELETE');

  final String value;
  const SyncStatus(this.value);
}

abstract class BleConstants {
  // --- UUIDs ---
  static const serviceUuid = "af56d6dd-3c39-4d67-9bbe-4fb04fa327cc";

  // UUID für Messdaten
  static const sessionUuid = "f9d76937-bd70-4e4f-a4da-0b718d5f5b6d";

  // UUID für Kalibrierungswerte
  static const calibUuid = "23de2cad-0fc8-49f4-bbcc-5eb2c9fdb91b";

  // UUID für State Machine
  static const statusUuid = "9b6d1c3a-91a2-4f23-8c11-1a2b3c4d5e6f";

  static const String deviceInfoServiceUuid = '180a';
  static const String firmwareRevisionUuid = '2a28';

  // --- Protokoll (Data Handler) ---
  static const flagStart = 0xAA;
  static const flagData = 0xBB;
  static const flagEnd = 0xCC;

  static const headerSize = 4;
  static const offsetCount = 4;
  static const offsetVolFactor = 6;

  // --- State Machine: VOM GERÄT GEMELDET (Read/Notify) ---
  static const int stateIdle = 0x00;
  static const int stateReady = 0x01;
  static const int stateRunning = 0x02;
  static const int stateCalibratedWithSuccess = (stateReady | 0x80);
  static const int stateSending = 0x03;
  static const int stateCalibrating = 0x04;
  static const int stateError = 0x05;

  // --- State Machine: ANFRAGE VOM HANDY (Write) ---
  static const int cmdSetIdle = 0x00;
  static const int cmdSetReady = 0x01;
  static const int cmdCalibrate = 0x02;
}
