class AppConstants {
  static const apiBaseUrl = 'https://...';
  static const bleDeviceId = 'ABC-123';
}



enum SyncStatus {
  synced('SYNCED'),
  pendingCreate('PENDING_CREATE'),
  pendingUpdate('PENDING_UPDATE'),
  pendingDelete('PENDING_DELETE');

  final String value;
  const SyncStatus(this.value);
}