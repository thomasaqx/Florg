import 'package:flutter/foundation.dart';

import '../models/financial_models.dart';
import './api_client.dart';
import './financial_repository.dart';
class FinancialDataController extends ChangeNotifier {
  FinancialDataController({FinancialRepository? repository})
    : _repository = repository ?? FinancialRepository();

  final FinancialRepository _repository;

  List<FinancialAccount> accounts = const [];
  List<Transaction> transactions = const [];
  List<FinancialCategory> categories = const [];
  bool isLoading = false;
  bool hasLoaded = false;
  String? errorMessage;
  int _loadRequest = 0;
  int _session = 0;
  bool _isDisposed = false;

  Future<void> load({bool showLoading = true}) async {
    final request = ++_loadRequest;
    final session = _session;
    if (showLoading) {
      isLoading = true;
      errorMessage = null;
      _notifyListeners();
    }

    try {
      final results = await Future.wait<dynamic>([
        _repository.listAccounts(),
        _repository.listCategories(),
      ]);
      final loadedAccounts = results[0] as List<FinancialAccount>;
      final loadedCategories = results[1] as List<FinancialCategory>;
      final loadedTransactions = await _repository.listTransactions(
        accounts: loadedAccounts,
        categories: loadedCategories,
      );
      if (!_isCurrent(request, session)) return;

      accounts = List.unmodifiable(loadedAccounts);
      categories = List.unmodifiable(loadedCategories);
      transactions = List.unmodifiable(loadedTransactions);
      errorMessage = null;
      hasLoaded = true;
    } on ApiException catch (error) {
      if (!_isCurrent(request, session)) return;
      errorMessage = error.message;
    } catch (_) {
      if (!_isCurrent(request, session)) return;
      errorMessage = 'Não foi possível carregar seus dados financeiros.';
    } finally {
      if (_isCurrent(request, session)) {
        isLoading = false;
        _notifyListeners();
      }
    }
  }

  Future<void> createAccount({
    required String name,
    required String type,
    required double balance,
  }) async {
    final session = _session;
    await _repository.createAccount(name: name, type: type, balance: balance);
    if (_isDisposed || session != _session) return;
    await load(showLoading: false);
  }

  Future<void> createTransaction({
    required String accountId,
    required String description,
    required double amount,
    required TransactionKind type,
    required DateTime occurredAt,
    String? categoryId,
  }) async {
    final session = _session;
    await _repository.createTransaction(
      accountId: accountId,
      description: description,
      amount: amount,
      type: type,
      occurredAt: occurredAt,
      categoryId: categoryId,
    );
    if (_isDisposed || session != _session) return;
    await load(showLoading: false);
  }

  void clear() {
    _session++;
    _loadRequest++;
    accounts = const [];
    transactions = const [];
    categories = const [];
    isLoading = false;
    hasLoaded = false;
    errorMessage = null;
    _notifyListeners();
  }

  bool _isCurrent(int request, int session) =>
      !_isDisposed && request == _loadRequest && session == _session;

  void _notifyListeners() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _loadRequest++;
    super.dispose();
  }
}
