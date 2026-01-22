import 'package:flutter/material.dart';

class UserSelectionField extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final String? selectedUserID;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onAddGuest;
  final bool isEditing;

  const UserSelectionField({
    super.key,
    required this.users,
    required this.selectedUserID,
    required this.onChanged,
    this.onAddGuest,
    this.isEditing = true,
  });

  @override
  Widget build(BuildContext context) {
    String selectedUserName = 'Unbekannt';
    if (selectedUserID != null) {
      final foundUser = users.firstWhere(
        (u) => u['userID'] == selectedUserID,
        orElse: () => {},
      );
      if (foundUser.isNotEmpty) {
        selectedUserName =
            foundUser['username'] ?? foundUser['name'] ?? 'Unbekannt';
      }
    }

    final theme = Theme.of(context);

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Getrichtert von',
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        enabled: isEditing,
      ),
      child: isEditing
          ? _buildDropdown(context)
          : Text(
              selectedUserName,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.38),
                // WICHTIG: Explizit auf Normal/Regular setzen, damit es exakt wie ein TextField aussieht
                fontWeight: FontWeight.w400,
              ),
            ),
    );
  }

  Widget _buildDropdown(BuildContext context) {
    if (users.isEmpty) {
      return const Text("Lade Benutzer...",
          style: TextStyle(color: Colors.grey));
    }

    final safeValue =
        users.any((u) => u['userID'] == selectedUserID) ? selectedUserID : null;

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        value: safeValue,
        hint: const Text('User wählen'),
        items: users.map((u) {
          return DropdownMenuItem<String>(
            value: u['userID'] as String,
            child: Text(u['username'] ?? u['name'] ?? 'Unbekannt'),
          );
        }).toList()
          ..addAll(onAddGuest != null
              ? [
                  const DropdownMenuItem(
                    value: 'add_guest',
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 18),
                        SizedBox(width: 8),
                        Text('Neuer Gast...',
                            style: TextStyle(fontStyle: FontStyle.italic)),
                      ],
                    ),
                  )
                ]
              : []),
        onChanged: (val) {
          if (val == 'add_guest') {
            onAddGuest?.call();
          } else {
            onChanged(val);
          }
        },
      ),
    );
  }
}

class EventSelectionField extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final String? selectedEventID;
  final ValueChanged<String?> onChanged;
  final bool isEditing;

  const EventSelectionField({
    super.key,
    required this.events,
    required this.selectedEventID,
    required this.onChanged,
    this.isEditing = true,
  });

  @override
  Widget build(BuildContext context) {
    String selectedEventName = 'Kein Event';
    if (selectedEventID != null) {
      final foundEvent = events.firstWhere(
        (e) => e['eventID'] == selectedEventID || e['id'] == selectedEventID,
        orElse: () => {},
      );
      if (foundEvent.isNotEmpty) {
        selectedEventName = foundEvent['name'] ?? 'Unbekanntes Event';
      }
    }

    final theme = Theme.of(context);

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Event',
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        enabled: isEditing,
      ),
      child: isEditing
          ? _buildDropdown(context)
          : Text(
              selectedEventName,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.38),
                // WICHTIG: Auch hier FontWeight auf w400 (Regular) zwingen
                fontWeight: FontWeight.w400,
              ),
            ),
    );
  }

  Widget _buildDropdown(BuildContext context) {
    if (events.isEmpty) {
      return DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: null,
          hint: const Text('Keine Events verfügbar'),
          items: const [
            DropdownMenuItem(value: null, child: Text('Kein Event'))
          ],
          onChanged: (val) {},
        ),
      );
    }

    final safeValue =
        events.any((e) => (e['eventID'] ?? e['id']) == selectedEventID)
            ? selectedEventID
            : null;

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        value: safeValue,
        hint: const Text('Kein Event'),
        items: [
          const DropdownMenuItem(value: null, child: Text('Kein Event')),
          ...events.map((e) => DropdownMenuItem(
                value: (e['eventID'] ?? e['id']) as String,
                child: Text(e['name'] ?? 'Unbekannt'),
              )),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
