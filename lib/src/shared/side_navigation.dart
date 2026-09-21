import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/navigation_item.dart';
import './layout.dart';
class SideNavigation extends StatelessWidget {
  const SideNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onSignOut,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 244,
      decoration: BoxDecoration(
        color: context.isDark ? FlorgPalette.inkDeep : colors.surface,
        border: Border(right: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FlorgSpacing.md,
            vertical: FlorgSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: FlorgSpacing.sm),
                child: BrandHeader(),
              ),
              const SizedBox(height: FlorgSpacing.xl),
              // A lista rola: numa tela baixa, nove destinos mais o rodape nao
              // cabem, e uma Column fixa estouraria em vez de deslizar.
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (var i = 0; i < appNavItems.length; i++)
                      NavButton(
                        item: appNavItems[i],
                        isSelected: selectedIndex == i,
                        onTap: () => onSelect(i),
                      ),
                    const SizedBox(height: FlorgSpacing.md),
                    SignOutTile(onSignOut: onSignOut),
                  ],
                ),
              ),
              const SizedBox(height: FlorgSpacing.md),
              HelpCard(onImport: () => onSelect(AppPage.import)),
            ],
          ),
        ),
      ),
    );
  }
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.compact = false});

  /// No celular a marca divide a barra superior com os botões, então só o
  /// logo e o nome cabem.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LeafLogo(size: 26),
          const SizedBox(width: FlorgSpacing.sm),
          Text(
            'FLORG',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              letterSpacing: 1.5,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const LeafLogo(size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FLORG',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'Organizador financeiro',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LeafLogo extends StatelessWidget {
  const LeafLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: LeafLogoPainter()),
    );
  }
}

class LeafLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 40;
    final scaleY = size.height / 40;
    canvas.scale(scaleX, scaleY);

    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFF5AB9A8);
    canvas.drawPath(
      Path()
        ..moveTo(20, 8)
        ..cubicTo(20, 8, 16, 10, 14, 14)
        ..cubicTo(12, 18, 13, 22, 13, 22)
        ..lineTo(20, 20)
        ..close(),
      paint,
    );

    paint.color = const Color(0xFF4A9B8E);
    canvas.drawPath(
      Path()
        ..moveTo(20, 8)
        ..cubicTo(20, 8, 24, 10, 26, 14)
        ..cubicTo(28, 18, 27, 22, 27, 22)
        ..lineTo(20, 20)
        ..close(),
      paint,
    );

    paint.color = const Color(0xFF6DCDB9);
    canvas.drawPath(
      Path()
        ..moveTo(20, 12)
        ..cubicTo(20, 12, 17, 13, 16, 16)
        ..cubicTo(15, 19, 16, 21, 16, 21)
        ..lineTo(20, 20)
        ..close(),
      paint,
    );

    paint.color = const Color(0xFF5AB9A8);
    canvas.drawPath(
      Path()
        ..moveTo(20, 12)
        ..cubicTo(20, 12, 23, 13, 24, 16)
        ..cubicTo(25, 19, 24, 21, 24, 21)
        ..lineTo(20, 20)
        ..close(),
      paint,
    );

    paint.color = const Color(0xCC1E4D47);
    canvas.drawPath(
      Path()
        ..moveTo(20, 20)
        ..cubicTo(20, 20, 18, 22, 16, 26)
        ..cubicTo(14, 30, 15, 34, 15, 34)
        ..cubicTo(15, 34, 16, 32, 18, 30)
        ..cubicTo(20, 28, 22, 27, 22, 27)
        ..cubicTo(22, 27, 21, 25, 20, 23)
        ..cubicTo(19, 21, 20, 20, 20, 20)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class NavButton extends StatelessWidget {
  const NavButton({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Selecionado e um preenchimento discreto com um tracinho verde na
    // esquerda, nao um botao inteiro em gradiente: com nove itens, nove
    // blocos verdes competiriam com o conteudo da tela.
    final foreground = isSelected ? colors.textPrimary : colors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(FlorgRadius.sm),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected ? colors.primaryMuted : Colors.transparent,
              borderRadius: BorderRadius.circular(FlorgRadius.sm),
              border: Border(
                left: BorderSide(
                  color: isSelected ? colors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 19,
                  color: isSelected ? colors.secondary : colors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
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

class SignOutTile extends StatelessWidget {
  const SignOutTile({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(FlorgRadius.sm),
        onTap: onSignOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FlorgRadius.sm),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.logout_rounded, color: colors.textSecondary, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sair',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HelpCard extends StatelessWidget {
  const HelpCard({super.key, this.onImport});

  /// Leva para a tela de importação. Null desabilita o botão.
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(FlorgSpacing.md),
      color: context.colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sem lançar nada à mão',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: FlorgSpacing.xs),
          Text(
            'Importe o extrato que o banco exporta em .xlsx ou .csv',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              label: 'Importar extrato',
              onPressed: onImport ?? () {},
              height: 38,
            ),
          ),
        ],
      ),
    );
  }
}
