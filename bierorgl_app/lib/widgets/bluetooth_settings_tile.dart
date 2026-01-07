import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/trichter_scanner_service.dart';
import '../services/trichter_connection_service.dart';

class BluetoothSettingsTile extends ConsumerWidget {
  const BluetoothSettingsTile({super.key});

  void _showBluetoothBottomSheet(BuildContext context, WidgetRef ref) {
    // Startet den Scan direkt beim Öffnen des Panels
    Future.microtask(() => ref.read(trichterScanProvider.notifier).startScan());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final scanState = ref.watch(trichterScanProvider);
            final devices = scanState.discoveredDevices;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Android Handle (Der graue Strich oben)
                  Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        'Verfügbare Geräte',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- DIE SUCH-ANIMATION (LINEAR INDICATOR) ---
                  if (scanState.isScanning) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: const LinearProgressIndicator(minHeight: 2),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    // Platzhalter, damit die Liste bei Scan-Stop nicht ruckartig springt
                    const SizedBox(height: 18),
                  ],

                  // --- DIE GERÄTELISTE ---
                  if (devices.isEmpty && !scanState.isScanning)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text("Keine Trichter in der Nähe gefunden"),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: devices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final result = devices[index];
                        final deviceName = result.device.platformName.isEmpty
                            ? "Unbekannter Trichter"
                            : result.device.platformName;

                        final isFirst = index == 0;
                        final isLast = index == devices.length - 1;

                        final borderRadius = BorderRadius.vertical(
                          top:
                              isFirst ? const Radius.circular(16) : Radius.zero,
                          bottom:
                              isLast ? const Radius.circular(16) : Radius.zero,
                        );

                        return Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow,
                            borderRadius: borderRadius,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: borderRadius,
                              onTap: () async {
                                // 1. Scan stoppen (notifier nutzen!)
                                await ref
                                    .read(trichterScanProvider.notifier)
                                    .stopScan();

                                // 2. Verbindung zum gewählten Gerät aufbauen
                                ref
                                    .read(trichterConnectionProvider.notifier)
                                    .connect(result.device);

                                // 3. Panel schließen
                                Navigator.pop(context);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 16),
                                child: Row(
                                  children: [
                                    Icon(Icons.bluetooth,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(deviceName,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16)),
                                          Text("Signal: ${result.rssi} dBm",
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize: 14)),
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
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(trichterScanProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: scanState.isBluetoothEnabled
            ? () => _showBluetoothBottomSheet(context, ref)
            : () => _showDisabledSnackBar(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).colorScheme.surfaceContainer,
          ),
          child: Row(
            children: [
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bluetooth',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      scanState.isBluetoothEnabled
                          ? 'Tippen zum Verbinden'
                          : 'Bluetooth ist ausgeschaltet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withOpacity(0.6)),
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

  void _showDisabledSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
        width: 240,
        shape: const StadiumBorder(),
        content: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_disabled, size: 18, color: Colors.white),
            SizedBox(width: 10),
            Text('Bluetooth aktivieren'),
          ],
        ),
      ),
    );
  }
}
