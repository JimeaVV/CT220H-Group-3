import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/money_utils.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/fintrack_logo.dart';
import '../../core/widgets/transaction_tile.dart';
import '../../models/report_models.dart';
import '../../providers/app_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final userId = user.uid;
    final summary = ref.watch(summaryProvider(userId));
    final wallets = ref.watch(walletsProvider(userId));
    final transactions = ref.watch(transactionsProvider(userId));

    Future<void> refresh() async {
      invalidateFinanceData(ref, userId);
      await Future.wait([
        ref.read(summaryProvider(userId).future),
        ref.read(walletsProvider(userId).future),
        ref.read(transactionsProvider(userId).future),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: const FinTrackLogo(size: 38, showName: true),
        actions: [
          IconButton(onPressed: refresh, icon: const Icon(Icons.refresh_rounded), tooltip: 'Làm mới'),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
          children: [
            Text(
              'Xin chào, ${user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim().split(' ').last : 'bạn'}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.6),
            ),
            const SizedBox(height: 4),
            Text('Đây là tình hình tài chính của bạn hôm nay.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 22),
            summary.when(
              data: (data) => _BalanceCard(summary: data),
              loading: () => const _LoadingCard(height: 190),
              error: (error, _) => ErrorCard(error: error, onRetry: () => ref.invalidate(summaryProvider(userId))),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Ví của bạn'),
            const SizedBox(height: 10),
            wallets.when(
              data: (items) {
                if (items.isEmpty) {
                  return _InlineActionCard(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Chưa có ví',
                    message: 'Tạo ví tiền mặt, ngân hàng hoặc MoMo để bắt đầu.',
                    onTap: () => context.push('/wallets'),
                  );
                }
                return SizedBox(
                  height: 116,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final wallet = items[index];
                      return InkWell(
                        onTap: () => context.push('/wallets'),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 190,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [const Icon(Icons.wallet_outlined, size: 18), const SizedBox(width: 8), Expanded(child: Text(wallet.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)))]),
                              const Spacer(),
                              Text(formatMoney(wallet.balance), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                              Text(wallet.type, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const _LoadingCard(height: 116),
              error: (error, _) => ErrorCard(error: error, onRetry: () => ref.invalidate(walletsProvider(userId))),
            ),
            const SizedBox(height: 26),
            const SectionHeader(title: 'Quản lý nhanh'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.75,
              children: [
                _QuickAction(icon: Icons.account_balance_wallet_outlined, label: 'Ví tiền', onTap: () => context.push('/wallets')),
                _QuickAction(icon: Icons.category_outlined, label: 'Danh mục', onTap: () => context.push('/categories')),
                _QuickAction(icon: Icons.savings_outlined, label: 'Ngân sách', onTap: () => context.push('/budgets')),
                _QuickAction(icon: Icons.autorenew_rounded, label: 'Giao dịch lặp', onTap: () => context.push('/recurring')),
              ],
            ),
            const SizedBox(height: 26),
            SectionHeader(title: 'Giao dịch gần đây', actionLabel: 'Thêm mới', onAction: () => context.push('/transaction/new')),
            const SizedBox(height: 4),
            transactions.when(
              data: (items) {
                if (items.isEmpty) {
                  return _InlineActionCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'Chưa có giao dịch',
                    message: 'Thêm khoản thu hoặc chi đầu tiên của bạn.',
                    onTap: () => context.push('/transaction/new'),
                  );
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Column(
                      children: [
                        for (final item in items.take(5)) ...[
                          TransactionTile(transaction: item),
                          if (item != items.take(5).last) const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                );
              },
              loading: () => const _LoadingCard(height: 220),
              error: (error, _) => ErrorCard(error: error, onRetry: () => ref.invalidate(transactionsProvider(userId))),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary});
  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tổng số dư', style: TextStyle(color: isDark ? Colors.black54 : Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(summary.currentBalance),
              style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.3),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _SummaryItem(label: 'Thu tháng ${summary.month}', value: summary.totalIncome, icon: Icons.south_west_rounded, darkCard: isDark)),
              Container(width: 1, height: 44, color: isDark ? Colors.black12 : Colors.white24),
              const SizedBox(width: 16),
              Expanded(child: _SummaryItem(label: 'Chi tháng ${summary.month}', value: summary.totalExpense, icon: Icons.north_east_rounded, darkCard: isDark)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value, required this.icon, required this.darkCard});
  final String label;
  final double value;
  final IconData icon;
  final bool darkCard;

  @override
  Widget build(BuildContext context) {
    final color = darkCard ? Colors.black : Colors.white;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color.withOpacity(0.6), fontSize: 11)),
              const SizedBox(height: 3),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(formatMoney(value), style: TextStyle(color: color, fontWeight: FontWeight.w800))),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [Icon(icon), const SizedBox(width: 12), Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)))]),
        ),
      ),
    );
  }
}

class _InlineActionCard extends StatelessWidget {
  const _InlineActionCard({required this.icon, required this.title, required this.message, required this.onTap});
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(message, style: Theme.of(context).textTheme.bodySmall)])),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: const CircularProgressIndicator(),
    );
  }
}
