import 'package:flutter/material.dart';
import '../sections/services/page_background.dart';

class MonthlyReviewDashboardPage extends StatelessWidget {
  const MonthlyReviewDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageBackground(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Headline
                  Text(
                    'Progress You Can See',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Description
                  Text(
                    'Every month, we track results and refine your strategy.',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[300],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // KPI Dashboard
                  _KpiDashboard(),
                  const SizedBox(height: 24),
                  // Monthly Summary / Highlights
                  _MonthlySummary(),
                  const SizedBox(height: 24),
                  // Budget vs Performance Visualization
                  _BudgetVsPerformanceChart(),
                  const SizedBox(height: 24),
                  // Before/After KPI Improvement Chart
                  _BeforeAfterKpiChart(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final kpis = [
      {'icon': Icons.show_chart, 'name': 'Traffic', 'value': '13,200', 'trend': '+15%'},
      {'icon': Icons.people_alt, 'name': 'Leads', 'value': '220', 'trend': '+8%'},
      {'icon': Icons.shopping_cart, 'name': 'Sales', 'value': '75', 'trend': '+12%'},
      {'icon': Icons.pie_chart, 'name': 'CAC/LTV', 'value': '3.2', 'trend': '-5%'},
    ];
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kpis.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final kpi = kpis[i];
          return _KpiCard(
            icon: kpi['icon'] as IconData,
            name: kpi['name'] as String,
            value: kpi['value'] as String,
            trend: kpi['trend'] as String,
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final String value;
  final String trend;
  const _KpiCard({required this.icon, required this.name, required this.value, required this.trend});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          width: 180,
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 28),
                    const SizedBox(width: 8),
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(trend, style: TextStyle(color: trend.startsWith('+') ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w600)),
                  ],
                ),
                // Optional: Add a sparkline or mini chart here
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthlySummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.check_circle, 'color': Colors.green, 'text': 'Win: Record traffic growth'},
      {'icon': Icons.warning, 'color': Colors.orange, 'text': 'Issue: Lead conversion dipped'},
      {'icon': Icons.edit_note, 'color': Colors.blue, 'text': 'Plan: Launch new campaign'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Monthly Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(item['icon'] as IconData, color: item['color'] as Color, size: 20),
              const SizedBox(width: 8),
              Text(item['text'] as String, style: const TextStyle(color: Colors.white70, fontSize: 15)),
            ],
          ),
        )),
      ],
    );
  }
}

class _BudgetVsPerformanceChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Example data
    final budget = 100.0;
    final actual = 120.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Budget vs Performance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 12),
        Row(
          children: [
            _Bar(label: 'Budget', value: budget, color: Colors.grey.shade600),
            const SizedBox(width: 16),
            _Bar(label: 'Actual', value: actual, color: Colors.blueAccent),
          ],
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _Bar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          width: 40,
          height: value,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: color.withAlpha((0.3 * 255).toInt()), blurRadius: 8, offset: const Offset(0, 4))],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _BeforeAfterKpiChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Example before/after data
    final before = 90.0;
    final after = 120.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('KPI Improvement (Before/After)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 12),
        Row(
          children: [
            _Bar(label: 'Before', value: before, color: Colors.redAccent),
            const SizedBox(width: 16),
            _Bar(label: 'After', value: after, color: Colors.greenAccent),
          ],
        ),
      ],
    );
  }
}
