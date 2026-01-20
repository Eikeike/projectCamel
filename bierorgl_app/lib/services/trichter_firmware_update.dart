import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Image; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// Use a prefix to prevent "UpdateManager" and "Image" conflicts
import 'package:mcumgr_flutter/mcumgr_flutter.dart' as mcumgr;
import 'package:mcumgr_flutter/models/image_upload_alignment.dart';
import 'package:mcumgr_flutter/models/firmware_upgrade_mode.dart';

// ============================================================================
// MODELS
// ============================================================================

class FirmwareInfo {
  final String currentVersion;
  final String? latestVersion;
  final String? releaseUrl;
  final bool isUpdateAvailable;

  FirmwareInfo({
    required this.currentVersion,
    this.latestVersion,
    this.releaseUrl,
    required this.isUpdateAvailable,
  });
}

class FirmwareUpdateState {
  final FirmwareInfo? firmwareInfo;
  final bool isLoading;
  final String? error;
  final bool isUpdating;
  final bool isSuccess;
  final double? updateProgress; 
  final String? updateStatus;

  FirmwareUpdateState({
    this.firmwareInfo,
    this.isLoading = false,
    this.error,
    this.isUpdating = false,
    this.isSuccess = false,
    this.updateProgress,
    this.updateStatus,
  });

  FirmwareUpdateState copyWith({
    FirmwareInfo? firmwareInfo,
    bool? isLoading,
    String? error,
    bool? isUpdating,
    bool? isSuccess,
    double? updateProgress,
    String? updateStatus,
  }) {
    return FirmwareUpdateState(
      firmwareInfo: firmwareInfo ?? this.firmwareInfo,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isUpdating: isUpdating ?? this.isUpdating,
      isSuccess: isSuccess ?? this.isSuccess,
      updateProgress: updateProgress ?? this.updateProgress,
      updateStatus: updateStatus ?? this.updateStatus,
    );
  }
}

// ============================================================================
// SERVICE (API Logic)
// ============================================================================

class FirmwareUpdateService {
  static const String owner = 'Eikeike';
  static const String repo = 'projectCamel';
  static const String prefix = 'trichter-';

  Future<String?> getLatestFirmwareVersion() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$owner/$repo/releases'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> releases = json.decode(response.body);
        final trichterReleases = releases.where((release) {
          final tagName = release['tag_name'] as String;
          return tagName.startsWith(prefix);
        }).toList();

