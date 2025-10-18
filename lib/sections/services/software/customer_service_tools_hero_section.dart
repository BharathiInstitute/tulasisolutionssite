import 'package:flutter/material.dart';

class CustomerServiceToolsHeroSection extends StatelessWidget {
	const CustomerServiceToolsHeroSection({super.key});
	@override
	Widget build(BuildContext context) {
		return Container(
			margin: const EdgeInsets.symmetric(vertical: 8),
			padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
			decoration: BoxDecoration(
				color: Colors.black.withValues(alpha: 0.03),
				borderRadius: BorderRadius.circular(18),
				border: Border.all(color: Colors.black12),
			),
			child: Center(
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 1050),
					child: LayoutBuilder(
						builder: (context, c) {
							final isWide = c.maxWidth > 880;
							return isWide
									? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
											const Expanded(flex: 5, child: _CsIntro()),
											const SizedBox(width: 44),
											const Expanded(flex: 6, child: _CsPanels()),
										])
									: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
											_CsIntro(),
											SizedBox(height: 40),
											_CsPanels(),
										]);
						},
					),
				),
			),
		);
	}
}

class _CsIntro extends StatelessWidget {
	const _CsIntro();
	@override
	Widget build(BuildContext context) {
		final t = Theme.of(context).textTheme;
		return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
			Text('Delight Every Interaction', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.05)),
			const SizedBox(height: 14),
			Text('Unified support inbox, SLA tracking, and proactive customer health signals – all in one workflow surface.',
					style: t.bodyLarge?.copyWith(height: 1.5)),
			const SizedBox(height: 26),
			Wrap(spacing: 10, runSpacing: 10, children: const [
				_CsChip('Omni Inbox'),
				_CsChip('SLA Alerts'),
				_CsChip('CSAT / NPS'),
				_CsChip('Macros'),
				_CsChip('Routing'),
			]),
			const SizedBox(height: 30),
			SizedBox(
				height: 46,
				child: ElevatedButton(
					style: ElevatedButton.styleFrom(
						backgroundColor: const Color(0xFF2563EB),
						foregroundColor: Colors.white,
						padding: const EdgeInsets.symmetric(horizontal: 30),
						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
					),
					onPressed: () => ScaffoldMessenger.of(context)
							.showSnackBar(const SnackBar(content: Text('Customer service module preview coming soon!'))),
					child: const Text('Elevate Support', style: TextStyle(fontWeight: FontWeight.w600)),
				),
			),
		]);
	}
}

class _CsChip extends StatelessWidget {
	final String label; const _CsChip(this.label);
	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
			decoration: BoxDecoration(
				color: Colors.black.withValues(alpha: 0.06),
				borderRadius: BorderRadius.circular(999),
				border: Border.all(color: Colors.black12),
			),
			child: Text(label, style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w600)),
		);
	}
}

class _CsPanels extends StatelessWidget {
	const _CsPanels();
	@override
	Widget build(BuildContext context) {
		return LayoutBuilder(builder: (context, c) {
			final wide = c.maxWidth >= 520;
			if (!wide) {
				return const Wrap(
					spacing: 18,
					runSpacing: 18,
					children: [
						_TicketPanel(),
						_SlaPanel(),
						_HealthPanel(),
						_MacroPanel(),
					],
				);
			}
			const double kPanelHeight = 220;
			return Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					// Row 1: Active Tickets + SLA & Satisfaction (equal width)
					Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Expanded(child: SizedBox(height: kPanelHeight, child: const _TicketPanel())),
							const SizedBox(width: 18),
							Expanded(child: SizedBox(height: kPanelHeight, child: const _SlaPanel())),
						],
					),
					const SizedBox(height: 18),
					// Row 2: Health Signals + Macros (equal width)
					Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Expanded(child: SizedBox(height: kPanelHeight, child: const _HealthPanel())),
							const SizedBox(width: 18),
							Expanded(child: SizedBox(height: kPanelHeight, child: const _MacroPanel())),
						],
					),
				],
			);
		});
	}
}

class _TicketPanel extends StatelessWidget {
	const _TicketPanel();
	@override
	Widget build(BuildContext context) {
		final tickets = const [
			('#4352', 'Payment Failure', 'High'),
			('#4353', 'Onboarding Query', 'Low'),
			('#4354', 'Feature Request', 'Medium'),
		];
		return _GlassCard(
			width: 300,
			title: 'Active Tickets',
			child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
				for (final t in tickets)
					Padding(
						padding: const EdgeInsets.only(bottom: 10),
						child: Row(children: [
							Expanded(flex: 3, child: Text(t.$1, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
							Expanded(flex: 6, child: Text(t.$2, style: const TextStyle(color: Colors.white70, fontSize: 12))),
							Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: _SeverityBadge(level: t.$3))),
						]),
					),
			]),
		);
	}
}

