import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  String selectedTab = 'Sessions';
  String selectedUserID = 'Alle';
  String selectedVolume = 'Alle';
  String selectedEventID = 'Alle';
  String selectedSort = 'Schnellste zuerst';

  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allEvents = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final users = await _dbHelper.getUsers();
    final events = await _dbHelper.getEvents();
    setState(() {
      _allUsers = users;
      _allEvents = events;
    });
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    List<Map<String, dynamic>> data;

    switch (selectedTab) {
      case 'Ø Zeit':
        data = await _dbHelper.getLeaderboardAverage();
        break;
      case 'Anzahl':
        data = await _dbHelper.getLeaderboardCount();
        break;
      case 'Volumen':
        data = await _dbHelper.getLeaderboardTotalVolume();
        break;
      default:
        int? vol;
        if (selectedVolume == '0,33') vol = 330;
        if (selectedVolume == '0,5') vol = 500;
        data = await _dbHelper.getLeaderboardData(
          userID: selectedUserID,
          volumeML: vol,
          eventID: selectedEventID,
          sortBy: selectedSort,
        );
    }

    setState(() => _entries = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('Leaderboard', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFFF9500))),
                  const SizedBox(height: 8),
                  Text('Die besten Trichterungen', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  _buildTabButton('Sessions', Icons.bolt),
                  _buildTabButton('Ø Zeit', Icons.schedule),
                  _buildTabButton('Anzahl', Icons.emoji_events),
                  _buildTabButton('Volumen', Icons.sports_bar),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Filters Card (Nur zeigen wenn Tab "Sessions")
            if (selectedTab == 'Sessions')
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildFilterLabel('Nutzer')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildFilterLabel('Volumen')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            selectedUserID,
                            ['Alle', ..._allUsers.map((u) => u['userID'].toString())],
                                (val) {
                              setState(() => selectedUserID = val!);
                              _loadLeaderboard();
                            },
                            names: ['Alle', ..._allUsers.map((u) => u['username'] ?? u['name'] ?? 'User')],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              _buildVolumeChip('Alle'),
                              const SizedBox(width: 4),
                              _buildVolumeChip('0,33'),
                              const SizedBox(width: 4),
                              _buildVolumeChip('0,5'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildFilterLabel('Event'),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      selectedEventID,
                      ['Alle', ..._allEvents.map((e) => e['eventID'].toString())],
                          (val) {
                        setState(() => selectedEventID = val!);
                        _loadLeaderboard();
                      },
                      names: ['Alle', ..._allEvents.map((e) => e['name'] ?? 'Event')],
                    ),
                    const SizedBox(height: 16),
                    _buildFilterLabel('Sortierung'),
                    const SizedBox(height: 8),
                    _buildDropdown(selectedSort, ['Schnellste zuerst', 'Langsamste zuerst', 'Neueste zuerst'], (val) {
                      setState(() => selectedSort = val!);
                      _loadLeaderboard();
                    }),
                  ],
                ),
              ),
            if (selectedTab == 'Sessions') const SizedBox(height: 20),

            // Leaderboard List
            Expanded(
              child: _entries.isEmpty
                  ? const Center(child: Text("Keine Daten vorhanden"))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final dbEntry = _entries[index];
                  String name = dbEntry['username'] ?? dbEntry['userRealName'] ?? 'Unbekannt';
                  String mainValue = '';
                  String subValue = '';

                  if (selectedTab == 'Sessions') {
                    mainValue = _formatDuration(dbEntry['durationMS']);
                    subValue = '${(dbEntry['volumeML'] / 1000).toStringAsFixed(2)} L • ${_formatDate(dbEntry['startedAt'])}';
                  } else if (selectedTab == 'Ø Zeit') {
                    mainValue = '${(dbEntry['avgValue'] / 1000).toStringAsFixed(2)}s';
                    subValue = 'Durchschnitt pro Liter';
                  } else if (selectedTab == 'Anzahl') {
                    mainValue = '${dbEntry['avgValue']}x';
                    subValue = 'Trichterungen gesamt';
                  } else if (selectedTab == 'Volumen') {
                    mainValue = '${(dbEntry['avgValue'] / 1000).toStringAsFixed(1)} L';
                    subValue = 'Gesamtvolumen';
                  }

                  return _buildLeaderboardEntry(index + 1, name, mainValue, subValue);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hilfsmethoden für UI
  Widget _buildFilterLabel(String label) => Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500));

  String _formatDuration(int ms) => '${(ms / 1000).toStringAsFixed(2)}s';

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      return DateFormat('dd.MM.').format(DateTime.parse(iso));
    } catch (e) {
      return '';
    }
  }

  Widget _buildTabButton(String label, IconData icon) {
    final isSelected = selectedTab == label;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => selectedTab = label);
          _loadLeaderboard();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isSelected ? const Color(0xFFFF9500) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey[600]),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String value, List<String> items, void Function(String?) onChanged, {List<String>? names}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: DropdownButton<String>(
        value: items.contains(value) ? value : items.first,
        isExpanded: true,
        underline: const SizedBox(),
        items: List.generate(items.length, (i) {
          return DropdownMenuItem(value: items[i], child: Text(names != null ? names[i] : items[i]));
        }),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildVolumeChip(String label) {
    final isSelected = selectedVolume == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => selectedVolume = label);
          _loadLeaderboard();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: isSelected ? const Color(0xFFFF9500) : Colors.grey[100], borderRadius: BorderRadius.circular(8)),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey[700])),
        ),
      ),
    );
  }

  Widget _buildLeaderboardEntry(int rank, String name, String value, String sub) {
    Color rankColor = rank == 1 ? const Color(0xFFFFD700) : (rank == 2 ? const Color(0xFFC0C0C0) : (rank == 3 ? const Color(0xFFCD7F32) : Colors.grey));
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: rankColor.withOpacity(0.1), child: Text('$rank', style: TextStyle(color: rankColor, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(sub, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ]),
          ),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF9500))),
        ],
      ),
    );
  }
}