import 'package:flutter/material.dart';
import 'package:project_camel/screens/debug_screen.dart';
import 'package:project_camel/screens/new_event_screen.dart';
import 'package:project_camel/services/auto_sync_controller.dart';
import 'trichtern_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'event_screen.dart';
import 'new_session_screen.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.autoSyncController,
  });

  final AutoSyncController autoSyncController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  AutoSyncController get autoSyncController => widget.autoSyncController;

  final List<Widget> _screens = [
    const TrichternScreen(),
    const NewEventScreen(),
    const LeaderboardScreen(),
    const ProfileScreen(),
    const DebugScreen(),
    SessionScreen(
      durationMS: 4500,
      calculatedVolumeML: 500,
      // 200 Impulse entsprechen 0,5L (da wir 200 Zeitstempel im Array haben)
      calibrationFactor: 200.0,
      allValues: List.generate(200, (i) {
        double x = i / 199.0;
        // Eine Glockenkurve verändert die Dichte der Zeitstempel
        // Wir nutzen eine Sinus-Verteilung für die Zeitabstände
        double speedFactor = 1.0 + 1.5 * math.sin(x * 3.14159);

        // Die Zeitstempel rücken in der Mitte näher zusammen
        return (1000 + (x * 4500 / speedFactor)).toInt();
      })
        ..sort(),
    )
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            autoSyncController.triggerSync();
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.sports_bar),
              label: 'Trichtern',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event),
              label: 'Events',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events),
              label: 'Leaderboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bug_report),
              label: 'DEBUG',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tram_outlined),
              label: 'Session',
            ),
          ],
        ),
      ),
    );
  }
}
