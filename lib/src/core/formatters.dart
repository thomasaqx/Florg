
import '../models/financial_models.dart';

/// Sum of the balances of the given accounts.
double totalBalanceOf(Iterable<FinancialAccount> source) =>
    source.fold(0, (sum, account) => sum + account.balance);

/// Transactions that fall within the month of [reference].
List<Transaction> transactionsInMonth(
  Iterable<Transaction> source,
  DateTime reference,
) => source
    .where(
      (transaction) =>
          transaction.date.year == reference.year &&
          transaction.date.month == reference.month,
    )
    .toList();

double totalFor(Iterable<Transaction> source, TransactionKind type) => source
    .where((transaction) => transaction.type == type)
    .fold(0, (sum, transaction) => sum + transaction.amount);

String formatCurrency(num value, {int decimals = 2}) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final integer = parts.first;
  final buffer = StringBuffer();

  for (var i = 0; i < integer.length; i++) {
    final remaining = integer.length - i;
    buffer.write(integer[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }

  final decimalPart = decimals > 0 ? ',${parts.last}' : '';
  return '${negative ? '-' : ''}R\$ ${buffer.toString()}$decimalPart';
}

String formatTransactionAmount(Transaction transaction) {
  final prefix = transaction.type == TransactionKind.income ? '+' : '-';
  return '$prefix${formatCurrency(transaction.amount)}';
}

String formatDate(DateTime date, {bool includeYear = true}) {
  const months = [
    'jan.',
    'fev.',
    'mar.',
    'abr.',
    'mai.',
    'jun.',
    'jul.',
    'ago.',
    'set.',
    'out.',
    'nov.',
    'dez.',
  ];
  final base = '${date.day} de ${months[date.month - 1]}';
  return includeYear ? '$base de ${date.year}' : base;
}

String transactionKindLabel(TransactionKind type) {
  return type == TransactionKind.income ? 'Receita' : 'Despesa';
}
