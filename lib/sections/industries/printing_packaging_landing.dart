// Migrated from lib/industries/printing_packaging_landing.dart
// Original kept temporarily until all imports are updated.
import 'dart:math' as math;
import 'package:flutter/material.dart';

class PrintingLandingContent {
	final String badge;
	final String headline;
	final String subtext;
	final List<ChipItem> quickChips;
	final List<FeatureItem> features;
	final VoidCallback onPrimary;
	final VoidCallback onSecondary;
	const PrintingLandingContent({
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
	final String label; // emoji + text allowed
	const ChipItem(this.label);
}

class FeatureItem {
	final String emoji; // use requested emoji icons
	final String title;
	final String desc;
	const FeatureItem(this.emoji, this.title, this.desc);
}

class PrintingPlaybookLanding extends StatefulWidget {
	const PrintingPlaybookLanding({super.key, required this.data, this.reduceMotion = false});
	final PrintingLandingContent data;
	final bool reduceMotion; // accessibility: disable float animations

	@override
	State<PrintingPlaybookLanding> createState() => _PrintingPlaybookLandingState();
}

class _PrintingPlaybookLandingState extends State<PrintingPlaybookLanding>
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

		const blue = Color(0xFF0D6EFD); // primary printing blue
		const gold = Color(0xFFD4AF37); // secondary accent
		const dark = Color(0xFF212529);
		final bg = Theme.of(context).scaffoldBackgroundColor;

		final text = _HeroText(
			data: widget.data,
			isDesktop: isDesktop,
			blue: blue,
			dark: dark,
		);
		final mock = _DeviceMockup(
			blue: blue,
			gold: gold,
			hovering: _hoverMock,
			controller: widget.reduceMotion ? null : _float,
			onHoverChanged: (v) => setState(() => _hoverMock = v),
		);

		return Container(
			color: bg,
			child: Column(
				children: [
					// Hero
					Padding(
						padding: EdgeInsets.symmetric(
							horizontal: isDesktop ? 48 : 20,
							vertical: isDesktop ? 40 : 24,
						),
						child: ConstrainedBox(
							constraints: const BoxConstraints(maxWidth: 1200),
							child: isDesktop
									? Row(
											crossAxisAlignment: CrossAxisAlignment.center,
											children: [
												Expanded(child: text),
												const SizedBox(width: 24),
												Expanded(child: mock),
											],
										)
									: Column(
											crossAxisAlignment:
													isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
											children: [
												text,
												const SizedBox(height: 20),
												Transform.scale(
													scale: isMobile ? 0.98 : 0.92,
													child: mock,
												),
											],
									),
						),
					),

					// Features grid
					Padding(
						padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
						child: ConstrainedBox(
							constraints: const BoxConstraints(maxWidth: 1200),
							child: Column(
								mainAxisSize: MainAxisSize.min,
								children: [
									_FeaturesGrid(items: widget.data.features),
								],
							),
						),
					),
				],
			),
		);
	}
}

class _HeroText extends StatefulWidget {
	const _HeroText({required this.data, required this.isDesktop, required this.blue, required this.dark});
	final PrintingLandingContent data;
	final bool isDesktop;
	final Color blue;
	final Color dark;
	@override
	State<_HeroText> createState() => _HeroTextState();
}

class _HeroTextState extends State<_HeroText> with SingleTickerProviderStateMixin {
	late final AnimationController _in = AnimationController(
		vsync: this,
		duration: const Duration(milliseconds: 600),
	)..forward();

	bool _hoverPrimary = false;
	bool _hoverSecondary = false;

