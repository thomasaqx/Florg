import 'package:flutter/foundation.dart';

import '../models/financial_models.dart';
import '../models/goal_models.dart';
import 'api_client.dart';
import 'goals_repository.dart';

/// Tetos de gasto do usuário, agora vindos do servidor.
///
/// As telas raciocinam por nome de categoria (é o que aparece no extrato) e a
/// API trabalha por id, então todo método que cruza os dois recebe a lista de
/// categorias de quem já a tem carregada. Guardar uma cópia aqui só criaria
/// uma segunda fonte da mesma verdade.
class BudgetController extends ChangeNotifier {
  BudgetController({BudgetRepository? repository})
    : _repository = repository ?? BudgetRepository();

  final BudgetRepository _repository;

  List<BudgetLimit> budgets = const [];
  bool isLoading = false;
  bool hasLoaded = false;
  String? errorMessage;

  bool _isDisposed = false;
  int _session = 0;

  /// Tetos de um mês, por nome de categoria: o formato que `budgetsFor` e as
  /// telas esperam.
  Map<String, double> limitsFor(
    List<FinancialCategory> categories, {
    DateTime? month,
  }) {
    final reference = month ?? DateTime.now();
    final namesById = {for (final item in categories) item.id: item.name};
    return {
      for (final budget in budgets)
        if (budget.month.year == reference.year &&
            budget.month.month == reference.month)
          if (namesById[budget.categoryId] != null)
            namesById[budget.categoryId]!: budget.limitAmount,
    };
  }

  String? _categoryIdFor(List<FinancialCategory> categories, String name) {
    for (final category in categories) {
      if (category.name == name) return category.id;
    }
    return null;
  }

  BudgetLimit? _budgetFor(String categoryId, DateTime month) {
    for (final budget in budgets) {
      if (budget.categoryId == categoryId &&
          budget.month.year == month.year &&
          budget.month.month == month.month) {
        return budget;
      }
    }
    return null;
  }

  Future<void> load({bool showLoading = true}) async {
    final session = _session;
    if (showLoading) {
      isLoading = true;
      errorMessage = null;
      _notify();
    }

    try {
      final loaded = await _repository.list();
      if (_isStale(session)) return;
      budgets = List.unmodifiable(loaded);
      errorMessage = null;
      hasLoaded = true;
    } on ApiException catch (error) {
      if (_isStale(session)) return;
      errorMessage = error.message;
    } catch (_) {
      if (_isStale(session)) return;
      errorMessage = 'Não foi possível carregar seus orçamentos.';
    } finally {
      if (!_isStale(session)) {
        isLoading = false;
        _notify();
      }
    }
  }

  /// Define (ou remove, com zero) o teto de uma categoria no mês.
  Future<void> setLimit({
    required List<FinancialCategory> categories,
    required String categoryName,
    required DateTime month,
    required double limitAmount,
  }) async {
    final categoryId = _categoryIdFor(categories, categoryName);
    if (categoryId == null) {
      errorMessage = 'Categoria "$categoryName" não existe no servidor.';
      _notify();
      return;
    }

    final session = _session;
    try {
      if (limitAmount <= 0) {
        final existing = _budgetFor(categoryId, month);
        if (existing == null) return;
        await _repository.delete(existing.id);
      } else {
        await _repository.set(
          categoryId: categoryId,
          month: month,
          limitAmount: limitAmount,
        );
      }
      if (_isStale(session)) return;
      await load(showLoading: false);
    } on ApiException catch (error) {
      if (_isStale(session)) return;
      errorMessage = error.message;
      _notify();
    }
  }

  void clear() {
    _session++;
    budgets = const [];
    isLoading = false;
    hasLoaded = false;
    errorMessage = null;
    _notify();
  }

  bool _isStale(int session) => _isDisposed || session != _session;

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
