import 'package:flutter/material.dart';
import 'color_constants.dart'; // Import der neuen Datei

class AppConstants {
  static const apiBaseUrl = 'https://dev.trichter.biertrinkenistgesund.de';
  static const loginPath = '/api/auth/login/';
  static const tokenRefreshPath = '/api/auth/token/refresh/';
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
  // UUIDs
  static const serviceUuid = "af56d6dd-3c39-4d67-9bbe-4fb04fa327cc";
  static const sessionUuid = "f9d76937-bd70-4e4f-a4da-0b718d5f5b6d";
  static const calibUuid = "23de2cad-0fc8-49f4-bbcc-5eb2c9fdb91b";

  // Protokoll
  static const flagStart = 0xAA;
  static const flagData = 0xBB;
  static const flagEnd = 0xCC;

  // Header Offsets
  static const headerSize = 4;
  static const offsetCount = 4; // Start-Paket Count
  static const offsetVolFactor = 6; // Start-Paket VolFactor
}
