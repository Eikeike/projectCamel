import 'package:flutter_riverpod/flutter_riverpod.dart';

enum EventSortOrder {
  alphabetical,
  newest,
  oldest,
  dateFrom,
}

/// Immutables Modell für den Filter-Status der Events
class EventFilters {
  final EventSortOrder sortOrder;
  final String searchQuery;

  const EventFilters({
    this.sortOrder = EventSortOrder.newest,
    this.searchQuery = '',
  });

  /// Prüft, ob ein Filter aktiv ist (für den "Reset"-Button in der UI)
  bool get hasActive => searchQuery.isNotEmpty || sortOrder != EventSortOrder.newest;

  EventFilters copyWith({EventSortOrder? sortOrder, String? searchQuery}) {
    return EventFilters(
      sortOrder: sortOrder ?? this.sortOrder,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is EventFilters &&
              runtimeType == other.runtimeType &&
              sortOrder == other.sortOrder &&
              searchQuery == other.searchQuery;

  @override
  int get hashCode => sortOrder.hashCode ^ searchQuery.hashCode;
}

/// Notifier für die Event-Filter
class EventFiltersNotifier extends Notifier<EventFilters> {
  @override
  EventFilters build() {
    return const EventFilters();
  }

  void setSortOrder(EventSortOrder order) {
    state = state.copyWith(sortOrder: order);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void reset() {
    state = const EventFilters();
  }
}

/// Provider-Definition (Analog zum Leaderboard mit .new)
final eventFiltersProvider =
NotifierProvider<EventFiltersNotifier, EventFilters>(
  EventFiltersNotifier.new,
);