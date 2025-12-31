import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'package:intl/intl.dart';

import 'session_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String selectedVolumeLabel = 'Alle';

  int? get selectedVolumeML {
    if (selectedVolumeLabel == '0,33 L') return 330;
    if (selectedVolumeLabel == '0,5 L') return 500;
    return null;
  }

  Future<void> _reloadData() async {
    setState(() {});
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
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
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _loadAllProfileData(),
          builder: (context, snapshot) {
            // 1. Ladezustand
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF9500)),
              );
            }

            // 2. Fehler oder kein User eingeloggt
            if (!snapshot.hasData || snapshot.data!['user'] == null) {
              return _buildNoUserUI();
            }

            final data = snapshot.data!;
            final user = data['user'] as Map<String, dynamic>;

            // Sicherer Cast der Listen (verhindert den 'Null' subtype Fehler)
            final allSessions = List<Map<String, dynamic>>.from(data['sessions'] ?? []);
            final history = List<Map<String, dynamic>>.from(data['history'] ?? []);
            final mostFrequentEvent = data['mostEvent'] as Map<String, dynamic>?;

            // Filterung für die Stat-Cards
            List<Map<String, dynamic>> filteredSessions = allSessions;
            if (selectedVolumeML != null) {
              filteredSessions = allSessions
                  .where((s) => s['volumeML'] == selectedVolumeML)
                  .toList();
            }

            // Berechnungen für Stats Grid
            int totalCount = filteredSessions.length;
            double totalVolumeL = allSessions.fold(0.0, (sum, s) => sum + ((s['volumeML'] as int? ?? 0) / 1000.0));

            String fastestTime = "0.00s";
            if (filteredSessions.isNotEmpty) {
              int minMS = filteredSessions
                  .map((s) => s['durationMS'] as int? ?? 0)
                  .reduce((a, b) => (a != 0 && a < b) ? a : b);
              fastestTime = "${(minMS / 1000).toStringAsFixed(2)}s";
            }

            String avgTime = "N/A";
            if (filteredSessions.isNotEmpty && selectedVolumeLabel != 'Alle') {
              double avgMS = filteredSessions
                  .map((s) => s['durationMS'] as int? ?? 0)
                  .reduce((a, b) => a + b) /
                  filteredSessions.length;
              avgTime = "${(avgMS / 1000).toStringAsFixed(2)}s";
            }

            // Beste Zeiten (fixe Werte für die Liste)
            String best033 = _getBestForVol(allSessions, 330);
            String best05 = _getBestForVol(allSessions, 500);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildAvatar(user['name']?.toString().isNotEmpty == true
                      ? user['name'][0]
                      : (user['firstname']?.toString().isNotEmpty == true ? user['firstname'][0] : 'U')),
                  const SizedBox(height: 16),
                  Text(
                    user['name'] ?? user['firstname'] ?? 'Unbekannt',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '@${user['username'] ?? 'user'}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),

                  _buildFilterHeader(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildVolumeChip('Alle'),
                      const SizedBox(width: 12),
                      _buildVolumeChip('0,33 L'),
                      const SizedBox(width: 12),
                      _buildVolumeChip('0,5 L'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildStatsGrid(totalCount, fastestTime, avgTime, totalVolumeL),
                  const SizedBox(height: 24),

                  _buildBestTimesCard(best033, best05),
                  const SizedBox(height: 16),

                  _buildMostEventCard(mostFrequentEvent),
                  const SizedBox(height: 24),

                  _buildHistoryCard(history),
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
    int min = vSess.map((s) => s['durationMS'] as int? ?? 0).reduce((a, b) => a < b ? a : b);
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9500)),
            child: const Text('Erneut versuchen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String initial) {
    return Container(
      width: 100, height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFFFF9500), shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: const Color(0xFFFF9500).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Center(child: Text(initial.toUpperCase(), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white))),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Filter nach Volumen', style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
          Text('Statistiken', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF9500) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? const Color(0xFFFF9500) : Colors.grey[300]!),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.grey[700])),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(int count, String fast, String avg, double totalVol) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard(Icons.emoji_events, const Color(0xFFFFD700), 'Gesamt', '$count', 'Trichterungen')),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(Icons.bolt, const Color(0xFF4CAF50), 'Schnellste', fast, 'Zeit')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard(Icons.show_chart, Colors.blue, 'Durchschnitt', avg, 'Zeit')),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(Icons.sports_bar, const Color(0xFFFF9500), 'Volumen', '${totalVol.toStringAsFixed(1)}L', 'Gesamt')),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, Color iconColor, String label, String value, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildBestTimesCard(String b33, String b5) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Beste Zeiten', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildBestTimeRow('0,33 L', b33),
          const Divider(height: 24),
          _buildBestTimeRow('0,5 L', b5),
        ],
      ),
    );
  }

  Widget _buildBestTimeRow(String volume, String time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(volume, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        Text(time, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: time.contains('keine') ? Colors.grey : Colors.black)),
      ],
    );
  }

  Widget _buildMostEventCard(Map<String, dynamic>? mostEvent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Meistgetrichtert', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (mostEvent != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mostEvent['name'] ?? 'Event', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      Text('Gesamt: ${((mostEvent['totalVol'] ?? 0) / 1000).toStringAsFixed(1)}L', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFFF9500), borderRadius: BorderRadius.circular(12)),
                  child: Text('${mostEvent['count']}x', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            )
          else
            const Text('Noch keine Daten vorhanden', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(List<Map<String, dynamic>> history) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Verlauf', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (history.isEmpty)
            const Text('Keine Sessions in der Historie', style: TextStyle(color: Colors.grey))
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
                  dateStr = DateFormat('dd.MM.yyyy').format(DateTime.parse(s['startedAt']));
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
            Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(width: 16),
            Expanded(child: Text(event, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            Text(volume, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SessionScreen(session: session)),
                  ).then((_) => _reloadData());
                } else if (val == 'delete') {
                  _confirmDeleteSession(session);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                const PopupMenuItem(value: 'delete', child: Text('Löschen', style: TextStyle(color: Colors.red))),
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
            Text(time, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFFF9500))),
            Text(flow, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }
}
