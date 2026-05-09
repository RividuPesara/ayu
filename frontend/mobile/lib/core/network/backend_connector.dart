import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

typedef TokenProvider = FutureOr<String?> Function();

class BackendConnector {
  BackendConnector._();

  static final BackendConnector instance = BackendConnector._();

  String? _baseUrlOverride;
  TokenProvider? _tokenProvider;
  String? _fallbackToken = 'dev-token';

  /// Configure backend access
  void configure({
    String? baseUrl,
    TokenProvider? tokenProvider,
    String? fallbackToken,
  }) {
    if (baseUrl != null) _baseUrlOverride = baseUrl;
    if (tokenProvider != null) _tokenProvider = tokenProvider;
    if (fallbackToken != null) _fallbackToken = fallbackToken;
  }

  String get baseUrl {
    if (_baseUrlOverride != null && _baseUrlOverride!.isNotEmpty) {
      return _baseUrlOverride!;
    }

    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }

    if (kIsWeb) {
      return 'http://localhost/api';
    }

    return 'http://10.0.2.2/api';
  }

  Uri uri(String path, {Map<String, dynamic>? queryParameters}) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final rawUri = Uri.parse('$baseUrl$normalizedPath');

    if (queryParameters == null || queryParameters.isEmpty) {
      return rawUri;
    }

    return rawUri.replace(
      queryParameters: queryParameters.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  Future<Map<String, String>> buildHeaders({
    Map<String, String>? extra,
    bool includeAuth = true,
    bool includeJsonContentType = true,
  }) async {
    final headers = <String, String>{};

    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
    }

    if (includeAuth) {
      final token = await _resolveToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (extra != null && extra.isNotEmpty) {
      headers.addAll(extra);
    }

    return headers;
  }

  Future<http.Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return http.get(
      uri(path, queryParameters: queryParameters),
      headers: await buildHeaders(extra: headers),
    );
  }

  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return http.post(
      uri(path, queryParameters: queryParameters),
      headers: await buildHeaders(extra: headers),
      body: _serializeBody(body),
    );
  }

  Future<http.Response> put(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return http.put(
      uri(path, queryParameters: queryParameters),
      headers: await buildHeaders(extra: headers),
      body: _serializeBody(body),
    );
  }

  Future<http.Response> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return http.patch(
      uri(path, queryParameters: queryParameters),
      headers: await buildHeaders(extra: headers),
      body: _serializeBody(body),
    );
  }

  Future<http.Response> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return http.delete(
      uri(path, queryParameters: queryParameters),
      headers: await buildHeaders(extra: headers),
      body: _serializeBody(body),
    );
  }

  Future<http.Response> multipartPost(
    String path,
    String field,
    List<int> bytes,
    String filename, {
    String? contentType,
    Map<String, String>? headers,
  }) async {
    final req = http.MultipartRequest('POST', uri(path));
    req.headers.addAll(
      await buildHeaders(extra: headers, includeJsonContentType: false),
    );
    req.files.add(
      http.MultipartFile.fromBytes(
        field,
        bytes,
        filename: filename,
        contentType: contentType != null ? MediaType.parse(contentType) : null,
      ),
    );
    final streamed = await req.send();
    return http.Response.fromStream(streamed);
  }

  Future<http.Request> request(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final request = http.Request(
      method,
      uri(path, queryParameters: queryParameters),
    );
    request.headers.addAll(await buildHeaders(extra: headers));
    final serialized = _serializeBody(body);
    if (serialized != null) {
      request.body = serialized;
    }
    return request;
  }

  Future<String?> _resolveToken() async {
    if (_tokenProvider != null) {
      return await _tokenProvider!.call();
    }
    return _fallbackToken;
  }

  String? _serializeBody(Object? body) {
    if (body == null) {
      return null;
    }
    if (body is String) {
      return body;
    }
    return jsonEncode(body);
  }
}
