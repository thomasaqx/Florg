import 'package:flutter/material.dart';

class NavItem {
  const NavItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Posição de cada tela dentro do IndexedStack do FlorgShell.
///
/// Existe porque o índice era escrito à mão em cada chamada de navegação, e o
/// botão de configurações apontava para a tela de metas. Com nome, uma tela nova
/// no meio da lista não desloca as outras silenciosamente.
abstract final class AppPage {
  static const home = 0;
  static const flora = 1;
  static const transactions = 2;
  static const import = 3;
  static const insights = 4;
  static const analytics = 5;
  static const accounts = 6;
  static const investments = 7;
  static const goals = 8;

  /// Fora da barra de navegação: só o avatar da barra superior abre.
  static const settings = 9;
}

/// Os itens visíveis na barra lateral, na ordem de AppPage.
const appNavItems = [
  NavItem('Início', Icons.home_rounded),
  NavItem('FLORA AI', Icons.auto_awesome_rounded),
  NavItem('Transações', Icons.credit_card_rounded),
  NavItem('Importar', Icons.upload_file_rounded),
  NavItem('Insights', Icons.trending_up_rounded),
  NavItem('Análises', Icons.bar_chart_rounded),
  NavItem('Contas', Icons.account_balance_wallet_rounded),
  NavItem('Investimentos', Icons.candlestick_chart_rounded),
  NavItem('Metas', Icons.flag_rounded),
];

/// O que cabe na barra inferior do celular.
///
/// Nove destinos numa NavigationBar viram nove alvos de 40px que ninguém
/// acerta. As telas de fora entram pelo menu "Mais".
const mobileNavPages = [
  AppPage.home,
  AppPage.flora,
  AppPage.transactions,
  AppPage.accounts,
];
