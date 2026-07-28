import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../models/recurring_transaction_model.dart';
import '../models/report_models.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/finance_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: FirebaseAuth.instance,
    dio: ref.watch(apiClientProvider).dio,
  );
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(apiClientProvider).dio);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).asData?.value;
});

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController();
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _load();
  }

  static const _key = 'fintrack_theme_mode';

  get sharedPreferences => null;

  Future<void> _load() async {
    final prefs = await sharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    state = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await sharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  Future<void> toggle(bool dark) =>
      setMode(dark ? ThemeMode.dark : ThemeMode.light);
}

final categoriesProvider = FutureProvider.autoDispose
    .family<List<CategoryModel>, String>((ref, userId) {
  return ref.watch(financeRepositoryProvider).getCategories(userId);
});

final walletsProvider =
    FutureProvider.autoDispose.family<List<WalletModel>, String>((ref, userId) {
  return ref.watch(financeRepositoryProvider).getWallets(userId);
});

final transactionsProvider = FutureProvider.autoDispose
    .family<List<TransactionModel>, String>((ref, userId) {
  return ref.watch(financeRepositoryProvider).getTransactions(userId);
});

final summaryProvider =
    FutureProvider.autoDispose.family<ReportSummary, String>((ref, userId) {
  return ref.watch(financeRepositoryProvider).getSummary(userId);
});

class ChartRequest {
  const ChartRequest(this.userId, this.period);
  final String userId;
  final String period;

  @override
  bool operator ==(Object other) =>
      other is ChartRequest && other.userId == userId && other.period == period;

  @override
  int get hashCode => Object.hash(userId, period);
}

final chartProvider = FutureProvider.autoDispose
    .family<List<ChartPoint>, ChartRequest>((ref, request) {
  return ref
      .watch(financeRepositoryProvider)
      .getChart(request.userId, request.period);
});

class BudgetRequest {
  const BudgetRequest(this.userId, this.month, this.year);
  final String userId;
  final int month;
  final int year;

  @override
  bool operator ==(Object other) =>
      other is BudgetRequest &&
      other.userId == userId &&
      other.month == month &&
      other.year == year;

  @override
  int get hashCode => Object.hash(userId, month, year);
}

final budgetStatusProvider = FutureProvider.autoDispose
    .family<List<BudgetStatusModel>, BudgetRequest>((ref, request) {
  return ref.watch(financeRepositoryProvider).getBudgetStatus(
        userId: request.userId,
        month: request.month,
        year: request.year,
      );
});

final recurringProvider = FutureProvider.autoDispose
    .family<List<RecurringTransactionModel>, String>((ref, userId) {
  return ref.watch(financeRepositoryProvider).getRecurringTransactions(userId);
});

void invalidateFinanceData(WidgetRef ref, String userId) {
  ref.invalidate(transactionsProvider(userId));
  ref.invalidate(walletsProvider(userId));
  ref.invalidate(summaryProvider(userId));
  ref.invalidate(chartProvider(ChartRequest(userId, 'week')));
  ref.invalidate(chartProvider(ChartRequest(userId, 'month')));
  final now = DateTime.now();
  ref.invalidate(
      budgetStatusProvider(BudgetRequest(userId, now.month, now.year)));
}
