import 'package:dio/dio.dart';
import '../core/network/api_exception.dart';
import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../models/recurring_transaction_model.dart';
import '../models/report_models.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';

class FinanceRepository {
  FinanceRepository(this._dio);

  final Dio _dio;

  List<Map<String, dynamic>> _listData(Response<dynamic> response) {
    final body = response.data;
    if (body is Map && body['data'] is List) {
      return (body['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return [];
  }

  Map<String, dynamic> _mapData(Response<dynamic> response) {
    final body = response.data;
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    return {};
  }

  Future<List<CategoryModel>> getCategories(String userId) async {
    try {
      final response = await _dio.get('/categories/$userId');
      return _listData(response).map(CategoryModel.fromJson).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<CategoryModel> createCategory({
    required String userId,
    required String name,
    required String type,
    required String icon,
  }) async {
    try {
      final response = await _dio.post(
        '/categories/',
        data: {'userId': userId, 'name': name, 'type': type, 'icon': icon},
      );
      return CategoryModel.fromJson(_mapData(response));
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<void> initializeDefaultCategories() async {
    try {
      await _dio.post('/categories/init-defaults/');
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<List<WalletModel>> getWallets(String userId) async {
    try {
      final response = await _dio.get('/wallets/user/$userId');
      return _listData(response).map(WalletModel.fromJson).toList();
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<WalletModel> createWallet({
    required String userId,
    required String name,
    required String type,
    required double balance,
  }) async {
    try {
      final response = await _dio.post(
        '/wallets/',
        data: {
          'userId': userId,
          'name': name,
          'type': type,
          'balance': balance
        },
      );
      return WalletModel.fromJson(_mapData(response));
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<WalletModel> updateWallet({
    required String walletId,
    required String name,
    required String type,
    required double balance,
  }) async {
    try {
      final response = await _dio.put(
        '/wallets/$walletId',
        data: {'name': name, 'type': type, 'balance': balance},
      );
      return WalletModel.fromJson(_mapData(response));
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<void> deleteWallet(String walletId) async {
    try {
      await _dio.delete('/wallets/$walletId');
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<void> transferMoney({
    required String userId,
    required String fromWalletId,
    required String toWalletId,
    required double amount,
  }) async {
    try {
      await _dio.post(
        '/wallets/transfer/',
        data: {
          'userId': userId,
          'fromWalletId': fromWalletId,
          'toWalletId': toWalletId,
          'amount': amount,
        },
      );
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<List<TransactionModel>> getTransactions(String userId) async {
    try {
      final response = await _dio.get('/transactions/user/$userId');
      final items = _listData(response).map(TransactionModel.fromJson).toList();
      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<TransactionModel> createTransaction(
      TransactionModel transaction) async {
    try {
      final response =
          await _dio.post('/transactions/', data: transaction.toPayload());
      return TransactionModel.fromJson(_mapData(response));
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<TransactionModel> updateTransaction(
      TransactionModel transaction) async {
    try {
      final payload = transaction.toPayload()..remove('userId');
      final response =
          await _dio.put('/transactions/${transaction.id}', data: payload);
      return TransactionModel.fromJson(_mapData(response));
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _dio.delete('/transactions/$transactionId');
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<ReportSummary> getSummary(String userId) async {
    try {
      final response = await _dio.get('/reports/summary/$userId');
      return ReportSummary.fromJson(_mapData(response));
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<List<ChartPoint>> getChart(String userId, String period) async {
    try {
      final response = await _dio.get(
        '/reports/chart/$userId',
        queryParameters: {'period': period},
      );
      return _listData(response).map(ChartPoint.fromJson).toList();
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<List<BudgetStatusModel>> getBudgetStatus({
    required String userId,
    required int month,
    required int year,
  }) async {
    try {
      final response = await _dio.get(
        '/budgets/user/$userId/status',
        queryParameters: {'month': month, 'year': year},
      );
      return _listData(response).map(BudgetStatusModel.fromJson).toList();
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<void> createBudget({
    required String userId,
    required String categoryId,
    required String categoryName,
    required double amountLimit,
    required int month,
    required int year,
  }) async {
    try {
      await _dio.post(
        '/budgets/',
        data: {
          'userId': userId,
          'categoryId': categoryId,
          'categoryName': categoryName,
          'amountLimit': amountLimit,
          'month': month,
          'year': year,
        },
      );
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<void> updateBudget({
    required String budgetId,
    required String categoryId,
    required String categoryName,
    required double amountLimit,
    required int month,
    required int year,
  }) async {
    try {
      await _dio.put(
        '/budgets/$budgetId',
        data: {
          'categoryId': categoryId,
          'categoryName': categoryName,
          'amountLimit': amountLimit,
          'month': month,
          'year': year,
        },
      );
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    try {
      await _dio.delete('/budgets/$budgetId');
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<List<RecurringTransactionModel>> getRecurringTransactions(
      String userId) async {
    try {
      final response = await _dio.get('/recurring_transactions/user/$userId');
      final items =
          _listData(response).map(RecurringTransactionModel.fromJson).toList();
      items.sort((a, b) => a.nextTriggerDate.compareTo(b.nextTriggerDate));
      return items;
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<void> createRecurring(Map<String, dynamic> payload) async {
    try {
      await _dio.post('/recurring_transactions/', data: payload);
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<void> updateRecurring(String id, Map<String, dynamic> payload) async {
    try {
      await _dio.put('/recurring_transactions/$id', data: payload);
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<void> deleteRecurring(String id) async {
    try {
      await _dio.delete('/recurring_transactions/$id');
    } catch (error) {
      throw mapApiException(error);
    }
  }

  Future<int> runRecurringNow() async {
    try {
      final response = await _dio.post('/recurring_transactions/run-now/');
      final body = response.data;
      if (body is Map) return (body['processedCount'] as num?)?.toInt() ?? 0;
      return 0;
    } catch (error) {
      throw mapApiException(error);
    }
  }
}
