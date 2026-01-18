import 'package:flutter/material.dart';
import '../../providers.dart';

class LeaderboardFilterBar extends StatelessWidget {
  final bool isRunsTab;
  final bool hasActiveFilters;
  final String selectedSortOrder;
  final Set<String> selectedUserIDs;
  final VolumeFilter selectedVolume;
  final String selectedEventID;
  final List<Map<String, dynamic>> allUsers;
  final List<Map<String, dynamic>> allEvents;
  final VoidCallback onResetFilters;
  final Function(String) onSortChanged;
  final Function(String) onUserSelectionChanged;
  final Function(VolumeFilter) onVolumeChanged;
  final Function(String) onEventChanged;

  const LeaderboardFilterBar({
    super.key,
    required this.isRunsTab,
    required this.hasActiveFilters,
    required this.selectedSortOrder,
    required this.selectedUserIDs,
    required this.selectedVolume,
    required this.selectedEventID,
    required this.allUsers,
    required this.allEvents,
    required this.onResetFilters,
    required this.onSortChanged,
    required this.onUserSelectionChanged,
    required this.onVolumeChanged,
    required this.onEventChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final sortKey = GlobalKey<PopupMenuButtonState>();
    final volumeKey = GlobalKey<PopupMenuButtonState>();
    final eventKey = GlobalKey<PopupMenuButtonState>();
    final userKey = GlobalKey<PopupMenuButtonState>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Sort Filter (Only visible on 'Runs' tab)
            if (isRunsTab) ...[
              _buildSortDropdown(
                context: context,
                key: sortKey,
                selectedSortOrder: selectedSortOrder,
                onSelected: onSortChanged,
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 24,
                child: VerticalDivider(color: colorScheme.outlineVariant),
              ),
              const SizedBox(width: 8),
            ],

            // User Filter
            _buildMultiSelectUserFilter(
              context: context,
              key: userKey,
              selectedUserIDs: selectedUserIDs,
              allUsers: allUsers,
              onSelected: onUserSelectionChanged,
            ),
            const SizedBox(width: 8),

            // Volume Filter
            _buildVolumeFilter(
              context: context,
              key: volumeKey,
              selectedVolume: selectedVolume,
              onSelected: onVolumeChanged,
            ),
            const SizedBox(width: 8),

            // Event Filter
            _buildSingleSelectFilter(
              context: context,
              key: eventKey,
              label: 'Event',
              currentValue: selectedEventID,
              items: allEvents.map((e) => e['eventID'].toString()).toList(),
              displayMap: {
                for (var e in allEvents)
                  e['eventID'].toString(): (e['name'] as String?) ?? 'Event'
              },
              icon: Icons.event,
              onSelected: onEventChanged,
            ),

            // Reset Button
            if (hasActiveFilters)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: IconButton.filledTonal(
                  onPressed: onResetFilters,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Filter zurücksetzen',
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _buildSortDropdown({
    required BuildContext context,
    required GlobalKey<PopupMenuButtonState> key,
    required String selectedSortOrder,
    required Function(String) onSelected,
  }) {
    return PopupMenuButton<String>(
      key: key,
      tooltip: 'Sortierung',
      onSelected: onSelected,
      itemBuilder: (context) => [
        _buildPopupItem(
          context,
          'Schnellste zuerst',
          selectedSortOrder == 'Schnellste zuerst',
        ),
        _buildPopupItem(
          context,
          'Langsamste zuerst',
          selectedSortOrder == 'Langsamste zuerst',
        ),
        _buildPopupItem(
          context,
          'Neueste zuerst',
          selectedSortOrder == 'Neueste zuerst',
        ),
      ],
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InputChip(
        label: Text(selectedSortOrder),
        avatar: const Icon(Icons.sort, size: 18),
        selected: true,
        showCheckmark: false,
        onPressed: () => key.currentState?.showButtonMenu(),
        deleteIcon: const Icon(Icons.arrow_drop_down, size: 18),
        onDeleted: () => key.currentState?.showButtonMenu(),
      ),
    );
  }

  static Widget _buildVolumeFilter({
    required BuildContext context,
    required GlobalKey<PopupMenuButtonState> key,
    required VolumeFilter selectedVolume,
    required Function(VolumeFilter) onSelected,
  }) {
    final isActive = selectedVolume != VolumeFilter.all;

    return PopupMenuButton<VolumeFilter>(
      key: key,
      tooltip: 'Volumen filtern',
      onSelected: onSelected,
      itemBuilder: (context) => [
        _buildVolumePopupItem(context, VolumeFilter.all, selectedVolume),
        _buildVolumePopupItem(context, VolumeFilter.koelsch, selectedVolume),
        _buildVolumePopupItem(context, VolumeFilter.l033, selectedVolume),
        _buildVolumePopupItem(context, VolumeFilter.l05, selectedVolume),
      ],
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InputChip(
        label: Text(
            isActive ? _volumeFilterDisplayName(selectedVolume) : 'Volumen'),
        avatar: isActive ? null : const Icon(Icons.local_drink, size: 18),
        selected: isActive,
        showCheckmark: false,
        deleteIcon: Icon(
          isActive ? Icons.close : Icons.arrow_drop_down,
          size: 18,
        ),
        onDeleted: () {
          if (isActive)
            onSelected(VolumeFilter.all);
          else
            key.currentState?.showButtonMenu();
        },
        onPressed: () => key.currentState?.showButtonMenu(),
      ),
    );
  }

  static String _volumeFilterDisplayName(VolumeFilter filter) {
    return switch (filter) {
      VolumeFilter.all => 'Alle',
      VolumeFilter.koelsch => 'Kölsch',
      VolumeFilter.l033 => '0,33 L',
      VolumeFilter.l05 => '0,5 L',
    };
  }

  static PopupMenuItem<VolumeFilter> _buildVolumePopupItem(
    BuildContext context,
    VolumeFilter filter,
    VolumeFilter selectedFilter,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = filter == selectedFilter;
    final text = _volumeFilterDisplayName(filter);

    return PopupMenuItem<VolumeFilter>(
      value: filter,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? colorScheme.primary : null,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check, color: colorScheme.primary, size: 20),
        ],
      ),
    );
  }

