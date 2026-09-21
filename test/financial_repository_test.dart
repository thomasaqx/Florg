import 'package:flutter_test/flutter_test.dart';

import 'package:florg/src/data/api_client.dart';
import 'package:florg/src/data/financial_repository.dart';
import 'package:florg/src/models/financial_models.dart';

class RecordingApiClient extends ApiClient {
  RecordingApiClient() : super(baseUrl: 'http://test');

  final posts = <({String path, Map<String, dynamic>? body})>[];
  final gets = <String>[];

  @override
  Future<dynamic> get(String path) async {
    gets.add(path);
    if (path == '/accounts') {
      return [
        {
          'id': 'account-1',
          'name': 'Conta principal',
          'type': 'checking',
          'balance': '100.50',
        },
      ];
    }
    if (path == '/categories') {
      return [
        {'id': 'category-1', 'name': 'Alimentação', 'icon': null},
      ];
    }
    if (path == '/transactions') {
      return [
        {
          'id': 'transaction-1',
          'account_id': 'account-1',
          'category_id': 'category-1',
          'description': 'Mercado',
          'amount': '25.75',
          'type': 'expense',
          'occurred_at': '2026-08-12',
        },
      ];
    }
    throw StateError('GET inesperado: $path');
  }

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool withAuth = true,
  }) async {
    posts.add((path: path, body: body));
    return <String, dynamic>{};
  }
}

void main() {
  test('mapeia contas, categorias e transações retornadas pela API', () async {
    final api = RecordingApiClient();
    final repository = FinancialRepository(apiClient: api);

    final accounts = await repository.listAccounts();
    final categories = await repository.listCategories();
    final transactions = await repository.listTransactions(
      accounts: accounts,
      categories: categories,
    );

    expect(accounts.single.name, 'Conta principal');
    expect(accounts.single.balance, 100.50);
    expect(categories.single.name, 'Alimentação');
    expect(transactions.single.description, 'Mercado');
    expect(transactions.single.category, 'Alimentação');
    expect(transactions.single.account, 'Conta principal');
    expect(transactions.single.amount, 25.75);
    // Uma requisição para o extrato inteiro, não uma por conta.
    expect(api.gets, ['/accounts', '/categories', '/transactions']);
  });

  test('envia payloads válidos para inserções manuais', () async {
    final api = RecordingApiClient();
    final repository = FinancialRepository(apiClient: api);

    await repository.createAccount(
      name: 'Carteira',
      type: 'wallet',
      balance: 10.5,
    );
    await repository.createTransaction(
      accountId: 'account-1',
      description: 'Almoço',
      amount: 32.9,
      type: TransactionKind.expense,
      occurredAt: DateTime(2026, 8, 12),
      categoryId: 'category-1',
    );

    expect(api.posts[0].path, '/accounts');
    expect(api.posts[0].body, {
      'name': 'Carteira',
      'type': 'wallet',
      'balance': '10.50',
    });
    expect(api.posts[1].path, '/transactions');
    expect(api.posts[1].body, {
      'account_id': 'account-1',
      'description': 'Almoço',
      'amount': '32.90',
      'type': 'expense',
      'occurred_at': '2026-08-12',
      'category_id': 'category-1',
    });
  });
}
