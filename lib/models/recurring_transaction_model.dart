class RecurringTransactionModel {
  const RecurringTransactionModel({
    required this.id,
    required this.userId,
    required this.walletId,
    required this.walletName,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.amount,
    required this.type,
    required this.note,
    required this.cycle,
    required this.nextTriggerDate,
    required this.isActive,
  });

  final String id;
  final String userId;
  final String walletId;
  final String walletName;
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final double amount;
  final String type;
  final String note;
  final String cycle;
  final DateTime nextTriggerDate;
  final bool isActive;

  factory RecurringTransactionModel.fromJson(Map<String, dynamic> json) => RecurringTransactionModel(
        id: json['id']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        walletId: json['walletId']?.toString() ?? '',
        walletName: json['walletName']?.toString() ?? '',
        categoryId: json['categoryId']?.toString() ?? '',
        categoryName: json['categoryName']?.toString() ?? '',
        categoryIcon: json['categoryIcon']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        type: json['type']?.toString() ?? 'Chi',
        note: json['note']?.toString() ?? '',
        cycle: json['cycle']?.toString() ?? 'monthly',
        nextTriggerDate: _parseDate(json['nextTriggerDate']),
        isActive: json['isActive'] != false,
      );

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
