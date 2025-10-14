import 'package:flutter/material.dart';

class LandingPagesHeroSection extends StatelessWidget {
	const LandingPagesHeroSection({super.key});
	@override
	Widget build(BuildContext context) {
		return Container(
			decoration: const BoxDecoration(
				gradient: LinearGradient(
					colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF), Color(0xFF0F172A)],
					begin: Alignment.topLeft,
					end: Alignment.bottomRight,
				),
			),
			padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 70),
			child: Center(
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 1100),
					child: LayoutBuilder(
						builder: (context, c) {
							final wide = c.maxWidth > 900;
							return wide
									? Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [
											Expanded(flex: 5, child: _LandingCopy()),
											SizedBox(width: 56),
											Expanded(flex: 6, child: _LandingMockup()),
										])
									: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
											_LandingCopy(),
											SizedBox(height: 48),
											_LandingMockup(),
										]);
						},
					),
				),
			),
		);
	}
}

class _LandingCopy extends StatelessWidget {
	const _LandingCopy();
	@override
	Widget build(BuildContext context) {
		final t = Theme.of(context).textTheme;
		return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
			Container(
				padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
				decoration: BoxDecoration(
					color: Colors.white.withValues(alpha: 0.12),
					borderRadius: BorderRadius.circular(999),
					border: Border.all(color: Colors.white24),
				),
				child: const Text('LANDING PAGES', style: TextStyle(letterSpacing: 1.1, fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
			),
			const SizedBox(height: 26),
			Text('Launch High‑Converting Pages in Minutes', style: t.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.05)),
			const SizedBox(height: 22),
			ConstrainedBox(
				constraints: const BoxConstraints(maxWidth: 560),
				child: Text('Rapidly build & iterate landing pages with modular sections, instant A/B test scaffolding, performance insights and integrated form analytics.',
						style: t.titleMedium?.copyWith(color: Colors.white.withValues(alpha: 0.78), height: 1.4, fontWeight: FontWeight.w500)),
			),
			const SizedBox(height: 30),
			Wrap(spacing: 12, runSpacing: 12, children: const [
				_LpChip('Template Library'),
				_LpChip('Drag Sections'),
				_LpChip('A/B Variants'),
				_LpChip('Heatmaps'),
				_LpChip('Analytics'),
			]),
			const SizedBox(height: 36),
			Row(children: [
				FilledButton(
					style: FilledButton.styleFrom(
						backgroundColor: const Color(0xFF3B82F6),
						foregroundColor: Colors.white,
						padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
					),
					onPressed: () {},
					child: const Text('Start Building', style: TextStyle(fontWeight: FontWeight.w700)),
				),
				const SizedBox(width: 18),
				OutlinedButton(
					style: OutlinedButton.styleFrom(
						foregroundColor: Colors.white,
						padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
						side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
					),
					onPressed: () {},
					child: const Text('Browse Templates', style: TextStyle(fontWeight: FontWeight.w700)),
				),
			]),
		]);
	}
}

class _LpChip extends StatelessWidget {
	final String label; const _LpChip(this.label);
	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
			decoration: BoxDecoration(
				color: Colors.white.withValues(alpha: 0.10),
				borderRadius: BorderRadius.circular(999),
				border: Border.all(color: Colors.white24),
			),
			child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
		);
	}
}

class _LandingMockup extends StatelessWidget {
	const _LandingMockup();
	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.all(24),
			decoration: BoxDecoration(
				color: const Color(0xFF0F172A),
				borderRadius: BorderRadius.circular(32),
				border: Border.all(color: const Color(0xFF1E3A8A)),
				boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.40), blurRadius: 40, offset: const Offset(0, 22))],
			),
			child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
				Row(children: [
					Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEF4444))),
					const SizedBox(width: 6),
					Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF59E0B))),
					const SizedBox(width: 6),
					Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981))),
				]),
				const SizedBox(height: 26),
				Container(
					padding: const EdgeInsets.all(18),
					decoration: BoxDecoration(
						color: const Color(0xFF1E3A8A),
						borderRadius: BorderRadius.circular(20),
						border: Border.all(color: const Color(0xFF1E40AF)),
					),
					child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
						Container(width: 160, height: 14, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(6))),
						const SizedBox(height: 16),
						Container(width: 220, height: 28, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8))),
						const SizedBox(height: 12),
						Container(width: 240, height: 12, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6))),
						const SizedBox(height: 4),
						Container(width: 200, height: 12, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6))),
						const SizedBox(height: 4),
						Container(width: 260, height: 12, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6))),
						const SizedBox(height: 26),
						Row(children: [
							Expanded(child: Container(height: 44, decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(14)))),
							const SizedBox(width: 14),
							Expanded(child: Container(height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white24)))),
						]),
					]),
				),
				const SizedBox(height: 28),
				Wrap(spacing: 12, runSpacing: 12, children: const [
					_InsightPill(icon: Icons.speed, label: '1.2s LCP'),
					_InsightPill(icon: Icons.check_circle, label: 'A/B Ready'),
					_InsightPill(icon: Icons.auto_graph, label: 'SEO Score 92'),
				]),
			]),
		);
	}
}

class _InsightPill extends StatelessWidget {
	final IconData icon; final String label; const _InsightPill({required this.icon, required this.label});
	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
			decoration: BoxDecoration(
				color: Colors.white.withValues(alpha: 0.12),
				borderRadius: BorderRadius.circular(999),
				border: Border.all(color: Colors.white24),
			),
			child: Row(mainAxisSize: MainAxisSize.min, children: [
				Icon(icon, size: 14, color: Colors.white70),
				const SizedBox(width: 6),
				Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
			]),
		);
	}
}