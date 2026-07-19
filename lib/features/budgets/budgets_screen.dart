import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/money_utils.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/budget_model.dart';
import '../../models/category_model.dart';
import '../../providers/app_providers.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  late int _month = DateTime.now().month;
  late int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final userId = user.uid;
    final request = BudgetRequest(userId, _month, _year);
    final budgets = ref.watch(budgetStatusProvider(request));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ngân sách'),
        actions: [
          IconButton(onPressed: () => _showBudgetForm(userId), icon: const Icon(Icons.add_rounded)),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _month,
                    decoration: const InputDecoration(labelText: 'Tháng'),
                    items: List.generate(12, (index) => DropdownMenuItem(value: index + 1, child: Text('Tháng ${index + 1}'))),
                    onChanged: (value) => setState(() => _month = value ?? _month),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _year,
                    decoration: const InputDecoration(labelText: 'Năm'),
                    items: List.generate(7, (index) {
                      final year = DateTime.now().year - 2 + index;
                      return DropdownMenuItem(value: year, child: Text('$year'));
                    }),
                    onChanged: (value) => setState(() => _year = value ?? _year),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: budgets.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(18),
                child: ErrorCard(error: error, onRetry: () => ref.invalidate(budgetStatusProvider(request))),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.savings_outlined,
                    title: 'Chưa đặt ngân sách',
                    message: 'Đặt giới hạn cho từng danh mục chi trong tháng $_month/$_year.',
                    actionLabel: 'Thêm ngân sách',
                    onAction: () => _showBudgetForm(userId),
                  );
                }
                final totalLimit = items.fold<double>(0, (sum, item) => sum + item.amountLimit);
                final totalSpent = items.fold<double>(0, (sum, item) => sum + item.totalSpent);
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(budgetStatusProvider(request));
                    await ref.read(budgetStatusProvider(request).future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 100),
                    children: [
                      _BudgetOverview(totalLimit: totalLimit, totalSpent: totalSpent, month: _month),
                      const SizedBox(height: 22),
                      const SectionHeader(title: 'Theo danh mục'),
                      const SizedBox(height: 10),
                      ...items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _BudgetCard(
                              item: item,
                              onEdit: () => _showBudgetForm(userId, existing: item),
                              onDelete: () => _deleteBudget(userId, item),
                            ),
                          )),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBudgetForm(userId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ngân sách'),
      ),
    );
  }

  Future<void> _showBudgetForm(String userId, {BudgetStatusModel? existing}) async {
    List<CategoryModel> categories;
    try {
      categories = (await ref.read(categoriesProvider(userId).future)).where((item) => item.type == 'Chi').toList();
    } catch (error) {
      if (mounted) showAppSnackBar(context, error.toString(), isError: true);
      return;
    }
    if (categories.isEmpty) {
      if (mounted) showAppSnackBar(context, 'Chưa có danh mục chi.', isError: true);
      return;
    }

    final amountController = TextEditingController(text: existing?.amountLimit.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    var categoryId = existing?.categoryId;
    if (!categories.any((item) => item.id == categoryId)) categoryId = categories.first.id;
    var month = _month;
    var year = _year;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(existing == null ? 'Đặt ngân sách' : 'Sửa ngân sách', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: categoryId,
                  decoration: const InputDecoration(labelText: 'Danh mục chi'),
                  items: categories.map((item) => DropdownMenuItem(value: item.id, child: Text('${item.icon} ${item.name}'.trim()))).toList(),
                  onChanged: (value) => setModalState(() => categoryId = value),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(labelText: 'Hạn mức', prefixText: '₫  '),
                  validator: (value) {
                    final amount = parseMoneyInput(value ?? '');
                    if (amount == null || amount <= 0) return 'Hạn mức phải lớn hơn 0';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: month,
                        decoration: const InputDecoration(labelText: 'Tháng'),
                        items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                        onChanged: (value) => setModalState(() => month = value ?? month),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: year,
                        decoration: const InputDecoration(labelText: 'Năm'),
                        items: List.generate(7, (i) {
                          final option = DateTime.now().year - 2 + i;
                          return DropdownMenuItem(value: option, child: Text('$option'));
                        }),
                        onChanged: (value) => setModalState(() => year = value ?? year),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) Navigator.pop(context, true);
                  },
                  child: Text(existing == null ? 'Tạo ngân sách' : 'Lưu thay đổi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (submitted != true) {
      return;
    }

    final category = categories.firstWhere((item) => item.id == categoryId);
    final repo = ref.read(financeRepositoryProvider);
    try {
      if (existing == null) {
        await repo.createBudget(
          userId: userId,
          categoryId: category.id,
          categoryName: category.name,
          amountLimit: parseMoneyInput(amountController.text)!,
          month: month,
          year: year,
        );
      } else {
        await repo.updateBudget(
          budgetId: existing.budgetId,
          categoryId: category.id,
          categoryName: category.name,
          amountLimit: parseMoneyInput(amountController.text)!,
          month: month,
          year: year,
        );
      }
      ref.invalidate(budgetStatusProvider(BudgetRequest(userId, month, year)));
      if (month != _month || year != _year) setState(() { _month = month; _year = year; });
      if (mounted) showAppSnackBar(context, existing == null ? 'Đã tạo ngân sách.' : 'Đã cập nhật ngân sách.');
    } catch (error) {
      if (mounted) showAppSnackBar(context, error.toString(), isError: true);
    } finally {
    }
  }

  Future<void> _deleteBudget(String userId, BudgetStatusModel item) async {
    final confirmed = await showDeleteConfirmation(
      context,
      title: 'Xóa ngân sách?',
      message: 'Xóa hạn mức của danh mục ${item.categoryName} trong tháng này.',
    );
    if (!confirmed) return;
    try {
      await ref.read(financeRepositoryProvider).deleteBudget(item.budgetId);
      ref.invalidate(budgetStatusProvider(BudgetRequest(userId, _month, _year)));
      if (mounted) showAppSnackBar(context, 'Đã xóa ngân sách.');
    } catch (error) {
      if (mounted) showAppSnackBar(context, error.toString(), isError: true);
    }
  }
}

class _BudgetOverview extends StatelessWidget {
  const _BudgetOverview({required this.totalLimit, required this.totalSpent, required this.month});
  final double totalLimit;
  final double totalSpent;
  final int month;

  @override
  Widget build(BuildContext context) {
    final progress = totalLimit <= 0 ? 0.0 : (totalSpent / totalLimit).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tổng ngân sách tháng $month', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            FittedBox(child: Text(formatMoney(totalLimit), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
            const SizedBox(height: 18),
            LinearProgressIndicator(value: progress, minHeight: 9, borderRadius: BorderRadius.circular(99)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text('Đã chi ${formatMoney(totalSpent)}', style: Theme.of(context).textTheme.bodySmall)),
                Text('${(progress * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.item, required this.onEdit, required this.onDelete});
  final BudgetStatusModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = (item.percentUsed / 100).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(item.categoryName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                if (item.isExceeded)
                  const Chip(label: Text('Vượt mức'))
                else if (item.isWarning)
                  const Chip(label: Text('Sắp hết')),
                PopupMenuButton<String>(
                  onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Sửa')),
                    PopupMenuItem(value: 'delete', child: Text('Xóa')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${formatMoney(item.totalSpent)} / ${formatMoney(item.amountLimit)}'),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(99)),
            const SizedBox(height: 9),
            Text(
              item.remaining >= 0 ? 'Còn lại ${formatMoney(item.remaining)}' : 'Đã vượt ${formatMoney(item.remaining.abs())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
