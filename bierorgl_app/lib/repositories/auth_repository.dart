import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:project_camel/auth/token_storage.dart';
import 'package:project_camel/core/constants.dart';
import 'package:project_camel/services/auto_sync_controller.dart';

class AuthRepository {
  final Dio _dio;
  final Dio _authDio;
  final TokenStorage _storage;
  //final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Completer<bool>? _refreshCompleter;

  AuthRepository()
      : _storage = createTokenStorage(),
        _dio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl)),
        _authDio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl)) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read('access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final isUnauthorized = status == 401;

          // Prevent recursion
          final isRefreshCall =
              error.requestOptions.path.contains(AppConstants.tokenRefreshPath);
          final alreadyRetried =
              error.requestOptions.extra['__retried'] == true;

          if (!isUnauthorized || isRefreshCall || alreadyRetried) {
            return handler.next(error);
          }

          final refreshed = await _refreshSingleFlight();

          if (refreshed) {
            final newAccessToken = await _storage.read('access_token');

            final requestOptions = error.requestOptions;
            requestOptions.extra['__retried'] = true;

            if (newAccessToken != null) {
              requestOptions.headers['Authorization'] =
                  'Bearer $newAccessToken';
            }

            try {
              final response = await _dio.fetch(requestOptions);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(e is DioException ? e : error);
            }
          } else {
            return handler.next(error);
          }
        },
      ),
    );
  }

  Future<bool> _refreshSingleFlight() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();

    try {
      final ok = await _tryRefreshToken();
      _refreshCompleter!.complete(ok);
      return ok;
    } catch (_) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  bool _looksLikeNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout;
  }

  Future<bool> _tryRefreshToken() async {
    print('AUTH: trying refresh...');

    final refreshToken = await _storage.read('refresh_token');
    if (refreshToken == null) return false;

    try {
      final response = await _authDio.post(
        AppConstants.tokenRefreshPath,
        data: {'refresh': refreshToken},
        options: Options(
          // Ensure refresh call itself doesn't get stuck on weird interceptors
          extra: {'__isRefresh': true},
        ),
      );

      final newAccessToken = response.data['access'] as String?;
      final newRefreshToken = response.data['refresh'] as String?; // rotation

      if (newAccessToken == null) return false;

      await _storage.write('access_token', newAccessToken);
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await _storage.write('refresh_token', newRefreshToken);
      }
      print('AUTH: refresh success. ');

      return true;
    } on DioException catch (e) {
      print('AUTH: refresh failed: $e');
      if (_looksLikeNetworkError(e)) {
        return false;
      }

      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        // optional: await logout();
        return false;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await _authDio.post(
      AppConstants.loginPath,
      data: {'email': email, 'password': password},
    );

    if (response.statusCode == 200) {
      final accessToken = response.data['access'] as String?;
      final refreshToken = response.data['refresh'] as String?;

      if (accessToken != null && refreshToken != null) {
        await _storage.write('access_token', accessToken);
        await _storage.write('refresh_token', refreshToken);
      } else {
        throw Exception('Login-Antwort unvollständig');
      }
    } else {
      throw Exception('Login fehlgeschlagen');
    }
  }

  Future<void> register({
    required String email,
    required String username,
    String? firstName,
    String? lastName,
    required String password,
    required String confirmPassword,
  }) async {
    final data = <String, dynamic>{
      'email': email,
      'username': username,
      'password1': password,
      'password2': confirmPassword,
    };

    if (firstName != null && firstName.trim().isNotEmpty) {
      data['first_name'] = firstName.trim();
    }
    if (lastName != null && lastName.trim().isNotEmpty) {
      data['last_name'] = lastName.trim();
    }

    final response = await _authDio.post(AppConstants.registerPath, data: data);

    final ok = response.statusCode != null &&
        (response.statusCode == 200 || response.statusCode == 201);

    if (!ok) throw Exception('Registrierung fehlgeschlagen');

    final accessToken = response.data['access'] as String?;
    final refreshToken = response.data['refresh'] as String?;

    if (accessToken == null || refreshToken == null) {
      throw Exception('Register-Antwort unvollständig (Tokens fehlen)');
    }

    await _storage.write('access_token', accessToken);
    await _storage.write('refresh_token', refreshToken);
  }

  Future<String?> _ensureValidAccessTokenOfflineSafe() async {
    final token = await _storage.read('access_token');
    if (token == null) return null;

    if (!JwtDecoder.isExpired(token)) return token;
    final refreshed = await _refreshSingleFlight();
    if (!refreshed) return null;

    return await _storage.read('access_token');
  }

  Future<String?> getUserID() async {
    try {
      final token = await _ensureValidAccessTokenOfflineSafe();
      if (token == null) return null;

      final decodedToken = JwtDecoder.decode(token);
      return decodedToken['user_id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await _storage.delete('access_token');
    await _storage.delete('refresh_token');
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path, {dynamic data}) {
    return _dio.delete(path, data: data);
  }

  Future<String?> getStoredUserIdAllowingExpired() async {
    try {
      final token = await _storage.read('access_token');
      if (token == null) return null;

      final decodedToken = JwtDecoder.decode(token);
      return decodedToken['user_id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> requestPasswordReset({required String email}) async {
    final response = await _authDio.post(
      AppConstants.passwordResetPath,
      data: {'email': email},
    );

    // Most APIs return 200/204 for “sent” (sometimes 201). Accept a range.
    final ok = response.statusCode != null &&
        (response.statusCode == 200 ||
            response.statusCode == 201 ||
            response.statusCode == 204);

    if (!ok) {
      throw Exception('Passwort-Reset fehlgeschlagen');
    }
  }
}
