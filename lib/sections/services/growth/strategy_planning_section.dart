import 'package:flutter/material.dart';

/// StrategyPlanningSection (simplified)
/// Provides only essential strategy planning info: title, focus chips, and a basic quarterly table.
class StrategyPlanningSection extends StatelessWidget {
	const StrategyPlanningSection({super.key, this.maxWidth = 1000, this.primaryColor = const Color(0xFF1f6feb)});

	final double maxWidth;
	final Color primaryColor;

	@override
	Widget build(BuildContext context) {
		final focusItems = _focusItems();
		final quarters = _quarters();
		return Padding(
			padding: const EdgeInsets.all(16),
			child: Center(
				child: ConstrainedBox(
					constraints: BoxConstraints(maxWidth: maxWidth),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						mainAxisSize: MainAxisSize.min,
						children: [
							Row(children: const [
								Icon(Icons.explore, color: Color(0xFF0f172a)),
								SizedBox(width: 8),
								Text('Strategy Planning', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0f172a))),
							]),
							const SizedBox(height: 6),
							const Text(
								'Quarterly clarity: align positioning, budget and experiments without heavy UI.',
								style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
							),
							const SizedBox(height: 20),
							Wrap(
								spacing: 12,
								runSpacing: 12,
								children: [for (final f in focusItems) _FocusChip(item: f, color: primaryColor)],
							),
							const SizedBox(height: 28),
							const Text('Quarter Focus', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0f172a))),
							const SizedBox(height: 12),
							_QuarterTable(rows: quarters, accent: primaryColor),
						],
					),
				),
			),
		);
	}

	List<_FocusItem> _focusItems() => const [
		_FocusItem(label: 'Positioning', desc: 'Clarify differentiator'),
		_FocusItem(label: 'Budget Split', desc: 'Allocate by ROI'),
		_FocusItem(label: 'Channel Mix', desc: 'Pick 2-3 primary'),
		_FocusItem(label: 'Experiments', desc: 'Rank & schedule'),
		_FocusItem(label: 'KPIs', desc: 'Define success'),
	];

	List<_QuarterRow> _quarters() => const [
		_QuarterRow(q: 'Q1', theme: 'Foundation', focus: 'Positioning + ICP', metric: 'Message test'),
		_QuarterRow(q: 'Q2', theme: 'Acquisition', focus: 'Channel ramp', metric: 'Lead velocity'),
		_QuarterRow(q: 'Q3', theme: 'Optimization', focus: 'Experiment cycles', metric: 'Conv. rate'),
		_QuarterRow(q: 'Q4', theme: 'Scale', focus: 'Double winners', metric: 'LTV/CAC'),
	];
}

class _FocusChip extends StatelessWidget {
	const _FocusChip({required this.item, required this.color});
	final _FocusItem item;
	final Color color;
	@override
	Widget build(BuildContext context) {
		return Tooltip(
			message: item.desc,
			child: Container(
				padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
				decoration: BoxDecoration(
					color: Colors.white,
					borderRadius: BorderRadius.circular(12),
					border: Border.all(color: color.withValues(alpha: 0.5)),
				),
				child: Text(item.label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
			),
		);
	}
}

class _FocusItem {
	final String label;
	final String desc;
	const _FocusItem({required this.label, required this.desc});
}

class _QuarterTable extends StatelessWidget {
	const _QuarterTable({required this.rows, required this.accent});
	final List<_QuarterRow> rows;
	final Color accent;
	@override
	Widget build(BuildContext context) {
		return Table(
			columnWidths: const {
				0: FixedColumnWidth(44),
				1: FlexColumnWidth(2),
				2: FlexColumnWidth(2),
				3: FlexColumnWidth(2),
			},
			border: TableBorder.all(color: accent.withValues(alpha: 0.12)),
			children: [
				TableRow(
					decoration: BoxDecoration(color: accent.withValues(alpha: 0.08)),
					children: const [
						Padding(padding: EdgeInsets.all(8), child: Text('Qtr', style: TextStyle(fontWeight: FontWeight.w700))),
						Padding(padding: EdgeInsets.all(8), child: Text('Theme', style: TextStyle(fontWeight: FontWeight.w700))),
						Padding(padding: EdgeInsets.all(8), child: Text('Focus', style: TextStyle(fontWeight: FontWeight.w700))),
						Padding(padding: EdgeInsets.all(8), child: Text('Metric', style: TextStyle(fontWeight: FontWeight.w700))),
					],
				),
				for (final r in rows)
					TableRow(children: [
						Padding(padding: const EdgeInsets.all(8), child: Text(r.q)),
						Padding(padding: const EdgeInsets.all(8), child: Text(r.theme)),
						Padding(padding: const EdgeInsets.all(8), child: Text(r.focus)),
						Padding(padding: const EdgeInsets.all(8), child: Text(r.metric)),
					]),
			],
		);
	}
}

class _QuarterRow {
	final String q;
	final String theme;
	final String focus;
	final String metric;
	const _QuarterRow({required this.q, required this.theme, required this.focus, required this.metric});
}