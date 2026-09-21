import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/flora_controller.dart';
import '../models/flora_models.dart';
import '../shared/chat.dart';

/// A conversa com a FLORA.
///
/// Ocupa a tela inteira em vez de viver num PageFrame rolável: um chat precisa
/// de uma lista que rola sozinha e de um campo fixo embaixo, e não de um
/// cabeçalho que sobe junto com as mensagens.
class FloraScreen extends StatefulWidget {
  const FloraScreen({super.key});

  @override
  State<FloraScreen> createState() => _FloraScreenState();
}

class _FloraScreenState extends State<FloraScreen> {
  final _scrollController = ScrollController();
  FloraController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FloraController>().loadStatus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<FloraController>();
    if (identical(controller, _controller)) return;
    _controller?.removeListener(_scrollToEnd);
    _controller = controller..addListener(_scrollToEnd);
  }

  @override
  void dispose() {
    _controller?.removeListener(_scrollToEnd);
    _scrollController.dispose();
    super.dispose();
  }

  /// Rola para a última mensagem depois do frame em que ela foi pintada.
  ///
  /// Antes do frame a lista ainda tem a altura antiga, e o scroll pararia
  /// acima da bolha nova.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final flora = context.watch<FloraController>();
    final isCompact = FlorgBreakpoints.isMobile(context);
    final padding = isCompact ? FlorgSpacing.md : FlorgSpacing.xl;

    return SafeArea(
      child: Column(
        children: [
          _FloraHeader(status: flora.status, compact: isCompact),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: flora.isEmpty
                    ? Padding(
                        padding: EdgeInsets.symmetric(horizontal: padding),
                        child: ChatEmptyState(
                          suggestions: flora.suggestions,
                          isLive: flora.status.isLive,
                          onSuggestionTap: flora.send,
                        ),
                      )
                    : _MessageList(
                        controller: _scrollController,
                        messages: flora.messages,
                        isThinking: flora.isThinking,
                        onRetry: flora.retry,
                        padding: padding,
                      ),
              ),
            ),
          ),
          if (flora.errorMessage != null)
            _ErrorBanner(
              message: flora.errorMessage!,
              onDismiss: flora.dismissError,
              padding: padding,
            ),
          _Composer(
            flora: flora,
            padding: padding,
            showSuggestions: !flora.isEmpty && !isCompact,
          ),
        ],
      ),
    );
  }
}

class _FloraHeader extends StatelessWidget {
  const _FloraHeader({required this.status, required this.compact});

  final FloraStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? FlorgSpacing.md : FlorgSpacing.xl,
        vertical: FlorgSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          const FloraAvatar(size: 34),
          const SizedBox(width: FlorgSpacing.sm + FlorgSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FLORA AI',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Inteligência financeira do FLORG',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (!compact) _ProviderBadge(status: status),
        ],
      ),
    );
  }
}

/// Diz se um modelo de verdade está respondendo.
///
/// Sem a chave do Claude configurada, o backend responde pelo provider
/// offline — e é honesto mostrar isso em vez de deixar parecer um modelo.
class _ProviderBadge extends StatelessWidget {
  const _ProviderBadge({required this.status});

  final FloraStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isLive = status.isLive;
    final color = isLive ? colors.success : colors.textMuted;

    return Tooltip(
      message: isLive
          ? 'Respostas geradas por modelo de linguagem'
          : 'Respostas calculadas no servidor a partir dos seus lançamentos',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: FlorgSpacing.sm + FlorgSpacing.xs,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FlorgRadius.pill),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: FlorgSpacing.sm),
            Text(
              isLive ? 'Modelo conectado' : 'Modo local',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.controller,
    required this.messages,
    required this.isThinking,
    required this.onRetry,
    required this.padding,
  });

  final ScrollController controller;
  final List<ChatMessage> messages;
  final bool isThinking;
  final ValueChanged<ChatMessage> onRetry;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.fromLTRB(padding, FlorgSpacing.lg, padding, 0),
      itemCount: messages.length + (isThinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= messages.length) return const FloraTypingIndicator();
        final message = messages[index];
        return ChatBubble(
          message: message,
          onRetry: message.hasFailed ? () => onRetry(message) : null,
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onDismiss,
    required this.padding,
  });

  final String message;
  final VoidCallback onDismiss;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, FlorgSpacing.sm, padding, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: FlorgSpacing.md,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(FlorgRadius.md),
              border: Border.all(color: colors.error.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: colors.error,
                ),
                const SizedBox(width: FlorgSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  tooltip: 'Fechar',
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.flora,
    required this.padding,
    required this.showSuggestions,
  });

  final FloraController flora;
  final double padding;
  final bool showSuggestions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        padding,
        FlorgSpacing.md,
        padding,
        FlorgSpacing.md,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showSuggestions) ...[
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: flora.suggestions.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: FlorgSpacing.sm),
                    itemBuilder: (context, index) => SuggestionChip(
                      label: flora.suggestions[index],
                      enabled: flora.canSend,
                      onTap: () => flora.send(flora.suggestions[index]),
                    ),
                  ),
                ),
                const SizedBox(height: FlorgSpacing.sm),
              ],
              ChatComposer(enabled: flora.canSend, onSend: flora.send),
            ],
          ),
        ),
      ),
    );
  }
}
