import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

// Enum for type safety
enum LeaderboardMetric { sessions, avgTime, count, volume }

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Keys to programmatically open Dropdown Menus
  final GlobalKey<PopupMenuButtonState> _sortKey = GlobalKey();
  final GlobalKey<PopupMenuButtonState> _volumeKey = GlobalKey();
  final GlobalKey<PopupMenuButtonState> _eventKey = GlobalKey();
  final GlobalKey<PopupMenuButtonState> _userKey = GlobalKey();

  late TabController _tabController;

  // Filter State
  Set<String> _selectedUserIDs = {};
  String _selectedVolume = 'Alle';
  String _selectedEventID = 'Alle';
  String _selectedSortOrder = 'Schnellste zuerst';

  // Data
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging ||
        _tabController.index != _tabController.previousIndex) {
      if (mounted) setState(() {});
      _loadLeaderboard();
    }
  }

  LeaderboardMetric _getMetricFromIndex(int index) {
    return LeaderboardMetric.values.elementAt(index);
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _dbHelper.getUsers(),
        _dbHelper.getEvents(),
      ]);

      if (mounted) {
        setState(() {
          _allUsers = results[0];
          _allEvents = results[1];
        });
        _loadLeaderboard();
      }
    } catch (e) {
      debugPrint("Error loading initial data: $e");
    }
  }

  Future<void> _loadLeaderboard() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> data;
      final currentMetric = _getMetricFromIndex(_tabController.index);

      switch (currentMetric) {
        case LeaderboardMetric.avgTime:
          data = await _dbHelper.getLeaderboardAverage();
          break;
        case LeaderboardMetric.count:
          data = await _dbHelper.getLeaderboardCount();
          break;
        case LeaderboardMetric.volume:
          data = await _dbHelper.getLeaderboardTotalVolume();
          break;
        case LeaderboardMetric.sessions:
        default:
          int? vol;
          if (_selectedVolume == '0,33') vol = 330;
          if (_selectedVolume == '0,5') vol = 500;

          String userFilter =
              _selectedUserIDs.isEmpty ? 'Alle' : _selectedUserIDs.join(',');

          data = await _dbHelper.getLeaderboardData(
            userID: userFilter,
            volumeML: vol,
            eventID: _selectedEventID,
            sortBy: _selectedSortOrder,
          );
      }

      if (mounted) {
        setState(() {
          _entries = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading leaderboard: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Check if any filter is active
    bool hasActiveFilters = _selectedUserIDs.isNotEmpty ||
        _selectedVolume != 'Alle' ||
        _selectedEventID != 'Alle';

    return Scaffold(
      backgroundColor: colorScheme.surface,

      // 1. APP BAR WITH PRIMARY TABS
      appBar: AppBar(
        title: const Text('Bestenliste',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        scrolledUnderElevation: 0,
        bottom: TabBar(
          controller: _tabController,
          // Fixed tabs (Primary Tabs style) filling the width
          isScrollable: false,
          // M3 Standard: Indicator matches tab width
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          // M3: Icon + Text stacked
          tabs: const [
            Tab(text: "Runs"),
            Tab(text: "Ø Zeit"),
            Tab(text: "Anzahl"),
            Tab(text: "Volumen"),
          ],
        ),
      ),

      body: Column(
        children: [
          // 2. FILTER BAR
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                  bottom: BorderSide(
                      color: colorScheme.outlineVariant.withOpacity(0.5))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Sort Filter (Only visible on 'Runs' tab)
                  if (_tabController.index == 0) ...[
                    _buildSortDropdown(),
                    const SizedBox(width: 8),
                    SizedBox(
                        height: 24,
                        child:
                            VerticalDivider(color: colorScheme.outlineVariant)),
                    const SizedBox(width: 8),
                  ],

                  // User Filter
                  _buildMultiSelectUserFilter(),
                  const SizedBox(width: 8),

                  // Volume Filter
                  _buildSingleSelectFilter(
                    key: _volumeKey,
                    label: 'Volumen',
                    currentValue: _selectedVolume,
                    items: ['0,33', '0,5'],
                    displayMap: {'0,33': '0,33 L', '0,5': '0,5 L'},
                    icon: Icons.local_drink,
                    onSelected: (val) {
                      setState(() => _selectedVolume = val);
                      _loadLeaderboard();
                    },
                  ),
                  const SizedBox(width: 8),

                  // Event Filter
                  _buildSingleSelectFilter(
                    key: _eventKey,
                    label: 'Event',
                    currentValue: _selectedEventID,
                    items:
                        _allEvents.map((e) => e['eventID'].toString()).toList(),
                    displayMap: {
                      for (var e in _allEvents)
                        e['eventID'].toString():
                            (e['name'] as String?) ?? 'Event'
                    },
                    icon: Icons.event,
                    onSelected: (val) {
                      setState(() => _selectedEventID = val);
                      _loadLeaderboard();
                    },
                  ),

                  // Reset Button
                  if (hasActiveFilters)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: IconButton.filledTonal(
                        onPressed: () {
                          setState(() {
                            _selectedUserIDs.clear();
                            _selectedVolume = 'Alle';
                            _selectedEventID = 'Alle';
                          });
                          _loadLeaderboard();
                        },
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Filter zurücksetzen',
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. CONTENT
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLeaderboardContent(LeaderboardMetric.sessions),
                _buildLeaderboardContent(LeaderboardMetric.avgTime),
                _buildLeaderboardContent(LeaderboardMetric.count),
                _buildLeaderboardContent(LeaderboardMetric.volume),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- CONTENT BUILDER ---
  Widget _buildLeaderboardContent(LeaderboardMetric metric) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_off,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text("Keine Ergebnisse",
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
    }

    final top3 = _entries.take(3).toList();
    final rest =
        _entries.length > 3 ? _entries.sublist(3) : <Map<String, dynamic>>[];

    return CustomScrollView(
      key: PageStorageKey(metric.toString()),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: _PodiumWidget(entries: top3, metric: metric),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => LeaderboardItem(
                  rank: index + 4, entry: rest[index], metric: metric),
              childCount: rest.length,
            ),
          ),
        ),
      ],
    );
  }

  // --- M3 FILTER COMPONENTS ---

  Widget _buildSortDropdown() {
    return PopupMenuButton<String>(
      key: _sortKey,
      tooltip: 'Sortierung',
      onSelected: (val) {
        setState(() => _selectedSortOrder = val);
        _loadLeaderboard();
      },
      itemBuilder: (context) => [
        _buildPopupItem(
            'Schnellste zuerst', _selectedSortOrder == 'Schnellste zuerst'),
        _buildPopupItem(
            'Langsamste zuerst', _selectedSortOrder == 'Langsamste zuerst'),
        _buildPopupItem(
            'Neueste zuerst', _selectedSortOrder == 'Neueste zuerst'),
      ],
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InputChip(
        label: Text(_selectedSortOrder),
        avatar: const Icon(Icons.sort, size: 18),
        selected: true,
        showCheckmark: false,
        onPressed: () => _sortKey.currentState?.showButtonMenu(),
        deleteIcon: const Icon(Icons.arrow_drop_down, size: 18),
        onDeleted: () => _sortKey.currentState?.showButtonMenu(),
      ),
    );
  }

  Widget _buildSingleSelectFilter({
    required GlobalKey<PopupMenuButtonState> key,
    required String label,
    required String currentValue,
    required List<String> items,
    required Map<String, String> displayMap,
    required IconData icon,
    required Function(String) onSelected,
  }) {
    final bool isActive = currentValue != 'Alle';

    return PopupMenuButton<String>(
      key: key,
      tooltip: '$label filtern',
      onSelected: onSelected,
      itemBuilder: (context) => items.map((val) {
        return _buildPopupItem(displayMap[val] ?? val, currentValue == val,
            value: val);
      }).toList(),
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InputChip(
        label:
            Text(isActive ? (displayMap[currentValue] ?? currentValue) : label),
        avatar: isActive ? null : Icon(icon, size: 18),
        selected: isActive,
        showCheckmark: false,
        deleteIcon:
            Icon(isActive ? Icons.close : Icons.arrow_drop_down, size: 18),
        onDeleted: () {
          if (isActive)
            onSelected('Alle');
          else
            key.currentState?.showButtonMenu();
        },
        onPressed: () => key.currentState?.showButtonMenu(),
      ),
    );
  }

  Widget _buildMultiSelectUserFilter() {
    final int count = _selectedUserIDs.length;
    final bool isActive = count > 0;

    String labelText = 'Nutzer';
    if (count == 1) {
      final uid = _selectedUserIDs.first;
      final user = _allUsers.firstWhere((u) => u['userID'].toString() == uid,
          orElse: () => <String, dynamic>{});
      labelText = (user['username'] as String?) ?? 'Unbekannt';
    } else if (count > 1) {
      labelText = '$count Nutzer';
    }

    return PopupMenuButton<String>(
      key: _userKey,
      tooltip: 'Nutzer wählen',
      onSelected: (val) {
        setState(() {
          if (_selectedUserIDs.contains(val))
            _selectedUserIDs.remove(val);
          else
            _selectedUserIDs.add(val);
        });
        _loadLeaderboard();
      },
      itemBuilder: (context) => _allUsers.map((u) {
        final id = u['userID'].toString();
        final name = (u['username'] as String?) ?? 'Unbekannt';
        return CheckedPopupMenuItem<String>(
          value: id,
          checked: _selectedUserIDs.contains(id),
          child: Text(name),
        );
      }).toList(),
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InputChip(
        label: Text(labelText),
        avatar: isActive ? null : const Icon(Icons.group, size: 18),
        selected: isActive,
        showCheckmark: false,
        deleteIcon:
            Icon(isActive ? Icons.close : Icons.arrow_drop_down, size: 18),
        onDeleted: () {
          if (isActive) {
            setState(() => _selectedUserIDs.clear());
            _loadLeaderboard();
          } else {
            _userKey.currentState?.showButtonMenu();
          }
        },
        onPressed: () => _userKey.currentState?.showButtonMenu(),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String text, bool isSelected,
      {String? value}) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuItem<String>(
      value: value ?? text,
      child: Row(
        children: [
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? colorScheme.primary : null))),
          if (isSelected)
            Icon(Icons.check, color: colorScheme.primary, size: 20),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PODIUM & ITEMS (Strict M3)
// ---------------------------------------------------------------------------

class _PodiumWidget extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final LeaderboardMetric metric;
  const _PodiumWidget({required this.entries, required this.metric});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return SizedBox(
      height: 280,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
              child: second != null
                  ? _buildPodiumColumn(context, second, 2, 100)
                  : const SizedBox()),
          const SizedBox(width: 8),
          Expanded(
              child: first != null
                  ? _buildPodiumColumn(context, first, 1, 140)
                  : const SizedBox()),
          const SizedBox(width: 8),
          Expanded(
              child: third != null
                  ? _buildPodiumColumn(context, third, 3, 70)
                  : const SizedBox()),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(BuildContext context, Map<String, dynamic> entry,
      int rank, double blockHeight) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFirst = rank == 1;

    final badgeColor = rank == 1
        ? const Color(0xFFFFD700)
        : (rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));

    final name = (entry['username'] as String?) ??
        (entry['userRealName'] as String?) ??
        'Unbekannt';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.topRight,
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeColor, width: 2),
                  boxShadow: isFirst
                      ? [
                          BoxShadow(
                              color: badgeColor.withOpacity(0.5),
                              blurRadius: 15)
                        ]
                      : []),
              child: CircleAvatar(
                  radius: isFirst ? 32 : 24,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  child: Text(initial,
                      style: TextStyle(
                          fontSize: isFirst ? 22 : 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant))),
            ),
            Positioned(
                top: -4,
                right: -4,
                child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5)),
                    alignment: Alignment.center,
                    child: Text('$rank',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)))),
          ],
        ),
        const SizedBox(height: 6),
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        Text(Formatter.formatValue(entry, metric),
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900, color: colorScheme.primary),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Container(
          height: blockHeight,
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    badgeColor.withOpacity(0.15),
                    colorScheme.surfaceContainer
                  ])),
          child: Align(
              alignment: Alignment.topCenter,
              child: Text(Formatter.formatSubValue(entry, metric),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis)),
        ),
      ],
    );
  }
}

