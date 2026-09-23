import 'package:florg/src/data/auth_repository.dart';
import 'package:florg/src/data/financial_repository.dart';
import 'package:florg/src/data/flora_repository.dart';
import 'package:florg/src/data/goals_repository.dart';
import 'package:florg/src/data/import_repository.dart';
import 'package:florg/src/models/financial_models.dart';
import 'package:florg/src/models/flora_models.dart';
import 'package:florg/src/models/goal_models.dart';
import 'package:florg/src/models/import_models.dart';

/// Repositórios de mentira para os testes de widget.
///
/// O app real fala com a API e guarda o token no cofre do sistema. Nenhum dos
/// dois existe dentro do `flutter test`, então sem estes dublês a tela fica
/// presa no indicador de sessão e todo teste falha antes da primeira asserção.

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.signedIn = false});

  bool signedIn;
  String? lastEmail;

  /// Falha a injetar no login, para testar o caminho de erro não-API.
  Object? loginFailure;

  @override
  String get baseUrl => 'http://fake';

  @override
  String get describedBaseUrl => '$baseUrl (dublê de teste)';

  @override
  Future<bool> get isAuthenticated async => signedIn;

  @override
  Future<AuthUser> currentUser() async =>
      const AuthUser(id: 'user-1', name: 'Ana Souza', email: 'ana@florg.com');

  @override
  Future<void> login({required String email, required String password}) async {
    if (loginFailure != null) throw loginFailure!;
    lastEmail = email;
    signedIn = true;
  }

  @override
  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    signedIn = true;
    return AuthUser(id: 'user-1', name: name, email: email);
  }

  @override
  Future<AuthUser> updateProfile({String? name, String? email}) async {
    if (updateFailure != null) throw updateFailure!;
    savedProfile = (name: name, email: email);
    return AuthUser(
      id: 'user-1',
      name: name ?? 'Ana Souza',
      email: email ?? 'ana@florg.com',
    );
  }

  /// O que a tela mandou salvar, e o erro que a API deve devolver.
  ({String? name, String? email})? savedProfile;
  Object? updateFailure;

  @override
  Future<void> signOut() async {
    signedIn = false;
  }
}

class FakeFinancialRepository implements FinancialRepository {
  FakeFinancialRepository({
    List<FinancialAccount>? accounts,
    List<Transaction>? transactions,
    List<FinancialCategory>? categories,
  }) : accounts = accounts ?? defaultAccounts(),
       transactions = transactions ?? defaultTransactions(),
       categories = categories ?? defaultCategories();

  List<FinancialAccount> accounts;
  List<Transaction> transactions;
  List<FinancialCategory> categories;

  static List<FinancialAccount> defaultAccounts() => const [
    FinancialAccount(
      id: 'account-1',
      name: 'Conta Corrente',
      type: 'checking',
      balance: 4200.00,
    ),
  ];

  static List<FinancialCategory> defaultCategories() => const [
    FinancialCategory(id: 'category-1', name: 'Alimentação'),
    FinancialCategory(id: 'category-2', name: 'Moradia'),
  ];

  /// Dois meses de extrato, para as comparações mês a mês terem base.
  static List<Transaction> defaultTransactions() {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 5);
    final lastMonth = DateTime(now.year, now.month - 1, 5);

    return [
      Transaction(
        id: 't1',
        date: thisMonth,
        description: 'Salário',
        category: 'Outros',
        amount: 5000,
        type: TransactionKind.income,
        account: 'Conta Corrente',
        accountId: 'account-1',
      ),
      Transaction(
        id: 't2',
        date: thisMonth,
        description: 'Supermercado',
        category: 'Alimentação',
        amount: 800,
        type: TransactionKind.expense,
        account: 'Conta Corrente',
        accountId: 'account-1',
      ),
      Transaction(
        id: 't3',
        date: lastMonth,
        description: 'Supermercado',
        category: 'Alimentação',
        amount: 400,
        type: TransactionKind.expense,
        account: 'Conta Corrente',
        accountId: 'account-1',
      ),
    ];
  }

  @override
  Future<List<FinancialAccount>> listAccounts() async => accounts;

  @override
  Future<List<FinancialCategory>> listCategories() async => categories;

  @override
  Future<List<Transaction>> listTransactions({
    required List<FinancialAccount> accounts,
    required List<FinancialCategory> categories,
  }) async => transactions;

  @override
  Future<void> createAccount({
    required String name,
    required String type,
    required double balance,
  }) async {}

  @override
  Future<void> createTransaction({
    required String accountId,
    required String description,
    required double amount,
    required TransactionKind type,
    required DateTime occurredAt,
    String? categoryId,
  }) async {}
}

class FakeImportRepository implements ImportRepository {
  SpreadsheetPreview? nextPreview;
  ImportCommit? lastCommit;

  @override
  Future<SpreadsheetPreview> preview({
    required String filename,
    required List<int> bytes,
    String? accountId,
    ColumnMapping? mapping,
  }) async {
    return nextPreview ??
        SpreadsheetPreview(
          filename: filename,
          headers: const ['Data', 'Descrição', 'Valor'],
          mapping: const ColumnMapping(date: 0, description: 1, amount: 2),
          totalRows: 1,
          rows: [
            ImportRow(
              line: 2,
              description: 'Padaria',
              amount: 18.50,
              type: TransactionKind.expense,
              occurredAt: DateTime(2026, 4, 1),
              fingerprint: 'xlsx:abc',
            ),
          ],
          skipped: const [],
          duplicateCount: 0,
        );
  }

