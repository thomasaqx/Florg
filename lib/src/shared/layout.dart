import 'dart:math' as math;
import 'package:flutter/material.dart';


import '../core/theme.dart';
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.trailing,
    this.floatingActionButton,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? trailing;

  /// Primary page action. Wrapped in its own Scaffold so it floats above the
  /// scrollable content instead of pushing the layout.
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 700;
    final content = SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isCompact ? 20 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: trailing == null || isCompact ? double.infinity : 420,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: FlorgSpacing.sm),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 32),
            ...children,
          ],
        ),
      ),
    );

    if (floatingActionButton == null) return content;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: content,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// O card do FLORG: superficie chapada, borda de 1px quase invisivel e canto
/// curto.
///
/// Sem sombra por padrao. No dark mode a hierarquia vem da superficie e do
/// espaco em volta; sombra sobre um fundo quase preto so suja a borda.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FlorgSpacing.lg),
    this.color,
    this.gradient,
    this.borderColor,
    this.bordered = true,
    this.shadow = false,
    this.radius = FlorgRadius.md,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;

  /// Borda diferente da padrao, para destacar um estado (erro, selecionado).
  final Color? borderColor;

  /// Um card sobre gradiente dispensa borda; o resto leva.
  final bool bordered;
  final bool shadow;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final showBorder = bordered && (gradient == null || borderColor != null);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        color: gradient == null ? (color ?? colors.surface) : null,
        border: showBorder
            ? Border.all(color: borderColor ?? colors.border)
            : null,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// Rotulo de secao em caixa alta espacada: o "SALDO TOTAL" da identidade.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color ?? context.colors.textSecondary,
      ),
    );
  }
}

/// Rotulo pequeno em cima, numero grande embaixo. O bloco que se repete em
/// toda tela de resumo.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.valueColor,
    this.valueSize = 28,
  });

  final String label;
  final String value;
  final String? caption;
  final Color? valueColor;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(label),
        const SizedBox(height: FlorgSpacing.sm),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FlorgText.figure(
            context,
            size: valueSize,
          ).copyWith(color: valueColor),
        ),
        if (caption != null) ...[
          const SizedBox(height: FlorgSpacing.xs),
          Text(caption!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class ResponsiveWrap extends StatelessWidget {
  const ResponsiveWrap({
    super.key,
    required this.children,
    this.minItemWidth = 260,
    this.maxColumns = 4,
    this.spacing = 24,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rawColumns = (constraints.maxWidth / minItemWidth).floor();
        final columns = math.max(1, math.min(maxColumns, rawColumns));
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class TwoColumnSection extends StatelessWidget {
  const TwoColumnSection({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 2,
    this.rightFlex = 1,
    this.breakpoint = 1100,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(children: [left, const SizedBox(height: 24), right]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: 24),
            Expanded(flex: rightFlex, child: right),
          ],
        );
      },
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 44,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.primary,
        borderRadius: BorderRadius.circular(FlorgRadius.md),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(FlorgRadius.md),
          onTap: onPressed,
          child: SizedBox(
            height: height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: context.colors.onPrimary),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OutlineActionButton extends StatelessWidget {
  const OutlineActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: context.colors.textSecondary,
        side: BorderSide(color: context.colors.border),
        backgroundColor: context.colors.surface,
        padding: const EdgeInsets.symmetric(
          horizontal: FlorgSpacing.md,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlorgRadius.md),
        ),
      ),
    );
  }
}

class SectionGap extends StatelessWidget {
  const SectionGap({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: 32);
}

/// Default decoration for the app's form fields.
/// So o que muda por campo. Preenchimento, borda e foco vem do
/// inputDecorationTheme, entao um ajuste de forma acontece no tema.
InputDecoration inputDecoration(
  BuildContext context, {
  String? hintText,
  IconData? prefixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, color: context.colors.textMuted, size: 18),
  );
}
