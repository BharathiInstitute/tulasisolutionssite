// Moved from lib/industries/cosmetics_landing.dart
// (Original path kept temporarily for diff reference during refactor)
import 'dart:math' as math;
import 'package:flutter/material.dart';

// Content model kept separate from UI
class CosmeticsLandingContent {
	final String badge;
	final String headline;
	final String subtext;
	final List<ChipItem> quickChips;
	final List<FeatureItem> features;
	final VoidCallback onPrimary;
	final VoidCallback onSecondary;
	const CosmeticsLandingContent({
		required this.badge,
		required this.headline,
		required this.subtext,
		required this.quickChips,
		required this.features,
		required this.onPrimary,
		required this.onSecondary,
	});
}

class ChipItem {
	final String label; // can include emoji, e.g., 💄 ✨
	const ChipItem(this.label);
}

class FeatureItem {
	final String emoji; // use requested emoji icons
	final String title;
	final String desc;
	const FeatureItem(this.emoji, this.title, this.desc);
}

class CosmeticsPlaybookLanding extends StatefulWidget {
	const CosmeticsPlaybookLanding({super.key, required this.data, this.reduceMotion = false});
	final CosmeticsLandingContent data;
	final bool reduceMotion; // accessibility: disable float animations

	@override
	State<CosmeticsPlaybookLanding> createState() => _CosmeticsPlaybookLandingState();
}

class _CosmeticsPlaybookLandingState extends State<CosmeticsPlaybookLanding>
		with SingleTickerProviderStateMixin {
	late final AnimationController _float = AnimationController(
		vsync: this,
		duration: const Duration(seconds: 3),
	)..repeat(reverse: true);
	bool _hoverMock = false;

	@override
	void dispose() {
		_float.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final w = MediaQuery.sizeOf(context).width;
		final isDesktop = w >= 1024;
		final isMobile = w < 600;

		const rose = Color(0xFFE91E63); // primary accent
		const gold = Color(0xFFD4AF37); // secondary accent
		const dark = Color(0xFF111111);
		final bg = Theme.of(context).scaffoldBackgroundColor;

		final text = _HeroText(
			data: widget.data,
			isDesktop: isDesktop,
			rose: rose,
			dark: dark,
		);
		final mock = _ProductMockup(
			rose: rose,
			gold: gold,
			hovering: _hoverMock,
			controller: widget.reduceMotion ? null : _float,
		);

		return MouseRegion(
			onEnter: (_) => setState(() => _hoverMock = true),
			onExit: (_) => setState(() => _hoverMock = false),
			child: AnimatedContainer(
				duration: const Duration(milliseconds: 260),
				curve: Curves.easeOutCubic,
				decoration: BoxDecoration(color: bg),
				padding: EdgeInsets.symmetric(
					vertical: isMobile ? 48 : 80,
					horizontal: isDesktop ? 72 : 28,
				),
				child: Center(
					child: ConstrainedBox(
						constraints: const BoxConstraints(maxWidth: 1280),
						child: LayoutBuilder(
							builder: (context, constraints) {
								final wide = constraints.maxWidth > 1000;
								if (wide) {
									return Row(
										crossAxisAlignment: CrossAxisAlignment.center,
										children: [
											Expanded(flex: 5, child: text),
											const SizedBox(width: 64),
											Expanded(flex: 5, child: mock),
										],
									);
								}
								return Column(
									crossAxisAlignment: CrossAxisAlignment.center,
									children: [
										text,
										const SizedBox(height: 48),
										mock,
									],
								);
							},
						),
					),
				),
			),
		);
	}
}

class _HeroText extends StatelessWidget {
	const _HeroText({
		required this.data,
		required this.isDesktop,
		required this.rose,
		required this.dark,
	});

	final CosmeticsLandingContent data;
	final bool isDesktop;
	final Color rose;
	final Color dark;

