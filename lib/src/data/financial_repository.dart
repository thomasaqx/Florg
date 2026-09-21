
import '../models/financial_models.dart';
import './api_client.dart';
class FinancialRepository {
  FinancialRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<FinancialAccount>> listAccounts() async {
    final json = await _apiClient.get('/accounts') as List<dynamic>;
    return json
        .map((item) => _accountFromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<FinancialCategory>> listCategories() async {
    final json = await _apiClient.get('/categories') as List<dynamic>;
    final categories = json
        .map((item) => _categoryFromJson(item as Map<String, dynamic>))
        .toList();
    categories.sort((a, b) => a.name.compareTo(b.name));
    return categories;
  }

  /// O extrato inteiro numa requisição só.
  ///
  /// GET /transactions já devolve tudo, ordenado. A versão anterior pedia uma
  /// requisição por conta: dez contas, dez idas ao servidor para montar a
  /// mesma lista.
  Future<List<Transaction>> listTransactions({
    required List<FinancialAccount> accounts,
    required List<FinancialCategory> categories,
  }) async {
    final categoriesById = {for (final item in categories) item.id: item.name};
    final accountsById = {for (final item in accounts) item.id: item};

    final json = await _apiClient.get('/transactions') as List<dynamic>;
    return [
      for (final item in json.cast<Map<String, dynamic>>())
        _transactionFromJson(
          item,
          account: accountsById[item['account_id'].toString()],
          categoriesById: categoriesById,
        ),
    ];
  }

  Future<void> createAccount({
    required String name,
    required String type,
    required double balance,
  }) async {
    await _apiClient.post(
      '/accounts',
      body: {'name': name, 'type': type, 'balance': balance.toStringAsFixed(2)},
    );
  }

  Future<void> createTransaction({
    required String accountId,
    required String description,
    required double amount,
    required TransactionKind type,
    required DateTime occurredAt,
    String? categoryId,
  }) async {
    await _apiClient.post(
      '/transactions',
      body: {
        'account_id': accountId,
        'description': description,
        'amount': amount.toStringAsFixed(2),
        'type': type.name,
        'occurred_at': _apiDate(occurredAt),
        if (categoryId != null) 'category_id': categoryId,
      },
    );
  }

  FinancialAccount _accountFromJson(Map<String, dynamic> json) {
    return FinancialAccount(
      id: json['id'].toString(),
      name: json['name'].toString(),
      type: json['type'].toString(),
      balance: _asDouble(json['balance']),
    );
  }

  FinancialCategory _categoryFromJson(Map<String, dynamic> json) {
    return FinancialCategory(
      id: json['id'].toString(),
      name: json['name'].toString(),
      icon: json['icon']?.toString(),
    );
  }

  Transaction _transactionFromJson(
    Map<String, dynamic> json, {
    required FinancialAccount? account,
    required Map<String, String> categoriesById,
  }) {
    final categoryId = json['category_id']?.toString();
    return Transaction(
      id: json['id'].toString(),
      date: DateTime.parse(json['occurred_at'].toString()),
      description: json['description'].toString(),
      category: categoryId == null
          ? 'Sem categoria'
          : (categoriesById[categoryId] ?? 'Sem categoria'),
      categoryId: categoryId,
      amount: _asDouble(json['amount']),
      type: json['type'].toString() == TransactionKind.income.name
          ? TransactionKind.income
          : TransactionKind.expense,
      accountId: json['account_id'].toString(),
      // Uma conta criada entre a leitura das contas e a do extrato não estaria
      // no mapa; melhor um rótulo neutro do que uma exceção na tela.
      account: account?.name ?? 'Conta',
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.parse(value.toString());
}

String _apiDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
