import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository {
  final Dio _dio = Dio(
    BaseOptions(baseUrl: 'https://dev.trichter.biertrinkenistgesund.de'),
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthRepository() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Access Token automatisch anhängen
          final token = await _storage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Wenn 401 → versuche Refresh
          if (error.response?.statusCode == 401) {
            final refreshToken = await _storage.read(key: 'refresh_token');

            if (refreshToken != null) {
              try {
                // neues Access Token holen
                final response = await _dio.post(
                  '/api/auth/refresh/',
                  data: {'refresh': refreshToken},
                );

                final newAccessToken = response.data['access'];
                await _storage.write(
                    key: 'access_token', value: newAccessToken);

                // ursprünglichen Request wiederholen
                final requestOptions = error.requestOptions;
                requestOptions.headers['Authorization'] =
                    'Bearer $newAccessToken';
                final clonedResponse = await _dio.fetch(requestOptions);

                return handler.resolve(clonedResponse);
              } catch (_) {
                // Refresh fehlgeschlagen → User ausloggen
                await logout();
                return handler.reject(error);
              }
            } else {
              // kein Refresh Token → User ausloggen
              await logout();
              return handler.reject(error);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Login: holt Access + Refresh Token und speichert sie
  Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/api/auth/login/',
      data: {
        'email': email,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      final accessToken = response.data['access'];
      final refreshToken = response.data['refresh'];

      await _storage.write(key: 'access_token', value: accessToken);
      await _storage.write(key: 'refresh_token', value: refreshToken);
    } else {
      throw Exception('Login fehlgeschlagen');
    }
  }

  /// Logout: löscht Tokens
  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  /// Access Token abrufen
  Future<String?> getAccessToken() async {
    return _storage.read(key: 'access_token');
  }

  /// Refresh Token abrufen
  Future<String?> getRefreshToken() async {
    return _storage.read(key: 'refresh_token');
  }

  /// Optional: einen Request direkt über AuthRepository machen
  Future<Response> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path, {dynamic data}) async {
    return _dio.delete(path, data: data);
  }
}
