import '../models/flora_models.dart';
import 'api_client.dart';

/// Acesso à FLORA.
///
/// O app nunca fala com a API do Claude: pergunta vai para o backend do FLORG
/// e é ele que decide qual provider responde. Chave de API nenhuma passa por
/// aqui.
class FloraRepository {
  FloraRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Quantos turnos anteriores acompanham a pergunta.
  ///
  /// O servidor não guarda sessão; o histórico vai junto. Mandar a conversa
  /// inteira cresceria sem limite, e o backend recusa acima de 20.
  static const historyLimit = 10;

  Future<ChatMessage> send({
    required String message,
    required List<ChatMessage> history,
  }) async {
    final recent = history.length <= historyLimit
        ? history
        : history.sublist(history.length - historyLimit);

    final json = await _apiClient.post(
      '/ai/chat',
      body: {
        'message': message,
        'history': [
          for (final item in recent)
            if (!item.hasFailed) item.toApiTurn(),
        ],
      },
    );
    return ChatMessage.fromFlora(json as Map<String, dynamic>);
  }

  Future<FloraStatus> status() async {
    final json = await _apiClient.get('/ai/status');
    return FloraStatus.fromJson(json as Map<String, dynamic>);
  }
}
