import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Passe diese Imports an deinen tatsächlichen Pfad an
import '../services/trichter_scanner_service.dart';
import '../services/trichter_connection_service.dart';

class BluetoothSettingsTile extends ConsumerWidget {
  const BluetoothSettingsTile({super.key});

  // ---------------------------------------------------------------------------
  // Haupt-Build Methode (Die Kachel in den Settings)
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(trichterScanProvider);
    final connectionState = ref.watch(trichterConnectionProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: scanState.isBluetoothEnabled
            ? () => _showBluetoothBottomSheet(context, ref, connectionState)
            : () => _showDisabledSnackBar(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).colorScheme.surfaceContainer,
          ),
          child: Row(
            children: [
              // Icon Box
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: scanState.isBluetoothEnabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Icon(
                  scanState.isBluetoothEnabled
                      ? Icons.bluetooth
                      : Icons.bluetooth_disabled,
                  color: scanState.isBluetoothEnabled
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.4),
                ),
              ),
              const SizedBox(width: 16),
              // Text Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bluetooth',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _getBluetoothConnectionText(connectionState, scanState),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_right),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom Sheet Logik
  // ---------------------------------------------------------------------------
  void _showBluetoothBottomSheet(
    BuildContext context,
    WidgetRef ref,
    TrichterConnectionState connectionState,
  ) {
    final isConnected =
        connectionState.status == TrichterConnectionStatus.connected;

    // Nur Scannen starten, wenn wir NICHT verbunden sind
    if (!isConnected) {
      Future.microtask(
          () => ref.read(trichterScanProvider.notifier).startScan());
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Erlaubt dynamische Höhe
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            // Live-States abonnieren
            final scanState = ref.watch(trichterScanProvider);
            final currentConnState = ref.watch(trichterConnectionProvider);
            final devices = scanState.discoveredDevices;
            final isDeviceConnected =
                currentConnState.status == TrichterConnectionStatus.connected;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Griff (Handle) ---
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------------------------------------------------------
                  // FALL A: VERBUNDEN -> Control Center anzeigen
                  // ---------------------------------------------------------
                  if (isDeviceConnected) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'Verbundenes Gerät',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    _buildConnectedDeviceCard(context, ref, currentConnState),
                  ]

                  // ---------------------------------------------------------
                  // FALL B: NICHT VERBUNDEN -> Scan Liste anzeigen
                  // ---------------------------------------------------------
                  else ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 16),
                      child: Text(
                        'Verfügbare Geräte',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),

