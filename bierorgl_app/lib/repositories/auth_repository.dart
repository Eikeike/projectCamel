import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:project_camel/core/constants.dart';

class AuthRepository {
  final Dio _dio;
  final Dio _authDio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Completer<bool>? _refreshCompleter;

  AuthRepository()
      : _dio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl)),
        _authDio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl)) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'access_token');
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
              error.requestOptions.path.contains('/api/auth/refresh/');
          final alreadyRetried =
              error.requestOptions.extra['__retried'] == true;

          if (!isUnauthorized || isRefreshCall || alreadyRetried) {
            return handler.next(error);
          }

          final refreshed = await _refreshSingleFlight();

          if (refreshed) {
            final newAccessToken = await _storage.read(key: 'access_token');

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
            // IMPORTANT: do NOT auto-logout here.
            // Let the app decide (e.g., show "Session expired" only if online and refresh truly rejected).
            return handler.next(error);
          }
        },
      ),
    );
  }

  Future<bool> _refreshSingleFlight() async {
    // If a refresh is already running, await it.
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
    // Covers offline, DNS, timeouts, etc.
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout;
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) return false;

    try {
      final response = await _authDio.post(
        '/api/auth/refresh/',
        data: {'refresh': refreshToken},
        options: Options(
          // Ensure refresh call itself doesn't get stuck on weird interceptors
          extra: {'__isRefresh': true},
        ),
      );

      final newAccessToken = response.data['access'] as String?;
      final newRefreshToken = response.data['refresh'] as String?; // rotation

      if (newAccessToken == null) return false;

      await _storage.write(key: 'access_token', value: newAccessToken);

      // If the API rotates refresh tokens, persist the new one.
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await _storage.write(key: 'refresh_token', value: newRefreshToken);
      }

      return true;
    } on DioException catch (e) {
      // Offline / temporary network issue: DO NOT logout; keep tokens and retry later.
      if (_looksLikeNetworkError(e)) {
        return false;
      }

      // If server explicitly rejects refresh token (e.g., 401/403), treat as invalid session.
      // You can choose to logout here OR signal to UI.
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
      '/api/auth/login/',
      data: {'email': email, 'password': password},
    );

    if (response.statusCode == 200) {
      final accessToken = response.data['access'] as String?;
      final refreshToken = response.data['refresh'] as String?;

      if (accessToken != null && refreshToken != null) {
        await _storage.write(key: 'access_token', value: accessToken);
        await _storage.write(key: 'refresh_token', value: refreshToken);
      } else {
        throw Exception('Login-Antwort unvollständig');
      }
    } else {
      throw Exception('Login fehlgeschlagen');
    }
  }

  Future<String?> _ensureValidAccessTokenOfflineSafe() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return null;

    if (!JwtDecoder.isExpired(token)) return token;

    // Token expired. Try refresh; if offline, it will fail and we return null.
    final refreshed = await _refreshSingleFlight();
    if (!refreshed) return null;

    return await _storage.read(key: 'access_token');
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
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
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
}
