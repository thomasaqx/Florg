import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException, PlatformException;
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'auth_repository.dart';

/// State of the user session.
///
/// [unknown] covers the gap between app start and finding out whether the
/// stored token is still valid. Without it, the login screen flashes before
/// the dashboard for users who were already signed in.
enum AuthStatus { unknown, authenticated, unauthenticated }

/// Porta padrão da API (ver backend/docker-compose.yml e o README).
const _apiPort = 8000;

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
    try {
      if (!await _repository.isAuthenticated) {
        _set(status: AuthStatus.unauthenticated);
        return;
      }
      user = await _repository.currentUser();
      _set(status: AuthStatus.authenticated);
    } catch (_) {
      // Token inválido, API fora do ar ou cofre do sistema indisponível: em
      // todos os casos a saída é a mesma, pedir login de novo. Um `catch` só
      // de ApiException deixava a tela de sessão carregando para sempre.
      try {
        await _repository.signOut();
      } catch (_) {
        // Se nem limpar o token dá, seguir para o login mesmo assim.
      }
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
    } catch (error) {
      errorMessage = _describe(error);
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

  /// Roda [action] e devolve se deu certo, sem nunca deixar a exceção escapar.
  ///
  /// O `catch` aqui era só de ApiException. Qualquer outra falha — backend fora
  /// do ar, URL base errada, cofre do sistema recusando gravar o token — subia
  /// pela tela de login, que esperava um `false` e nunca chegava a mostrar o
  /// erro: o botão parava de girar e nada mais acontecia.
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
    } catch (error) {
      errorMessage = _describe(error);
      status = AuthStatus.unauthenticated;
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  /// Traduz uma falha que não veio da API numa frase que diz o que conferir.
  ///
  /// Reconhece SocketException pelo texto em vez de importar `dart:io`: esse
  /// import não compila em Flutter web, que é justamente onde o erro de
  /// conexão aparece como XMLHttpRequest.
  String _describe(Object error) {
    final detail = error.toString();
    if (error is http.ClientException ||
        detail.contains('SocketException') ||
        detail.contains('XMLHttpRequest') ||
        detail.contains('Connection refused') ||
        detail.contains('Failed host lookup')) {
      final url = _repository.baseUrl;
      // Apontar o app para a porta em que ele mesmo é servido é o engano
      // mais comum, e sem essa dica o erro não diz que a porta está errada.
      final hint = url.contains(':$_apiPort')
          ? ''
          : ' A API do FLORG responde na porta $_apiPort por padrão — '
                'confira se $url é mesmo o endereço dela.';
      return 'Não consegui falar com o servidor em $url. '
          'Confira se o backend está rodando e se a URL base está certa.$hint';
    }
    if (error is MissingPluginException || error is PlatformException) {
      return 'Não consegui guardar sua sessão no cofre do sistema. '
          'No Linux isso costuma ser libsecret faltando; no desktop, um '
          '"flutter clean" seguido de recompilar resolve.';
    }
    return 'Falha inesperada ao entrar: $detail';
  }

  void _set({required AuthStatus status}) {
    this.status = status;
    notifyListeners();
  }
}
