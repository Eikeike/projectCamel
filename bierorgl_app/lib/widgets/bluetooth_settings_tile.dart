import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bluetooth_service.dart';

class BluetoothSettingsTile extends ConsumerWidget {
  const BluetoothSettingsTile({super.key});

  void _showBluetoothBottomSheet(BuildContext context, WidgetRef ref) {
    // ref.read(bluetoothServiceProvider.notifier).startScan();

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
            final state = ref.watch(bluetoothServiceProvider);
            final isConnected = state.connectedDevice != null;

            // Beispiel-Liste für die Demo
            final List<Map<String, String>> dummyDevices = [
              {'name': 'BIERORGL v1.0', 'status': 'Signal: Sehr stark'},
              {'name': 'BIERORGL PRO', 'status': 'Zuletzt verbunden'},
              {'name': 'Trichter-Master 3000', 'status': 'Verfügbar'},
            ];

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
                  // Android Handle
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

                  // Such-Indikator
                  if (!isConnected) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: const LinearProgressIndicator(minHeight: 2),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // --- GRUPPIERTE LISTE (Look wie in deiner Vorlage) ---
                  ListView.separated(
                    shrinkWrap: true, // Wichtig für BottomSheets
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dummyDevices.length,
                    separatorBuilder: (_, __) => const SizedBox(
                        height:
                            2), // Winziger Abstand oder 0 für nahtlosen Übergang
                    itemBuilder: (context, index) {
                      final device = dummyDevices[index];
                      final isFirst = index == 0;
                      final isLast = index == dummyDevices.length - 1;

                      // Abrundung nur für das erste und letzte Element
                      final borderRadius = BorderRadius.vertical(
                        top: isFirst ? const Radius.circular(16) : Radius.zero,
                        bottom:
                            isLast ? const Radius.circular(16) : Radius.zero,
                      );

                      return Container(
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: borderRadius,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: borderRadius,
                            onTap: () => Navigator.pop(context),
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
                                        Text(device['name']!,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                        Text(device['status']!,
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
    final bluetoothState = ref.watch(bluetoothServiceProvider);
    final isConnected = bluetoothState.connectedDevice != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: bluetoothState.isEnabled
            ? () => _showBluetoothBottomSheet(context, ref)
            : () {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor:
                        Theme.of(context).colorScheme.inverseSurface,
                    behavior: SnackBarBehavior.floating,
                    // Durch 'width' statt 'margin' wird die Snackbar kompakt
                    width: 240,
                    elevation: 4,
                    shape:
                        StadiumBorder(), // Erzeugt die perfekte Pillen-Form (Android 16 Style)
                    duration: const Duration(milliseconds: 3000),
                    content: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize:
                          MainAxisSize.min, // Inhalt so schmal wie möglich
                      children: [
                        Icon(
                          Icons.bluetooth_disabled,
                          size: 18,
                          color: Theme.of(context).colorScheme.onInverseSurface,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Bitte Bluetooth einschalten',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).colorScheme.onInverseSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
                  color: bluetoothState.isEnabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Icon(
                  bluetoothState.isEnabled
                      ? Icons.bluetooth
                      : Icons.bluetooth_disabled,
                  color: bluetoothState.isEnabled
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
                      bluetoothState.isEnabled
                          ? (isConnected
                              ? 'Verbunden mit ${bluetoothState.connectedDevice?.platformName ?? "Gerät"}'
                              : 'Tippen zum Verbinden')
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
}