	@override
	void dispose() {
		_in.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final isDesktop = widget.isDesktop;
		final scale = MediaQuery.textScalerOf(context).scale(1.0);
		final headlineSize = isDesktop ? 54.0 : 30.0;

		return FadeTransition(
			opacity: CurvedAnimation(parent: _in, curve: Curves.easeOutCubic),
			child: SlideTransition(
				position: Tween<Offset>(begin: const Offset(0, .06), end: Offset.zero).animate(_in),
				child: Column(
					crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
					children: [
						// Badge
						Container(
							padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
							decoration: BoxDecoration(
								color: widget.blue.withValues(alpha: .08),
								borderRadius: BorderRadius.circular(999),
								border: Border.all(color: widget.blue.withValues(alpha: .2)),
							),
							child: Text('🖨️📦 ${widget.data.badge}',
									semanticsLabel: widget.data.badge,
									style: const TextStyle(fontWeight: FontWeight.w600)),
						),
						const SizedBox(height: 14),
						Text(
							widget.data.headline,
							textAlign: isDesktop ? TextAlign.left : TextAlign.center,
							style: TextStyle(
								fontSize: headlineSize * scale,
								height: 1.1,
								fontWeight: FontWeight.w800,
								color: widget.dark,
								fontFamily: 'Poppins',
							),
						),
						const SizedBox(height: 10),
						Text(
							widget.data.subtext,
							textAlign: isDesktop ? TextAlign.left : TextAlign.center,
							style: TextStyle(fontSize: 16 * scale, color: Colors.black.withValues(alpha: .75)),
						),
						const SizedBox(height: 16),
						// CTA row
						Wrap(
							spacing: 12,
							runSpacing: 8,
							alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
							children: [
								MouseRegion(
									onEnter: (_) => setState(() => _hoverPrimary = true),
									onExit: (_) => setState(() => _hoverPrimary = false),
									child: AnimatedScale(
										duration: const Duration(milliseconds: 160),
										scale: _hoverPrimary ? 1.02 : 0.98,
										child: DecoratedBox(
											decoration: BoxDecoration(
												boxShadow: _hoverPrimary
													? [
														BoxShadow(
															color: widget.blue.withValues(alpha: .28),
															blurRadius: 18,
															offset: const Offset(0, 6),
														)
													]
													: [],
											borderRadius: BorderRadius.circular(10),
											),
											child: ElevatedButton(
												onPressed: widget.data.onPrimary,
												style: ElevatedButton.styleFrom(
													backgroundColor: widget.blue,
													foregroundColor: Colors.white,
													minimumSize: const Size(48, 48),
													padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
													shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
													elevation: 2,
												),
												child: const Text('Get the Playbook'),
											),
										),
										), // end AnimatedScale primary
									), // end MouseRegion primary
									MouseRegion(
									onEnter: (_) => setState(() => _hoverSecondary = true),
									onExit: (_) => setState(() => _hoverSecondary = false),
									child: AnimatedScale(
										duration: const Duration(milliseconds: 160),
										scale: _hoverSecondary ? 1.02 : 0.98,
										child: OutlinedButton(
											onPressed: widget.data.onSecondary,
											style: OutlinedButton.styleFrom(
												minimumSize: const Size(48, 48),
												padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
												shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
												side: BorderSide(color: Colors.black.withValues(alpha: .15)),
											),
											child: const Text('See Sample Catalog'),
										),
									),
								), // end MouseRegion secondary
							], // end CTA children list
						), // end Wrap

						const SizedBox(height: 14),
						Wrap(
							spacing: 8,
							runSpacing: 8,
							alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
							children: widget.data.quickChips
									.map((c) => Container(
											padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
											decoration: BoxDecoration(
												color: Colors.white,
												borderRadius: BorderRadius.circular(20),
												border: Border.all(color: Colors.black.withValues(alpha: .08)),
											),
											child: Text(c.label, style: const TextStyle(fontSize: 13)),
										))
										.toList(),
						),
					],
				),
			),
		);
	}
}

class _DeviceMockup extends StatelessWidget {
	const _DeviceMockup({
		required this.blue,
		required this.gold,
		required this.hovering,
		required this.controller,
		required this.onHoverChanged,
	});
	final Color blue;
	final Color gold;
	final bool hovering;
	final AnimationController? controller;
	final ValueChanged<bool> onHoverChanged;

