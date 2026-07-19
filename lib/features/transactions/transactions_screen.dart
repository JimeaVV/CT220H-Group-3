import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/money_utils.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/transaction_tile.dart';
import '../../models/transaction_model.dart';
import '../../providers/app_providers.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _filter = 'Tất cả';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final userId = user.uid;
    final asyncItems = ref.watch(transactionsProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao dịch'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(transactionsProvider(userId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: asyncItems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(18),
          child: ErrorCard(error: error, onRetry: () => ref.invalidate(transactionsProvider(userId))),
        ),
        data: (items) {
          final filtered = items.where((item) {
            final matchesType = _filter == 'Tất cả' || item.type == _filter;
            final needle = _query.trim().toLowerCase();
            final matchesQuery = needle.isEmpty ||
                item.note.toLowerCase().contains(needle) ||
                item.categoryName.toLowerCase().contains(needle) ||
                item.walletName.toLowerCase().contains(needle);
            return matchesType && matchesQuery;
          }).toList();
          final income = filtered.where((e) => e.type == 'Thu').fold<double>(0, (sum, e) => sum + e.amount);
          final expense = filtered.where((e) => e.type == 'Chi').fold<double>(0, (sum, e) => sum + e.amount);

          return RefreshIndicator(
            onRefresh: () async {
              invalidateFinanceData(ref, userId);
              await ref.read(transactionsProvider(userId).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
              children: [
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Tìm ghi chú, danh mục hoặc ví...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Tất cả', label: Text('Tất cả')),
                    ButtonSegment(value: 'Thu', label: Text('Thu')),
                    ButtonSegment(value: 'Chi', label: Text('Chi')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (value) => setState(() => _filter = value.first),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _TotalCard(label: 'Tổng thu', value: income, icon: Icons.south_west_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: _TotalCard(label: 'Tổng chi', value: expense, icon: Icons.north_east_rounded)),
                  ],
                ),
                const SizedBox(height: 22),
                SectionHeader(title: '${filtered.length} giao dịch'),
                const SizedBox(height: 6),
                if (filtered.isEmpty)
                  EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Không có giao dịch',
                    message: 'Thử đổi bộ lọc hoặc tạo giao dịch mới.',
                    actionLabel: 'Thêm giao dịch',
                    onAction: () => context.push('/transaction/new'),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Column(
                        children: [
                          for (var i = 0; i < filtered.length; i++) ...[
                            TransactionTile(
                              transaction: filtered[i],
                              onTap: () => context.push('/transaction/edit', extra: filtered[i]),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) => _handleAction(action, filtered[i], userId),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Sửa')),
                                  PopupMenuItem(value: 'delete', child: Text('Xóa')),
                                ],
                              ),
                            ),
                            if (i < filtered.length - 1) const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleAction(String action, TransactionModel item, String userId) async {
    if (action == 'edit') {
      await context.push('/transaction/edit', extra: item);
      return;
    }

    final confirmed = await showDeleteConfirmation(
      context,
      title: 'Xóa giao dịch?',
      message: 'Số dư của ví sẽ được hoàn lại theo giao dịch này.',
    );
    if (!confirmed) return;

    try {
      await ref.read(financeRepositoryProvider).deleteTransaction(item.id);
      invalidateFinanceData(ref, userId);
      if (mounted) showAppSnackBar(context, 'Đã xóa giao dịch.');
    } catch (error) {
      if (mounted) showAppSnackBar(context, error.toString(), isError: true);
    }
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.label, required this.value, required this.icon});
  final String label;
  final double value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 13),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatMoney(value), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            ),
          ],
        ),
      ),
    );
  }
}
