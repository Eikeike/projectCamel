// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../services/bluetooth_service.dart';
//
// class DeviceSelectionScreen extends ConsumerWidget {
//   const DeviceSelectionScreen({super.key});
//
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final bluetoothState = ref.watch(bluetoothServiceProvider);
//     final bluetoothService = ref.read(bluetoothServiceProvider.notifier);
//
//     return Scaffold(
//       backgroundColor: const Color(0xFF1C1C1E),
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF1C1C1E),
//         elevation: 0,
//         title: const Text(
//           'Bluetooth',
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 24,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         centerTitle: true,
//       ),
//       body: Column(
//         children: [
//           // Mit Trichter verbinden Header
//           Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: const Color(0xFF2C2C2E),
//               borderRadius: BorderRadius.circular(12),
//               border: Border(
//                 bottom: BorderSide(
//                   color: Colors.grey[800]!,
//                   width: 0.5,
//                 ),
//               ),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text(
//                   'Mit Trichter verbinden',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 16,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 Switch(
//                   value: bluetoothState.isEnabled,
//                   onChanged: (value) {
//                     if (value) {
//                       bluetoothService.turnOnBluetooth();
//                     }
//                   },
//                   activeColor: const Color(0xFF007AFF),
//                 ),
//               ],
//             ),
//           ),
//
//           const SizedBox(height: 20),
//
//           // Scan Button
//           if (bluetoothState.isEnabled)
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 20),
//               child: SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton.icon(
//                   onPressed: bluetoothState.isScanning
//                       ? null
//                       : () => bluetoothService.startScan(),
//                   icon: bluetoothState.isScanning
//                       ? const SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2,
//                       color: Colors.white,
//                     ),
//                   )
//                       : const Icon(Icons.search),
//                   label: Text(
//                     bluetoothState.isScanning
//                         ? 'Suche läuft...'
//                         : 'Nach Geräten suchen',
//                     style: const TextStyle(fontSize: 16),
//                   ),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF007AFF),
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//
//           const SizedBox(height: 20),
//
//           // Geräteliste
//           if (bluetoothState.availableDevices.isNotEmpty)
//             Expanded(
//               child: Container(
//                 margin: const EdgeInsets.symmetric(horizontal: 20),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF2C2C2E),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Padding(
//                       padding: EdgeInsets.all(16),
//                       child: Text(
//                         'Gekoppelte Geräte',
//                         style: TextStyle(
//                           color: Colors.white70,
//                           fontSize: 13,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ),
//                     Divider(
//                       height: 1,
//                       color: Colors.grey[800],
//                     ),
//                     Expanded(
//                       child: ListView.separated(
//                         itemCount: bluetoothState.availableDevices.length,
//                         separatorBuilder: (context, index) => Divider(
//                           height: 1,
//                           color: Colors.grey[800],
//                           indent: 64,
//                         ),
//                         itemBuilder: (context, index) {
//                           final result = bluetoothState.availableDevices[index];
//                           final device = result.device;
//                           final deviceName = device.platformName.isEmpty
//                               ? 'Unbekanntes Gerät'
//                               : device.platformName;
//
//                           return ListTile(
//                             leading: Container(
//                               width: 40,
//                               height: 40,
//                               decoration: BoxDecoration(
//                                 color: Colors.grey[800],
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: const Icon(
//                                 Icons.device_hub,
//                                 color: Colors.white70,
//                                 size: 24,
//                               ),
//                             ),
//                             title: Text(
//                               deviceName,
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 16,
//                               ),
//                             ),
//                             subtitle: Text(
//                               device.remoteId.toString(),
//                               style: TextStyle(
//                                 color: Colors.grey[500],
//                                 fontSize: 13,
//                               ),
//                             ),
//                             trailing: result.rssi != 0
//                                 ? Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 8,
//                                 vertical: 4,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: _getSignalColor(result.rssi).withOpacity(0.2),
//                                 borderRadius: BorderRadius.circular(4),
//                               ),
//                               child: Text(
//                                 '${result.rssi} dBm',
//                                 style: TextStyle(
//                                   color: _getSignalColor(result.rssi),
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                             )
//                                 : null,
//                             onTap: () {
//                               bluetoothService.connectToDevice(device);
//                               Navigator.pop(context);
//                             },
//                           );
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//
//           // Empty State
//           if (bluetoothState.availableDevices.isEmpty && !bluetoothState.isScanning)
//             Expanded(
//               child: Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(
//                       Icons.bluetooth_searching,
//                       size: 64,
//                       color: Colors.grey[600],
//                     ),
//                     const SizedBox(height: 16),
//                     Text(
//                       bluetoothState.isEnabled
//                           ? 'Keine Geräte gefunden'
//                           : 'Bluetooth ist ausgeschaltet',
//                       style: TextStyle(
//                         color: Colors.grey[500],
//                         fontSize: 16,
//                       ),
//                     ),
//                     if (bluetoothState.isEnabled) ...[
//                       const SizedBox(height: 8),
//                       Text(
//                         'Starte einen Scan, um Geräte zu finden',
//                         style: TextStyle(
//                           color: Colors.grey[600],
//                           fontSize: 14,
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//
//           // Error Display
//           if (bluetoothState.error != null)
//             Container(
//               margin: const EdgeInsets.all(20),
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.red[900]!.withOpacity(0.3),
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: Colors.red[700]!),
//               ),
//               child: Row(
//                 children: [
//                   const Icon(Icons.error_outline, color: Colors.red),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Text(
//                       bluetoothState.error!,
//                       style: const TextStyle(color: Colors.red),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//
//           // Details/OK Buttons
//           Padding(
//             padding: const EdgeInsets.all(20),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextButton(
//                     onPressed: () {
//                       // Details anzeigen (später implementieren)
//                     },
//                     child: const Text(
//                       'Details',
//                       style: TextStyle(
//                         color: Color(0xFF007AFF),
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                 ),
//                 Container(
//                   width: 1,
//                   height: 40,
//                   color: Colors.grey[800],
//                 ),
//                 Expanded(
//                   child: TextButton(
//                     onPressed: () => Navigator.pop(context),
//                     child: const Text(
//                       'OK',
//                       style: TextStyle(
//                         color: Color(0xFF007AFF),
//                         fontSize: 16,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Color _getSignalColor(int rssi) {
//     if (rssi > -60) return Colors.green;
//     if (rssi > -80) return Colors.orange;
//     return Colors.red;
//   }
// }