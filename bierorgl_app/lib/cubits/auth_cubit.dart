import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/auth_repository.dart';

// States
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final String userId;

  const AuthAuthenticated(this.userId);

  @override
  List<Object?> get props => [userId];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit(this._authRepository) : super(AuthInitial());

  Future<void> login(String email, String password) async {
    emit(AuthLoading());
    try {
      // Schritt 1: Führe den Login durch. Diese Methode gibt 'void' zurück.
      await _authRepository.login(email: email, password: password);

      // Schritt 2: Hole nach dem erfolgreichen Login die User-ID aus dem Repository.
      // Dafür muss im AuthRepository eine Methode wie `getUserID()` existieren.
      final String? userId = await _authRepository.getUserID();

      if (userId != null) {
        // Schritt 3: Wenn die ID vorhanden ist, wurde der Nutzer authentifiziert.
        emit(AuthAuthenticated(userId));
      } else {
        // Schritt 4: Sicherheitsnetz, falls der Login klappt, aber keine ID zurückkommt.
        throw Exception('Login erfolgreich, aber User-ID konnte nicht abgerufen werden.');
      }
    } catch (e) {
      emit(AuthError(e.toString()));
      // Kurz warten, damit eine eventuelle Fehlermeldung in der UI sichtbar ist.
      await Future.delayed(const Duration(milliseconds: 100));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> logout() async {
    // Rufe die Logout-Methode im Repository auf.
    await _authRepository.logout();
    // Setze den Status auf nicht authentifiziert.
    emit(AuthUnauthenticated());
  }
}
