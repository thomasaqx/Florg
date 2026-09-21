import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/auth_controller.dart';
import '../data/budget_controller.dart';
import '../data/financial_data_controller.dart';
import '../data/flora_controller.dart';
import '../data/goals_controller.dart';
import '../models/navigation_item.dart';
import '../screens/accounts_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/flora_screen.dart';
import '../screens/goals_screen.dart';
import '../screens/import_screen.dart';
import '../screens/insights_screen.dart';
import '../screens/investments_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/transactions_screen.dart';
import '../shared/side_navigation.dart';

class FlorgApp extends StatefulWidget {
  const FlorgApp({super.key});

  @override
  State<FlorgApp> createState() => _FlorgAppState();
}

class _FlorgAppState extends State<FlorgApp> {
  /// O FLORG é dark-first: é como a marca se apresenta, e é onde o verde
  /// petróleo funciona. O claro continua disponível em Configurações.
  bool _isDarkMode = true;
  bool _showRegister = false;

  void _toggleTheme() => setState(() => _isDarkMode = !_isDarkMode);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FLORG',
      theme: FlorgTheme.light(),
      darkTheme: FlorgTheme.dark(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: _homeFor(auth),
    );
  }

  Widget _homeFor(AuthController auth) {
    switch (auth.status) {
      // Hold the screen until the stored token is validated: showing login
      // here would make it flash for users who are already signed in.
      case AuthStatus.unknown:
        return const _SessionLoadingScreen();

      case AuthStatus.authenticated:
        return FlorgShell(
          isDarkMode: _isDarkMode,
          onToggleTheme: _toggleTheme,
          onSignOut: _signOut,
        );

      case AuthStatus.unauthenticated:
        if (_showRegister) {
          return RegisterScreen(
            isDarkMode: _isDarkMode,
            onToggleTheme: _toggleTheme,
            onBackToLogin: () => setState(() => _showRegister = false),
          );
        }
        return LoginScreen(
          isDarkMode: _isDarkMode,
          onToggleTheme: _toggleTheme,
          onCreateAccount: () => setState(() => _showRegister = true),
        );
    }
  }

  /// Zera tudo que ficou em memória antes de sair.
  ///
  /// Sem isso, a próxima pessoa a entrar veria por um instante o extrato, as
  /// metas e a conversa com a FLORA de quem saiu.
  void _signOut() {
    context.read<FinancialDataController>().clear();
    context.read<GoalsController>().clear();
    context.read<BudgetController>().clear();
    context.read<FloraController>().clear();
    context.read<AuthController>().signOut();
  }
}

/// Shown while the stored session is validated against the API.
class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class FlorgShell extends StatefulWidget {
  const FlorgShell({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onSignOut,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  @override
  State<FlorgShell> createState() => _FlorgShellState();
}

class _FlorgShellState extends State<FlorgShell> {
  int _selectedIndex = AppPage.home;
  bool _isSidebarOpen = true;
  bool _transactionAlerts = true;
  bool _weeklySummary = true;
  bool _budgetAlerts = true;
  bool _hideBalances = false;

  @override
  void initState() {
    super.initState();
    // Outside build so it does not fire on every rebuild of the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FinancialDataController>().load();
      context.read<GoalsController>().load();
      context.read<BudgetController>().load();
    });
  }

  List<Widget> _pages(Map<String, double> budgetLimits) => [
    DashboardScreen(
      onNavigate: _selectPage,
      hideBalances: _hideBalances,
      budgetLimits: budgetLimits,
    ),
    const FloraScreen(),
    const TransactionsScreen(),
    ImportScreen(onFinished: () => _selectPage(AppPage.transactions)),
    InsightsScreen(budgetLimits: budgetLimits),
    AnalyticsScreen(budgetLimits: budgetLimits),
    AccountsScreen(
      onSignOut: widget.onSignOut,
      hideBalancesByDefault: _hideBalances,
    ),
    const InvestmentsScreen(),
    const GoalsScreen(),
    SettingsScreen(
      isDarkMode: widget.isDarkMode,
      onToggleTheme: widget.onToggleTheme,
      onSignOut: widget.onSignOut,
      transactionAlerts: _transactionAlerts,
      weeklySummary: _weeklySummary,
      budgetAlerts: _budgetAlerts,
      hideBalances: _hideBalances,
      onTransactionAlertsChanged: (value) =>
          setState(() => _transactionAlerts = value),
      onWeeklySummaryChanged: (value) => setState(() => _weeklySummary = value),
      onBudgetAlertsChanged: (value) => setState(() => _budgetAlerts = value),
      onHideBalancesChanged: (value) => setState(() => _hideBalances = value),
    ),
  ];

  void _selectPage(int index) => setState(() => _selectedIndex = index);

  void _toggleSidebar() => setState(() => _isSidebarOpen = !_isSidebarOpen);