	@override
	Widget build(BuildContext context) {
		final scale = MediaQuery.textScalerOf(context).scale(1.0);
		final hSize = isDesktop ? 56.0 : 42.0;
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						Container(
							padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
							decoration: BoxDecoration(
								color: rose.withValues(alpha: .12),
								borderRadius: BorderRadius.circular(8),
							),
							child: Text(data.badge, style: TextStyle(color: rose, fontWeight: FontWeight.w600)),
						),
					],
				),
				const SizedBox(height: 22),
				Text(
					data.headline,
					style: TextStyle(
						fontSize: hSize * scale,
						fontWeight: FontWeight.w800,
						color: dark,
						height: 1.07,
						letterSpacing: -1.2,
					),
				),
				const SizedBox(height: 24),
				Text(
					data.subtext,
					style: TextStyle(color: dark.withValues(alpha: .68), height: 1.45, fontSize: 18 * scale),
				),
				const SizedBox(height: 30),
				Wrap(
					spacing: 10,
					runSpacing: 10,
					children: data.quickChips
						.map((c) => Container(
							padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
							decoration: BoxDecoration(
								color: rose.withValues(alpha: .08),
								borderRadius: BorderRadius.circular(30),
							),
							child: Text(c.label, style: TextStyle(color: dark.withValues(alpha: .80))),
						))
						.toList(),
				),
				const SizedBox(height: 36),
				_Buttons(onPrimary: data.onPrimary, onSecondary: data.onSecondary, rose: rose),
				const SizedBox(height: 50),
				_Grid(features: data.features, rose: rose, dark: dark),
			],
		);
	}
}

class _Buttons extends StatelessWidget {
	const _Buttons({required this.onPrimary, required this.onSecondary, required this.rose});
	final VoidCallback onPrimary;
	final VoidCallback onSecondary;
	final Color rose;
	@override
	Widget build(BuildContext context) {
		return Wrap(
			spacing: 16,
			runSpacing: 12,
			children: [
				FilledButton(
					onPressed: onPrimary,
					style: FilledButton.styleFrom(
						backgroundColor: rose,
						padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
						textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
					),
					child: const Text('Get the playbook'),
				),
				OutlinedButton(
					onPressed: onSecondary,
					style: OutlinedButton.styleFrom(
						padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
					),
					child: Text('See success stories', style: TextStyle(color: rose)),
				),
			],
		);
	}
}

class _Grid extends StatelessWidget {
	const _Grid({required this.features, required this.rose, required this.dark});
	final List<FeatureItem> features;
	final Color rose;
	final Color dark;
	@override
	Widget build(BuildContext context) {
		final isWide = MediaQuery.sizeOf(context).width >= 1000;
		final crossAxisCount = isWide ? 3 : 1;
		return GridView.builder(
			physics: const NeverScrollableScrollPhysics(),
			shrinkWrap: true,
			itemCount: features.length,
			gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
				crossAxisCount: crossAxisCount,
				mainAxisSpacing: 26,
				crossAxisSpacing: 26,
				childAspectRatio: isWide ? 1.1 : 3.2,
			),
			itemBuilder: (c, i) => _FeatureCard(item: features[i], rose: rose, dark: dark),
		);
	}
}

class _FeatureCard extends StatefulWidget {
	const _FeatureCard({required this.item, required this.rose, required this.dark});
	final FeatureItem item;
	final Color rose;
	final Color dark;
	@override
	State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> with SingleTickerProviderStateMixin {
	late final AnimationController _controller = AnimationController(
		vsync: this,
		duration: const Duration(milliseconds: 460),
	)..forward();
	bool _hover = false;

	@override
	void dispose() {
		_controller.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
		return MouseRegion(
			onEnter: (_) => setState(() => _hover = true),
			onExit: (_) => setState(() => _hover = false),
			child: AnimatedScale(
				scale: _hover ? 1.04 : 1.0,
				duration: const Duration(milliseconds: 180),
				curve: Curves.easeOut,
				child: FadeTransition(
					opacity: curve,
					child: DecoratedBox(
						decoration: BoxDecoration(
							color: Colors.white,
							borderRadius: BorderRadius.circular(26),
							boxShadow: [
								BoxShadow(
									color: Colors.black.withValues(alpha: .05),
									blurRadius: 18,
									offset: const Offset(0, 8),
								),
							],
						),
						child: Padding(
							padding: const EdgeInsets.all(24),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(widget.item.emoji, style: const TextStyle(fontSize: 32)),
									const SizedBox(height: 16),
									Text(
										widget.item.title,
										style: TextStyle(
											fontWeight: FontWeight.w700,
											fontSize: 18,
											color: widget.dark,
										),
									),
									const SizedBox(height: 10),
									Text(
										widget.item.desc,
										style: TextStyle(
											color: widget.dark.withValues(alpha: .70),
											height: 1.4,
										),
									),
								],
							),
						),
					),
				),
				)); // close AnimatedScale + MouseRegion
	}
}

