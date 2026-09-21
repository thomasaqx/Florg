import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the JWT in the OS encrypted store (Keychain/Keystore/DPAPI),
/// never in plain SharedPreferences.
class TokenStorage {
  const TokenStorage._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'florg_access_token';

  static Future<String?> read() => _storage.read(key: _tokenKey);

  static Future<void> save(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<void> clear() => _storage.delete(key: _tokenKey);

  static Future<bool> get hasToken async => (await read()) != null;
}
