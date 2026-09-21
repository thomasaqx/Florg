import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/flora_models.dart';

/// A marca da FLORA: quadrado de canto curto com o verde da casa.
///
/// Não é um avatar redondo de chat genérico; segue os cantos do resto do app.
class FloraAvatar extends StatelessWidget {
  const FloraAvatar({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(FlorgRadius.sm),
      ),
      child: Text(
        'F',
        style: TextStyle(
          color: FlorgPalette.onAccent,
          fontSize: size * 0.45,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

/// Uma mensagem da conversa.
///
/// Usuário à direita, em verde; FLORA à esquerda, na superfície do app. A
/// bolha nunca passa de [maxWidthFactor] da largura para a linha não ficar
/// longa demais para ler no desktop.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.maxWidthFactor = 0.78,
  });

  final ChatMessage message;
  final VoidCallback? onRetry;
  final double maxWidthFactor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isUser = message.isFromUser;
    final maxWidth = MediaQuery.sizeOf(context).width * maxWidthFactor;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth.clamp(220.0, 640.0)),
      padding: const EdgeInsets.symmetric(
        horizontal: FlorgSpacing.md,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isUser ? colors.primary : colors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(FlorgRadius.md),
          topRight: const Radius.circular(FlorgRadius.md),
          bottomLeft: Radius.circular(isUser ? FlorgRadius.md : FlorgRadius.sm),
          bottomRight: Radius.circular(isUser ? FlorgRadius.sm : FlorgRadius.md),
        ),
        border: isUser ? null : Border.all(color: colors.border),
      ),
      child: SelectableText(
        message.content,
        style: TextStyle(
          height: 1.5,
          fontSize: 14.5,
          color: isUser ? colors.onPrimary : colors.textPrimary,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: FlorgSpacing.md),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const FloraAvatar(),
            const SizedBox(width: FlorgSpacing.sm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (message.status == ChatMessageStatus.sending)
                  Opacity(opacity: 0.6, child: bubble)
                else
                  bubble,
                if (message.hasFailed) _FailedHint(onRetry: onRetry),
                if (!isUser && !message.usedContext) const _GenericAnswerHint(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedHint extends StatelessWidget {
  const _FailedHint({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: FlorgSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: context.colors.error,
          ),
          const SizedBox(width: FlorgSpacing.xs),
          Text(
            'Não enviou.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.colors.error),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: FlorgSpacing.sm),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Tentar de novo'),
            ),
        ],
      ),
    );
  }
}

/// Avisa que a resposta não olhou o extrato.
///
/// Sem isso, uma saudação da FLORA pareceria uma leitura das contas do
/// usuário.
class _GenericAnswerHint extends StatelessWidget {
  const _GenericAnswerHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: FlorgSpacing.xs, left: 2),
      child: Text(
        'Resposta sem consultar seus lançamentos',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.colors.textMuted),
      ),
    );
  }
}

/// Três pontos pulsando enquanto a FLORA processa.
class FloraTypingIndicator extends StatefulWidget {
  const FloraTypingIndicator({super.key});

  @override
  State<FloraTypingIndicator> createState() => _FloraTypingIndicatorState();
}

class _FloraTypingIndicatorState extends State<FloraTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: FlorgSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FloraAvatar(),
          const SizedBox(width: FlorgSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: FlorgSpacing.md,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(FlorgRadius.md),
              border: Border.all(color: colors.border),
            ),
            child: Semantics(
              label: 'FLORA está analisando',
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < 3; index++) ...[
                        if (index > 0) const SizedBox(width: FlorgSpacing.xs),
                        _Dot(
                          opacity: _opacityFor(index),
                          color: colors.secondary,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Cada ponto acende um terço de ciclo depois do anterior.
  double _opacityFor(int index) {
    final phase = (_controller.value - index * 0.22) % 1.0;
    return 0.25 + 0.75 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.opacity, required this.color});

  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity.clamp(0.0, 1.0)),
      ),
    );
  }
}

/// Sugestão clicável, para quem não sabe o que perguntar.
class SuggestionChip extends StatelessWidget {
  const SuggestionChip({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(FlorgRadius.md),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: FlorgSpacing.md,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(FlorgRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: enabled ? colors.textPrimary : colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de texto do chat, com envio por Enter.
///
/// Shift+Enter quebra linha; Enter sozinho envia, que é o que se espera de um
/// chat no desktop. No celular o teclado mostra a ação de enviar.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    required this.enabled,
    this.hintText = 'Pergunte sobre o seu dinheiro',
  });

  final ValueChanged<String> onSend;
  final bool enabled;
  final String hintText;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncHasText);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncHasText);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _syncHasText() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    _controller.clear();
    widget.onSend(text);
    // Devolve o foco: quem está conversando costuma perguntar de novo.
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canSend = widget.enabled && _hasText;

    return Container(
      padding: const EdgeInsets.all(FlorgSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(FlorgRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('flora-input'),
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              minLines: 1,
              maxLines: 5,
              maxLength: 2000,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              style: TextStyle(fontSize: 14.5, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: widget.hintText,
                counterText: '',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: FlorgSpacing.sm,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: FlorgSpacing.sm),
          IconButton(
            key: const ValueKey('flora-send'),
            onPressed: canSend ? _submit : null,
            tooltip: 'Enviar',
            style: IconButton.styleFrom(
              backgroundColor: canSend ? colors.primary : colors.surfaceElevated,
              foregroundColor: canSend ? colors.onPrimary : colors.textMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FlorgRadius.sm),
              ),
            ),
            icon: const Icon(Icons.arrow_upward_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

/// O que a tela mostra antes da primeira pergunta.
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({
    super.key,
    required this.suggestions,
    required this.onSuggestionTap,
    required this.isLive,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSuggestionTap;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: FlorgSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FloraAvatar(size: 48),
              const SizedBox(height: FlorgSpacing.lg),
              Text(
                'Pergunte alguma coisa\nsobre o seu dinheiro.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: FlorgSpacing.sm),
              Text(
                'A FLORA lê os seus lançamentos e responde com a conta já '
                'feita, e o motivo junto.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: FlorgSpacing.xl),
              Wrap(
                spacing: FlorgSpacing.sm,
                runSpacing: FlorgSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  for (final suggestion in suggestions)
                    SuggestionChip(
                      label: suggestion,
                      onTap: () => onSuggestionTap(suggestion),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
