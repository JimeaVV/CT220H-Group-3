import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../providers/app_providers.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, this.transaction});

  final TransactionModel? transaction;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late String _type;
  late DateTime _date;
  String? _walletId;
  String? _categoryId;
  bool _saving = false;

  bool get _editing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final item = widget.transaction;
    _amountController =
        TextEditingController(text: item == null ? '' : item.amount.toString());
    _noteController = TextEditingController(text: item?.note ?? '');
    _type = item?.type ?? 'Chi';
    _date = item?.date.toLocal() ?? DateTime.now();
    _walletId = item?.walletId;
    _categoryId = item?.categoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final userId = user.uid;
    final walletsAsync = ref.watch(walletsProvider(userId));
    final categoriesAsync = ref.watch(categoriesProvider(userId));

    return Scaffold(
      appBar:
          AppBar(title: Text(_editing ? 'Sửa giao dịch' : 'Thêm giao dịch')),
      body: walletsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(18),
          child: ErrorCard(
              error: error,
              onRetry: () => ref.invalidate(walletsProvider(userId))),
        ),
        data: (wallets) => categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(18),
            child: ErrorCard(
                error: error,
                onRetry: () => ref.invalidate(categoriesProvider(userId))),
          ),
          data: (categories) => _buildForm(userId, wallets, categories),
        ),
      ),
    );
  }

  Widget _buildForm(String userId, List<WalletModel> wallets,
      List<CategoryModel> categories) {
    final filteredCategories =
        categories.where((item) => item.type == _type).toList();
    if (_walletId == null && wallets.isNotEmpty) _walletId = wallets.first.id;
    if (_categoryId == null ||
        !filteredCategories.any((item) => item.id == _categoryId)) {
      _categoryId =
          filteredCategories.isEmpty ? null : filteredCategories.first.id;
    }

    if (wallets.isEmpty) {
      return EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Cần tạo ví trước',
        message: 'Mỗi giao dịch phải được gắn với một ví.',
        actionLabel: 'Tạo ví',
        onAction: () => context.push('/wallets'),
      );
    }
    if (filteredCategories.isEmpty) {
      return EmptyState(
        icon: Icons.category_outlined,
        title: 'Chưa có danh mục $_type',
        message: 'Khởi tạo danh mục mặc định hoặc tạo danh mục riêng.',
        actionLabel: 'Quản lý danh mục',
        onAction: () => context.push('/categories'),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'Chi',
                  label: Text('Khoản chi'),
                  icon: Icon(Icons.north_east_rounded)),
              ButtonSegment(
                  value: 'Thu',
                  label: Text('Khoản thu'),
                  icon: Icon(Icons.south_west_rounded)),
            ],
            selected: {_type},
            onSelectionChanged: (values) {
              setState(() {
                _type = values.first;
                _categoryId = null;
              });
            },
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _amountController,
            autofocus: !_editing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            ],
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            decoration:
                const InputDecoration(labelText: 'Số tiền', prefixText: '₫  '),
            validator: (value) {
              final amount = parseMoneyInput(value ?? '');
              if (amount == null || amount <= 0)
                return 'Số tiền phải lớn hơn 0';
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _walletId,
            decoration: const InputDecoration(
                labelText: 'Ví',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined)),
            items: wallets
                .map((wallet) => DropdownMenuItem(
                    value: wallet.id, child: Text(wallet.name)))
                .toList(),
            onChanged: (value) => setState(() => _walletId = value),
            validator: (value) => value == null ? 'Hãy chọn ví' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _categoryId,
            decoration: const InputDecoration(
                labelText: 'Danh mục',
                prefixIcon: Icon(Icons.category_outlined)),
            items: filteredCategories
                .map((category) => DropdownMenuItem(
                    value: category.id,
                    child: Text('${category.icon} ${category.name}'.trim())))
                .toList(),
            onChanged: (value) => setState(() => _categoryId = value),
            validator: (value) => value == null ? 'Hãy chọn danh mục' : null,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDateTime,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'Ngày giờ',
                  prefixIcon: Icon(Icons.calendar_month_outlined)),
              child: Text(formatDateTime(_date)),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _noteController,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
                labelText: 'Ghi chú',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded)),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving
                ? null
                : () => _save(userId, wallets, filteredCategories),
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: Text(_editing ? 'Lưu thay đổi' : 'Thêm giao dịch'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _date,
    );
    if (selectedDate == null || !mounted) return;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (selectedTime == null) return;
    setState(() {
      _date = DateTime(selectedDate.year, selectedDate.month, selectedDate.day,
          selectedTime.hour, selectedTime.minute);
    });
  }

  Future<void> _save(String userId, List<WalletModel> wallets,
      List<CategoryModel> categories) async {
    if (!_formKey.currentState!.validate()) return;
    final wallet = wallets.firstWhere((item) => item.id == _walletId);
    final category = categories.firstWhere((item) => item.id == _categoryId);
    final amount = parseMoneyInput(_amountController.text)!;
    final transaction = TransactionModel(
      id: widget.transaction?.id ?? '',
      userId: userId,
      walletId: wallet.id,
      walletName: wallet.name,
      categoryId: category.id,
      categoryName: category.name,
      categoryIcon: category.icon,
      amount: amount,
      type: _type,
      date: _date,
      note: _noteController.text.trim(),
    );

    setState(() => _saving = true);
    try {
      final repo = ref.read(financeRepositoryProvider);
      if (_editing) {
        await repo.updateTransaction(transaction);
      } else {
        await repo.createTransaction(transaction);
      }
      invalidateFinanceData(ref, userId);
      if (!mounted) return;
      showAppSnackBar(
          context, _editing ? 'Đã cập nhật giao dịch.' : 'Đã thêm giao dịch.');
      context.pop();
    } catch (error) {
      if (mounted) showAppSnackBar(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
