import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../providers/leaderboard_filters_provider.dart';
import '../repositories/sesion_repository.dart';
import '../widgets/leaderboard/leaderboard_filter_bar.dart';
import '../widgets/leaderboard/leaderboard_runs_tab.dart';
import '../widgets/leaderboard/leaderboard_aggregated_tab.dart';

// Enum for tab selection and metric display
enum LeaderboardMetric { sessions, avgTime, count, volume }

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // User and event lists for filter bar
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allEvents = [];

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
    }
  }

  /// Build params for Riverpod provider (Runs tab)
  LeaderboardParams _currentParams(LeaderboardFilters filters) {
    final sortEnum = _mapSortStringToEnum(filters.sortOrder);
    final volumeML = _parseVolume(filters.volume);
    final eventID = filters.eventID == 'Alle' ? null : filters.eventID;
    // Don't spread the Set; use it directly (immutable in filters)
    final userIDs = filters.userIDs.isEmpty ? null : filters.userIDs;

    return (
      sort: sortEnum,
      userIDs: userIDs,
      volumeML: volumeML,
      eventID: eventID,
      limit: null,
      offset: null,
    );
  }

  /// Map UI sort string to LeaderboardSort enum
  LeaderboardSort _mapSortStringToEnum(String sortString) {
    return switch (sortString) {
      'Schnellste zuerst' => LeaderboardSort.fastest,
      'Langsamste zuerst' => LeaderboardSort.slowest,
      'Neueste zuerst' => LeaderboardSort.newest,
      _ => LeaderboardSort.fastest,
    };
  }

  /// Parse volume filter to ml value
  int? _parseVolume(VolumeFilter volumeFilter) {
    return switch (volumeFilter) {
      VolumeFilter.all => null,
      VolumeFilter.koelsch => 200,
      VolumeFilter.l033 => 330,
      VolumeFilter.l05 => 500,
    };
  }

  Future<void> _loadInitialData() async {
    try {
      final dbHelper = ref.read(databaseHelperProvider);
      final results = await Future.wait([
        dbHelper.getUsers(),
        dbHelper.getEvents(),
      ]);

      if (mounted) {
        setState(() {
          _allUsers = results[0];
          _allEvents = results[1];
        });
      }
    } catch (e) {
      debugPrint("Error loading initial data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Watch filter state from provider
    final filters = ref.watch(leaderboardFiltersProvider);
    final filtersNotifier = ref.read(leaderboardFiltersProvider.notifier);

    return Scaffold(
      backgroundColor: colorScheme.surface,

      // 1. APP BAR WITH PRIMARY TABS
      appBar: AppBar(
        title: Text('Leaderboard',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: colorScheme.primary)),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        scrolledUnderElevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
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
          LeaderboardFilterBar(
            isRunsTab: _tabController.index == 0,
            hasActiveFilters: filters.hasActive,
            selectedSortOrder: filters.sortOrder,
            selectedUserIDs: filters.userIDs,
            selectedVolume: filters.volume,
            selectedEventID: filters.eventID,
            allUsers: _allUsers,
            allEvents: _allEvents,
            onResetFilters: () {
              filtersNotifier.reset();
            },
            onSortChanged: (val) {
              filtersNotifier.setSortOrder(val);
            },
            onUserSelectionChanged: (val) {
              filtersNotifier.toggleUser(val);
            },
            onVolumeChanged: (val) {
              filtersNotifier.setVolume(val);
            },
            onEventChanged: (val) {
              filtersNotifier.setEvent(val);
            },
          ),

          // 3. CONTENT
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Runs tab: Uses leaderboardSessionsProvider
                LeaderboardRunsTab(params: _currentParams(filters)),
                // Aggregated tabs: Use dedicated provider families
                LeaderboardAggregatedTab(
                  params: _buildParamsForMetric(filters),
                  metric: LeaderboardMetric.avgTime,
                  getAsyncData: (ref) => ref.watch(
                      leaderboardAvgSecondsPerLiterProvider(
                          _buildParamsForMetric(filters))),
                ),
                LeaderboardAggregatedTab(
                  params: _buildParamsForMetric(filters),
                  metric: LeaderboardMetric.count,
                  getAsyncData: (ref) => ref.watch(
                      leaderboardSessionCountProvider(
                          _buildParamsForMetric(filters))),
                ),
                LeaderboardAggregatedTab(
                  params: _buildParamsForMetric(filters),
                  metric: LeaderboardMetric.volume,
                  getAsyncData: (ref) => ref.watch(
                      leaderboardTotalVolumeProvider(
                          _buildParamsForMetric(filters))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build params for aggregation providers (no volumeML or sort, no limit/offset)
  LeaderboardParams _buildParamsForMetric(LeaderboardFilters filters) {
    final eventID = filters.eventID == 'Alle' ? null : filters.eventID;
    final volumeML = _parseVolume(filters.volume);
    final userIDs = filters.userIDs.isEmpty ? null : filters.userIDs;

    return (
      sort: LeaderboardSort.fastest, // unused for aggregation, but required
      userIDs: userIDs,
      volumeML: volumeML,
      eventID: eventID,
      limit: null,
      offset: null,
    );
  }
}
