// FollowUpProcessSection implementation migrated to services/training
// Original sections file now exports this one. Placeholder minimalist version (can enhance later).

import 'package:flutter/material.dart';

class FollowUpProcessSection extends StatelessWidget {
	const FollowUpProcessSection({super.key, this.primaryColor = const Color(0xFF2563eb)});
	final Color primaryColor;
	@override
	Widget build(BuildContext context) {
		return Container(
			decoration: BoxDecoration(
				gradient: LinearGradient(colors: [primaryColor.withValues(alpha: 0.05), primaryColor.withValues(alpha: 0.15)], begin: Alignment.topLeft, end: Alignment.bottomRight),
				borderRadius: BorderRadius.circular(20),
				border: Border.all(color: primaryColor.withValues(alpha: 0.30)),
			),
			padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text('Follow-Up Process', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: primaryColor.darken())),
					const SizedBox(height: 8),
					const Text('Systemize consistent, multi-channel follow-ups that convert more deals.', style: TextStyle(fontSize: 16, color: Color(0xFF334155))),
					const SizedBox(height: 22),
					LayoutBuilder(builder: (context, c) {
						final items = const [
							_FItem('Sequenced touches', 'Day-by-day mapped cadence across channels.'),
							_FItem('Script library', 'Contextual replies & objection handlers.'),
							_FItem('Smart reminders', 'Never miss a promised follow-up again.'),
							_FItem('Analytics', 'See drop-offs & optimize timing.'),
						];
						final isWide = c.maxWidth > 600;
						final children = [for (final it in items) _FeatureTile(item: it, primary: primaryColor)];
						if (isWide) {
							return Wrap(
								spacing: 16,
								runSpacing: 16,
								children: children.map((e) => SizedBox(width: (c.maxWidth - 16) / 2, child: e)).toList(),
							);
						}
						return Column(children: [for (int i = 0; i < children.length; i++) ...[children[i], if (i != children.length - 1) const SizedBox(height: 14)]]);
					}),
					const SizedBox(height: 28),
					Wrap(spacing: 14, runSpacing: 12, children: const [
						_Kpi(label: 'Touch Coverage', value: '94%'),
						_Kpi(label: 'Reply Rate', value: '+22%'),
						_Kpi(label: 'Deal Acceleration', value: '-18%'),
					]),
				],
			),
		);
	}
}

class _FItem {
	const _FItem(this.title, this.desc);
	final String title; final String desc;
}

class _FeatureTile extends StatefulWidget {
	const _FeatureTile({required this.item, required this.primary});
	final _FItem item; final Color primary;
	@override State<_FeatureTile> createState() => _FeatureTileState();
}

class _FeatureTileState extends State<_FeatureTile> {
	bool _hover = false;
	@override
	Widget build(BuildContext context) {
		return MouseRegion(
			onEnter: (_) => setState(() => _hover = true),
			onExit: (_) => setState(() => _hover = false),
			child: AnimatedContainer(
				duration: const Duration(milliseconds: 160),
				padding: const EdgeInsets.all(14),
				decoration: BoxDecoration(
					color: Colors.white,
					borderRadius: BorderRadius.circular(14),
					border: Border.all(color: widget.primary.withValues(alpha: 0.35)),
					boxShadow: [
						BoxShadow(
							color: Colors.black.withValues(alpha: _hover ? 0.10 : 0.05),
							blurRadius: _hover ? 20 : 12,
							offset: const Offset(0, 6),
						),
					],
				),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Text(widget.item.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
						const SizedBox(height: 6),
						Text(widget.item.desc, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
					],
				),
			),
		);
	}
}

class _Kpi extends StatelessWidget {
	const _Kpi({required this.label, required this.value});
	final String label; final String value;
	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(14),
				border: Border.all(color: const Color(0xFFE2E8F0)),
				boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 6))],
			),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
					const SizedBox(height: 4),
					Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.indigo.shade600)),
				],
			),
		);
	}
}

extension _ColorShade on Color {
	Color darken([double amount = .12]) {
		final hsl = HSLColor.fromColor(this);
		final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
		return hslDark.toColor();
	}
}