import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/models/session.dart';
import 'package:project_camel/models/event.dart';
import 'package:project_camel/providers.dart';
import 'package:project_camel/screens/session_screen.dart';
import 'package:project_camel/widgets/pie_chart.dart';
import 'package:project_camel/widgets/session_list.dart';
import '../auth/auth_providers.dart';
import 'settings_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // ===========================================================================
  // 1. STATE & VARIABLES
  // ===========================================================================

  int? get selectedVolumeML {
    switch (ref.watch(volumeFilterProvider)) {
      case VolumeFilter.koelsch:
        return 200;
      case VolumeFilter.l033:
        return 330;
      case VolumeFilter.l05:
        return 500;
      case VolumeFilter.all:
        return null;
    }
  }

  final _scrollController = ScrollController();
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 2. LOGIC & ACTIONS
  // ===========================================================================

  // void _showGraph(Map<String, dynamic> session) {
  //   final String? valuesJson = session['valuesJSON'] as String?;
  //   final num? rawVolumeFactor = session['calibrationFactor'] as num?;
  //   final int? volumeCalibrationFactor = rawVolumeFactor?.toInt();

  //   final List<dynamic> allValues =
  //       valuesJson != null ? jsonDecode(valuesJson) : [];
  //   final List<dynamic> graphValues =
  //       allValues.length > 1 ? allValues.sublist(1) : [];
  //   final String graphValuesJson = jsonEncode(graphValues);

  //   if (valuesJson != null && volumeCalibrationFactor != null) {
  //     showGeneralDialog(
  //       context: context,
  //       barrierDismissible: true,
  //       barrierLabel: 'Graph',
  //       transitionDuration: const Duration(milliseconds: 400),
  //       pageBuilder: (context, anim1, anim2) => Container(),
  //       transitionBuilder: (context, anim1, anim2, child) {
  //         return ScaleTransition(
  //           scale: anim1,
  //           child: Padding(
  //             padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
  //             child: SessionGraphScreen(
  //               valuesJson: graphValuesJson,
  //               volumeCalibrationValue: volumeCalibrationFactor,
  //             ),
  //           ),
  //         );
  //       },
  //     );
  //   } else {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //           content: Text('Keine Graphendaten für diese Session verfügbar.'),
  //           backgroundColor: Colors.amber),
  //     );
  //   }
  // }

  // void _confirmDeleteSession(Session session) {
  //   final sessionName = session.name ?? 'diese Session';
  //   final sessionID = session.id;

  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Session löschen?'),
  //       content: Text('Möchtest du "$sessionName" wirklich löschen?'),
  //       actions: [
  //         TextButton(
  //             onPressed: () => Navigator.pop(context),
  //             child: const Text('Abbrechen')),
  //         TextButton(
  //           onPressed: () async {
  //             await ref
  //                 .read(sessionRepositoryProvider)
  //                 .markSessionAsDeleted(sessionID);
  //             if (mounted) Navigator.pop(context);
  //           },
  //           child: const Text('Löschen', style: TextStyle(color: Colors.red)),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // ===========================================================================
  // 3. UI BUILD METHOD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    if (authState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final userId = authState.userId!;
    final userAsync = ref.watch(userByIdProvider(userId));
    final userSessionsAsync = ref.watch(sessionsByUserIDProvider(userId));
    final userTopEvents = ref.watch(topEventsByUserProvider(userId));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: userAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary),
          ),
          error: (e, _) => Center(child: Text('Fehler: $e')),
          data: (user) {
            if (user == null) return _buildNoUserUI();

            // Render sessions only when they are ready to avoid flicker and fake empties
            return userSessionsAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary),
              ),
              error: (e, _) =>
                  Center(child: Text('Fehler beim Laden der Historie: $e')),
              data: (allSessions) {
                // top events are optional — use .asData to avoid blocking the UI
                final List<EventStats>? topEvents = userTopEvents.asData?.value;
                final EventStats? mostFrequentEvent =
                    (topEvents != null && topEvents.isNotEmpty)
                        ? topEvents.first
                        : null;

                // --- FILTERUNG ---
                List<Session> filteredSessions = allSessions;
                if (selectedVolumeML != null) {
                  filteredSessions = allSessions
                      .where((s) => s.volumeML == selectedVolumeML)
                      .toList();
                }

                // --- BERECHNUNGEN ---
                int totalCount = filteredSessions.length;
                double totalVolumeL = filteredSessions.fold(
                    0.0, (sum, s) => sum + s.volumeLiters);

                String fastestTime = "0.00s";
                if (filteredSessions.isNotEmpty) {
                  int minMS = filteredSessions
                      .map((s) => s.durationMS)
                      .reduce((a, b) => (a != 0 && a < b) ? a : b);
                  fastestTime = "${(minMS / 1000).toStringAsFixed(2)} s";
                }

                String avgTime = "N/A";
                if (filteredSessions.isNotEmpty &&
                    ref.watch(volumeFilterProvider) != VolumeFilter.all) {
                  double avgMS = filteredSessions
                          .map((s) => s.durationMS)
                          .reduce((a, b) => a + b) /
                      filteredSessions.length;
                  avgTime = "${(avgMS / 1000).toStringAsFixed(2)} s";
                }

                return SingleChildScrollView(
                  controller: _scrollController,

                  // Padding angepasst: Oben weniger (10), da der Button Platz braucht
                  padding: const EdgeInsets.only(
                      left: 20, right: 20, top: 10, bottom: 20),
                  child: Column(
                    children: [
                      // -----------------------------------------------------------
                      // SETTINGS BUTTON (Scrollt jetzt mit!)
                      // -----------------------------------------------------------
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen()),
                            );
                          },
                          icon: const Icon(Icons.settings),
                          tooltip: 'Einstellungen',
                        ),
                      ),

                      // -----------------------------------------------------------
                      // PROFIL INHALT
                      // -----------------------------------------------------------
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

                      // Filter Chips
                      _buildFilterHeader(),
                      Row(
                        children: [
                          _buildVolumeChip('Alle', VolumeFilter.all),
                          const SizedBox(width: 12),
                          _buildVolumeChip('Kölsch', VolumeFilter.koelsch),
                          const SizedBox(width: 12),
                          _buildVolumeChip('0,33 L', VolumeFilter.l033),
                          const SizedBox(width: 12),
                          _buildVolumeChip('0,5 L', VolumeFilter.l05),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Statistiken Grid
                      _buildStatsGrid(
                          totalCount, fastestTime, avgTime, totalVolumeL),
                      const SizedBox(height: 24),

                      // Kuchendiagramm
                      _buildPieChartCard(),
                      const SizedBox(height: 24),

                      // Meistgetrichtert Event
                      _buildMostEventCard(mostFrequentEvent),
                      const SizedBox(height: 24),

                      _buildSessionHistory(AsyncValue.data(allSessions)),

                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. HELPER WIDGETS
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // UI für nicht eingeloggte User
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Runder Avatar mit Initialen
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Überschrift für den Filter-Bereich
  // ---------------------------------------------------------------------------
  Widget _buildFilterHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 16, bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(Icons.water_drop,
              size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Filter nach Volumen',
            style: TextStyle(
              fontSize: Theme.of(context).textTheme.titleMedium?.fontSize,
              //fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Einzelner Filter-Chip (z.B. "0,33 L")
  // ---------------------------------------------------------------------------
  Widget _buildVolumeChip(String text, VolumeFilter label) {
    final isSelected = ref.watch(volumeFilterProvider) == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(volumeFilterProvider.notifier).setFilter(label),
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
          child: Text(text,
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

  // ---------------------------------------------------------------------------
  // Das 2x2 Grid für die Statistiken (Count, Bestzeit, Avg, Volumen)
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Einzelne Karte innerhalb des Statistik-Grids
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Karte für das Kuchendiagramm
  // ---------------------------------------------------------------------------
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
          const SizedBox(
            height: 220, // adjust as you like
            width: double.infinity,
            child: PieChartSample2(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Karte für das häufigste Event
  // ---------------------------------------------------------------------------
  Widget _buildMostEventCard(EventStats? mostEvent) {
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
                      Text(mostEvent.eventName,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500)),
                      Text(
                          'Gesamt: ${(mostEvent.totalVolumeL).toStringAsFixed(1)}L',
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
                  child: Text('${mostEvent.sessionCount}x',
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

  //               String dateStr = "Unbekannt";
  //               try {
  //                 dateStr = DateFormat('dd.MM.yyyy')
  //                     .format(DateTime.parse(s['startedAt']));
  //               } catch (_) {}

  //               return _buildHistoryItem(
  //                 session: s,
  //                 date: dateStr,
  //                 event: s['eventName'] ?? 'Privat',
  //                 time: '${timeS.toStringAsFixed(2)}s',
  //                 volume: '${volL.toStringAsFixed(2)}L',
  //                 flow: '${flow.toStringAsFixed(3)} L/s',
  //               );
  //             },
  //           ),
  //       ],
  //     ),
  //   );
  // }

//   Widget _buildHistoryItem(Session session) {
//   return SessionListTile(
//     session: session,
//     onEdit: () {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => SessionScreen()//(session: session),
//         ),
//       ).then((_) => _reloadData());
//     },
//     onDelete: () => _confirmDeleteSession(session),
//     onShowGraph: () => _showGraph(session),
//   );
// }

  Widget _buildSessionHistory(AsyncValue<List<Session>> allSessionsAsync) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Text(
            'Verlauf',
            style: TextStyle(
              fontSize: Theme.of(context).textTheme.titleMedium?.fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Content from provider
        allSessionsAsync.when(
          loading: () => SizedBox(
            width: double.infinity,
            child: Center(
              child: CircularProgressIndicator(color: cs.primary),
            ),
          ),
          error: (err, stack) => Text(
            'Fehler beim Laden der Historie',
            style: TextStyle(color: cs.error),
          ),
          data: (sessions) {
            if (sessions.isEmpty) {
              return Text(
                'Keine Sessions in der Historie',
                style: TextStyle(color: cs.onSurfaceVariant),
              );
            }

            // Just your list, full width, no extra card styling
            return SizedBox(
              width: double.infinity,
              child: SessionList(
                key: const PageStorageKey('sessionsByUserList'),
                sessions: sessions,
                embedded: true, // important so it plays nice in the Column
                onSessionTap: (session) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => (SessionScreen(
                          session: session)), // or SessionDetailsScreen
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
