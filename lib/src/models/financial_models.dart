import 'package:flutter/material.dart';

enum TransactionKind { income, expense }

enum InsightKind { warning, success, info }

class Transaction {
  const Transaction({
    required this.id,
    required this.date,
    required this.description,
    required this.category,
    required this.amount,
    required this.type,
    required this.account,
    this.categoryId,
    this.accountId,
    this.isRecurring = false,
    this.isUnnecessary = false,
  });

  final String id;
  final DateTime date;
  final String description;

  /// Category name, for display.
  final String category;
  final double amount;
  final TransactionKind type;

  /// Account name, for display.
  final String account;

  /// Category id from the API. Null for mocked data.
  final String? categoryId;

  /// Account id from the API. Null for mocked data.
  final String? accountId;

  final bool isRecurring;
  final bool isUnnecessary;

  Transaction copyWith({
    String? description,
    String? category,
    String? categoryId,
    double? amount,
    TransactionKind? type,
    DateTime? date,
  }) {
    return Transaction(
      id: id,
      date: date ?? this.date,
      description: description ?? this.description,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      account: account,
      accountId: accountId,
      isRecurring: isRecurring,
      isUnnecessary: isUnnecessary,
    );
  }
}

class FinancialAccount {
  const FinancialAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.institution = '',
  });

  final String id;
  final String name;
  final String type;
  final double balance;

  /// Financial institution. Empty for manually created accounts; only
  /// populated once Open Finance lands (phase 2).
  final String institution;
}

/// Transaction category, as returned by GET /categories.
class FinancialCategory {
  const FinancialCategory({required this.id, required this.name, this.icon});

  final String id;
  final String name;
  final String? icon;
}

class Budget {
  const Budget({
    required this.category,
    required this.allocated,
    required this.spent,
    required this.color,
  });

  final String category;
  final double allocated;
  final double spent;
  final Color color;
}

class MonthlySpending {
  const MonthlySpending({
    required this.month,
    required this.spending,
    required this.income,
  });

  final String month;
  final double spending;
  final double income;
}

class CategorySlice {
  const CategorySlice({
    required this.name,
    required this.value,
    required this.color,
  });

  final String name;
  final double value;
  final Color color;
}

class Insight {
  const Insight({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.category,
    this.potentialSavings,
  });

  final String id;
  final InsightKind type;
  final String title;
  final String description;
  final String category;
  final double? potentialSavings;
}
