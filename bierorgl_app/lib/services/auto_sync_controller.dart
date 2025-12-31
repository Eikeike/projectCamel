import 'dart:async';
import 'package:project_camel/core/constants.dart';

import 'sync_service.dart';

class AutoSyncController {
  final SyncService _syncService;

  Timer? _debounceTimer;
  bool _isSyncing = false;
  bool _hasPendingChanges = false;

  AutoSyncController(this._syncService);

  void triggerSync() {
    _hasPendingChanges = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: AppConstants.autoSyncDebounceIntervalSeconds), _runIfNeeded);
  }

  Future<void> _runIfNeeded() async {
    if (_isSyncing || !_hasPendingChanges) return;

    _isSyncing = true;
    _hasPendingChanges = false;

    try {
      await _syncService.sync();
    } catch (e, s) {
      print("AutoSyncController: sync failed: $e\n$s");
    } finally {
      _isSyncing = false;

      if (_hasPendingChanges) {
        _runIfNeeded();
      }
    }
  }
}