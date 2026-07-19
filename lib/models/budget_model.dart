class BudgetStatusModel {
  const BudgetStatusModel({
    required this.budgetId,
    required this.categoryId,
    required this.categoryName,
    required this.amountLimit,
    required this.totalSpent,
    required this.remaining,
    required this.percentUsed,
    required this.isExceeded,
    required this.isWarning,
  });

  final String budgetId;
  final String categoryId;
  final String categoryName;
  final double amountLimit;
  final double totalSpent;
  final double remaining;
  final double percentUsed;
  final bool isExceeded;
  final bool isWarning;

  factory BudgetStatusModel.fromJson(Map<String, dynamic> json) => BudgetStatusModel(
        budgetId: json['budgetId']?.toString() ?? json['id']?.toString() ?? '',
        categoryId: json['categoryId']?.toString() ?? '',
        categoryName: json['categoryName']?.toString() ?? '',
        amountLimit: (json['amountLimit'] as num?)?.toDouble() ?? 0,
        totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0,
        remaining: (json['remaining'] as num?)?.toDouble() ?? 0,
        percentUsed: (json['percentUsed'] as num?)?.toDouble() ?? 0,
        isExceeded: json['isExceeded'] == true,
        isWarning: json['isWarning'] == true,
      );
}
