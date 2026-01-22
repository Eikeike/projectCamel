import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart'; // NEU
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/models/session.dart';
import 'package:project_camel/models/event.dart';
import 'package:project_camel/providers.dart';
import 'package:project_camel/screens/event_edit_screen.dart';
// import 'package:project_camel/screens/new_session_screen.dart';
import 'package:project_camel/widgets/pie_chart.dart';
import 'package:project_camel/widgets/session_list.dart';
import '../auth/auth_providers.dart';
import '../screens/new_session_screen.dart';
import 'settings_screen.dart';

// ===========================================================================
// DATA OBJECT FOR VIEW STATS
// ===========================================================================
class _ProfileViewStats {
  final int count;
  final double totalVolumeL;
  final String fastestTime;
  final String avgText;
  final String avgLabel;
  final List<Session> filteredSessions;

  const _ProfileViewStats({
    required this.count,
    required this.totalVolumeL,
    required this.fastestTime,
    required this.avgText,
    required this.avgLabel,
    required this.filteredSessions,
  });
}

// ===========================================================================
// INTERNAL PROVIDER
// ===========================================================================
final _profileStatsProvider = Provider.autoDispose
    .family<_ProfileViewStats, List<Session>>((ref, allSessions) {
  final currentFilter = ref.watch(volumeFilterProvider);

  // 1. Filter Logic
  int? targetMl;
  switch (currentFilter) {
    case VolumeFilter.koelsch:
      targetMl = 200;
      break;
    case VolumeFilter.l033:
      targetMl = 330;
      break;
    case VolumeFilter.l05:
      targetMl = 500;
      break;
    case VolumeFilter.all:
      targetMl = null;
      break;
  }

  final filteredSessions = targetMl != null
      ? allSessions.where((s) => s.volumeML == targetMl).toList()
      : allSessions;

  // 2. Calculation Logic
  final totalCount = filteredSessions.length;
  double totalVolumeL = 0.0;

  int minMS =
      filteredSessions.isNotEmpty ? filteredSessions.first.durationMS : 0;

  for (var s in filteredSessions) {
    totalVolumeL += s.volumeLiters;
    if (s.durationMS > 0 && (minMS == 0 || s.durationMS < minMS)) {
      minMS = s.durationMS;
    }
  }

  String fastestTime = "0.00s";
  if (filteredSessions.isNotEmpty && minMS > 0) {
    fastestTime = "${(minMS / 1000).toStringAsFixed(2)} s";
  }

  String avgText = "N/A";
  String avgLabel = "Durchschnitt";

  if (filteredSessions.isNotEmpty) {
    if (currentFilter == VolumeFilter.all) {
      double totalSpeed = 0.0;
      int validSessions = 0;
      for (var s in filteredSessions) {
        if (s.durationMS > 0) {
          totalSpeed += s.volumeLiters / (s.durationMS / 1000);
          validSessions++;
        }
      }
      if (validSessions > 0) {
        avgText = "${(totalSpeed / validSessions).toStringAsFixed(3)} L/s";
        avgLabel = "Ø Speed";
      }
    } else {
      double totalMS = 0.0;
      for (var s in filteredSessions) {
        totalMS += s.durationMS;
      }
      avgText =
          "${(totalMS / filteredSessions.length / 1000).toStringAsFixed(2)} s";
      avgLabel = "Ø Zeit";
    }
  }

  return _ProfileViewStats(
    count: totalCount,
    totalVolumeL: totalVolumeL,
    fastestTime: fastestTime,
    avgText: avgText,
    avgLabel: avgLabel,
    filteredSessions: filteredSessions,
  );
});

