import 'package:flutter/material.dart';

class UserSelectionField extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final String? selectedUserID;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onAddGuest;

  const UserSelectionField({
    super.key,
    required this.users,
    required this.selectedUserID,
    required this.onChanged,
    this.onAddGuest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0, left: 4),
          child: Text('Wer hat getrichtert?',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: [
                Expanded(
                  child: DropdownMenu<String>(
                    // Sorgt dafür, dass das Menü die Breite des Containers nutzt
                    width: constraints.maxWidth - (onAddGuest != null ? 60 : 0),
                    initialSelection: selectedUserID,
                    hintText: 'User wählen',
                    requestFocusOnTap: false,
                    // Das Styling des Textfeldes (M3 Look)
                    inputDecorationTheme: InputDecorationTheme(
                      filled: true,
                      fillColor:
                          Theme.of(context).colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    // Das eigentliche M3 Menü Styling
                    menuStyle: MenuStyle(
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      elevation: WidgetStateProperty.all(6),
                    ),
                    onSelected: onChanged,
                    dropdownMenuEntries: users.map((u) {
                      return DropdownMenuEntry<String>(
                        value: u['userID'] as String,
                        label: u['username'] ?? u['name'] ?? 'Unbekannt',
                        // Hier kannst du sogar Icons hinzufügen
                        leadingIcon: const Icon(Icons.person_outline, size: 20),
                      );
                    }).toList(),
                  ),
                ),
                if (onAddGuest != null) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: onAddGuest,
                    icon: const Icon(Icons.person_add_alt_1),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class EventSelectionField extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final String? selectedEventID;
  final ValueChanged<String?> onChanged;

  const EventSelectionField({
    super.key,
    required this.events,
    required this.selectedEventID,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0, left: 4),
          child: Text('Event', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            return DropdownMenu<String>(
              width: constraints.maxWidth,
              initialSelection: selectedEventID,
              hintText: 'Optional: Event zuordnen',
              requestFocusOnTap: false,
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              menuStyle: MenuStyle(
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
              onSelected: onChanged,
              dropdownMenuEntries: events.map((e) {
                return DropdownMenuEntry<String>(
                  value: e['eventID'] as String,
                  label: e['name'] ?? 'Unbekanntes Event',
                  leadingIcon: const Icon(Icons.event_note, size: 20),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
