class ReportSummary {
  const ReportSummary({
    required this.currentBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.month,
    required this.year,
  });

  final double currentBalance;
  final double totalIncome;
  final double totalExpense;
  final int month;
  final int year;

  factory ReportSummary.fromJson(Map<String, dynamic> json) => ReportSummary(
        currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0,
        totalIncome: (json['totalIncome'] as num?)?.toDouble() ?? 0,
        totalExpense: (json['totalExpense'] as num?)?.toDouble() ?? 0,
        month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
        year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      );
}

class ChartPoint {
  const ChartPoint({required this.date, required this.income, required this.expense});

  final DateTime date;
  final double income;
  final double expense;

  factory ChartPoint.fromJson(Map<String, dynamic> json) => ChartPoint(
        date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
        income: (json['income'] as num?)?.toDouble() ?? 0,
        expense: (json['expense'] as num?)?.toDouble() ?? 0,
      );
}
