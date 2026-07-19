class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.userId,
    required this.walletId,
    required this.walletName,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.amount,
    required this.type,
    required this.date,
    required this.note,
    this.isFromRecurring = false,
    this.recurringId,
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
  final DateTime date;
  final String note;
  final bool isFromRecurring;
  final String? recurringId;

  factory TransactionModel.fromJson(Map<String, dynamic> json) => TransactionModel(
        id: json['id']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        walletId: json['walletId']?.toString() ?? '',
        walletName: json['walletName']?.toString() ?? '',
        categoryId: json['categoryId']?.toString() ?? '',
        categoryName: json['categoryName']?.toString() ?? '',
        categoryIcon: json['categoryIcon']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        type: json['type']?.toString() ?? 'Chi',
        date: _parseDate(json['date']),
        note: json['note']?.toString() ?? '',
        isFromRecurring: json['isFromRecurring'] == true,
        recurringId: json['recurringId']?.toString(),
      );

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  Map<String, dynamic> toPayload() => {
        'userId': userId,
        'walletId': walletId,
        'walletName': walletName,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'categoryIcon': categoryIcon,
        'amount': amount,
        'type': type,
        'date': date.toUtc().toIso8601String(),
        'note': note,
      };
}
