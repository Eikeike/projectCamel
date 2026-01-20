import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/trichter_firmware_update.dart';
import '../services/trichter_connection_service.dart';

class FirmwareUpdateSection extends ConsumerStatefulWidget {
  const FirmwareUpdateSection({super.key});

  @override
  ConsumerState<FirmwareUpdateSection> createState() => _FirmwareUpdateSectionState();
}

/// Widget that displays firmware update information.
class _FirmwareUpdateSectionState extends ConsumerState<FirmwareUpdateSection> {

  String _prevDeviceId = '';

  void _dismissError() {
    ref.read(firmwareUpdateProvider.notifier).reset();
  }

  void _handleSuccessTap() {
    // Navigate to your desired screen here
    // Example: Navigator.of(context).pushNamed('/connection');
    // Or using go_router: context.go('/connection');
    
    // For now, just reset the state to allow checking for updates again
    ref.read(firmwareUpdateProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(trichterConnectionProvider);
    final firmwareState = ref.watch(firmwareUpdateProvider);

    if (connectionState.connectedDevice != null) {
      _prevDeviceId = connectionState.connectedDevice?.remoteId.toString() ?? '';
    }

    if (connectionState.firmwareVersion != null && 
          firmwareState.firmwareInfo == null && 
          !firmwareState.isLoading &&
          firmwareState.error == null &&
          !firmwareState.isSuccess) { // Don't auto-check if there's a success state
        // Use microtask to avoid building while building
        Future.microtask(() => 
          ref.read(firmwareUpdateProvider.notifier).checkForUpdates(connectionState.firmwareVersion!)
        );
    }


    final bool isConnected = connectionState.status == TrichterConnectionStatus.connected;
    final bool isProcessing = firmwareState.isUpdating || firmwareState.isSuccess;
    final bool hasError = firmwareState.error != null;

    // Widget stays visible even after disconnect if there's a success state, error, or update in progress
    if (!isConnected && !isProcessing && !hasError) {
      return const SizedBox.shrink();
    }

    // If we are connected but don't have firmware info yet, show a loader
    if (isConnected && 
        firmwareState.firmwareInfo == null && 
        firmwareState.isLoading && 
        !hasError &&
        !firmwareState.isSuccess) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Text(
          'Firmware',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // 1. Current Version Row (only show if connected or no success state)
              if (!firmwareState.isSuccess)
                ListTile(
                  leading: const Icon(Icons.memory),
                  title: const Text('Aktuelle Version'),
                  trailing: (connectionState.firmwareVersion == null && !isProcessing && !hasError)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          connectionState.firmwareVersion ?? "---",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),

              // 2. Loading State (Checking for updates)
              if (firmwareState.isLoading && !hasError && !firmwareState.isSuccess)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),

              // 3. Error State
              if (hasError)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline, 
                            color: Theme.of(context).colorScheme.error,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Update fehlgeschlagen',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  firmwareState.error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                // Show additional context if available
                                if (firmwareState.updateStatus != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Status: ${firmwareState.updateStatus}',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Action buttons for error state
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _dismissError,
                            child: const Text('Schließen'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () {
                              final deviceId = _prevDeviceId.isNotEmpty 
                                  ? _prevDeviceId 
                                  : connectionState.connectedDevice?.remoteId.toString();
                              if (deviceId != null) {
                                connectionState.connectedDevice?.requestConnectionPriority(connectionPriorityRequest: ConnectionPriority.lowPower);
                                ref.read(firmwareUpdateProvider.notifier).performUpdate(deviceId);
                              } else {
                                // Try to reconnect first
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Bitte verbinde dich zuerst mit dem Trichter'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Erneut versuchen'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // 4. Success State - NEW DESIGN
              if (firmwareState.isSuccess)
                InkWell(
                  onTap: _handleSuccessTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Neuste Software eingetrichtert!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Verbinde dich neu und leg sofort los',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Icon(
                          Icons.touch_app,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        Text(
                          'Tippe hier',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 5. Updating State
              if (firmwareState.isUpdating)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: firmwareState.updateProgress,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        firmwareState.updateStatus ?? "Verarbeitung...",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (firmwareState.updateProgress != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${(firmwareState.updateProgress! * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      // Add cancel button during update
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton.icon(
                          onPressed: () {
                            ref.read(firmwareUpdateProvider.notifier).cancelUpdate();
                          },
                          icon: const Icon(Icons.cancel),
                          label: const Text('Abbrechen'),
                        ),
                      ),
                    ],
                  ),
                ),

              // 6. Update Available / Up-to-Date State
              if (firmwareState.firmwareInfo != null && !firmwareState.isSuccess && !firmwareState.isLoading && !firmwareState.isUpdating) ...[
                const Divider(indent: 16, endIndent: 16, height: 1),
                if (firmwareState.firmwareInfo!.isUpdateAvailable)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.system_update, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Update verfügbar', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text('Version ${firmwareState.firmwareInfo?.latestVersion ?? "---"}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              final deviceId = connectionState.connectedDevice?.remoteId.toString();
                              if (deviceId != null) {
                                ref.read(firmwareUpdateProvider.notifier).performUpdate(deviceId);
                              }
                            },
                            icon: const Icon(Icons.download),
                            label: const Text('Firmware jetzt updaten'),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text('Auf dem neuesten Stand'),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}