class _ProductMockup extends StatefulWidget {
	const _ProductMockup({
		required this.rose,
		required this.gold,
		required this.hovering,
		this.controller,
	});
	final Color rose;
	final Color gold;
	final bool hovering;
	final AnimationController? controller;
	@override
	State<_ProductMockup> createState() => _ProductMockupState();
}

class _ProductMockupState extends State<_ProductMockup> with SingleTickerProviderStateMixin {
	@override
	Widget build(BuildContext context) {
		final base = Container(
			width: 430,
			constraints: const BoxConstraints(maxWidth: 520),
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(40),
				boxShadow: [
					BoxShadow(
						color: Colors.black.withValues(alpha: .06),
						blurRadius: 30,
						offset: const Offset(0, 16),
					),
				],
			),
			child: AspectRatio(
				aspectRatio: 3/4,
				child: Padding(
					padding: const EdgeInsets.all(30),
					child: _BottleArt(rose: widget.rose, gold: widget.gold),
				),
			),
		);

		if (widget.controller == null) {
			return base;
		}
		return AnimatedBuilder(
			animation: widget.controller!,
			builder: (context, child) {
				final t = widget.controller!.value;
				final dy = math.sin(t * math.pi) * 16;
				return Transform.translate(
					offset: Offset(0, -dy - (widget.hovering ? 6 : 0)),
					child: base,
				);
			},
		);
	}
}

class _BottleArt extends StatelessWidget {
	const _BottleArt({required this.rose, required this.gold});
	final Color rose;
	final Color gold;
	@override
	Widget build(BuildContext context) {
		return CustomPaint(
			painter: _BottlePainter(rose: rose, gold: gold),
		); 
	}
}

class _BottlePainter extends CustomPainter {
	const _BottlePainter({required this.rose, required this.gold});
	final Color rose;
	final Color gold;
	@override
	void paint(Canvas canvas, Size size) {
		final paint = Paint()..isAntiAlias = true;
		final w = size.width;
		final h = size.height;
		// base bottle body
		paint.color = rose.withValues(alpha: .85);
		final body = RRect.fromRectAndRadius(Rect.fromLTWH(w * .25, h * .15, w * .50, h * .63), const Radius.circular(26));
		canvas.drawRRect(body, paint);
		// label
		paint.color = Colors.white;
		final label = RRect.fromRectAndRadius(Rect.fromLTWH(w * .30, h * .30, w * .40, h * .28), const Radius.circular(20));
		canvas.drawRRect(label, paint);
		// cap
		paint.color = gold.withValues(alpha: .92);
		final cap = RRect.fromRectAndRadius(Rect.fromLTWH(w * .40, h * .07, w * .20, h * .12), const Radius.circular(8));
		canvas.drawRRect(cap, paint);
		// highlight
		paint.color = Colors.white.withValues(alpha: .20);
		canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .27, h * .17, w * .15, h * .46), const Radius.circular(22)), paint);
	}
	@override
	bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Sample content factory (mirrors pattern used by other industry pages) moved from legacy file
CosmeticsLandingContent sampleCosmeticsContent({
	required VoidCallback onPrimary,
	required VoidCallback onSecondary,
}) {
	return CosmeticsLandingContent(
		badge: 'NEW 2025',
		headline: 'Cosmetics Growth Playbook',
		subtext:
				'Leverage persona-driven campaigns, offer sequencing and compliant product launches to scale online & offline cosmetic sales.',
		quickChips: const [
			ChipItem('💄 Product Launch Kits'),
			ChipItem('🧴 SKU Performance'),
			ChipItem('🛍️ Retail Bundles'),
			ChipItem('📦 Packaging Upgrades'),
			ChipItem('📣 Influencer Briefs'),
			ChipItem('⚖️ Compliance Ready'),
		],
		features: const [
			FeatureItem('🧪', 'Persona & Routine Mapping', 'Clarify morning/night routines, seasonal shifts & trial triggers.'),
			FeatureItem('📊', 'Promo & Launch Calendar', 'Structured new product & bundle rollout frameworks.'),
			FeatureItem('🎯', 'Funnel Creative Library', 'Ad+landing variants for awareness → conversion → retention.'),
			FeatureItem('📦', 'Packaging & Offer Stack', 'Value ladders: hero + cross-sell + bundle + subscription.'),
			FeatureItem('🤝', 'Influencer Activation SOPs', 'Brief templates, UGC specs & performance tracking sheets.'),
			FeatureItem('📈', 'Retention & Reorder Flows', 'Email / WhatsApp triggered nurture & replenishment journeys.'),
		],
		onPrimary: onPrimary,
		onSecondary: onSecondary,
	);
}