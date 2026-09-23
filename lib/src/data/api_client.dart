import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'token_storage.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// De onde saiu a URL base da API.
///
/// Saber a URL não basta para diagnosticar: um `--dart-define` esquecido num
/// atalho da IDE e o padrão do app produzem erros idênticos na tela, e só a
/// origem separa "eu configurei errado" de "o padrão não serve aqui".
enum ApiBaseUrlSource {
  /// Veio de `--dart-define=FLORG_API_BASE_URL=...` em tempo de compilação.
  dartDefine,

  /// Emulador Android, onde `localhost` é a própria VM.
  androidEmulator,

  /// O padrão para todo o resto.
  fallback,

  /// Passada direto no construtor (testes).
  explicit,
}

class ApiClient {
  ApiClient({String? baseUrl})
    : baseUrl = baseUrl ?? _defaultBaseUrl(),
      baseUrlSource = baseUrl != null
          ? ApiBaseUrlSource.explicit
          : _defaultBaseUrlSource();

  final String baseUrl;

  /// Como [baseUrl] foi decidida, para a mensagem de erro dizer o que conferir.
  final ApiBaseUrlSource baseUrlSource;

  /// Overrides the discovered URL, for a physical device or a staging server:
  /// `flutter run --dart-define=FLORG_API_BASE_URL=http://192.168.0.10:8000`.
  static const _configuredBaseUrl = String.fromEnvironment(
    'FLORG_API_BASE_URL',
  );

  static bool get _isAndroidDevice =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String _defaultBaseUrl() {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    // The Android emulator runs in its own VM; "localhost" there is the VM,
    // not the host machine.
    if (_isAndroidDevice) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  static ApiBaseUrlSource _defaultBaseUrlSource() {
    if (_configuredBaseUrl.isNotEmpty) return ApiBaseUrlSource.dartDefine;
    if (_isAndroidDevice) return ApiBaseUrlSource.androidEmulator;
    return ApiBaseUrlSource.fallback;
  }

  /// A URL base e de onde ela veio, em uma linha, para log e tela de erro.
  ///
  /// `--dart-define` é lido na compilação: trocar a flag e dar hot restart
  /// mantém o valor antigo. É por isso que a origem aparece aqui.
  String get describedBaseUrl {
    final origin = switch (baseUrlSource) {
      ApiBaseUrlSource.dartDefine =>
        'definida por --dart-define=FLORG_API_BASE_URL na compilação',
      ApiBaseUrlSource.androidEmulator => 'padrão do emulador Android',
      ApiBaseUrlSource.fallback => 'padrão do app',
      ApiBaseUrlSource.explicit => 'passada no construtor',
    };
    return '$baseUrl ($origin)';
  }

  Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (withAuth) {
      final token = await TokenStorage.read();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
    return _decode(response);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool withAuth = true,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(withAuth: withAuth),
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(response);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(response);
  }

  /// PATCH manda só os campos presentes no mapa.
  ///
  /// Um `null` explícito no corpo é diferente de campo ausente: o primeiro
  /// limpa o valor, o segundo não mexe nele.
  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
    return _decode(response);
  }

  /// Uploads a file as multipart/form-data, for the spreadsheet import.
  ///
  /// Takes the bytes rather than a path because on the web there is no path to
  /// read from, only the bytes the picker hands over.
  Future<dynamic> postFile(
    String path, {
    required String filename,
    required List<int> bytes,
    String field = 'file',
    Map<String, String> fields = const {},
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    final token = await TokenStorage.read();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);
    request.files.add(
      http.MultipartFile.fromBytes(field, bytes, filename: filename),
    );

    final streamed = await request.send();
    return _decode(await http.Response.fromStream(streamed));
  }

  /// FastAPI's OAuth2PasswordRequestForm expects form-urlencoded, not JSON.
  Future<dynamic> postForm(String path, Map<String, String> fields) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: fields,
    );
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    var message = 'Erro inesperado (${response.statusCode})';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
    } catch (_) {
      // Body was not JSON; keep the generic message.
    }
    throw ApiException(response.statusCode, message);
  }
}