	@override
	Widget build(BuildContext context) {
		final width = MediaQuery.sizeOf(context).width;
		final isMobile = width < 600;
		final base = _MockupBody(blue: blue, gold: gold, isMobile: isMobile);
		final shadow = [
			BoxShadow(
				color: Colors.black.withValues(alpha: hovering ? .22 : .14),
				blurRadius: hovering ? 22 : 14,
				offset: const Offset(0, 10),
			)
		];

		Widget child = AnimatedScale(
			duration: const Duration(milliseconds: 220),
			curve: Curves.easeOut,
			scale: hovering ? 1.03 : 1.0,
			child: Container(
				decoration: BoxDecoration(boxShadow: shadow, borderRadius: BorderRadius.circular(18)),
				child: base,
			),
		);

		if (controller != null) {
			child = AnimatedBuilder(
				animation: controller!,
				builder: (context, c) {
					final t = controller!.value; // 0..1
					final dy = math.sin(t * 2 * math.pi) * 6; // -6..+6
					return Transform.translate(offset: Offset(0, dy), child: c);
				},
				child: child,
			);
		}

		return MouseRegion(
			onEnter: (_) => onHoverChanged(true),
			onExit: (_) => onHoverChanged(false),
			child: child,
		);
	}
}

class _MockupBody extends StatelessWidget {
	const _MockupBody({required this.blue, required this.gold, required this.isMobile});
	final Color blue;
	final Color gold;
	final bool isMobile;
	@override
	Widget build(BuildContext context) {
		// 16:9 desktop/tablet, 9:16 on mobile to echo portrait device
		return ClipRRect(
			borderRadius: BorderRadius.circular(18),
			child: Container(
				color: Colors.white,
				child: AspectRatio(
					aspectRatio: isMobile ? 9 / 16 : 16 / 9,
					child: Stack(
						fit: StackFit.expand,
						children: [
							// Subtle printing texture via dotted grid lines
							CustomPaint(
								painter: _DottedGridPainter(color: Colors.black.withValues(alpha: .05)),
							),
							// Screen content placeholder
							Align(
								alignment: Alignment.center,
								child: Padding(
									padding: const EdgeInsets.all(16.0),
									child: ClipRRect(
										borderRadius: BorderRadius.circular(14),
										child: Container(
											decoration: BoxDecoration(
												color: Colors.white,
												border: Border.all(color: Colors.black.withValues(alpha: .06)),
												boxShadow: [
													BoxShadow(
														color: Colors.black.withValues(alpha: .08),
														blurRadius: 10,
														offset: const Offset(0, 6),
													),
												],
											),
											child: _DashboardPlaceholder(primary: blue, accent: gold),
										), // end inner Container
									), // end ClipRRect
								), // end Padding
							), // end Align
							], // end Stack children
						), // end Stack
					), // end AspectRatio
				), // end outer Container
			); // end ClipRRect
	}
}

class _DottedGridPainter extends CustomPainter {
	_DottedGridPainter({required this.color});
	final Color color;
	@override
	void paint(Canvas canvas, Size size) {
		final p = Paint()
			..color = color
			..strokeWidth = 1.0;
		const step = 16.0;
		for (double y = 0; y <= size.height; y += step) {
			for (double x = 0; x <= size.width; x += step) {
				canvas.drawCircle(Offset(x, y), .6, p);
			}
		}
	}
	@override
	bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashboardPlaceholder extends StatelessWidget {
	const _DashboardPlaceholder({required this.primary, required this.accent});
	final Color primary;
	final Color accent;
	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.all(12.0),
			child: GridView.count(
				crossAxisCount: 2,
				crossAxisSpacing: 10,
				mainAxisSpacing: 10,
				physics: const NeverScrollableScrollPhysics(),
				children: List.generate(4, (i) {
					return Material(
						color: Colors.white,
						elevation: 1,
						borderRadius: BorderRadius.circular(10),
						child: Container(
							decoration: BoxDecoration(
								borderRadius: BorderRadius.circular(10),
								border: Border.all(color: Colors.black.withValues(alpha: .06)),
							),
							padding: const EdgeInsets.all(12),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Container(width: 80, height: 10, color: Colors.black.withValues(alpha: .65)),
									const SizedBox(height: 6),
									Container(width: 60, height: 8, color: Colors.black.withValues(alpha: .35)),
									const Spacer(),
									Align(
										alignment: Alignment.centerLeft,
										child: ElevatedButton(
											onPressed: () {},
											style: ElevatedButton.styleFrom(
												backgroundColor: primary,
												foregroundColor: Colors.white,
												minimumSize: const Size(36, 36),
												shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
											),
											child: const Text('View'),
										),
									),
								],
							),
						),
					);
				}),
			),
		);
	}
}

