import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app/florg_app.dart';
import 'src/data/api_client.dart';
import 'src/data/auth_controller.dart';
import 'src/data/auth_repository.dart';
import 'src/data/budget_controller.dart';
import 'src/data/financial_data_controller.dart';
import 'src/data/financial_repository.dart';
import 'src/data/flora_controller.dart';
import 'src/data/flora_repository.dart';
import 'src/data/goals_controller.dart';
import 'src/data/goals_repository.dart';
import 'src/data/import_repository.dart';

void main() {
  runApp(const FlorgBootstrap());
}

/// Builds the dependency graph once and injects it into the app.
///
/// Everything shares a single ApiClient, so switching the base URL
/// (dev, staging, production) changes the whole app in one place.
class FlorgBootstrap extends StatelessWidget {
  const FlorgBootstrap({
    super.key,
    this.authRepository,
    this.financialRepository,
    this.importRepository,
    this.floraRepository,
    this.goalsRepository,
    this.budgetRepository,
  });

  /// Repositórios injetados nos testes de widget.
  ///
  /// Em produção ficam nulos e o app monta os de verdade. Sem isto o teste
  /// precisaria de rede e do cofre do sistema operacional, que não existem no
  /// `flutter test`, e o app travava na tela de sessão carregando.
  final AuthRepository? authRepository;
  final FinancialRepository? financialRepository;
  final ImportRepository? importRepository;
  final FloraRepository? floraRepository;
  final GoalsRepository? goalsRepository;
  final BudgetRepository? budgetRepository;

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();
    final auth = authRepository ?? AuthRepository(apiClient: apiClient);
    final financial =
        financialRepository ?? FinancialRepository(apiClient: apiClient);
    final imports = importRepository ?? ImportRepository(apiClient: apiClient);
    final flora = floraRepository ?? FloraRepository(apiClient: apiClient);
    final goals = goalsRepository ?? GoalsRepository(apiClient: apiClient);
    final budgets = budgetRepository ?? BudgetRepository(apiClient: apiClient);

    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<AuthRepository>.value(value: auth),
        Provider<FinancialRepository>.value(value: financial),
        Provider<ImportRepository>.value(value: imports),
        Provider<FloraRepository>.value(value: flora),
        Provider<GoalsRepository>.value(value: goals),
        Provider<BudgetRepository>.value(value: budgets),
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(repository: auth)..restoreSession(),
        ),
        ChangeNotifierProvider<FinancialDataController>(
          create: (_) => FinancialDataController(repository: financial),
        ),
        ChangeNotifierProvider<GoalsController>(
          create: (_) => GoalsController(repository: goals),
        ),
        ChangeNotifierProvider<BudgetController>(
          create: (_) => BudgetController(repository: budgets),
        ),
        ChangeNotifierProvider<FloraController>(
          create: (_) => FloraController(repository: flora),
        ),
      ],
      child: const FlorgApp(),
    );
  }
}
