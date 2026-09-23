import 'api_client.dart';
import 'token_storage.dart';

class AuthUser {
  const AuthUser({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
  );
}

class AuthRepository {
  AuthRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Para a mensagem de erro dizer em qual endereço a tentativa falhou.
  /// Sem isso, "não consegui falar com o servidor" não ajuda a descobrir que a
  /// URL base aponta para outro host.
  String get baseUrl => _apiClient.baseUrl;

  Future<bool> get isAuthenticated => TokenStorage.hasToken;

  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final json = await _apiClient.post(
      '/auth/register',
      withAuth: false,
      body: {'name': name, 'email': email, 'password': password},
    );
    return AuthUser.fromJson(json as Map<String, dynamic>);
  }

  Future<void> login({required String email, required String password}) async {
    final json = await _apiClient.postForm('/auth/login', {
      'username': email,
      'password': password,
    });
    await TokenStorage.save(json['access_token'] as String);
  }

  /// Confirms with the API that the stored token is still valid.
  Future<AuthUser> currentUser() async {
    final json = await _apiClient.get('/auth/me');
    return AuthUser.fromJson(json as Map<String, dynamic>);
  }

  /// Atualiza o próprio perfil. O id vem do token, nunca do corpo.
  Future<AuthUser> updateProfile({String? name, String? email}) async {
    final json = await _apiClient.patch('/auth/me', body: {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
    });
    return AuthUser.fromJson(json as Map<String, dynamic>);
  }

  Future<void> signOut() => TokenStorage.clear();
}