class _FeaturesGrid extends StatelessWidget {
	const _FeaturesGrid({required this.items});
	final List<FeatureItem> items;
	@override
	Widget build(BuildContext context) {
		return LayoutBuilder(builder: (context, c) {
			final w = c.maxWidth;
			int cols = 1;
			if (w >= 1024) {
				cols = 4;
			} else if (w >= 700) {
				cols = 2;
			}
			return GridView.builder(
				shrinkWrap: true,
				physics: const NeverScrollableScrollPhysics(),
				itemCount: items.length,
				gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
					crossAxisCount: cols,
					mainAxisExtent: 220,
					crossAxisSpacing: 16,
					mainAxisSpacing: 16,
				),
				itemBuilder: (context, i) => _FeatureCard(item: items[i], index: i),
			);
		});
	}
}

class _FeatureCard extends StatefulWidget {
	const _FeatureCard({required this.item, required this.index});
	final FeatureItem item;
	final int index;
	@override
	State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> with SingleTickerProviderStateMixin {
	late final AnimationController _in = AnimationController(
		vsync: this,
		duration: Duration(milliseconds: 250 + 80 * widget.index),
	)..forward();

	@override
	void dispose() {
		_in.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		const dark = Color(0xFF212529);
		return FadeTransition(
			opacity: _in,
			child: SlideTransition(
				position: Tween<Offset>(begin: const Offset(0, .05), end: Offset.zero).animate(_in),
				child: Semantics(
					button: true,
					label: widget.item.title,
					child: Material(
						color: Colors.white,
						borderRadius: BorderRadius.circular(14),
						elevation: 2,
						child: InkWell(
							borderRadius: BorderRadius.circular(14),
							onTap: () {},
							child: Padding(
								padding: const EdgeInsets.all(16.0),
								child: Row(
									children: [
										Container(
											width: 44,
											height: 44,
											decoration: BoxDecoration(
												color: Colors.black.withValues(alpha: .04),
												borderRadius: BorderRadius.circular(12),
											),
											child: Center(
												child: Text(
													widget.item.emoji,
													style: const TextStyle(fontSize: 22),
												),
											),
										),
										const SizedBox(width: 12),
										Expanded(
											child: Column(
												crossAxisAlignment: CrossAxisAlignment.start,
												mainAxisAlignment: MainAxisAlignment.center,
												children: [
													Text(widget.item.title,
														style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: dark)),
													const SizedBox(height: 6),
													Text(widget.item.desc,
														style: TextStyle(fontSize: 13, color: Colors.black.withValues(alpha: .65))),
												],
											),
										)
									],
								),
							),
						),
					),
				),
			),
		);
	}
}

// Sample data factory
PrintingLandingContent samplePrintingContent({
	required VoidCallback onPrimary,
	required VoidCallback onSecondary,
}) {
	return PrintingLandingContent(
		badge: 'Printing & Packaging Growth Playbook',
		headline: 'Printing & Packaging Growth Playbook',
		subtext: 'Quote-to-production workflows and catalogs for print shops and brands.',
		quickChips: const [
			ChipItem('🧾 Quote builder'),
			ChipItem('📦 Packaging templates'),
			ChipItem('🏷️ Label compliance'),
			ChipItem('📊 KPIs'),
		],
		features: const [
			FeatureItem('🧾', 'Quote builder', 'Pricing matrices, taxes, delivery'),
			FeatureItem('📦', 'Packaging templates', 'Die-lines and size presets'),
			FeatureItem('🏷️', 'Label compliance', 'FSSAI/cosmetics checklist'),
			FeatureItem('📊', 'KPIs', 'Turnaround time, wastage, margin'),
		],
		onPrimary: onPrimary,
		onSecondary: onSecondary,
	);
}