class _SeverityBadge extends StatelessWidget {
	final String level; const _SeverityBadge({required this.level});
	@override
	Widget build(BuildContext context) {
		late Color color;
		switch (level) {
			case 'High':
				color = const Color(0xFFEF4444);
				break;
			case 'Medium':
				color = const Color(0xFFF59E0B);
				break;
			default:
				color = const Color(0xFF10B981);
		}
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
			decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.3))),
			child: Text(level, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
		);
	}
}

class _SlaPanel extends StatelessWidget {
	const _SlaPanel();
	@override
	Widget build(BuildContext context) {
		final metrics = const [
			('First Response', '6m', 0.83),
			('Resolution', '1h 12m', 0.67),
			('CSAT', '94%', 0.94),
		];
		return _GlassCard(
			width: 300,
			title: 'SLA & Satisfaction',
			child: Column(children: [
				for (final m in metrics)
					Padding(
						padding: const EdgeInsets.only(bottom: 12),
						child: Row(children: [
							Expanded(flex: 5, child: Text(m.$1, style: const TextStyle(color: Colors.white70, fontSize: 12))),
							Expanded(flex: 3, child: Text(m.$2, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
							Expanded(flex: 5, child: _Bar(pct: m.$3)),
						]),
					),
			]),
		);
	}
}

class _HealthPanel extends StatelessWidget {
	const _HealthPanel();
	@override
	Widget build(BuildContext context) {
		final signals = const [
			('Churn Risk', 0.32, Color(0xFFEF4444)),
			('Expansion', 0.56, Color(0xFF2563EB)),
			('Sentiment', 0.78, Color(0xFF10B981)),
		];
		return _GlassCard(
			width: 300,
			title: 'Health Signals',
			child: Column(children: [
				for (final s in signals)
					Padding(
						padding: const EdgeInsets.only(bottom: 12),
						child: Row(children: [
							Expanded(flex: 5, child: Text(s.$1, style: const TextStyle(color: Colors.white70, fontSize: 12))),
							Expanded(flex: 5, child: _Bar(pct: s.$2, color: s.$3)),
						]),
					),
			]),
		);
	}
}

class _MacroPanel extends StatelessWidget {
	const _MacroPanel();
	@override
	Widget build(BuildContext context) {
		final macros = const [
			'Refund Flow',
			'Bug Escalation',
			'Outage Notice',
			'Welcome Reply',
		];
		return _GlassCard(
			width: 300,
			title: 'Macros',
			child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
				for (final m in macros)
					Padding(
						padding: const EdgeInsets.only(bottom: 10),
						child: Row(children: [
							const Icon(Icons.play_circle, size: 14, color: Colors.white54),
							const SizedBox(width: 8),
							Expanded(child: Text(m, style: const TextStyle(color: Colors.white, fontSize: 12))),
						]),
					),
			]),
		);
	}
}

class _GlassCard extends StatelessWidget {
	final double width; final String title; final Widget child; const _GlassCard({required this.width, required this.title, required this.child});
	@override
	Widget build(BuildContext context) {
		return Container(
			width: width,
			padding: const EdgeInsets.all(16),
			decoration: BoxDecoration(
				color: Colors.black.withValues(alpha: 0.04),
				borderRadius: BorderRadius.circular(18),
				border: Border.all(color: Colors.black12),
			),
			child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
				Text(title, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
				const SizedBox(height: 14),
				child,
			]),
		);
	}
}

class _Bar extends StatelessWidget {
	final double pct; final Color? color; const _Bar({required this.pct, this.color});
	@override
	Widget build(BuildContext context) {
		return LayoutBuilder(builder: (context, c) {
			return Stack(children: [
				Container(
					height: 8,
					decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
				),
				AnimatedContainer(
					duration: const Duration(milliseconds: 700),
					curve: Curves.easeOut,
					height: 8,
						width: c.maxWidth * pct,
					decoration: BoxDecoration(
						gradient: LinearGradient(colors: [
							(color ?? const Color(0xFF2563EB)),
							(color ?? const Color(0xFF3B82F6)).withValues(alpha: 0.7),
						]),
						borderRadius: BorderRadius.circular(4),
					),
				),
			]);
		});
	}
}