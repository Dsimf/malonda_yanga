import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode = 0]);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();

  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://malonda-yanga.onrender.com',
  );
  static const _storage = FlutterSecureStorage();
  static http.Client _httpClient = http.Client();
  static String? _accessToken;
  static String? _refreshToken;
  static bool _rememberSession = false;
  static bool _testing = false;

  static void configureForTesting(http.Client client) {
    _httpClient.close();
    _httpClient = client;
    _accessToken = null;
    _refreshToken = null;
    _rememberSession = false;
    _testing = true;
  }

  static Future<Map<String, dynamic>> register(
    Map<String, Object?> data,
  ) async {
    final response = await _send('POST', '/auth/register', body: data);
    await _saveSession(response);
    return response;
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    // Clear any previous (possibly stale) tokens before authenticating so
    // the new session fully replaces the old one.
    await logout();
    final response = await _send(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    await _saveSession(response, persist: rememberMe);
    return response;
  }

  static Future<void> requestPasswordReset(String email) async {
    await _send('POST', '/auth/password/reset', body: {'email': email.trim()});
  }

  static Future<Map<String, dynamic>> me() async =>
      (await _send('GET', '/auth/me')) as Map<String, dynamic>;

  /// Returns true if a previously saved session exists (remember me).
  /// Only considers persisted storage, not the in-memory access token.
  static Future<bool> hasSavedSession() async {
    if (_testing) return false;
    try {
      final accessToken = await _storage.read(key: 'access_token');
      final refreshToken = await _storage.read(key: 'refresh_token');
      _rememberSession = accessToken != null || refreshToken != null;
      if (accessToken != null) _accessToken ??= accessToken;
      if (refreshToken != null) _refreshToken ??= refreshToken;
      return _rememberSession;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _rememberSession = false;
    await _removeStoredSession();
  }

  static Future<List<Map<String, dynamic>>> products({String? search}) async {
    final data = await _send(
      'GET',
      '/products',
      query: search == null || search.trim().isEmpty
          ? null
          : {'search': search.trim()},
    );
    return (data as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> createProduct(
    Map<String, Object?> data,
  ) async =>
      (await _send('POST', '/products', body: data)) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> updateProduct(
    String id,
    Map<String, Object?> data,
  ) async =>
      (await _send('PATCH', '/products/$id', body: data))
          as Map<String, dynamic>;

  static Future<void> deleteProduct(String id) async {
    await _send('DELETE', '/products/$id');
  }

  static Future<Map<String, dynamic>> uploadProductImage(
    String productId, {
    required String contentType,
    required String imageBase64,
  }) async => (await _send(
    'PUT',
    '/products/$productId/image',
    body: {'content_type': contentType, 'image_base64': imageBase64},
  )) as Map<String, dynamic>;

  static Future<List<Map<String, dynamic>>> suppliers() async =>
      ((await _send('GET', '/suppliers')) as List).cast<Map<String, dynamic>>();

  static Future<Map<String, dynamic>> createSupplier(
    Map<String, Object?> data,
  ) async =>
      (await _send('POST', '/suppliers', body: data)) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> updateSupplier(
    String id,
    Map<String, Object?> data,
  ) async =>
      (await _send('PATCH', '/suppliers/$id', body: data))
          as Map<String, dynamic>;

  static Future<void> deleteSupplier(String id) async {
    await _send('DELETE', '/suppliers/$id');
  }

  static Future<Map<String, dynamic>> createSale(Map<String, Object?> data) =>
      _send(
        'POST',
        '/sales',
        body: data,
      ).then((value) => value as Map<String, dynamic>);

  /// Voids/removes a sale that was recorded by mistake.
  static Future<void> deleteSale(String saleId) async {
    await _send('DELETE', '/sales/$saleId');
  }

  static Future<List<Map<String, dynamic>>> laybys() async =>
      ((await _send('GET', '/laybys')) as List).cast<Map<String, dynamic>>();

  /// Every layby sale (open and settled) with its payment history attached
  /// under a 'payments' key.
  static Future<List<Map<String, dynamic>>> laybyHistory() async =>
      ((await _send('GET', '/laybys/history')) as List)
          .cast<Map<String, dynamic>>();

  static Future<Map<String, dynamic>> payLayby(
    String saleId,
    num amount,
  ) async => (await _send(
    'POST',
    '/laybys/$saleId/payments',
    body: {'amount': amount},
  )) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> dashboard() async =>
      (await _send('GET', '/dashboard')) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> reports({
    required DateTime start,
    required DateTime end,
  }) async => (await _send(
    'GET',
    '/reports',
    query: {'start_date': _dateOnly(start), 'end_date': _dateOnly(end)},
  )) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> shopSettings() async =>
      (await _send('GET', '/settings')) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> updateShopSettings(
    Map<String, Object?> data,
  ) async =>
      (await _send('PATCH', '/settings', body: data)) as Map<String, dynamic>;

  static Future<List<Map<String, dynamic>>> expenses({
    required DateTime start,
    required DateTime end,
  }) async => ((await _send(
    'GET',
    '/expenses',
    query: {'start_date': _dateOnly(start), 'end_date': _dateOnly(end)},
  )) as List)
      .cast<Map<String, dynamic>>();

  static Future<Map<String, dynamic>> createExpense(
    Map<String, Object?> data,
  ) async => (await _send('POST', '/expenses', body: data)) as Map<String, dynamic>;

  static Future<void> deleteExpense(String id) async {
    await _send('DELETE', '/expenses/$id');
  }

  static Future<List<Map<String, dynamic>>> employees() async =>
      ((await _send('GET', '/employees')) as List).cast<Map<String, dynamic>>();

  static Future<Map<String, dynamic>> createEmployee({
    required String displayName,
    required String email,
    required String password,
  }) async => (await _send(
    'POST',
    '/employees',
    body: {
      'display_name': displayName,
      'email': email,
      'password': password,
    },
  )) as Map<String, dynamic>;

  static Future<void> deleteEmployee(String id) async {
    await _send('DELETE', '/employees/$id');
  }

  static Future<dynamic> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    return _sendUri(method, uri, body: body);
  }

  static Future<dynamic> _sendUri(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
    bool retry = true,
  }) async {
    final token = await _readAccessToken();
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    late final http.Response response;
    try {
      final streamedResponse = await _httpClient.send(request);
      response = await http.Response.fromStream(streamedResponse);
    } on http.ClientException catch (error) {
      throw ApiException('The API request failed: $error', 0);
    }

    // Supabase rejects expired or malformed JWTs with 401 or 403
    // (error_code "bad_jwt", "JWT expired", signature errors, ...), so
    // treat either status as an expired session and try to refresh it.
    final bodyLower = response.body.toLowerCase();
    final isBadJwt = response.statusCode == 401 ||
        (response.statusCode == 403 &&
            (bodyLower.contains('bad_jwt') ||
                bodyLower.contains('jwt') ||
                bodyLower.contains('token') ||
                bodyLower.contains('permission denied') ||
                bodyLower.contains('row-level security')));
    if (isBadJwt && retry && await _refreshSession()) {
      return _sendUri(method, uri, body: body, retry: false);
    }
    if (isBadJwt) {
      // Either the refresh token is dead too (or refresh already signed
      // out), or this was the retried attempt and it failed again — force
      // a clean sign-out so stale tokens don't linger.
      await logout();
    }

    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      throw ApiException(
        'The API returned an invalid response.',
        response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(decoded), response.statusCode);
    }
    return decoded;
  }

  /// Extracts a human-readable message from any error body the API might
  /// return: `{"detail": "..."}`, FastAPI validation errors
  /// (`{"detail": [{"msg": ...}]}`), a bare string, an array, or an
  /// empty/non-JSON body. Never throws — a malformed error body must not
  /// mask the actual HTTP status with a Dart type error.
  static String _errorMessage(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) {
        // FastAPI 422 validation errors: use the first message.
        final first = detail.first;
        if (first is Map<String, dynamic>) {
          final msg = first['msg'];
          if (msg is String && msg.trim().isNotEmpty) return msg;
        }
        if (first != null) return first.toString();
      }
      if (detail is Map<String, dynamic>) {
        final msg = detail['msg'] ?? detail['message'];
        if (msg is String && msg.trim().isNotEmpty) return msg;
        return detail.toString();
      }
      final message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) return message;
    } else if (decoded is String && decoded.trim().isNotEmpty) {
      return decoded;
    } else if (decoded is List && decoded.isNotEmpty) {
      return decoded.first.toString();
    }
    return 'Request failed.';
  }

  static Future<String?> _readAccessToken() async {
    if (_accessToken != null) return _accessToken;
    if (_testing) return null;
    try {
      _accessToken = await _storage.read(key: 'access_token');
      _refreshToken = await _storage.read(key: 'refresh_token');
      _rememberSession = _accessToken != null || _refreshToken != null;
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      throw ApiException(
        'Could not read the saved session: ${error.message}',
        0,
      );
    }
    return _accessToken;
  }

  static Future<void> _saveSession(
    Map<String, dynamic> response, {
    bool persist = true,
  }) async {
    _accessToken = response['access_token'] as String?;
    _refreshToken = response['refresh_token'] as String?;
    _rememberSession = persist && _accessToken != null;
    if (_testing) return;
    try {
      if (!_rememberSession) {
        await _storage.delete(key: 'access_token');
        await _storage.delete(key: 'refresh_token');
      } else {
        await _storage.write(key: 'access_token', value: _accessToken);
        await _storage.write(key: 'refresh_token', value: _refreshToken);
      }
    } on MissingPluginException {
      return;
    } on PlatformException catch (error) {
      _accessToken = null;
      _refreshToken = null;
      throw ApiException(
        'Could not securely save the session: ${error.message}',
        0,
      );
    }
  }

  static Future<void> _removeStoredSession() async {
    if (_testing) return;
    try {
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'refresh_token');
    } on MissingPluginException {
      return;
    } on PlatformException catch (error) {
      throw ApiException(
        'Could not securely clear the saved session: ${error.message}',
        0,
      );
    }
  }

  static Future<bool> _refreshSession() {
    // Share a single in-flight refresh across concurrent requests.
    // Supabase rotates the refresh token on every use, so a second
    // parallel refresh with the old token returns 400 "invalid refresh
    // token" and would needlessly fail the retried request.
    _refreshing ??= _refreshSessionOnce();
    return _refreshing!.whenComplete(() => _refreshing = null);
  }

  static Future<bool>? _refreshing;

  static Future<bool> _refreshSessionOnce() async {
    if (_refreshToken == null) {
      if (_testing) return false;
      try {
        _refreshToken = await _storage.read(key: 'refresh_token');
      } on MissingPluginException {
        return false;
      } on PlatformException catch (error) {
        throw ApiException(
          'Could not read the refresh token: ${error.message}',
          0,
        );
      }
    }
    final refreshToken = _refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await _sendUri(
        'POST',
        Uri.parse('$_baseUrl/auth/refresh'),
        body: {'refresh_token': refreshToken},
        retry: false,
      );
      await _saveSession(
        response as Map<String, dynamic>,
        persist: _rememberSession,
      );
      return _accessToken != null;
    } on ApiException catch (error) {
      // The refresh token is dead (expired, reused, or revoked). A failed
      // refresh can never succeed again, so force a clean sign-out and
      // report "no session" instead of letting the error propagate to
      // every caller that just wanted to retry once.
      if (error.statusCode >= 400) {
        await logout();
        return false;
      }
      // Network-level failures (statusCode 0): don't destroy the session,
      // the server might just be temporarily unreachable.
      rethrow;
    }
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
