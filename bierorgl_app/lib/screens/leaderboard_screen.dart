import 'package:flutter/material.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String selectedTab = 'Sessions';
  String selectedUser = 'Alle';
  String selectedVolume = 'Alle';
  String selectedEvent = 'Alle';
  String selectedSort = 'Schnellste zuerst';

  // Mock Data
  final List<Map<String, dynamic>> mockEntries = [
    {
      'name': 'Lisa',
      'event': 'Felix Geburtstag',
      'date': '15.06.',
      'location': 'Hamburg',
      'time': '1.92s',
      'volume': '0.33 L',
      'rank': 1,
    },
    {
      'name': 'Max',
      'event': 'Hurricane Festival 2025',
      'date': '21.06.',
      'location': 'Scheeßel',
      'time': '2.83s',
      'volume': '0.5 L',
      'rank': 2,
    },
    {
      'name': 'Tom',
      'event': '',
      'date': '10.06.',
      'location': 'Berlin',
      'time': '3.21s',
      'volume': '0.5 L',
      'rank': 3,
    },
    {
      'name': 'jonas',
      'event': '',
      'date': '11.11.',
      'location': 'Hamburg',
      'time': '3.6s',
      'volume': '0.5 L',
      'rank': 4,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Leaderboard',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF9500),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Die besten Trichterungen',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
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

            // Filters Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User & Volume Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nutzer',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDropdown(selectedUser, ['Alle', 'Lisa', 'Max', 'Tom'], (val) {
                              setState(() => selectedUser = val!);
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Volumen',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildVolumeChip('Alle', selectedVolume == 'Alle'),
                                const SizedBox(width: 8),
                                _buildVolumeChip('0,33', selectedVolume == '0,33'),
                                const SizedBox(width: 8),
                                _buildVolumeChip('0,5', selectedVolume == '0,5'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Event Dropdown
                  Text(
                    'Event',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDropdown(selectedEvent, ['Alle', 'Felix Geburtstag', 'Hurricane Festival 2025'], (val) {
                    setState(() => selectedEvent = val!);
                  }),
                  const SizedBox(height: 16),

                  // Sort Dropdown
                  Text(
                    'Sortierung',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDropdown(selectedSort, ['Schnellste zuerst', 'Langsamste zuerst', 'Neueste zuerst'], (val) {
                    setState(() => selectedSort = val!);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Leaderboard List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: mockEntries.length,
                itemBuilder: (context, index) {
                  final entry = mockEntries[index];
                  return _buildLeaderboardEntry(entry);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon) {
    final isSelected = selectedTab == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF9500) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String value, List<String> items, void Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildVolumeChip(String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedVolume = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF9500) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardEntry(Map<String, dynamic> entry) {
    IconData rankIcon;
    Color rankColor;

    if (entry['rank'] == 1) {
      rankIcon = Icons.emoji_events;
      rankColor = const Color(0xFFFFD700);
    } else if (entry['rank'] == 2) {
      rankIcon = Icons.emoji_events;
      rankColor = const Color(0xFFC0C0C0);
    } else if (entry['rank'] == 3) {
      rankIcon = Icons.military_tech;
      rankColor = const Color(0xFFCD7F32);
    } else {
      rankIcon = Icons.tag;
      rankColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: entry['rank'] <= 3
                  ? Icon(rankIcon, color: rankColor, size: 24)
                  : Text(
                '#${entry['rank']}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (entry['event'].isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          entry['event'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      entry['date'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 2),
                    Text(
                      entry['location'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry['time'],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF9500),
                ),
              ),
              Text(
                entry['volume'],
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}