// ===========================================================================
// MAIN SCREEN
// ===========================================================================

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authLoading =
        ref.watch(authControllerProvider.select((s) => s.isLoading));
    if (authLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userId = ref.watch(authControllerProvider.select((s) => s.userId));
    if (userId == null) return _buildNoUserUI(context);

    final userAsync = ref.watch(userByIdProvider(userId));
    final userSessionsAsync = ref.watch(sessionsByUserIDProvider(userId));
    final userTopEventsAsync = ref.watch(topEventsByUserProvider(userId));

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
            if (user == null) return _buildNoUserUI(context);

            return userSessionsAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary),
              ),
              error: (e, _) =>
                  Center(child: Text('Fehler beim Laden der Historie: $e')),
              data: (allSessions) {
                final topEvents = userTopEventsAsync.asData?.value;
                final mostFrequentEvent =
                    (topEvents != null && topEvents.isNotEmpty)
                        ? topEvents.first
                        : null;

                return SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    children: [
                      const _SettingsButton(),

                      // Statische User Info
                      _UserInfoHeader(user: user),
                      const SizedBox(height: 24),

                      // Filter Section
                      const _FilterSection(),
                      const SizedBox(height: 24),

                      // Stats Grid
                      _StatsSection(allSessions: allSessions),
                      const SizedBox(height: 24),

                      // Charts
                      RepaintBoundary(
                        child: _PieChartSection(allSessions: allSessions),
                      ),
                      const SizedBox(height: 24),

                      // MAP CARD (Nur Light Mode)
                      _LocationsCard(sessions: allSessions),
                      const SizedBox(height: 24),

                      // Top Event
                      _MostEventCard(mostEvent: mostFrequentEvent),
                      const SizedBox(height: 24),

                      // History
                      _HistorySection(sessions: allSessions),
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

  Widget _buildNoUserUI(BuildContext context) {
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
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary),
            child: const Text('Erneut versuchen',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// SUB-WIDGETS
// ===========================================================================

class _LocationsCard extends StatelessWidget {
  final List<Session> sessions;

  const _LocationsCard({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // 1. Prepare data
    final validPoints = sessions
        .where((s) =>
            s.latitude != 0 &&
            s.longitude != 0 &&
            s.latitude != null &&
            s.longitude != null)
        .map((s) => LatLng(s.latitude!, s.longitude!))
        .toList();

    if (validPoints.isEmpty) return const SizedBox.shrink();

    // 2. Create Markers
    final List<Marker> markers = validPoints.map((point) {
      return Marker(
        point: point,
        width: 30,
        height: 30,
        child: Icon(
          Icons.location_on,
          color: theme.colorScheme.primary,
          size: 30,
        ),
      );
    }).toList();

    // --- ÄNDERUNG: Wähle die URL basierend auf dem Theme ---
    // CartoDB Positron (Hell) vs. CartoDB Dark Matter (Dunkel)
    final mapUrl = isDarkMode
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.map_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Trichter-Orte',
                    style: TextStyle(
                      fontSize: theme.textTheme.titleMedium?.fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '${validPoints.length} Orte',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // The Map
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 250,
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: validPoints,
                  padding: const EdgeInsets.all(50),
                  maxZoom: 15.0,
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                // --- ÄNDERUNG: Einfachere TileLayer Struktur ---
                TileLayer(
                  urlTemplate: mapUrl,
                  userAgentPackageName: 'com.example.project_camel',
                  // WICHTIG für CartoDB:
                  subdomains: const ['a', 'b', 'c', 'd'],
                ),

                // Clustering
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 45,
                    size: const Size(40, 40),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(50),
                    markers: markers,
                    builder: (context, markers) {
                      return Container(
                        decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3))
                            ]),
                        alignment: Alignment.center,
                        child: Text(
                          markers.length.toString(),
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // --- ÄNDERUNG: Korrekte Attribution für CartoDB ---
                RichAttributionWidget(
                  animationConfig: const ScaleRAWA(),
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () {}, // Hier ggf. Link öffnen logic einfügen
                    ),
                    TextSourceAttribution(
                      '© CARTO',
                      onTap: () {}, // Hier ggf. Link auf carto.com
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
        icon: const Icon(Icons.settings),
        tooltip: 'Einstellungen',
      ),
    );
  }
}

class _UserInfoHeader extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserInfoHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user['name'] ?? user['firstname'] ?? 'Unbekannt';
    final username = user['username'] ?? 'user';
    final String initial = name.toString().isNotEmpty
        ? name[0]
        : (user['firstname']?.toString().isNotEmpty == true
            ? user['firstname'][0]
            : 'U');

    return Column(
      children: [
        _UserAvatar(initial: initial),
        const SizedBox(height: 16),
        Text(
          name,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        Text(
          '@$username',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String initial;
  const _UserAvatar({required this.initial});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primaryContainer.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initial.toUpperCase(),
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 16, bottom: 10),
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
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const Row(
          children: [
            _VolumeChip(text: 'Alle', value: VolumeFilter.all),
            SizedBox(width: 12),
            _VolumeChip(text: 'Kölsch', value: VolumeFilter.koelsch),
            SizedBox(width: 12),
            _VolumeChip(text: '0,33 L', value: VolumeFilter.l033),
            SizedBox(width: 12),
            _VolumeChip(text: '0,5 L', value: VolumeFilter.l05),
          ],
        ),
      ],
    );
  }
}

class _VolumeChip extends ConsumerWidget {
  final String text;
  final VolumeFilter value;

  const _VolumeChip({required this.text, required this.value});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(volumeFilterProvider) == value;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(volumeFilterProvider.notifier).setFilter(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.surfaceContainer,
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsSection extends ConsumerWidget {
  final List<Session> allSessions;

  const _StatsSection({required this.allSessions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(_profileStatsProvider(allSessions));

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.emoji_events,
                label: 'Trichterungen',
                value: '${stats.count}',
                subtitle: 'Trichterungen',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.timer,
                label: 'Bestzeit',
                value: stats.fastestTime,
                subtitle: 'Zeit',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.av_timer,
                label: stats.avgLabel,
                value: stats.avgText,
                subtitle: 'Zeit',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.sports_bar,
                label: 'Gesamtvolumen',
                value: '${stats.totalVolumeL.toStringAsFixed(1)} L',
                subtitle: 'Gesamt',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: theme.colorScheme.onPrimaryContainer,
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
                    fontSize: theme.textTheme.titleMedium?.fontSize,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: theme.textTheme.bodySmall?.fontSize,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PieChartSection extends StatelessWidget {
  final List<Session> allSessions;
  const _PieChartSection({required this.allSessions});

  @override
  Widget build(BuildContext context) {
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
            height: 220,
            width: double.infinity,
            child: PieChartSample2(sessions: allSessions),
          ),
        ],
      ),
    );
  }
}

class _MostEventCard extends ConsumerWidget {
  final EventStats? mostEvent;
  const _MostEventCard({required this.mostEvent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final eventAsync = (mostEvent == null)
        ? const AsyncValue<Event?>.data(null)
        : ref.watch(eventByIdProvider(mostEvent!.eventId));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Meistgetrichtert',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (mostEvent == null)
            Text(
              'Noch keine Daten vorhanden',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            )
          else
            eventAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text(
                'Event konnte nicht geladen werden: $e',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              data: (event) {
                if (event == null) {
                  return Text(
                    'Event nicht gefunden',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  );
                }

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EventEditScreen(event: event),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Gesamt: ${mostEvent!.totalVolumeL.toStringAsFixed(1)}L',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${mostEvent!.sessionCount}x',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  final List<Session> sessions;
  const _HistorySection({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (sessions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(context),
          const SizedBox(height: 12),
          Text(
            'Keine Sessions in der Historie',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          )
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(context),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SessionList(
            key: const PageStorageKey('sessionsByUserList'),
            sessions: sessions,
            embedded: true,
            showAvatar: false,
            onSessionTap: (session) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SessionScreen(session: session),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        'Verlauf',
        style: TextStyle(
          fontSize: Theme.of(context).textTheme.titleMedium?.fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