  @override
  Widget build(BuildContext context) {
    final isDesktop = FlorgBreakpoints.isDesktop(context);
    // Os tetos vêm por id de categoria e as telas trabalham por nome, então a
    // tradução precisa das duas fontes.
    final data = context.watch<FinancialDataController>();
    final budgetLimits = context.watch<BudgetController>().limitsFor(
      data.categories,
    );
    // A tela da FLORA já tem cabeçalho próprio e precisa da altura inteira.
    final isFullBleedPage = _selectedIndex == AppPage.flora;

    return Scaffold(
      backgroundColor: context.colors.background,
      bottomNavigationBar: isDesktop
          ? null
          : _MobileNavBar(
              selectedIndex: _selectedIndex,
              onSelect: _selectPage,
              onOpenMore: _openMoreMenu,
            ),
      body: Row(
        children: [
          if (isDesktop && _isSidebarOpen)
            SideNavigation(
              selectedIndex: _selectedIndex,
              onSelect: _selectPage,
              onSignOut: widget.onSignOut,
            ),
          Expanded(
            child: Column(
              children: [
                if (!isFullBleedPage || isDesktop)
                  AppTopBar(
                    isSidebarOpen: _isSidebarOpen,
                    onToggleSidebar: _toggleSidebar,
                    showNotificationBadge: _transactionAlerts,
                    onOpenSettings: () => _selectPage(AppPage.settings),
                    showSidebarToggle: isDesktop,
                  ),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _pages(budgetLimits),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// As telas que não couberam na barra inferior.
  Future<void> _openMoreMenu() async {
    final colors = context.colors;
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(FlorgRadius.lg),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < appNavItems.length; index++)
              if (!mobileNavPages.contains(index))
                ListTile(
                  leading: Icon(appNavItems[index].icon, color: colors.secondary),
                  title: Text(appNavItems[index].label),
                  onTap: () => Navigator.of(context).pop(index),
                ),
            ListTile(
              leading: Icon(Icons.settings_rounded, color: colors.secondary),
              title: const Text('Configurações'),
              onTap: () => Navigator.of(context).pop(AppPage.settings),
            ),
          ],
        ),
      ),
    );

    if (selected != null && mounted) _selectPage(selected);
  }
}

/// Barra inferior do celular: quatro destinos e um "Mais".
class _MobileNavBar extends StatelessWidget {
  const _MobileNavBar({
    required this.selectedIndex,
    required this.onSelect,
    required this.onOpenMore,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onOpenMore;

  static const _moreIndex = -1;

  @override
  Widget build(BuildContext context) {
    final position = mobileNavPages.indexOf(selectedIndex);
    // Uma página aberta pelo "Mais" não corresponde a destino nenhum; o
    // indicador então fica no "Mais".
    final indicatorIndex = position == -1 ? mobileNavPages.length : position;

    return NavigationBar(
      selectedIndex: indicatorIndex,
      onDestinationSelected: (index) {
        if (index == mobileNavPages.length) {
          onOpenMore();
          return;
        }
        onSelect(mobileNavPages[index]);
      },
      destinations: [
        for (final page in mobileNavPages)
          NavigationDestination(
            icon: Icon(appNavItems[page].icon),
            label: appNavItems[page].label,
          ),
        const NavigationDestination(
          icon: Icon(Icons.more_horiz_rounded),
          label: 'Mais',
          tooltip: 'Mais telas',
        ),
      ],
    );
  }

  // ignore: unused_element
  static int get moreIndex => _moreIndex;
}

class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.isSidebarOpen,
    required this.onToggleSidebar,
    required this.onOpenSettings,
    required this.showNotificationBadge,
    this.showSidebarToggle = true,
  });

  final bool isSidebarOpen;
  final VoidCallback onToggleSidebar;
  final VoidCallback onOpenSettings;
  final bool showNotificationBadge;
  final bool showSidebarToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      bottom: false,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: FlorgSpacing.lg),
        decoration: BoxDecoration(
          color: colors.background,
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            if (showSidebarToggle)
              IconButton(
                key: const ValueKey('toggle-sidebar'),
                onPressed: onToggleSidebar,
                tooltip: isSidebarOpen
                    ? 'Fechar menu lateral'
                    : 'Abrir menu lateral',
                style: IconButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(FlorgRadius.sm),
                  ),
                ),
                icon: Icon(
                  isSidebarOpen ? Icons.menu_open_rounded : Icons.menu_rounded,
                ),
              )
            else
              const BrandHeader(compact: true),
            const Spacer(),
            _TopBarAction(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notificações',
              showBadge: showNotificationBadge,
            ),
            const SizedBox(width: FlorgSpacing.md),
            Tooltip(
              message: 'Configurações do usuário',
              child: InkWell(
                key: const ValueKey('open-settings'),
                borderRadius: BorderRadius.circular(FlorgRadius.sm),
                onTap: onOpenSettings,
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: primaryGradient,
                    borderRadius: BorderRadius.circular(FlorgRadius.sm),
                  ),
                  child: const Text(
                    'F',
                    style: TextStyle(
                      color: FlorgPalette.onAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBarAction extends StatelessWidget {
  const _TopBarAction({
    required this.icon,
    required this.tooltip,
    this.showBadge = false,
  });

  final IconData icon;
  final String tooltip;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () {},
          tooltip: tooltip,
          style: IconButton.styleFrom(
            foregroundColor: colors.textSecondary,
            side: BorderSide(color: colors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FlorgRadius.sm),
            ),
          ),
          icon: Icon(icon, size: 20),
        ),
        if (showBadge)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colors.secondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
