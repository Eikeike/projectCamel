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
          ],
        ),
      ),
    );
  }
}
