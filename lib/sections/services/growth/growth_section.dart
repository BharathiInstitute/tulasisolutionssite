import 'package:flutter/material.dart';
import '../growth/strategy_planning_section.dart';
import '../growth/sales_target_setting_section.dart';
import '../growth/monthly_review_section.dart';

/// Composite GrowthSection that groups strategy planning, sales targets,
/// and monthly review into one cohesive block with a shared heading and
/// consistent spacing.
class GrowthSection extends StatelessWidget {
  const GrowthSection({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 1100;
    final isMedium = width >= 860;

    // Decide layout: three columns on very wide, two columns on medium, stacked on small.
    final children = <Widget>[
      const StrategyPlanningSection(),
      const SalesTargetSettingSection(),
      const MonthlyReviewSection(),
    ];

    Widget layout;
    if (isWide) {
      layout = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: children[0]),
          const SizedBox(width: 32),
          Expanded(child: children[1]),
          const SizedBox(width: 32),
          Expanded(child: children[2]),
        ],
      );
    } else if (isMedium) {
      layout = Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[0]),
              const SizedBox(width: 32),
              Expanded(child: children[1]),
            ],
          ),
          const SizedBox(height: 32),
          children[2],
        ],
      );
    } else {
      layout = Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: 40),
          ]
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 56),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[100]!, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: const [
                Icon(Icons.trending_up, color: Color(0xFF0f172a)),
                SizedBox(width: 8),
                Text('Growth Engine', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Color(0xFF0f172a))),
              ]),
              const SizedBox(height: 8),
              const Text(
                'The three pillars we implement and review with you every month – clear strategic direction, measurable sales targets, and transparent performance reviews.',
                style: TextStyle(color: Color(0xFF475569), height: 1.4),
              ),
              const SizedBox(height: 40),
              layout,
            ],
          ),
        ),
      ),
    );
  }
}
