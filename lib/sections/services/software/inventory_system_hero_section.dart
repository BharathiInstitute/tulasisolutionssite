// Canonical implementation moved here from sections/software.
import 'package:flutter/material.dart';

class InventorySystemHeroSection extends StatelessWidget {
	const InventorySystemHeroSection({super.key});
	@override
	Widget build(BuildContext context) {
		return Container(
			decoration: const BoxDecoration(
				gradient: LinearGradient(
					colors: [Color(0xFF0B6B53), Color(0xFF065F46)],
					begin: Alignment.topLeft,
					end: Alignment.bottomRight,
				),
			),
			padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
			child: Center(
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 1000),
					child: LayoutBuilder(
						builder: (context, constraints) {
							final isWide = constraints.maxWidth > 820;
							final content = <Widget>[
								const Expanded(flex: 5, child: _InventoryIntro()),
								const SizedBox(width: 32),
								const Expanded(flex: 6, child: _InventoryPanels()),
							];
							return isWide
									? Row(crossAxisAlignment: CrossAxisAlignment.start, children: content)
									: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
											const _InventoryIntro(),
											const SizedBox(height: 32),
											const _InventoryPanels(),
										]);
						},
					),
				),
			),
		);
	}
}

class _InventoryIntro extends StatelessWidget {
	const _InventoryIntro();
	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context).textTheme;
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Text('Inventory Intelligence', style: theme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.1)),
				const SizedBox(height: 12),
				Text('Unified stock tracking, reorder automation, and multi-location visibility – so you never miss a sale or overstock again.',
						style: theme.bodyLarge?.copyWith(color: Colors.white70, height: 1.5)),
				const SizedBox(height: 20),
				Wrap(
					spacing: 10,
					runSpacing: 10,
					children: const [
						_Chip(text: 'Realtime Levels'),
						_Chip(text: 'Low Stock Alerts'),
						_Chip(text: 'Multi-Location'),
						_Chip(text: 'Batch / Expiry'),
						_Chip(text: 'Purchase Planning'),
					],
				),
				const SizedBox(height: 28),
				SizedBox(
					height: 46,
					child: ElevatedButton(
						style: ElevatedButton.styleFrom(
							backgroundColor: const Color(0xFF10B981),
							foregroundColor: Colors.white,
							padding: const EdgeInsets.symmetric(horizontal: 28),
							shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
						),
						onPressed: () => ScaffoldMessenger.of(context)
								.showSnackBar(const SnackBar(content: Text('Inventory automation coming soon!'))),
						child: const Text('Optimize Stock', style: TextStyle(fontWeight: FontWeight.w600)),
					),
				),
			],
		);
	}
}

class _Chip extends StatelessWidget {
	final String text;
	const _Chip({required this.text});
	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
			decoration: BoxDecoration(
				color: Colors.white.withValues(alpha: 0.12),
				borderRadius: BorderRadius.circular(999),
				border: Border.all(color: Colors.white24),
			),
			child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
		);
	}
}

class _InventoryPanels extends StatelessWidget {
	const _InventoryPanels();
	@override
	Widget build(BuildContext context) {
		return LayoutBuilder(builder: (context, c) {
			final isNarrow = c.maxWidth < 520;
			final panels = const [
				_MetricCard(icon: Icons.inventory_2, label: 'SKUs', value: '1,248'),
				_MetricCard(icon: Icons.local_shipping, label: 'In Transit', value: '312'),
				_MetricCard(icon: Icons.shopping_cart_checkout, label: 'Pending Orders', value: '54'),
				_MetricCard(icon: Icons.warning_amber_rounded, label: 'Low Stock', value: '17'),
			];
			return Wrap(
				spacing: 16,
				runSpacing: 16,
				children: [
					SizedBox(
						width: isNarrow ? c.maxWidth : (c.maxWidth - 16) / 2,
						child: const _StockTimeline(),
					),
					SizedBox(
						width: isNarrow ? c.maxWidth : (c.maxWidth - 16) / 2,
						child: const _ReorderList(),
					),
					for (final p in panels)
						SizedBox(
							width: isNarrow ? (c.maxWidth - 16) / 2 : (c.maxWidth - 48) / 4,
							child: p,
						),
				],
			);
		});
	}
}

class _MetricCard extends StatelessWidget {
	final IconData icon; final String label; final String value;
	const _MetricCard({required this.icon, required this.label, required this.value});
	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.all(14),
			decoration: BoxDecoration(
				color: const Color(0xFF064E3B),
				borderRadius: BorderRadius.circular(14),
				border: Border.all(color: const Color(0xFF065F46)),
			),
			child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
				Icon(icon, color: const Color(0xFF34D399), size: 18),
				const SizedBox(height: 10),
				Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
				const SizedBox(height: 4),
				Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
			]),
		);
	}
}

class _StockTimeline extends StatelessWidget {
	const _StockTimeline();
	@override
	Widget build(BuildContext context) {
		final entries = const [
			('08:30', 'Inbound Shipment #A102 received (+480)'),
			('09:10', 'Order #SO-773 picked (-35)'),
			('09:40', 'Order #SO-774 picked (-12)'),
			('10:05', 'Reorder suggestion for SKU-554'),
			('10:20', 'Transfer to Mumbai Hub (-120)'),
		];
		return Container(
			padding: const EdgeInsets.all(16),
			decoration: BoxDecoration(
				color: const Color(0xFF064E3B),
				borderRadius: BorderRadius.circular(18),
				border: Border.all(color: const Color(0xFF065F46)),
			),
			child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
				const Text('Live Activity', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
				const SizedBox(height: 12),
				for (final e in entries)
					Padding(
						padding: const EdgeInsets.only(bottom: 10),
						child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
							SizedBox(width: 54, child: Text(e.$1, style: const TextStyle(color: Colors.white54, fontSize: 11))),
							const SizedBox(width: 8),
							Expanded(child: Text(e.$2, style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35))),
						]),
					),
			]),
		);
	}
}

class _ReorderList extends StatelessWidget {
	const _ReorderList();
	@override
	Widget build(BuildContext context) {
		final items = const [
			('SKU-554', 'Widget Kit', 12),
			('SKU-889', 'Sensor Pack', 5),
			('SKU-332', 'Control Board', 22),
			('SKU-771', 'Battery Module', 9),
		];
		return Container(
			padding: const EdgeInsets.all(16),
			decoration: BoxDecoration(
				color: const Color(0xFF064E3B),
				borderRadius: BorderRadius.circular(18),
				border: Border.all(color: const Color(0xFF065F46)),
			),
			child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
				const Text('Reorder Watchlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
				const SizedBox(height: 12),
				for (final it in items)
					Padding(
						padding: const EdgeInsets.only(bottom: 10),
						child: Row(children: [
							Expanded(flex: 3, child: Text(it.$1, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
							Expanded(flex: 4, child: Text(it.$2, style: const TextStyle(color: Colors.white70, fontSize: 12))),
							Expanded(flex: 2, child: Text('Qty: ${it.$3}', style: const TextStyle(color: Colors.white, fontSize: 12))),
							Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: Text(it.$3 < 15 ? 'Reorder' : 'OK', style: TextStyle(color: it.$3 < 15 ? const Color(0xFFF59E0B) : const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w700)))),
						]),
					),
			]),
		);
	}
}