import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/money_utils.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/wallet_model.dart';
import '../../providers/app_providers.dart';

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final userId = user.uid;
    final wallets = ref.watch(walletsProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ví tiền'),
        actions: [
          IconButton(onPressed: () => _showTransfer(context, ref, userId), icon: const Icon(Icons.swap_horiz_rounded), tooltip: 'Chuyển tiền'),
          IconButton(onPressed: () => _showWalletForm(context, ref, userId), icon: const Icon(Icons.add_rounded)),
          const SizedBox(width: 6),
        ],
      ),
      body: wallets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(18),
          child: ErrorCard(error: error, onRetry: () => ref.invalidate(walletsProvider(userId))),
        ),
        data: (items) {
          final total = items.fold<double>(0, (sum, item) => sum + item.balance);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(walletsProvider(userId));
              await ref.read(walletsProvider(userId).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tổng tài sản', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.black54 : Colors.white70)),
                      const SizedBox(height: 8),
                      FittedBox(
                        child: Text(
                          formatMoney(total),
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${items.length} ví đang hoạt động', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.black54 : Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SectionHeader(title: 'Danh sách ví', actionLabel: 'Chuyển tiền', onAction: () => _showTransfer(context, ref, userId)),
                const SizedBox(height: 10),
                if (items.isEmpty)
                  EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Chưa có ví',
                    message: 'Tạo ít nhất một ví để ghi nhận giao dịch.',
                    actionLabel: 'Tạo ví',
                    onAction: () => _showWalletForm(context, ref, userId),
                  )
                else
                  ...items.map(
                    (wallet) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(_walletIcon(wallet.type)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(wallet.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                    const SizedBox(height: 3),
                                    Text(wallet.type, style: Theme.of(context).textTheme.bodySmall),
                                    const SizedBox(height: 8),
                                    Text(formatMoney(wallet.balance), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (action) async {
                                  if (action == 'edit') {
                                    await _showWalletForm(context, ref, userId, wallet: wallet);
                                  } else {
                                    await _deleteWallet(context, ref, userId, wallet);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Sửa ví')),
                                  PopupMenuItem(value: 'delete', child: Text('Xóa ví')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showWalletForm(context, ref, userId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tạo ví'),
      ),
    );
  }

  static IconData _walletIcon(String type) {
    final value = type.toLowerCase();
    if (value.contains('bank')) return Icons.account_balance_outlined;
    if (value.contains('wallet') || value.contains('momo')) return Icons.phone_android_rounded;
    return Icons.payments_outlined;
  }

  static Future<void> _showWalletForm(
    BuildContext context,
    WidgetRef ref,
    String userId, {
    WalletModel? wallet,
  }) async {
    final nameController = TextEditingController(text: wallet?.name ?? '');
    final balanceController = TextEditingController(text: wallet == null ? '' : wallet.balance.toString());
    final formKey = GlobalKey<FormState>();
    var type = wallet?.type ?? 'Cash';

    final result = await showModalBottomSheet<bool>(
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
                Text(wallet == null ? 'Tạo ví mới' : 'Chỉnh sửa ví', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Tên ví'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Hãy nhập tên ví' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Loại ví'),
                  items: const [
                    DropdownMenuItem(value: 'Cash', child: Text('Tiền mặt')),
                    DropdownMenuItem(value: 'Bank', child: Text('Ngân hàng')),
                    DropdownMenuItem(value: 'E-Wallet', child: Text('Ví điện tử')),
                  ],
                  onChanged: (value) => setModalState(() => type = value ?? 'Cash'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: balanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(labelText: 'Số dư', prefixText: '₫  '),
                  validator: (value) {
                    final amount = parseMoneyInput(value ?? '');
                    if (amount == null || amount < 0) return 'Số dư không hợp lệ';
                    return null;
                  },
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) Navigator.pop(context, true);
                  },
                  child: Text(wallet == null ? 'Tạo ví' : 'Lưu thay đổi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != true) {
      return;
    }

    try {
      final repo = ref.read(financeRepositoryProvider);
      final balance = parseMoneyInput(balanceController.text)!;
      if (wallet == null) {
        await repo.createWallet(userId: userId, name: nameController.text.trim(), type: type, balance: balance);
      } else {
        await repo.updateWallet(walletId: wallet.id, name: nameController.text.trim(), type: type, balance: balance);
      }
      invalidateFinanceData(ref, userId);
      if (context.mounted) showAppSnackBar(context, wallet == null ? 'Đã tạo ví.' : 'Đã cập nhật ví.');
    } catch (error) {
      if (context.mounted) showAppSnackBar(context, error.toString(), isError: true);
    } finally {
    }
  }

  static Future<void> _deleteWallet(BuildContext context, WidgetRef ref, String userId, WalletModel wallet) async {
    final confirmed = await showDeleteConfirmation(
      context,
      title: 'Xóa ${wallet.name}?',
      message: 'Hãy chắc rằng ví không còn được dùng bởi giao dịch hoặc lịch lặp.',
    );
    if (!confirmed) return;
    try {
      await ref.read(financeRepositoryProvider).deleteWallet(wallet.id);
      invalidateFinanceData(ref, userId);
      if (context.mounted) showAppSnackBar(context, 'Đã xóa ví.');
    } catch (error) {
      if (context.mounted) showAppSnackBar(context, error.toString(), isError: true);
    }
  }

  static Future<void> _showTransfer(BuildContext context, WidgetRef ref, String userId) async {
    List<WalletModel> wallets;
    try {
      wallets = await ref.read(walletsProvider(userId).future);
    } catch (error) {
      if (context.mounted) showAppSnackBar(context, error.toString(), isError: true);
      return;
    }
    if (wallets.length < 2) {
      if (context.mounted) showAppSnackBar(context, 'Cần ít nhất hai ví để chuyển tiền.', isError: true);
      return;
    }

    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var fromId = wallets.first.id;
    var toId = wallets[1].id;

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
                Text('Chuyển tiền giữa các ví', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: fromId,
                  decoration: const InputDecoration(labelText: 'Từ ví'),
                  items: wallets.map((e) => DropdownMenuItem(value: e.id, child: Text('${e.name} • ${formatMoney(e.balance)}'))).toList(),
                  onChanged: (value) => setModalState(() => fromId = value ?? fromId),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: toId,
                  decoration: const InputDecoration(labelText: 'Đến ví'),
                  items: wallets.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                  onChanged: (value) => setModalState(() => toId = value ?? toId),
                  validator: (_) => fromId == toId ? 'Ví nguồn và ví đích phải khác nhau' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(labelText: 'Số tiền chuyển', prefixText: '₫  '),
                  validator: (value) {
                    final amount = parseMoneyInput(value ?? '');
                    if (amount == null || amount <= 0) return 'Số tiền phải lớn hơn 0';
                    return null;
                  },
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) Navigator.pop(context, true);
                  },
                  child: const Text('Chuyển tiền'),
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

    try {
      await ref.read(financeRepositoryProvider).transferMoney(
            userId: userId,
            fromWalletId: fromId,
            toWalletId: toId,
            amount: parseMoneyInput(amountController.text)!,
          );
      invalidateFinanceData(ref, userId);
      if (context.mounted) showAppSnackBar(context, 'Chuyển tiền thành công.');
    } catch (error) {
      if (context.mounted) showAppSnackBar(context, error.toString(), isError: true);
    } finally {
    }
  }
}
