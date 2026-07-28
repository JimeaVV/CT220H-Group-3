import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/category_model.dart';
import '../../models/recurring_transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../providers/app_providers.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final userId = user.uid;
    final itemsAsync = ref.watch(recurringProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao dịch định kỳ'),
        actions: [
          IconButton(
            tooltip: 'Xử lý lịch đến hạn ngay',
            onPressed: () => _runNow(context, ref, userId),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(recurringProvider(userId).future),
        child: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(18),
            children: [
              ErrorCard(
                error: error,
                onRetry: () => ref.invalidate(recurringProvider(userId)),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.65,
                    child: EmptyState(
                      icon: Icons.event_repeat_rounded,
                      title: 'Chưa có giao dịch lặp',
                      message:
                          'Tạo lịch cho tiền nhà, tiền mạng, lương hoặc các khoản cố định.',
                      actionLabel: 'Tạo lịch đầu tiên',
                      onAction: () => _showRecurringForm(context, ref, userId),
                    ),
                  ),
                ],
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Nút chạy ở góc trên sẽ yêu cầu backend ghi nhận mọi lịch đã đến hạn.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                for (final item in items) ...[
                  _RecurringCard(
                    item: item,
                    onToggle: (active) =>
                        _toggleActive(context, ref, userId, item, active),
                    onEdit: () => _showRecurringForm(context, ref, userId,
                        existing: item),
                    onDelete: () => _delete(context, ref, userId, item),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRecurringForm(context, ref, userId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tạo lịch'),
      ),
    );
  }

  static Future<void> _runNow(
      BuildContext context, WidgetRef ref, String userId) async {
    try {
      final processed =
          await ref.read(financeRepositoryProvider).runRecurringNow();
      ref.invalidate(recurringProvider(userId));
      invalidateFinanceData(ref, userId);
      if (context.mounted) {
        showAppSnackBar(
          context,
          processed == 0
              ? 'Không có giao dịch nào đến hạn.'
              : 'Đã ghi nhận $processed giao dịch đến hạn.',
        );
      }
    } catch (error) {
      if (context.mounted)
        showAppSnackBar(context, error.toString(), isError: true);
    }
  }

  static Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    String userId,
    RecurringTransactionModel item,
    bool active,
  ) async {
    try {
      await ref.read(financeRepositoryProvider).updateRecurring(
        item.id,
        {'isActive': active},
      );
      ref.invalidate(recurringProvider(userId));
      if (context.mounted) {
        showAppSnackBar(
            context, active ? 'Đã bật lịch lặp.' : 'Đã tạm dừng lịch lặp.');
      }
    } catch (error) {
      if (context.mounted)
        showAppSnackBar(context, error.toString(), isError: true);
    }
  }

  static Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String userId,
    RecurringTransactionModel item,
  ) async {
    final confirmed = await showDeleteConfirmation(
      context,
      title: 'Xóa lịch giao dịch?',
      message:
          'Lịch “${item.note.isEmpty ? item.categoryName : item.note}” sẽ bị xóa vĩnh viễn.',
    );
    if (!confirmed) return;

    try {
      await ref.read(financeRepositoryProvider).deleteRecurring(item.id);
      ref.invalidate(recurringProvider(userId));
      if (context.mounted) showAppSnackBar(context, 'Đã xóa lịch giao dịch.');
    } catch (error) {
      if (context.mounted)
        showAppSnackBar(context, error.toString(), isError: true);
    }
  }

  static Future<void> _showRecurringForm(
    BuildContext context,
    WidgetRef ref,
    String userId, {
    RecurringTransactionModel? existing,
  }) async {
    List<WalletModel> wallets;
    List<CategoryModel> categories;
    try {
      final result = await Future.wait([
        ref.read(walletsProvider(userId).future),
        ref.read(categoriesProvider(userId).future),
      ]);
      wallets = result[0] as List<WalletModel>;
      categories = result[1] as List<CategoryModel>;
    } catch (error) {
      if (context.mounted)
        showAppSnackBar(context, error.toString(), isError: true);
      return;
    }

    if (wallets.isEmpty) {
      if (context.mounted)
        showAppSnackBar(context, 'Hãy tạo ít nhất một ví trước.',
            isError: true);
      return;
    }
    if (categories.isEmpty) {
      if (context.mounted)
        showAppSnackBar(context, 'Hãy tạo danh mục trước.', isError: true);
      return;
    }

    final amountController = TextEditingController(
      text: existing == null ? '' : existing.amount.toString(),
    );
    final noteController = TextEditingController(text: existing?.note ?? '');
    final formKey = GlobalKey<FormState>();
    var type = existing?.type ?? 'Chi';
    var walletId = existing?.walletId;
    var categoryId = existing?.categoryId;
    var cycle = existing?.cycle ?? 'monthly';
    var nextDate = existing?.nextTriggerDate.toLocal() ??
        DateTime.now().add(const Duration(days: 1));
    var isActive = existing?.isActive ?? true;

    if (!wallets.any((item) => item.id == walletId))
      walletId = wallets.first.id;
    var filteredCategories =
        categories.where((item) => item.type == type).toList();
    if (!filteredCategories.any((item) => item.id == categoryId)) {
      categoryId =
          filteredCategories.isEmpty ? null : filteredCategories.first.id;
    }

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          filteredCategories =
              categories.where((item) => item.type == type).toList();
          if (!filteredCategories.any((item) => item.id == categoryId)) {
            categoryId =
                filteredCategories.isEmpty ? null : filteredCategories.first.id;
          }

          Future<void> pickDate() async {
            final selected = await showDatePicker(
              context: context,
              initialDate: nextDate,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
            );
            if (selected == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(nextDate),
            );
            if (time == null) return;
            setModalState(() {
              nextDate = DateTime(
                selected.year,
                selected.month,
                selected.day,
                time.hour,
                time.minute,
              );
            });
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          existing == null
                              ? 'Tạo giao dịch định kỳ'
                              : 'Sửa giao dịch định kỳ',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Chi', label: Text('Khoản chi')),
                      ButtonSegment(value: 'Thu', label: Text('Khoản thu')),
                    ],
                    selected: {type},
                    onSelectionChanged: (values) {
                      setModalState(() {
                        type = values.first;
                        categoryId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    autofocus: existing == null,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Số tiền',
                      prefixText: '₫  ',
                    ),
                    validator: (value) {
                      final amount = parseMoneyInput(value ?? '');
                      if (amount == null || amount <= 0)
                        return 'Số tiền phải lớn hơn 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: walletId,
                    decoration: const InputDecoration(
                      labelText: 'Ví',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                    items: wallets
                        .map((item) => DropdownMenuItem(
                            value: item.id, child: Text(item.name)))
                        .toList(),
                    onChanged: (value) => setModalState(() => walletId = value),
                    validator: (value) => value == null ? 'Hãy chọn ví' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Danh mục',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: filteredCategories
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text('${item.icon} ${item.name}'.trim()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setModalState(() => categoryId = value),
                    validator: (value) =>
                        value == null ? 'Hãy chọn danh mục phù hợp' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: cycle,
                    decoration: const InputDecoration(
                      labelText: 'Chu kỳ',
                      prefixIcon: Icon(Icons.loop_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'daily', child: Text('Hằng ngày')),
                      DropdownMenuItem(
                          value: 'weekly', child: Text('Hằng tuần')),
                      DropdownMenuItem(
                          value: 'monthly', child: Text('Hằng tháng')),
                      DropdownMenuItem(
                          value: 'yearly', child: Text('Hằng năm')),
                    ],
                    onChanged: (value) =>
                        setModalState(() => cycle = value ?? cycle),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: pickDate,
                    borderRadius: BorderRadius.circular(16),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Lần ghi nhận tiếp theo',
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                      child: Text(formatDateTime(nextDate)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: noteController,
                    maxLines: 2,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú',
                      prefixIcon: Icon(Icons.notes_rounded),
                      alignLabelWithHint: true,
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Kích hoạt lịch'),
                    subtitle: const Text('Tắt để tạm dừng mà không cần xóa.'),
                    value: isActive,
                    onChanged: (value) => setModalState(() => isActive = value),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () {
                      if (formKey.currentState!.validate())
                        Navigator.pop(context, true);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: Text(existing == null ? 'Tạo lịch' : 'Lưu thay đổi'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (submitted != true) {
      return;
    }

    final wallet = wallets.firstWhere((item) => item.id == walletId);
    final category = categories.firstWhere((item) => item.id == categoryId);
    final payload = <String, dynamic>{
      'walletId': wallet.id,
      'walletName': wallet.name,
      'categoryId': category.id,
      'categoryName': category.name,
      'categoryIcon': category.icon,
      'amount': parseMoneyInput(amountController.text)!,
      'type': type,
      'note': noteController.text.trim(),
      'cycle': cycle,
      'nextTriggerDate': nextDate.toUtc().toIso8601String(),
      'isActive': isActive,
    };

    try {
      final repo = ref.read(financeRepositoryProvider);
      if (existing == null) {
        await repo.createRecurring({'userId': userId, ...payload});
      } else {
        await repo.updateRecurring(existing.id, payload);
      }
      ref.invalidate(recurringProvider(userId));
      if (context.mounted) {
        showAppSnackBar(
          context,
          existing == null
              ? 'Đã tạo giao dịch định kỳ.'
              : 'Đã cập nhật giao dịch định kỳ.',
        );
      }
    } catch (error) {
      if (context.mounted)
        showAppSnackBar(context, error.toString(), isError: true);
    } finally {}
  }
}

class _RecurringCard extends StatelessWidget {
  const _RecurringCard({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final RecurringTransactionModel item;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final income = item.type == 'Thu';
    return Opacity(
      opacity: item.isActive ? 1 : 0.58,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.06),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      item.categoryIcon.isEmpty
                          ? (income ? '↙' : '↗')
                          : item.categoryIcon,
                      style: const TextStyle(fontSize: 21),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.note.isEmpty ? item.categoryName : item.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${item.walletName} • ${_cycleLabel(item.cycle)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) =>
                        value == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                      PopupMenuItem(value: 'delete', child: Text('Xóa')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${income ? '+' : '-'}${formatMoney(item.amount)}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Tiếp theo: ${formatDateTime(item.nextTriggerDate)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(value: item.isActive, onChanged: onToggle),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _cycleLabel(String cycle) => switch (cycle) {
        'daily' => 'Hằng ngày',
        'weekly' => 'Hằng tuần',
        'yearly' => 'Hằng năm',
        _ => 'Hằng tháng',
      };
}
