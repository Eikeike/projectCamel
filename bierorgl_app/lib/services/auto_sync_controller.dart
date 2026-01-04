import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/core/constants.dart';
import 'package:project_camel/services/sync_service.dart';
import 'package:project_camel/auth/auth_providers.dart'; // for authControllerProvider

class AutoSyncController {
  final SyncService _syncService;
  final Ref _ref;

  Timer? _debounceTimer;
  bool _isSyncing = false;
  bool _hasPendingChanges = false;

  AutoSyncController(this._syncService, this._ref);

  void triggerSync() {
    _hasPendingChanges = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(seconds: AppConstants.autoSyncDebounceIntervalSeconds),
      _runIfNeeded,
    );
  }

  Future<void> _runIfNeeded() async {
    if (_isSyncing || !_hasPendingChanges) return;

    _isSyncing = true;
    _hasPendingChanges = false;

    try {
      await _syncService.sync();
    } on DioException catch (e, s) {
      print("AutoSyncController: sync failed (DioException): $e\n$s");

      final statusCode = e.response?.statusCode;
      if (statusCode == 401) {
        // AuthRepository's interceptor already tried refresh
        // If still 401 ->it called logout() (cleared tokens).
        // tell Riverpod "auth state changed" by invalidating the provider.
        _ref.invalidate(authControllerProvider);
      }
    } catch (e, s) {
      print("AutoSyncController: sync failed (unexpected): $e\n$s");
    } finally {
      _isSyncing = false;

      if (_hasPendingChanges) {
        _runIfNeeded();
      }
    }
  }
}