  @override
  Future<ImportResult> commit({
    required String accountId,
    required String filename,
    required List<ImportRow> rows,
  }) async {
    lastCommit = ImportCommit(accountId: accountId, rows: rows);
    return ImportResult(
      imported: rows.length,
      duplicates: 0,
      accountBalance: 4181.50,
    );
  }

  @override
  Future<List<ImportBatch>> listBatches() async => const [];
}

class ImportCommit {
  const ImportCommit({required this.accountId, required this.rows});

  final String accountId;
  final List<ImportRow> rows;
}


/// FLORA de mentira: responde na hora, sem rede.
///
/// [answer] é o que ela devolve; [failure] faz o envio falhar, para o teste
/// do estado de erro.
class FakeFloraRepository implements FloraRepository {
  FakeFloraRepository({this.answer = 'Você tem R\$ 320,00 de folga na semana.', this.failure});

  String answer;
  Object? failure;
  final List<String> sentMessages = [];
  final List<List<ChatMessage>> sentHistories = [];
  FloraStatus statusResponse = FloraStatus.fallback;

  @override
  Future<ChatMessage> send({
    required String message,
    required List<ChatMessage> history,
  }) async {
    sentMessages.add(message);
    sentHistories.add(List.of(history));
    if (failure != null) throw failure!;
    return ChatMessage(
      id: 'flora-${sentMessages.length}',
      author: ChatAuthor.flora,
      content: answer,
      sentAt: DateTime(2026, 4, 20),
    );
  }

  @override
  Future<FloraStatus> status() async => statusResponse;
}

class FakeGoalsRepository implements GoalsRepository {
  FakeGoalsRepository({List<Goal>? goals}) : goals = goals ?? [];

  final List<Goal> goals;
  final List<String> deleted = [];
  final List<({String id, double amount})> contributions = [];

  @override
  Future<List<Goal>> list() async => List.of(goals);

  @override
  Future<Goal> create({
    required String title,
    required double targetAmount,
    String? description,
    double savedAmount = 0,
    DateTime? deadline,
    GoalPriority priority = GoalPriority.medium,
    String? icon,
    String? linkedAccountId,
  }) async {
    final goal = Goal(
      id: 'goal-${goals.length + 1}',
      title: title,
      description: description,
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      deadline: deadline,
      priority: priority,
      icon: icon,
      linkedAccountId: linkedAccountId,
    );
    goals.add(goal);
    return goal;
  }

  @override
  Future<Goal> update(
    String id, {
    String? title,
    String? description,
    double? targetAmount,
    double? savedAmount,
    DateTime? deadline,
    GoalPriority? priority,
    String? icon,
    String? linkedAccountId,
    bool clearDeadline = false,
    bool clearLinkedAccount = false,
  }) async {
    final index = goals.indexWhere((goal) => goal.id == id);
    final current = goals[index];
    final updated = Goal(
      id: current.id,
      title: title ?? current.title,
      description: description ?? current.description,
      targetAmount: targetAmount ?? current.targetAmount,
      savedAmount: savedAmount ?? current.savedAmount,
      deadline: clearDeadline ? null : (deadline ?? current.deadline),
      priority: priority ?? current.priority,
      icon: icon ?? current.icon,
      linkedAccountId: clearLinkedAccount
          ? null
          : (linkedAccountId ?? current.linkedAccountId),
    );
    goals[index] = updated;
    return updated;
  }

  @override
  Future<Goal> contribute(String id, double amount) async {
    contributions.add((id: id, amount: amount));
    final index = goals.indexWhere((goal) => goal.id == id);
    final current = goals[index];
    final updated = Goal(
      id: current.id,
      title: current.title,
      description: current.description,
      targetAmount: current.targetAmount,
      savedAmount: current.savedAmount + amount,
      deadline: current.deadline,
      priority: current.priority,
      icon: current.icon,
      linkedAccountId: current.linkedAccountId,
    );
    goals[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    goals.removeWhere((goal) => goal.id == id);
  }
}

class FakeBudgetRepository implements BudgetRepository {
  FakeBudgetRepository({List<BudgetLimit>? budgets})
    : budgets = budgets ?? [];

  final List<BudgetLimit> budgets;
  final List<({String categoryId, DateTime month, double limit})> saved = [];
  final List<String> deleted = [];

  @override
  Future<List<BudgetLimit>> list({DateTime? month}) async {
    if (month == null) return List.of(budgets);
    return budgets
        .where(
          (item) =>
              item.month.year == month.year && item.month.month == month.month,
        )
        .toList();
  }

  @override
  Future<BudgetLimit> set({
    required String categoryId,
    required DateTime month,
    required double limitAmount,
  }) async {
    saved.add((categoryId: categoryId, month: month, limit: limitAmount));
    final first = DateTime(month.year, month.month, 1);
    final budget = BudgetLimit(
      id: 'budget-${budgets.length + 1}',
      categoryId: categoryId,
      month: first,
      limitAmount: limitAmount,
    );
    budgets.removeWhere(
      (item) =>
          item.categoryId == categoryId &&
          item.month.year == first.year &&
          item.month.month == first.month,
    );
    budgets.add(budget);
    return budget;
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    budgets.removeWhere((item) => item.id == id);
  }
}
