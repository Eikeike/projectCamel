import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart'; // Dieser Import ist entscheidend
import 'package:project_camel/core/constants.dart';

class AuthRepository {
  final Dio _dio;
  final Dio _authDio; // ohne Interceptor für login/refresh
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

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
          final isUnauthorized = error.response?.statusCode == 401;
          final isRefreshCall = error.requestOptions.path.contains('/api/auth/refresh/');

          if (isUnauthorized && !isRefreshCall) {
            final refreshed = await _tryRefreshToken();

            if (refreshed) {
              final newAccessToken = await _storage.read(key: 'access_token');
              final requestOptions = error.requestOptions;

              if (newAccessToken != null) {
                requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              }

              final clonedResponse = await _dio.fetch(requestOptions);
              return handler.resolve(clonedResponse);
            } else {
              await logout();
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) return false;

    try {
      final response = await _authDio.post(
        '/api/auth/refresh/',
        data: {'refresh': refreshToken},
      );

      final newAccessToken = response.data['access'] as String?;
      if (newAccessToken == null) return false;

      await _storage.write(key: 'access_token', value: newAccessToken);
      return true;
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
      data: {
        'email': email,
        'password': password,
      },
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

  Future<String?> _ensureValidAccessToken() async {
    var token = await _storage.read(key: 'access_token');
    if (token == null) return null;

    final isExpired = JwtDecoder.isExpired(token);
    if (!isExpired) return token;

    final refreshed = await _tryRefreshToken();
    if (!refreshed) return null;

    token = await _storage.read(key: 'access_token');
    return token;
  }

  Future<String?> getUserID() async {
    try {
      final token = await _ensureValidAccessToken();
      if (token == null) {
        print("Kein gültiges Access Token vorhanden.");
        return null;
      }

      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['user_id']?.toString();
      return userId;
    } catch (e) {
      print('Fehler beim Dekodieren des Tokens: $e');
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
