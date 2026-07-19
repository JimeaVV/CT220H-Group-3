import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../reports/reports_screen.dart';
import '../transactions/transactions_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = [
    HomeScreen(),
    TransactionsScreen(),
    ReportsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/transaction/new'),
        tooltip: 'Thêm giao dịch',
        child: const Icon(Icons.add_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          children: [
            Expanded(child: _NavButton(index: 0, currentIndex: _index, icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Tổng quan', onTap: _select)),
            Expanded(child: _NavButton(index: 1, currentIndex: _index, icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long_rounded, label: 'Giao dịch', onTap: _select)),
            const SizedBox(width: 66),
            Expanded(child: _NavButton(index: 2, currentIndex: _index, icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart_rounded, label: 'Báo cáo', onTap: _select)),
            Expanded(child: _NavButton(index: 3, currentIndex: _index, icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Cá nhân', onTap: _select)),
          ],
        ),
      ),
    );
  }

  void _select(int index) => setState(() => _index = index);
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = index == currentIndex;
    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? selectedIcon : icon, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(fontSize: 10.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