class LeaderboardItem extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> entry;
  final LeaderboardMetric metric;
  const LeaderboardItem(
      {super.key,
      required this.rank,
      required this.entry,
      required this.metric});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final name = (entry['username'] as String?) ??
        (entry['userRealName'] as String?) ??
        'Unbekannt';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                width: 24,
                child: Text('#$rank',
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold))),
            const SizedBox(width: 8),
            CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.secondaryContainer,
                child: Text(initial,
                    style: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 14))),
          ],
        ),
        title: Text(name,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(Formatter.formatSubValue(entry, metric),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
        trailing: Text(Formatter.formatValue(entry, metric),
            style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.primary, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class Formatter {
  static String formatValue(
      Map<String, dynamic> entry, LeaderboardMetric metric) {
    final val = entry['avgValue'] ?? entry['durationMS'];
    if (val == null && metric != LeaderboardMetric.sessions) return '-';

    final numValue = (val is int) ? val : (int.tryParse(val.toString()) ?? 0);

    switch (metric) {
      case LeaderboardMetric.sessions:
        final duration = (entry['durationMS'] as int?) ?? 0;
        return '${(duration / 1000).toStringAsFixed(2)}s';
      case LeaderboardMetric.avgTime:
        return '${(numValue / 1000).toStringAsFixed(2)}s';
      case LeaderboardMetric.count:
        return '${numValue}x';
      case LeaderboardMetric.volume:
        return '${(numValue / 1000).toStringAsFixed(1)} L';
    }
  }

  static String formatSubValue(
      Map<String, dynamic> entry, LeaderboardMetric metric) {
    switch (metric) {
      case LeaderboardMetric.sessions:
        final vol = ((entry['volumeML'] as int?) ?? 0) / 1000;
        final date = _formatDate(entry['startedAt'] as String?);
        return '${vol.toStringAsFixed(2)} L • $date';
      case LeaderboardMetric.avgTime:
        return 'Durchschnitt / Liter';
      case LeaderboardMetric.count:
        return 'Gesamtanzahl';
      case LeaderboardMetric.volume:
        return 'Gesamtvolumen';
    }
  }

  static String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      return DateFormat('dd.MM.').format(DateTime.parse(iso));
    } catch (_) {
      return '';
    }
  }
}
