import 'package:flutter/foundation.dart';

import '../models/flora_models.dart';
import 'api_client.dart';
import 'flora_repository.dart';

/// Estado da conversa com a FLORA.
///
/// A bolha do usuário entra na lista antes da resposta chegar, e é a mesma
/// instância que muda de status: assim um envio que falha vira um botão de
/// tentar de novo no lugar certo da conversa, em vez de sumir.
class FloraController extends ChangeNotifier {
  FloraController({FloraRepository? repository})
    : _repository = repository ?? FloraRepository();

  final FloraRepository _repository;

  final List<ChatMessage> _messages = [];
  FloraStatus status = FloraStatus.fallback;
  bool isThinking = false;
  String? errorMessage;

  bool _isDisposed = false;
  int _session = 0;
  int _idCounter = 0;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isEmpty => _messages.isEmpty;
  List<String> get suggestions => status.suggestions;

  /// Pode enviar? Não enquanto a FLORA está pensando: dois envios seguidos
  /// chegariam com o mesmo histórico e a resposta do segundo ignoraria o
  /// primeiro.
  bool get canSend => !isThinking;

  Future<void> loadStatus() async {
    final session = _session;
    try {
      final loaded = await _repository.status();
      if (_isStale(session)) return;
      status = loaded;
      _notify();
    } on ApiException {
      // Sem status a conversa ainda funciona: as sugestões padrão bastam.
    } catch (_) {
      // idem.
    }
  }

  Future<void> send(String text) async {
    final content = text.trim();
    if (content.isEmpty || !canSend) return;

    final session = _session;
    final outgoing = ChatMessage(
      id: _nextId(),
      author: ChatAuthor.user,
      content: content,
      sentAt: DateTime.now(),
      status: ChatMessageStatus.sending,
    );

    _messages.add(outgoing);
    isThinking = true;
    errorMessage = null;
    _notify();

    // O histórico exclui a mensagem recém-adicionada: ela vai no campo
    // `message`, e repetida nos dois lugares a FLORA leria a pergunta duas
    // vezes.
    final history = _messages.sublist(0, _messages.length - 1);

    try {
      final reply = await _repository.send(message: content, history: history);
      if (_isStale(session)) return;
      _replace(outgoing.id, outgoing.copyWith(status: ChatMessageStatus.sent));
      _messages.add(reply);
    } on ApiException catch (error) {
      if (_isStale(session)) return;
      _replace(outgoing.id, outgoing.copyWith(status: ChatMessageStatus.failed));
      errorMessage = error.message;
    } catch (_) {
      if (_isStale(session)) return;
      _replace(outgoing.id, outgoing.copyWith(status: ChatMessageStatus.failed));
      errorMessage = 'Não consegui falar com a FLORA. Verifique sua conexão.';
    } finally {
      if (!_isStale(session)) {
        isThinking = false;
        _notify();
      }
    }
  }

  /// Reenvia uma pergunta que falhou, descartando a bolha antiga.
  Future<void> retry(ChatMessage message) async {
    if (!message.isFromUser || !canSend) return;
    _messages.removeWhere((item) => item.id == message.id);
    _notify();
    await send(message.content);
  }

  void dismissError() {
    if (errorMessage == null) return;
    errorMessage = null;
    _notify();
  }

  /// Limpa a conversa. Chamado no logout: a próxima pessoa a entrar não pode
  /// ver o extrato da anterior no histórico do chat.
  void clear() {
    _session++;
    _messages.clear();
    isThinking = false;
    errorMessage = null;
    _notify();
  }

  void _replace(String id, ChatMessage updated) {
    final index = _messages.indexWhere((item) => item.id == id);
    if (index != -1) _messages[index] = updated;
  }

  String _nextId() => 'local-${_idCounter++}';

  bool _isStale(int session) => _isDisposed || session != _session;

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
