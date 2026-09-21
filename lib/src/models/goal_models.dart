/// Prioridade de uma meta, como o backend a nomeia.
enum GoalPriority { low, medium, high }

extension GoalPriorityLabel on GoalPriority {
  String get label => switch (this) {
    GoalPriority.low => 'Baixa',
    GoalPriority.medium => 'Média',
    GoalPriority.high => 'Alta',
  };
}

GoalPriority goalPriorityFrom(String? value) {
  return GoalPriority.values.firstWhere(
    (item) => item.name == value,
    orElse: () => GoalPriority.medium,
  );
}

/// Uma meta de poupança, agora vinda de GET /goals.
///
/// Antes as metas viviam só na memória da sessão do app: fechou, perdeu.
class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
    this.description,
    this.deadline,
    this.priority = GoalPriority.medium,
    this.icon,
    this.linkedAccountId,
  });

  final String id;
  final String title;
  final String? description;
  final double targetAmount;
  final double savedAmount;
  final DateTime? deadline;
  final GoalPriority priority;

  /// Chave do ícone escolhido na tela (viagem, casa, carro...).
  final String? icon;

  /// Quando preenchido, o progresso segue o saldo da conta em vez do valor
  /// guardado à mão.
  final String? linkedAccountId;

  bool get isLinked => linkedAccountId != null;

  /// Quanto já foi juntado, considerando a conta vinculada quando existe.
  double savedWith(double? linkedAccountBalance) {
    final value = isLinked ? (linkedAccountBalance ?? savedAmount) : savedAmount;
    return value < 0 ? 0 : value;
  }

  double progressWith(double? linkedAccountBalance) {
    if (targetAmount <= 0) return 0;
    return (savedWith(linkedAccountBalance) / targetAmount).clamp(0.0, 1.0);
  }

  double remainingWith(double? linkedAccountBalance) {
    final value = targetAmount - savedWith(linkedAccountBalance);
    return value < 0 ? 0 : value;
  }

  bool isCompletedWith(double? linkedAccountBalance) =>
      targetAmount > 0 && savedWith(linkedAccountBalance) >= targetAmount;

  bool isOverdueWith(double? linkedAccountBalance) =>
      !isCompletedWith(linkedAccountBalance) &&
      deadline != null &&
      deadline!.isBefore(DateTime.now());

  factory Goal.fromJson(Map<String, dynamic> json) {
    final deadline = json['deadline']?.toString();
    return Goal(
      id: json['id'].toString(),
      title: json['title'].toString(),
      description: json['description']?.toString(),
      targetAmount: _asDouble(json['target_amount']),
      savedAmount: _asDouble(json['saved_amount']),
      deadline: deadline == null ? null : DateTime.tryParse(deadline),
      priority: goalPriorityFrom(json['priority']?.toString()),
      icon: json['icon']?.toString(),
      linkedAccountId: json['linked_account_id']?.toString(),
    );
  }
}

/// Teto de gasto de uma categoria num mês, como vem de GET /budgets.
///
/// Não se confunde com o `Budget` de financial_models: aquele é o que a tela
/// desenha (teto mais gasto mais cor), este é o registro que o banco guarda.
class BudgetLimit {
  const BudgetLimit({
    required this.id,
    required this.categoryId,
    required this.month,
    required this.limitAmount,
  });

  final String id;
  final String categoryId;

  /// Sempre o primeiro dia do mês: é assim que o backend guarda.
  final DateTime month;
  final double limitAmount;

  factory BudgetLimit.fromJson(Map<String, dynamic> json) {
    return BudgetLimit(
      id: json['id'].toString(),
      categoryId: json['category_id'].toString(),
      month: DateTime.parse(json['month'].toString()),
      limitAmount: _asDouble(json['limit_amount']),
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
