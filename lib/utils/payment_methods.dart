import '../database/database.dart';

/// Payment methods for [kind]: methods used by expenses and withdrawals, most
/// used within [kind] first. [current] is always included so a freshly entered
/// method stays visible.
List<String> paymentMethodSuggestions({
  required List<MoneyTransaction> transactions,
  required TransactionKind kind,
  String current = '',
}) {
  final own = <String, int>{};
  final all = <String, int>{};
  for (final t in transactions) {
    final method = t.method.trim();
    final usesMethod = t.isSpending || t.isWithdrawal;
    if (!usesMethod || method.isEmpty) continue;
    all[method] = (all[method] ?? 0) + 1;
    if (t.type == kind) own[method] = (own[method] ?? 0) + 1;
  }
  if (kind != TransactionKind.withdrawal) all.putIfAbsent(cashMethod, () => 0);
  // Cash is what a withdrawal produces, not a way to pay for it.
  if (kind == TransactionKind.withdrawal) all.remove(cashMethod);

  final trimmed = current.trim();
  if (trimmed.isNotEmpty && !all.containsKey(trimmed)) {
    all[trimmed] = 0;
    own[trimmed] = 999;
  }

  int ownCount(String m) => own[m] ?? 0;
  return all.keys.toList()
    ..sort((a, b) {
      final byOwn = ownCount(b).compareTo(ownCount(a));
      return byOwn != 0 ? byOwn : all[b]!.compareTo(all[a]!);
    });
}
