import 'package:flutter/foundation.dart';

import '../models/goal_models.dart';
import 'api_client.dart';
import 'goals_repository.dart';

/// Metas do usuário, agora vindas do servidor.
class GoalsController extends ChangeNotifier {
  GoalsController({GoalsRepository? repository})
    : _repository = repository ?? GoalsRepository();

  final GoalsRepository _repository;

  List<Goal> goals = const [];
  bool isLoading = false;
  bool hasLoaded = false;
  String? errorMessage;

  bool _isDisposed = false;
  int _session = 0;

  bool get isEmpty => goals.isEmpty;

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
      goals = List.unmodifiable(loaded);
      errorMessage = null;
      hasLoaded = true;
    } on ApiException catch (error) {
      if (_isStale(session)) return;
      errorMessage = error.message;
    } catch (_) {
      if (_isStale(session)) return;
      errorMessage = 'Não foi possível carregar suas metas.';
    } finally {
      if (!_isStale(session)) {
        isLoading = false;
        _notify();
      }
    }
  }

  Future<void> create({
    required String title,
    required double targetAmount,
    String? description,
    double savedAmount = 0,
    DateTime? deadline,
    GoalPriority priority = GoalPriority.medium,
    String? icon,
    String? linkedAccountId,
  }) {
    return _mutate(
      () => _repository.create(
        title: title,
        targetAmount: targetAmount,
        description: description,
        savedAmount: savedAmount,
        deadline: deadline,
        priority: priority,
        icon: icon,
        linkedAccountId: linkedAccountId,
      ),
    );
  }

  Future<void> update(
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
  }) {
    return _mutate(
      () => _repository.update(
        id,
        title: title,
        description: description,
        targetAmount: targetAmount,
        savedAmount: savedAmount,
        deadline: deadline,
        priority: priority,
        icon: icon,
        linkedAccountId: linkedAccountId,
        clearDeadline: clearDeadline,
        clearLinkedAccount: clearLinkedAccount,
      ),
    );
  }

  Future<void> contribute(String id, double amount) =>
      _mutate(() => _repository.contribute(id, amount));

  Future<void> delete(String id) => _mutate(() => _repository.delete(id));

  void clear() {
    _session++;
    goals = const [];
    isLoading = false;
    hasLoaded = false;
    errorMessage = null;
    _notify();
  }

  /// Escreve e recarrega. A lista vem do servidor, não de um palpite local,
  /// para o app nunca mostrar um valor que o banco recusou.
  Future<void> _mutate(Future<void> Function() action) async {
    final session = _session;
    try {
      await action();
      if (_isStale(session)) return;
      await load(showLoading: false);
    } on ApiException catch (error) {
      if (_isStale(session)) return;
      errorMessage = error.message;
      _notify();
      rethrow;
    }
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
