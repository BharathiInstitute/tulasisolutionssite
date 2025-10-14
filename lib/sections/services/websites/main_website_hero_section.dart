import 'package:flutter/material.dart';

class MainWebsiteHeroSection extends StatelessWidget {
	const MainWebsiteHeroSection({super.key});
	@override
	Widget build(BuildContext context) {
		final size = MediaQuery.sizeOf(context);
		final isWide = size.width > 920;
		return Container(
			decoration: const BoxDecoration(
				gradient: LinearGradient(
					colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
					begin: Alignment.topLeft,
					end: Alignment.bottomRight,
				),
			),
			padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 32, vertical: isWide ? 90 : 60),
			child: Center(
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 1250),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Wrap(
								spacing: 10,
								runSpacing: 10,
								children: const [
									_MwBadge('MAIN SITE'),
									_MwBadge('BRAND HUB'),
								],
							),
							const SizedBox(height: 30),
							Text(
								'Your Digital HQ\nFor Trust & Growth',
								style: Theme.of(context).textTheme.displaySmall?.copyWith(
											color: Colors.white,
											fontWeight: FontWeight.w800,
											height: 1.05,
										),
							),
							const SizedBox(height: 26),
							ConstrainedBox(
								constraints: const BoxConstraints(maxWidth: 720),
								child: Text(
									'Launch a lightning‑fast marketing site that unifies product storytelling, gated assets, blog, partner pages and conversion journeys—fully optimized for organic discovery.',
									style: Theme.of(context).textTheme.titleMedium?.copyWith(
												color: Colors.white.withValues(alpha: 0.78),
												height: 1.45,
												fontWeight: FontWeight.w500,
											),
								),
							),
							const SizedBox(height: 34),
							Wrap(
								spacing: 12,
								runSpacing: 12,
								children: const [
									_MwChip('CMS'),
									_MwChip('Modular Sections'),
									_MwChip('Blog Engine'),
									_MwChip('SEO Schema'),
									_MwChip('Media Library'),
									_MwChip('Analytics Hooks'),
								],
							),
							const SizedBox(height: 40),
							Row(children: [
								FilledButton(
									style: FilledButton.styleFrom(
										backgroundColor: const Color(0xFF6366F1),
										foregroundColor: Colors.white,
										padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 20),
										shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
									),
									onPressed: () {},
									child: const Text('Explore Platform', style: TextStyle(fontWeight: FontWeight.w700)),
								),
								const SizedBox(width: 18),
								OutlinedButton(
									style: OutlinedButton.styleFrom(
										foregroundColor: Colors.white,
										padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
										shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
										side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
									),
									onPressed: () {},
									child: const Text('View Case Studies', style: TextStyle(fontWeight: FontWeight.w700)),
								),
							]),
							const SizedBox(height: 64),
							_Showcase(isWide: isWide),
						],
					),
				),
			),
		);
	}
}

class _MwBadge extends StatelessWidget {
	final String text; const _MwBadge(this.text);
	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
			decoration: BoxDecoration(
				color: Colors.white.withValues(alpha: 0.12),
				borderRadius: BorderRadius.circular(999),
				border: Border.all(color: Colors.white24),
			),
			child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.1)),
		);
	}
}

class _MwChip extends StatelessWidget {
	final String label; const _MwChip(this.label);
	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
			decoration: BoxDecoration(
				color: Colors.white.withValues(alpha: 0.10),
				borderRadius: BorderRadius.circular(999),
				border: Border.all(color: Colors.white24),
			),
			child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
		);
	}
}

class _Showcase extends StatelessWidget {
	final bool isWide; const _Showcase({required this.isWide});
	@override
	Widget build(BuildContext context) {
		final grid = Wrap(
			spacing: 22,
			runSpacing: 22,
			children: const [
				_ShowTile(icon: Icons.view_compact_alt, label: 'Section Builder'),
				_ShowTile(icon: Icons.article_outlined, label: 'Blog CMS'),
				_ShowTile(icon: Icons.lock_open_rounded, label: 'Gated Assets'),
				_ShowTile(icon: Icons.search_rounded, label: 'SEO Console'),
				_ShowTile(icon: Icons.integration_instructions, label: 'Integrations'),
				_ShowTile(icon: Icons.analytics_outlined, label: 'Journey Insights'),
			],
		);
		return Container(
			padding: const EdgeInsets.all(30),
			decoration: BoxDecoration(
				color: const Color(0xFF1E293B),
				borderRadius: BorderRadius.circular(40),
				border: Border.all(color: const Color(0xFF334155)),
				boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 50, offset: const Offset(0, 28))],
			),
			child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
				const Text('Unified Content & Conversion Stack', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
				const SizedBox(height: 24),
				grid,
			]),
		);
	}
}

class _ShowTile extends StatelessWidget {
	final IconData icon; final String label; const _ShowTile({required this.icon, required this.label});
	@override
	Widget build(BuildContext context) {
		return Container(
			width: 160,
			height: 120,
			padding: const EdgeInsets.all(16),
			decoration: BoxDecoration(
				color: const Color(0xFF0F172A),
				borderRadius: BorderRadius.circular(28),
				border: Border.all(color: const Color(0xFF334155)),
			),
			child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
				Icon(icon, color: const Color(0xFF6366F1), size: 22),
				const Spacer(),
				Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
			]),
		);
	}
}