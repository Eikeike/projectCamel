import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/providers.dart';
import 'package:project_camel/widgets/pie_chart.dart';
import '../auth/auth_providers.dart';

import '../services/database_helper.dart';
import 'package:intl/intl.dart';

import 'session_graph_screen.dart'; // NEU: Import für den Graphen-Screen
import 'session_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String selectedVolumeLabel = 'Alle';

  int? get selectedVolumeML {
    if (selectedVolumeLabel == '0,33 L') return 330;
    if (selectedVolumeLabel == '0,5 L') return 500;
    return null;
  }

  Future<void> _logout() async {
    ref.read(autoSyncControllerProvider).disable();
    await DatabaseHelper().updateLoggedInUser(null);
    await ref.read(authControllerProvider.notifier).logout();
  }

  Future<void> _reloadData() async {
    setState(() {});
  }

  void _showGraph(Map<String, dynamic> session) {
    final String? valuesJson = session['valuesJSON'] as String?;
    final int? timeCalibrationFactor = session['timeCalibrationFactor'];

    // KORREKTUR: Robusten Wert aus der Datenbank lesen
    final num? rawVolumeFactor = session['calibrationFactor'] as num?;
    final int? volumeCalibrationFactor = rawVolumeFactor?.toInt();

    // Tipp für den Graphen: ignoriere den ersten (oft falschen) Wert
    final List<dynamic> allValues =
        valuesJson != null ? jsonDecode(valuesJson) : [];
    final List<dynamic> graphValues =
        allValues.length > 1 ? allValues.sublist(1) : [];
    final String graphValuesJson = jsonEncode(graphValues);

    if (valuesJson != null && volumeCalibrationFactor != null) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Graph',
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, anim1, anim2) => Container(), // Platzhalter
        transitionBuilder: (context, anim1, anim2, child) {
          return ScaleTransition(
            scale: anim1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
              child: SessionGraphScreen(
                // Gib hier die gefilterte Liste weiter
                valuesJson: graphValuesJson,
                // Platzhalter, diese Werte müssen aus der DB kommen oder fix sein
                volumeCalibrationValue: volumeCalibrationFactor,
              ),
            ),
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Keine Graphendaten für diese Session verfügbar.'),
            backgroundColor: Colors.amber),
      );
    }
  }

  void _confirmDeleteSession(Map<String, dynamic> session) {
    final sessionName = session['name'] as String? ?? 'diese Session';
    final sessionID = session['sessionID'] as String;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session löschen?'),
        content: Text('Möchtest du "$sessionName" wirklich löschen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          TextButton(
            onPressed: () async {
              await _dbHelper.markSessionAsDeleted(sessionID);
              if (mounted) Navigator.pop(context);
              _reloadData();
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _loadAllProfileData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary),
              );
            }

            if (!snapshot.hasData || snapshot.data!['user'] == null) {
              return _buildNoUserUI();
            }

            final data = snapshot.data!;
            final user = data['user'] as Map<String, dynamic>;
            final allSessions =
                List<Map<String, dynamic>>.from(data['sessions'] ?? []);
            final history =
                List<Map<String, dynamic>>.from(data['history'] ?? []);
            final mostFrequentEvent =
                data['mostEvent'] as Map<String, dynamic>?;

            List<Map<String, dynamic>> filteredSessions = allSessions;
            if (selectedVolumeML != null) {
              filteredSessions = allSessions
                  .where((s) => s['volumeML'] == selectedVolumeML)
                  .toList();
            }

            int totalCount = filteredSessions.length;
            double totalVolumeL = allSessions.fold(
                0.0, (sum, s) => sum + ((s['volumeML'] as int? ?? 0) / 1000.0));

            String fastestTime = "0.00s";
            if (filteredSessions.isNotEmpty) {
              int minMS = filteredSessions
                  .map((s) => s['durationMS'] as int? ?? 0)
                  .reduce((a, b) => (a != 0 && a < b) ? a : b);
              fastestTime = "${(minMS / 1000).toStringAsFixed(2)} s";
            }

            String avgTime = "N/A";
            if (filteredSessions.isNotEmpty && selectedVolumeLabel != 'Alle') {
              double avgMS = filteredSessions
                      .map((s) => s['durationMS'] as int? ?? 0)
                      .reduce((a, b) => a + b) /
                  filteredSessions.length;
              avgTime = "${(avgMS / 1000).toStringAsFixed(2)} s";
            }

            String best033 = _getBestForVol(allSessions, 330);
            String best05 = _getBestForVol(allSessions, 500);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildAvatar(user['name']?.toString().isNotEmpty == true
                      ? user['name'][0]
                      : (user['firstname']?.toString().isNotEmpty == true
                          ? user['firstname'][0]
                          : 'U')),
                  const SizedBox(height: 16),
                  Text(
                    user['name'] ?? user['firstname'] ?? 'Unbekannt',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '@${user['username'] ?? 'user'}',
                    style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(height: 24),

                  _buildFilterHeader(),
                  Row(
                    children: [
                      _buildVolumeChip('Alle'),
                      const SizedBox(width: 12),
                      _buildVolumeChip('Kölsch'),
                      const SizedBox(width: 12),
                      _buildVolumeChip('0,33 L'),
                      const SizedBox(width: 12),
                      _buildVolumeChip('0,5 L'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildStatsGrid(
                      totalCount, fastestTime, avgTime, totalVolumeL),
                  const SizedBox(height: 24),

                  _buildPieChartCard(), // 👈 instead of Row(children: [PieChartSample2()])
                  const SizedBox(height: 24),
                  // _buildBestTimesCard(best033, best05),
                  // const SizedBox(height: 16),

                  _buildMostEventCard(mostFrequentEvent),
                  const SizedBox(height: 24),

                  _buildHistoryCard(history),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _logout,
                    child: const Text(
                      "Logout",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadAllProfileData() async {
    final uid = await _dbHelper.getLoggedInUserID();
    if (uid == null) {
      return {'user': null};
    }

    final user = await _dbHelper.getUserByID(uid);
    final sessions = await _dbHelper.getUserStats(uid);
    final history = await _dbHelper.getHistory(uid);
    final mostEvent = await _dbHelper.getMostFrequentEvent(uid);

    return {
      'user': user,
      'sessions': sessions,
      'history': history,
      'mostEvent': mostEvent,
    };
  }

  String _getBestForVol(List<Map<String, dynamic>> sessions, int vol) {
    var vSess = sessions.where((s) => s['volumeML'] == vol).toList();
    if (vSess.isEmpty) return "Noch keine";
    int min = vSess
        .map((s) => s['durationMS'] as int? ?? 0)
        .reduce((a, b) => a < b ? a : b);
    return "${(min / 1000).toStringAsFixed(2)}s";
  }

  Widget _buildNoUserUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_off_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Kein Profil ausgewählt',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Wähle einen User beim Trichtern aus.'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() {}), // Refresh
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary),
            child: const Text('Erneut versuchen',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String initial) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Center(
          child: Text(initial.toUpperCase(),
              style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimary))),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(Icons.water_drop,
              size: 20, color: Theme.of(context).colorScheme.primary),
          Text(' Filter nach Volumen',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          //Text('Statistiken', style: TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildVolumeChip(String label) {
    bool isSelected = selectedVolumeLabel == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedVolumeLabel = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainer),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface)),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(int count, String fast, String avg, double totalVol) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    Icons.emoji_events,
                    Theme.of(context).colorScheme.primary,
                    'Trichterungen',
                    '$count',
                    'Trichterungen')),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard(
                    Icons.timer,
                    Theme.of(context).colorScheme.primary,
                    'Bestzeit',
                    fast,
                    'Zeit')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    Icons.av_timer,
                    Theme.of(context).colorScheme.primary,
                    'Durchschnitt',
                    avg,
                    'Zeit')),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard(
                    Icons.sports_bar,
                    Theme.of(context).colorScheme.primary,
                    'Gesamtvolumen',
                    '${totalVol.toStringAsFixed(1)} L',
                    'Gesamt')),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    IconData icon,
    Color iconColor,
    String label,
    String value,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: Theme.of(context).textTheme.titleMedium?.fontSize,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
                    //fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildBestTimesCard(String b33, String b5) {
  //   return Container(
  //     padding: const EdgeInsets.all(20),
  //     decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         const Text('Beste Zeiten', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  //         const SizedBox(height: 16),
  //         _buildBestTimeRow('0,33 L', b33),
  //         const Divider(height: 24),
  //         _buildBestTimeRow('0,5 L', b5),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildBestTimeRow(String volume, String time) {
  //   return Row(
  //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //     children: [
  //       Text(volume, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
  //       Text(time, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: time.contains('keine') ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface)),
  //     ],
  //   );
  // }

  Widget _buildPieChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
            'Volumenverteilung',
            style: TextStyle(
              fontSize: Theme.of(context).textTheme.titleMedium?.fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(
            height: 220, // adjust as you like
            width: double.infinity,
            child: const PieChartSample2(),
          ),
        ],
      ),
    );
  }

  Widget _buildMostEventCard(Map<String, dynamic>? mostEvent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Meistgetrichtert',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (mostEvent != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mostEvent['name'] ?? 'Event',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500)),
                      Text(
                          'Gesamt: ${((mostEvent['totalVol'] ?? 0) / 1000).toStringAsFixed(1)}L',
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('${mostEvent['count']}x',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ],
            )
          else
            Text('Noch keine Daten vorhanden',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(List<Map<String, dynamic>> history) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Verlauf',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (history.isEmpty)
            Text('Keine Sessions in der Historie',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final s = history[index];
                double volL = (s['volumeML'] as int? ?? 0) / 1000.0;
                double timeS = (s['durationMS'] as int? ?? 1) / 1000.0;
                double flow = volL / timeS;

                String dateStr = "Unbekannt";
                try {
                  dateStr = DateFormat('dd.MM.yyyy')
                      .format(DateTime.parse(s['startedAt']));
                } catch (_) {}

                return _buildHistoryItem(
                  session: s,
                  date: dateStr,
                  event: s['eventName'] ?? 'Privat',
                  time: '${timeS.toStringAsFixed(2)}s',
                  volume: '${volL.toStringAsFixed(2)}L',
                  flow: '${flow.toStringAsFixed(3)} L/s',
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem({
    required Map<String, dynamic> session,
    required String date,
    required String event,
    required String time,
    required String volume,
    required String flow,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today,
                size: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(date,
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(width: 16),
            Expanded(
                child: Text(event,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis)),
            Text(volume,
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => SessionScreen(session: session)),
                  ).then((_) => _reloadData());
                } else if (val == 'delete') {
                  _confirmDeleteSession(session);
                } else if (val == 'show_graph') {
                  // NEU: Aufruf der Graphen-Methode
                  _showGraph(session);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                const PopupMenuItem(
                    value: 'show_graph', child: Text('Graph anzeigen')), // NEU
                const PopupMenuItem(
                    value: 'delete',
                    child:
                        Text('Löschen', style: TextStyle(color: Colors.red))),
              ],
              icon: const Icon(Icons.more_vert, size: 20.0),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(time,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary)),
            Text(flow,
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}
