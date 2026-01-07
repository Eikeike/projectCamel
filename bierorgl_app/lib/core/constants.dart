class AppConstants {
  static const apiBaseUrl = 'https://dev.trichter.biertrinkenistgesund.de';
  static const bleDeviceId = 'ABC-123';
  static const autoSyncDebounceIntervalSeconds = 7; //ja ich weiß geiler name
}

enum SyncStatus {
  synced('SYNCED'),
  pendingCreate('PENDING_CREATE'),
  pendingUpdate('PENDING_UPDATE'),
  pendingDelete('PENDING_DELETE');

  final String value;
  const SyncStatus(this.value);
}