                    // Ladebalken beim Scannen
                    if (scanState.isScanning)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),

                    // Empty State
                    if (devices.isEmpty && !scanState.isScanning)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text("Keine Trichter in der Nähe gefunden"),
                        ),
                      )
                    // Device List
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: devices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final result = devices[index];
                          final deviceName = result.device.platformName.isEmpty
                              ? "Unbekannter Trichter"
                              : result.device.platformName;

                          return Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  // Scan stoppen und verbinden
                                  await ref
                                      .read(trichterScanProvider.notifier)
                                      .stopScan();
                                  ref
                                      .read(trichterConnectionProvider.notifier)
                                      .connect(result.device);

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.bluetooth,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              deviceName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              "Signal: ${result.rssi} dBm",
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Widget: Connected Card (Control Center)
  // ---------------------------------------------------------------------------
  Widget _buildConnectedDeviceCard(
      BuildContext context, WidgetRef ref, TrichterConnectionState state) {
    final deviceName =
        state.connectedDevice?.platformName ?? "Unbekannter Trichter";
    final status = state.deviceStatus;
    final notifier = ref.read(trichterConnectionProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow, // Neutraler Hintergrund wie Liste
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 1. Info Zeile
          Row(
            children: [
              Icon(Icons.bluetooth_connected, color: scheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  deviceName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20), // Abstand

          // 2. Action Zeile: Buttons + Trennen
          Row(
            children: [
              // --- Steuerungs-Buttons (Linker Bereich) ---
              // Diese Methoden liefern Expanded Widgets zurück
              ..._buildControlButtons(context, status, notifier),

              const SizedBox(width: 12),

              // --- Trenner (Vertikale Linie) ---
              Container(
                height: 24,
                width: 1,
                color: scheme.outlineVariant,
              ),
              const SizedBox(width: 12),

              // --- Trennen Button (Rechter Bereich) ---
              IconButton(
                onPressed: () {
                  notifier.disconnect();
                  Navigator.pop(context); // Sheet schließen
                },
                style: IconButton.styleFrom(
                  foregroundColor: scheme.error,
                  backgroundColor: scheme.errorContainer.withOpacity(0.3),
                ),
                icon: const Icon(Icons.link_off),
                tooltip: "Trennen",
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Logik für die Steuerungs-Buttons (State Machine)
  // ---------------------------------------------------------------------------
  List<Widget> _buildControlButtons(BuildContext context,
      TrichterDeviceStatus status, TrichterConnectionService notifier) {
    // Helper: Kompakte Buttons für das BottomSheet
    Widget btn(String text, IconData icon, VoidCallback onTap,
        {bool isPrimary = false}) {
      return Expanded(
        child: SizedBox(
          height: 44,
          child: isPrimary
              ? FilledButton.icon(
                  onPressed: onTap,
                  icon: Icon(icon, size: 18),
                  label: Text(text),
                  style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                )
              : FilledButton.tonalIcon(
                  onPressed: onTap,
                  icon: Icon(icon, size: 18),
                  label: Text(text),
                  style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                ),
        ),
      );
    }

    Widget outlinedBtn(String text, IconData icon, VoidCallback onTap) {
      return Expanded(
        child: SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(text),
            style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
          ),
        ),
      );
    }

    const gap = SizedBox(width: 8);

    switch (status) {
      // IDLE -> Calibrate | Ready
      case TrichterDeviceStatus.idle:
        return [
          btn("Kalibrieren", Icons.tune,
              () => notifier.requestState(TrichterDeviceStatus.calibrating)),
          gap,
          btn("Aufwecken", Icons.power_settings_new,
              () => notifier.requestState(TrichterDeviceStatus.ready),
              isPrimary: true),
        ];

      // READY -> Idle | Calibrate
      case TrichterDeviceStatus.ready:
        return [
          outlinedBtn("Standby", Icons.bedtime,
              () => notifier.requestState(TrichterDeviceStatus.idle)),
          gap,
          btn("Kalibrieren", Icons.tune,
              () => notifier.requestState(TrichterDeviceStatus.calibrating)),
        ];

      // CALIBRATING -> Idle | Ready (Fertig)
      case TrichterDeviceStatus.calibrating:
        return [
          outlinedBtn("Standby", Icons.bedtime,
              () => notifier.requestState(TrichterDeviceStatus.idle)),
          gap,
          btn("Fertig", Icons.check,
              () => notifier.requestState(TrichterDeviceStatus.ready),
              isPrimary: true),
        ];

      // ERROR -> Reset
      case TrichterDeviceStatus.error:
        return [
          btn("Reset", Icons.refresh,
              () => notifier.requestState(TrichterDeviceStatus.idle),
              isPrimary: true)
        ];

      default:
        return [const Spacer()];
    }
  }

  // ---------------------------------------------------------------------------
  // Hilfsfunktionen & Snackbars
  // ---------------------------------------------------------------------------
  String _getBluetoothConnectionText(
    TrichterConnectionState connState,
    TrichterScanState scanState,
  ) {
    if (!scanState.isBluetoothEnabled) {
      return "Bluetooth ausgeschaltet";
    }
    if (connState.status == TrichterConnectionStatus.connected) {
      return connState.connectedDevice?.platformName ?? "Verbunden";
    }
    return "Tippen zum Verbinden";
  }

  void _showDisabledSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
        width: 240,
        shape: const StadiumBorder(),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_disabled,
                size: 18,
                color: Theme.of(context).colorScheme.onInverseSurface),
            const SizedBox(width: 10),
            const Text('Bluetooth aktivieren'),
          ],
        ),
      ),
    );
  }
}
