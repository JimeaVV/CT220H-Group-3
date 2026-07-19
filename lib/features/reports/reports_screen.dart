import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_utils.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/report_models.dart';
import '../../providers/app_providers.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _period = 'month';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final userId = user.uid;
    final summary = ref.watch(summaryProvider(userId));
    final chart = ref.watch(chartProvider(ChartRequest(userId, _period)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo'),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(summaryProvider(userId));
              ref.invalidate(chartProvider(ChartRequest(userId, _period)));
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'week', label: Text('7 ngày')),
              ButtonSegment(value: 'month', label: Text('30 ngày')),
            ],
            selected: {_period},
            onSelectionChanged: (value) => setState(() => _period = value.first),
          ),
          const SizedBox(height: 20),
          summary.when(
            data: (data) => _SummaryCards(summary: data),
            loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
            error: (error, _) => ErrorCard(error: error, onRetry: () => ref.invalidate(summaryProvider(userId))),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Cơ cấu thu chi tháng này'),
          const SizedBox(height: 12),
          summary.when(
            data: (data) => _IncomeExpensePie(summary: data),
            loading: () => const SizedBox(height: 240, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 26),
          SectionHeader(title: _period == 'week' ? 'Biến động 7 ngày' : 'Biến động 30 ngày'),
          const SizedBox(height: 12),
          chart.when(
            data: (points) => _DailyBarChart(points: points),
            loading: () => const SizedBox(height: 300, child: Center(child: CircularProgressIndicator())),
            error: (error, _) => ErrorCard(
              error: error,
              onRetry: () => ref.invalidate(chartProvider(ChartRequest(userId, _period))),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Nếu báo cáo trả lỗi Firestore index, tạo composite index cho collection transactions với userId và date.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});
  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _MetricCard(label: 'Thu nhập', value: summary.totalIncome, icon: Icons.south_west_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _MetricCard(label: 'Chi tiêu', value: summary.totalExpense, icon: Icons.north_east_rounded)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});
  final String label;
  final double value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 14),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatMoney(value), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeExpensePie extends StatelessWidget {
  const _IncomeExpensePie({required this.summary});
  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final income = summary.totalIncome;
    final expense = summary.totalExpense;
    final total = income + expense;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? Colors.white : Colors.black;
    final secondary = isDark ? Colors.white38 : Colors.black38;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: total <= 0
            ? const SizedBox(
                height: 200,
                child: EmptyState(
                  icon: Icons.donut_large_outlined,
                  title: 'Chưa có dữ liệu',
                  message: 'Biểu đồ sẽ xuất hiện khi có giao dịch trong tháng.',
                ),
              )
            : SizedBox(
                height: 230,
                child: Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          centerSpaceRadius: 52,
                          sectionsSpace: 3,
                          startDegreeOffset: -90,
                          sections: [
                            PieChartSectionData(value: income, color: primary, radius: 34, showTitle: false),
                            PieChartSectionData(value: expense, color: secondary, radius: 34, showTitle: false),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Legend(color: primary, label: 'Thu', value: income),
                          const SizedBox(height: 20),
                          _Legend(color: secondary, label: 'Chi', value: expense),
                          const SizedBox(height: 20),
                          Text(
                            'Chênh lệch',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            child: Text(
                              formatMoney(income - expense),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 11, height: 11, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              FittedBox(child: Text(formatMoney(value), style: const TextStyle(fontWeight: FontWeight.w800))),
            ],
          ),
        ),
      ],
    );
  }
}

class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({required this.points});
  final List<ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Card(
        child: SizedBox(
          height: 260,
          child: EmptyState(
            icon: Icons.bar_chart_rounded,
            title: 'Chưa có dữ liệu biểu đồ',
            message: 'Hãy thêm giao dịch trong khoảng thời gian đã chọn.',
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final incomeColor = isDark ? Colors.white : Colors.black;
    final expenseColor = isDark ? Colors.white38 : Colors.black38;
    final maxAmount = points.fold<double>(0, (maxValue, item) => math.max(maxValue, math.max(item.income, item.expense)));
    final maxY = maxAmount <= 0 ? 1.0 : maxAmount * 1.25;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 22, 18, 14),
        child: SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (_) => FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                    '${rodIndex == 0 ? 'Thu' : 'Chi'}\n${formatMoney(rod.toY)}',
                    TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= points.length) return const SizedBox.shrink();
                      final step = points.length > 12 ? 3 : points.length > 7 ? 2 : 1;
                      if (index % step != 0 && index != points.length - 1) return const SizedBox.shrink();
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          formatShortDate(points[index].date),
                          style: const TextStyle(fontSize: 9),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < points.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 3,
                    barRods: [
                      BarChartRodData(toY: points[i].income, width: points.length > 14 ? 5 : 8, color: incomeColor, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: points[i].expense, width: points.length > 14 ? 5 : 8, color: expenseColor, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
