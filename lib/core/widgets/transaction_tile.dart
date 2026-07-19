import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import '../utils/date_utils.dart';
import '../utils/money_utils.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.trailing,
  });

  final TransactionModel transaction;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'Thu';
    final icon = transaction.categoryIcon.trim().isEmpty ? (isIncome ? '↗' : '↘') : transaction.categoryIcon;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      leading: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(icon, style: const TextStyle(fontSize: 21)),
      ),
      title: Text(
        transaction.note.trim().isEmpty ? transaction.categoryName : transaction.note,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${transaction.categoryName} • ${transaction.walletName}\n${formatDateTime(transaction.date)}'),
      isThreeLine: true,
      trailing: trailing ??
          Text(
            '${isIncome ? '+' : '-'}${formatMoney(transaction.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
    );
  }
}
