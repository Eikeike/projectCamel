import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';

class DeviceSelectionScreen extends ConsumerWidget {
  const DeviceSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bluetoothState = ref.watch(bluetoothServiceProvider);
    final bluetoothNotifier = ref.read(bluetoothServiceProvider.notifier);

    const backgroundColor = Color(0xFFFFF8F0);
    const accentOrange = Color(0xFFFF9500);
    const accentBlue = Color(0xFF2196F3);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Trichter suchen',
          style: TextStyle(
            color: accentOrange,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 10),
                        Icon(
                          Icons.bluetooth,
                          color: bluetoothState.isEnabled ? accentBlue : Colors.grey[400],
                        ),
                        const SizedBox(width: 15),
                        const Text(
                          'Bluetooth Status',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Switch(
                      value: bluetoothState.isEnabled,
                      onChanged: (value) => bluetoothNotifier.turnOnBluetooth(),
                      activeColor: accentBlue,
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (bluetoothState.isEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: bluetoothState.isScanning
                      ? null
                      : () async {
                    if (await _requestPermissions()) {
                      bluetoothNotifier.startScan();
                    }
                  },
                  icon: bluetoothState.isScanning
                      ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.search),
                  label: Text(bluetoothState.isScanning ? 'Suche läuft...' : 'Nach Trichter suchen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),

          Expanded(
            child: bluetoothState.availableDevices.isEmpty && !bluetoothState.isScanning
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: bluetoothState.availableDevices.length,
              itemBuilder: (context, index) {
                final result = bluetoothState.availableDevices[index];
                final device = result.device;
                final deviceName = device.platformName.isEmpty ? 'Bierorgl Trichter' : device.platformName;

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: accentBlue.withOpacity(0.1),
                      child: const Icon(Icons.sports_bar, color: accentBlue, size: 20),
                    ),
                    title: Text(deviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(device.remoteId.toString()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await bluetoothNotifier.connectToDevice(device);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),

          if (bluetoothState.error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(bluetoothState.error!, style: const TextStyle(color: Colors.redAccent)),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(child: TextButton(onPressed: () {}, child: const Text('Hilfe'))),
                Container(width: 1, height: 30, color: Colors.grey[300]),
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen'))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_searching, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Suche nach kompatiblen Trichtern...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}