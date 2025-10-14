import 'package:flutter/material.dart';

/// MonthlyReviewSection (simplified) - metrics + wins/issues/next only.
class MonthlyReviewSection extends StatelessWidget {
	const MonthlyReviewSection({super.key, this.maxWidth = 900});
	final double maxWidth;
	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.all(16),
			child: Center(
				child: ConstrainedBox(
					constraints: BoxConstraints(maxWidth: maxWidth),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						mainAxisSize: MainAxisSize.min,
						children: [
							const _Header(),
							const SizedBox(height: 20),
							const _MetricStrip(),
							const SizedBox(height: 28),
							_ReviewLists(),
						],
					),
				),
			),
		);
	}
}

class _Header extends StatelessWidget {
	const _Header();
	@override
	Widget build(BuildContext context) => Row(children: const [
				Icon(Icons.assessment, color: Color(0xFF0f172a)),
				SizedBox(width: 8),
				Text('Monthly Review', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0f172a))),
			]);
}

class _MetricStrip extends StatelessWidget {
	const _MetricStrip();
	static final _items = [
		_MetricItem('Traffic', '13.2k', '+15%'),
		_MetricItem('Leads', '220', '+8%'),
		_MetricItem('Sales', '75', '+12%'),
		_MetricItem('CAC', '310', '-6%'),
	];
	@override
	Widget build(BuildContext context) => LayoutBuilder(builder: (c, cons) {
				final horizontal = cons.maxWidth > 620;
				final cards = _items.map((m) => _MetricCard(m)).toList();
				if (horizontal) {
					return Row(children: [
						for (int i = 0; i < cards.length; i++) ...[
							Expanded(child: cards[i]),
							if (i != cards.length - 1) const SizedBox(width: 14),
						]
					]);
				}
				return Column(children: [
					for (int i = 0; i < cards.length; i++) ...[
						cards[i],
						if (i != cards.length - 1) const SizedBox(height: 14),
					]
				]);
			});
}

class _MetricCard extends StatelessWidget {
	const _MetricCard(this.item);
	final _MetricItem item;
@override
Widget build(BuildContext context) {
	final neg = item.delta.startsWith('-');
	final color = neg ? const Color(0xFFdc2626) : const Color(0xFF16a34a);
	return Container(
		padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
		decoration: BoxDecoration(
			color: Colors.white,
			borderRadius: BorderRadius.circular(12),
			border: Border.all(color: color.withValues(alpha: 46)),
			boxShadow: [BoxShadow(color: color.withValues(alpha: 20), blurRadius: 8, offset: Offset(0, 4))],
		),
		child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
			Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0f172a))),
			const SizedBox(height: 6),
			Text(item.value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
			const SizedBox(height: 4),
			Text(item.delta, style: TextStyle(fontSize: 12, color: color)),
		]),
	);
}

}

class _MetricItem {
	final String label;
	final String value;
	final String delta;
	const _MetricItem(this.label, this.value, this.delta);
}

class _ReviewLists extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Text('Wins', style: const TextStyle(fontWeight: FontWeight.bold)),
				const SizedBox(height: 6),
				Text('- Launched new campaign'),
				Text('- Improved conversion rate'),
				const SizedBox(height: 16),
				Text('Issues', style: const TextStyle(fontWeight: FontWeight.bold)),
				const SizedBox(height: 6),
				Text('- Lead quality dropped'),
				Text('- CAC increased'),
				const SizedBox(height: 16),
				Text('Next Steps', style: const TextStyle(fontWeight: FontWeight.bold)),
				const SizedBox(height: 6),
				Text('- Test new channels'),
				Text('- Optimize landing pages'),
			],
		);
	}
}
