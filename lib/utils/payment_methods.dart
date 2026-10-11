import '../database/database.dart';

/// Payment methods used before for [kind], most frequent first.
/// [current] is always included so a freshly entered method stays visible.
List<String> paymentMethodSuggestions({
  required List<MoneyTransaction> transactions,
  required TransactionKind kind,
  String current = '',
}) {
  final counts = <String, int>{};
  for (final t in transactions) {
    final method = t.method.trim();
    if (t.type == kind && method.isNotEmpty) {
      counts[method] = (counts[method] ?? 0) + 1;
    }
  }
  if (kind == TransactionKind.expense) counts.putIfAbsent(cashMethod, () => 0);

  final trimmed = current.trim();
  if (trimmed.isNotEmpty && !counts.containsKey(trimmed)) {
    counts[trimmed] = 999;
  }

  return counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
}
