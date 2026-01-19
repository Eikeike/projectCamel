import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_camel/providers.dart';
import 'package:project_camel/repositories/auth_repository.dart';
import '../services/database_helper.dart';

class AuthState {
  final bool isLoading;
  final String? userId;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.userId,
    this.errorMessage,
  });

  bool get isAuthenticated => userId != null;

  static const _unset = Object();

  AuthState copyWith({
    bool? isLoading,
    Object? userId = _unset,
    Object? errorMessage = _unset,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      userId: userId == _unset ? this.userId : userId as String?,
      errorMessage:
          errorMessage == _unset ? this.errorMessage : errorMessage as String?,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthController extends Notifier<AuthState> {
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    _loadInitialAuthState();
    return const AuthState(isLoading: true);
  }

  Future<void> _loadInitialAuthState() async {
    try {
      final userId = await _authRepository.getStoredUserIdAllowingExpired();

      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        userId: userId, // null => not logged in
        errorMessage: null,
      );
      ref.read(autoSyncControllerProvider).triggerSync();
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        userId: null,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _authRepository.login(email: email, password: password);

      final userId = await _authRepository.getStoredUserIdAllowingExpired();

      if (userId == null) {
        throw Exception('Login erfolgreich, aber User-ID fehlt im Token.');
      }
      await DatabaseHelper().updateLoggedInUser(userId);

      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        userId: userId,
        errorMessage: null,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        userId: null,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    print('AUTH: logout() called - clearing tokens');
    await _authRepository.logout();
    if (!ref.mounted) return;
    state = state.copyWith(
      userId: null,
      errorMessage: null,
      isLoading: false,
    );
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
