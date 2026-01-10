import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../services/database_helper.dart';

/// ----------------------
/// STATE MODEL
/// ----------------------
class SessionState {
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> events;
  final String? selectedUserID;
  final String? selectedEventID;
  final int selectedVolumeML;
  final bool isSaving;

  const SessionState({
    this.users = const [],
    this.events = const [],
    this.selectedUserID,
    this.selectedEventID,
    this.selectedVolumeML = 500,
    this.isSaving = false,
  });

  SessionState copyWith({
    List<Map<String, dynamic>>? users,
    List<Map<String, dynamic>>? events,
    String? selectedUserID,
    String? selectedEventID,
    int? selectedVolumeML,
    bool? isSaving,
  }) {
    return SessionState(
      users: users ?? this.users,
      events: events ?? this.events,
      selectedUserID: selectedUserID ?? this.selectedUserID,
      selectedEventID: selectedEventID ?? this.selectedEventID,
      selectedVolumeML: selectedVolumeML ?? this.selectedVolumeML,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

/// ----------------------
/// NOTIFIER
/// ----------------------
class SessionStateNotifier extends Notifier<SessionState> {
  final _dbService = SessionDbService();

  @override
  SessionState build() => const SessionState();

  /// Initiale Daten laden
  Future<void> initData(int suggestedVolume) async {
    final users = await _dbService.loadUsers();
    final events = await _dbService.loadEvents();

    state = state.copyWith(
      users: users,
      events: events,
      selectedVolumeML: suggestedVolume,
    );
  }

  /// Gast hinzufügen
  Future<void> addGuest(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    await _dbService.saveUser(trimmed);

    final updatedUsers = await _dbService.loadUsers();

    final newGuest = updatedUsers.firstWhere(
      (u) => u['name'] == trimmed,
      orElse: () => <String, dynamic>{},
    );

    state = state.copyWith(
      users: updatedUsers,
      selectedUserID: newGuest['userID'],
    );
  }

  /// Formular Setter
  void selectUser(String id) => state = state.copyWith(selectedUserID: id);
  void selectEvent(String id) => state = state.copyWith(selectedEventID: id);
  void setVolume(int ml) => state = state.copyWith(selectedVolumeML: ml);
  void setSaving(bool value) => state = state.copyWith(isSaving: value);

  /// Session speichern
  Future<void> commitSession(Map<String, dynamic> data, bool isEditing) async {
    await _dbService.commitSession(data, isEditing);
  }

  /// State zurücksetzen nach speichern/verwerfen
  void reset() {
    state = const SessionState();
  }
}

/// ----------------------
/// PROVIDER
/// ----------------------
final sessionStateProvider =
    NotifierProvider<SessionStateNotifier, SessionState>(
  SessionStateNotifier.new,
);

/// ----------------------
/// DB SERVICE
/// ----------------------
class SessionDbService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Map<String, dynamic>>> loadUsers() => _dbHelper.getUsers();
  Future<List<Map<String, dynamic>>> loadEvents() => _dbHelper.getEvents();

  Future<void> saveUser(String name) async {
    final newId = const Uuid().v4();
    await _dbHelper.insertUser({
      'userID': newId,
      'name': name,
      'username': 'gast_${name.toLowerCase().replaceAll(' ', '_')}',
      'eMail': 'gast@bierorgl.de',
    });
  }

  Future<void> commitSession(Map<String, dynamic> data, bool isEditing) async {
    await _dbHelper.saveSessionForSync(data, isEditing: isEditing);
  }
}
