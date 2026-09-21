import '../models/goal_models.dart';
import 'api_client.dart';

/// Metas persistidas em /goals.
class GoalsRepository {
  GoalsRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Goal>> list() async {
    final json = await _apiClient.get('/goals') as List<dynamic>;
    return json.map((item) => Goal.fromJson(item as Map<String, dynamic>)).toList();
  }

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
    final json = await _apiClient.post(
      '/goals',
      body: {
        'title': title,
        'target_amount': _money(targetAmount),
        'saved_amount': _money(savedAmount),
        'priority': priority.name,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (deadline != null) 'deadline': _apiDate(deadline),
        if (icon != null) 'icon': icon,
        if (linkedAccountId != null) 'linked_account_id': linkedAccountId,
      },
    );
    return Goal.fromJson(json as Map<String, dynamic>);
  }

  /// PATCH: só o que for passado muda.
  ///
  /// [clearDeadline] e [clearLinkedAccount] existem porque `null` num
  /// parâmetro opcional significa "não mexer"; sem eles não haveria como
  /// desvincular uma conta.
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
    final json = await _apiClient.patch('/goals/$id', body: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (targetAmount != null) 'target_amount': _money(targetAmount),
      if (savedAmount != null) 'saved_amount': _money(savedAmount),
      if (priority != null) 'priority': priority.name,
      if (icon != null) 'icon': icon,
      if (clearDeadline) 'deadline': null
      else if (deadline != null) 'deadline': _apiDate(deadline),
      if (clearLinkedAccount) 'linked_account_id': null
      else if (linkedAccountId != null) 'linked_account_id': linkedAccountId,
    });
    return Goal.fromJson(json as Map<String, dynamic>);
  }

  Future<Goal> contribute(String id, double amount) async {
    final json = await _apiClient.post(
      '/goals/$id/contributions',
      body: {'amount': _money(amount)},
    );
    return Goal.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _apiClient.delete('/goals/$id');
}

/// Tetos de gasto persistidos em /budgets.
class BudgetRepository {
  BudgetRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<BudgetLimit>> list({DateTime? month}) async {
    final query = month == null ? '' : '?month=${_apiDate(month)}';
    final json = await _apiClient.get('/budgets$query') as List<dynamic>;
    return json
        .map((item) => BudgetLimit.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// PUT: um teto por categoria por mês. Chamar de novo troca o valor.
  Future<BudgetLimit> set({
    required String categoryId,
    required DateTime month,
    required double limitAmount,
  }) async {
    final json = await _apiClient.put(
      '/budgets',
      body: {
        'category_id': categoryId,
        'month': _apiDate(month),
        'limit_amount': _money(limitAmount),
      },
    );
    return BudgetLimit.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _apiClient.delete('/budgets/$id');
}

/// Duas casas, como texto: o backend guarda Numeric(12,2) e double serializado
/// direto chegaria com a imprecisão do ponto flutuante.
String _money(double value) => value.toStringAsFixed(2);

String _apiDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
