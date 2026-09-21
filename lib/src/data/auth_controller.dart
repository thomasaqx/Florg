import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'auth_repository.dart';

/// State of the user session.
///
/// [unknown] covers the gap between app start and finding out whether the
/// stored token is still valid. Without it, the login screen flashes before
/// the dashboard for users who were already signed in.
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  AuthController({required AuthRepository repository})
    : _repository = repository;

  final AuthRepository _repository;

  AuthStatus status = AuthStatus.unknown;
  AuthUser? user;
  bool isSubmitting = false;
  String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Checks on startup whether the stored token is still accepted by the API.
  /// An expired or revoked token must fall back to the login screen.
  Future<void> restoreSession() async {
    if (!await _repository.isAuthenticated) {
      _set(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      user = await _repository.currentUser();
      _set(status: AuthStatus.authenticated);
    } on ApiException {
      // Invalid token or API unreachable: discard it and ask for login again.
      await _repository.signOut();
      _set(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login({required String email, required String password}) {
    return _submit(() async {
      await _repository.login(email: email, password: password);
      user = await _repository.currentUser();
    });
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _submit(() async {
      await _repository.register(name: name, email: email, password: password);
      // Signing up leaves the user authenticated, so they do not have to
      // retype the credentials they just chose.
      await _repository.login(email: email, password: password);
      user = await _repository.currentUser();
    });
  }

  /// Salva nome e e-mail. Devolve false e preenche [errorMessage] se a API
  /// recusar (e-mail já usado, por exemplo).
  Future<bool> updateProfile({String? name, String? email}) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      user = await _repository.updateProfile(name: name, email: email);
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    user = null;
    errorMessage = null;
    _set(status: AuthStatus.unauthenticated);
  }

  Future<bool> _submit(Future<void> Function() action) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      status = AuthStatus.unauthenticated;
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  void _set({required AuthStatus status}) {
    this.status = status;
    notifyListeners();
  }
}