        if (trichterReleases.isNotEmpty) {
          trichterReleases.sort((a, b) {
            final versionA = (a['tag_name'] as String).replaceFirst(prefix, '');
            final versionB = (b['tag_name'] as String).replaceFirst(prefix, '');
            return _compareVersions(versionB, versionA);
          });
          final latest = trichterReleases.first;
          return (latest['tag_name'] as String).replaceFirst(prefix, '');
        }
      }
      return null;
    } catch (e) {
      throw Exception('GitHub API Error: $e');
    }
  }

  bool isNewerVersion(String currentVersion, String latestVersion) {
    return _compareVersions(latestVersion, currentVersion) > 0;
  }

  Future<Uint8List> downloadFirmware(String version) async {
    final assetUrl = 'https://github.com/$owner/$repo/releases/download/$prefix$version/zephyr.signed.bin';
    final response = await http.get(Uri.parse(assetUrl));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Download Failed: ${response.statusCode}');
    }
  }

  static int _compareVersions(String v1, String v2) {
    try {
      final v1Parts = v1.split('.').map(int.parse).toList();
      final v2Parts = v2.split('.').map(int.parse).toList();
      while (v1Parts.length < 3) v1Parts.add(0);
      while (v2Parts.length < 3) v2Parts.add(0);
      for (int i = 0; i < 3; i++) {
        if (v1Parts[i] > v2Parts[i]) return 1;
        if (v1Parts[i] < v2Parts[i]) return -1;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }
}

// ============================================================================
// PROVIDERS & NOTIFIER
// ============================================================================

final firmwareUpdateServiceProvider = Provider<FirmwareUpdateService>((ref) {
  return FirmwareUpdateService();
});

class FirmwareUpdateNotifier extends Notifier<FirmwareUpdateState> {
  // Use the prefix to specify the library's UpdateManager
  mcumgr.FirmwareUpdateManager? _updateManager;

  @override
  FirmwareUpdateState build() {
    ref.onDispose(() {
      _killManager();
    });
    return FirmwareUpdateState();
  }

  void _killManager() {
    _updateManager?.kill();
    _updateManager = null;
  }

  void dismissSuccess() {
    state = state.copyWith(isSuccess: false);
  }

  Future<void> checkForUpdates(String currentVersion) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final service = ref.read(firmwareUpdateServiceProvider);
      final latestVersion = await service.getLatestFirmwareVersion();

      if (latestVersion == null) {
        state = state.copyWith(isLoading: false, error: 'No GitHub version found');
        return;
      }

      final isUpdateAvailable = service.isNewerVersion(currentVersion, latestVersion);

      state = state.copyWith(
        isLoading: false,
        firmwareInfo: FirmwareInfo(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          isUpdateAvailable: isUpdateAvailable,
        ),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> performUpdate(String deviceId) async {
    if (state.firmwareInfo?.latestVersion == null) {
      state = state.copyWith(error: 'No update version available');
      return;
    }

    state = state.copyWith(
      isUpdating: true,
      updateProgress: 0.0,
      updateStatus: 'Firmware herunterladen...',
      error: null,
    );

    try {
      final service = ref.read(firmwareUpdateServiceProvider);
      final version = state.firmwareInfo!.latestVersion!;
      final firmwareData = await service.downloadFirmware(version);

      final managerFactory = mcumgr.FirmwareUpdateManagerFactory();
      _updateManager = await managerFactory.getUpdateManager(deviceId);

      state = state.copyWith(updateStatus: 'Verbinde...');

      // Call setup as required
      _updateManager!.setup();

      // Listen to State Changes
      _updateManager!.updateStateStream?.listen((event) {
        if (event == mcumgr.FirmwareUpgradeState.success) {
          _finishUpdate();
        } else if (event == mcumgr.FirmwareUpgradeState.confirm)
        {
          state = state.copyWith(updateStatus: 'Update wird installiert...');
        } else
        {
          state = state.copyWith(updateStatus: event.toString().split('.').last);
        }
      }, onError: (e) {
        state = state.copyWith(isUpdating: false, error: 'Update Error: $e');
        _killManager();
      });

      // Listen to Progress
      _updateManager!.progressStream.listen((event) {
        final progress = event.bytesSent.toDouble() / event.imageSize.toDouble();
        state = state.copyWith(
          updateProgress: progress,
          updateStatus: 'Uploading: ${(event.bytesSent/1000).toStringAsFixed(2)} / ${(event.imageSize/1000).toStringAsFixed(2)} kB',
        );
      });

      _updateManager!.logger.logMessageStream
        .where((log) => log.level.rawValue > 0) // filter out debug messages
        .listen((log) {
      print(log.message);
    });

      final configuration = const mcumgr.FirmwareUpgradeConfiguration(
        estimatedSwapTime: Duration(seconds: 10),
        byteAlignment: ImageUploadAlignment.disabled,
        firmwareUpgradeMode: FirmwareUpgradeMode.testAndConfirm,
        eraseAppSettings: true,
        pipelineDepth: 1,
      );

      // Start the update
      await _updateManager!.updateWithImageData(imageData: firmwareData, configuration: configuration);

    } catch (e) {
      state = state.copyWith(isUpdating: false, error: 'Exception: $e');
      _killManager();
    }
  }

  void _finishUpdate() {
    state = state.copyWith(
      isUpdating: false,
      isSuccess: true,
      updateProgress: 1.0,
      updateStatus: 'Neuste Software eingetrichtert! Probier sie sofort aus:',
    );
    _killManager();
  }

  void reset() {
    _killManager();
    state = FirmwareUpdateState();
  }

  void cancelUpdate() {
    _updateManager?.cancel();
    _killManager();
    state = state.copyWith(isUpdating: false, updateStatus: 'Cancelled');
  }
}

final firmwareUpdateProvider =
    NotifierProvider<FirmwareUpdateNotifier, FirmwareUpdateState>(() {
  return FirmwareUpdateNotifier();
});