  static Widget _buildSingleSelectFilter({
    required BuildContext context,
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
        return _buildPopupItem(
          context,
          displayMap[val] ?? val,
          currentValue == val,
          value: val,
        );
      }).toList(),
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InputChip(
        label: Text(
          isActive ? (displayMap[currentValue] ?? currentValue) : label,
        ),
        avatar: isActive ? null : Icon(icon, size: 18),
        selected: isActive,
        showCheckmark: false,
        deleteIcon: Icon(
          isActive ? Icons.close : Icons.arrow_drop_down,
          size: 18,
        ),
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

  static Widget _buildMultiSelectUserFilter({
    required BuildContext context,
    required GlobalKey<PopupMenuButtonState> key,
    required Set<String> selectedUserIDs,
    required List<Map<String, dynamic>> allUsers,
    required Function(String) onSelected,
  }) {
    final int count = selectedUserIDs.length;
    final bool isActive = count > 0;

    String labelText = 'Nutzer';
    if (count == 1) {
      final uid = selectedUserIDs.first;
      final user = allUsers.firstWhere((u) => u['userID'].toString() == uid,
          orElse: () => <String, dynamic>{});
      labelText = (user['username'] as String?) ?? 'Unbekannt';
    } else if (count > 1) {
      labelText = '$count Nutzer';
    }

    return PopupMenuButton<String>(
      key: key,
      tooltip: 'Nutzer wählen',
      onSelected: onSelected,
      itemBuilder: (context) => allUsers.map((u) {
        final id = u['userID'].toString();
        final name = (u['username'] as String?) ?? 'Unbekannt';
        return CheckedPopupMenuItem<String>(
          value: id,
          checked: selectedUserIDs.contains(id),
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
        deleteIcon: Icon(
          isActive ? Icons.close : Icons.arrow_drop_down,
          size: 18,
        ),
        onDeleted: () {
          if (isActive) {
            // Reset signal will be handled by parent
            for (final id in selectedUserIDs.toList()) {
              onSelected(id);
            }
          } else {
            key.currentState?.showButtonMenu();
          }
        },
        onPressed: () => key.currentState?.showButtonMenu(),
      ),
    );
  }

  static PopupMenuItem<String> _buildPopupItem(
    BuildContext context,
    String text,
    bool isSelected, {
    String? value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuItem<String>(
      value: value ?? text,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? colorScheme.primary : null,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check, color: colorScheme.primary, size: 20),
        ],
      ),
    );
  }
}
