import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

/// Immutable model for leaderboard filter state
class LeaderboardFilters {
  final Set<String> userIDs;
  final VolumeFilter volume;
  final String eventID;
  final String sortOrder;

  const LeaderboardFilters({
    this.userIDs = const {},
    this.volume = VolumeFilter.l05,
    this.eventID = 'Alle',
    this.sortOrder = 'Schnellste zuerst',
  });

  /// Check if any filter is active (not in default state)
  bool get hasActive =>
      userIDs.isNotEmpty || volume != VolumeFilter.l05 || eventID != 'Alle';

  /// Create a copy with optional field overrides
  LeaderboardFilters copyWith({
    Set<String>? userIDs,
    VolumeFilter? volume,
    String? eventID,
    String? sortOrder,
  }) {
    return LeaderboardFilters(
      userIDs: userIDs ?? this.userIDs,
      volume: volume ?? this.volume,
      eventID: eventID ?? this.eventID,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaderboardFilters &&
          runtimeType == other.runtimeType &&
          userIDs == other.userIDs &&
          volume == other.volume &&
          eventID == other.eventID &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode =>
      userIDs.hashCode ^
      volume.hashCode ^
      eventID.hashCode ^
      sortOrder.hashCode;
}

/// Notifier for managing leaderboard filter state
class LeaderboardFiltersNotifier extends Notifier<LeaderboardFilters> {
  @override
  LeaderboardFilters build() {
    return const LeaderboardFilters();
  }

  /// Reset all filters to default state
  void reset() {
    state = const LeaderboardFilters();
  }

  /// Toggle user selection (add or remove)
  void toggleUser(String userId) {
    final updated = {...state.userIDs};
    if (updated.contains(userId)) {
      updated.remove(userId);
    } else {
      updated.add(userId);
    }
    state = state.copyWith(userIDs: updated);
  }

  /// Set volume filter
  void setVolume(VolumeFilter volume) {
    state = state.copyWith(volume: volume);
  }

  /// Set event filter
  void setEvent(String eventId) {
    state = state.copyWith(eventID: eventId);
  }

  /// Set sort order
  void setSortOrder(String sortOrder) {
    state = state.copyWith(sortOrder: sortOrder);
  }
}

/// Provider for leaderboard filter state
final leaderboardFiltersProvider =
    NotifierProvider<LeaderboardFiltersNotifier, LeaderboardFilters>(
  LeaderboardFiltersNotifier.new,
);
