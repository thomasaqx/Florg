/// Quem falou numa mensagem do chat.
enum ChatAuthor { user, flora }

/// Uma mensagem na conversa com a FLORA.
///
/// Carrega o próprio estado de envio porque a bolha do usuário aparece antes
/// da resposta chegar: sem isso a tela precisaria de uma lista paralela só
/// para saber o que ainda está no ar.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.author,
    required this.content,
    required this.sentAt,
    this.status = ChatMessageStatus.sent,
    this.usedContext = true,
  });

  final String id;
  final ChatAuthor author;
  final String content;
  final DateTime sentAt;
  final ChatMessageStatus status;

  /// Falso quando a FLORA respondeu sem olhar o extrato (saudação, ou conta
  /// nenhuma cadastrada). A tela usa para não vender uma frase genérica como
  /// análise.
  final bool usedContext;

  bool get isFromUser => author == ChatAuthor.user;
  bool get hasFailed => status == ChatMessageStatus.failed;

  ChatMessage copyWith({ChatMessageStatus? status}) {
    return ChatMessage(
      id: id,
      author: author,
      content: content,
      sentAt: sentAt,
      status: status ?? this.status,
      usedContext: usedContext,
    );
  }

  factory ChatMessage.fromFlora(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      author: ChatAuthor.flora,
      content: json['content'].toString(),
      sentAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      usedContext: json['used_context'] as bool? ?? true,
    );
  }

  /// Só o que a API precisa para replayar a conversa.
  Map<String, String> toApiTurn() => {
    'role': isFromUser ? 'user' : 'assistant',
    'content': content,
  };
}

enum ChatMessageStatus { sending, sent, failed }

/// De onde vêm as respostas neste momento.
class FloraStatus {
  const FloraStatus({
    required this.provider,
    required this.isLive,
    required this.suggestions,
  });

  final String provider;

  /// Verdadeiro quando um modelo de verdade está respondendo; falso quando é
  /// o provider offline do backend.
  final bool isLive;
  final List<String> suggestions;

  static const fallback = FloraStatus(
    provider: 'mock',
    isLive: false,
    suggestions: [
      'Como estão minhas finanças?',
      'Quanto posso gastar?',
      'Analise meus gastos',
      'Posso investir este mês?',
    ],
  );

  factory FloraStatus.fromJson(Map<String, dynamic> json) {
    final suggestions = (json['suggestions'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
    return FloraStatus(
      provider: json['provider']?.toString() ?? 'mock',
      isLive: json['is_live'] as bool? ?? false,
      suggestions: suggestions.isEmpty ? fallback.suggestions : suggestions,
    );
  }
}
