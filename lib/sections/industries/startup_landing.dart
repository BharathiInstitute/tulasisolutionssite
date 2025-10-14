import 'dart:math' as math;
import 'package:flutter/material.dart';

class StartupLandingContent {
	final String badge;
	final String headline;
	final String subtext;
	final List<ChipItem> quickChips;
	final List<FeatureItem> features;
	final VoidCallback onPrimary;
	final VoidCallback onSecondary;
	const StartupLandingContent({
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
	final String label;
	const ChipItem(this.label);
}

class FeatureItem {
	final String emoji;
	final String title;
	final String desc;
	const FeatureItem(this.emoji, this.title, this.desc);
}

class StartupPlaybookLanding extends StatefulWidget {
	const StartupPlaybookLanding({super.key, required this.data, this.reduceMotion = false});
	final StartupLandingContent data;
	final bool reduceMotion;

	@override
	State<StartupPlaybookLanding> createState() => _StartupPlaybookLandingState();
}

class _StartupPlaybookLandingState extends State<StartupPlaybookLanding>
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

		const purple = Color(0xFF6F42C1);
		const gold = Color(0xFFD4AF37);
		const dark = Color(0xFF212529);

		final text = _HeroText(
			data: widget.data,
			isDesktop: isDesktop,
			purple: purple,
			dark: dark,
		);
		final mock = _DeviceMockup(
			purple: purple,
			gold: gold,
			hovering: _hoverMock,
			controller: widget.reduceMotion ? null : _float,
			onHoverChanged: (v) => setState(() => _hoverMock = v),
		);

		return Container(
			decoration: const BoxDecoration(
				gradient: LinearGradient(
					colors: [Color(0xFFF8F9FB), Color(0xFFF3F0FF)],
					begin: Alignment.topLeft,
					end: Alignment.bottomRight,
				),
			),
			child: Column(
				children: [
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
					Padding(
						padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
						child: ConstrainedBox(
							constraints: const BoxConstraints(maxWidth: 1200),
							child: _FeaturesGrid(items: widget.data.features),
						),
					),
				],
			),
		);
	}
}

class _HeroText extends StatefulWidget {
	const _HeroText({required this.data, required this.isDesktop, required this.purple, required this.dark});
	final StartupLandingContent data;
	final bool isDesktop;
	final Color purple;
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
						Container(
							padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
							decoration: BoxDecoration(
								color: widget.purple.withValues(alpha: .08),
								borderRadius: BorderRadius.circular(999),
								border: Border.all(color: widget.purple.withValues(alpha: .25)),
							),
							child: Text('🚀 ${widget.data.badge}',
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
																	color: widget.purple.withValues(alpha: .28),
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
													backgroundColor: widget.purple,
													foregroundColor: Colors.white,
													minimumSize: const Size(48, 48),
													padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
													shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
													elevation: 2,
												),
												child: const Text('Get the Playbook'),
											),
										),
									),
								),
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
											child: const Text('See Sample Templates'),
										),
									),
								),
							],
						),
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
		required this.purple,
		required this.gold,
		required this.hovering,
		required this.controller,
		required this.onHoverChanged,
	});
	final Color purple;
	final Color gold;
	final bool hovering;
	final AnimationController? controller;
	final ValueChanged<bool> onHoverChanged;

	@override
	Widget build(BuildContext context) {
		final width = MediaQuery.sizeOf(context).width;
		final isMobile = width < 600;
		final base = _MockupBody(purple: purple, gold: gold, isMobile: isMobile);
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
					final t = controller!.value;
					final dy = math.sin(t * 2 * math.pi) * 6;
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
	const _MockupBody({required this.purple, required this.gold, required this.isMobile});
	final Color purple;
	final Color gold;
	final bool isMobile;
	@override
	Widget build(BuildContext context) {
		return ClipRRect(
			borderRadius: BorderRadius.circular(18),
			child: Container(
				color: Colors.white,
				child: AspectRatio(
					aspectRatio: isMobile ? 9 / 16 : 16 / 9,
					child: Stack(
						fit: StackFit.expand,
						children: [
							const DecoratedBox(
								decoration: BoxDecoration(
									gradient: LinearGradient(
										colors: [Color(0xFFEEF0FF), Color(0xFFF3E8FF)],
										begin: Alignment.topLeft,
										end: Alignment.bottomRight,
									),
								),
							),
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
											child: _PitchAndLandingPlaceholder(primary: purple, accent: gold),
										),
									),
								),
							),
						],
					),
				),
			),
		);
	}
}

class _PitchAndLandingPlaceholder extends StatelessWidget {
	const _PitchAndLandingPlaceholder({required this.primary, required this.accent});
	final Color primary;
	final Color accent;
	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.all(12.0),
			child: Row(
				children: [
					Expanded(
						child: Stack(
							children: [
								Align(
									alignment: Alignment.centerLeft,
									child: Container(
										margin: const EdgeInsets.only(top: 10, left: 6),
										decoration: BoxDecoration(
											color: Colors.black.withValues(alpha: .04),
											borderRadius: BorderRadius.circular(12),
										),
									),
								),
								Align(
									alignment: Alignment.center,
									child: FractionallySizedBox(
										widthFactor: 0.85,
										heightFactor: 0.85,
										child: Container(
											decoration: BoxDecoration(
												color: Colors.white,
												border: Border.all(color: Colors.black.withValues(alpha: .06)),
												borderRadius: BorderRadius.circular(12),
												boxShadow: [
													BoxShadow(
														color: Colors.black.withValues(alpha: .05),
														blurRadius: 8,
														offset: const Offset(0, 4),
													)
												],
											),
											child: Center(
												child: Text('Pitch Deck',
														style: TextStyle(
																color: Colors.black.withValues(alpha: .55), fontWeight: FontWeight.w600)),
											),
										),
									),
								),
							],
						),
					),
					const SizedBox(width: 12),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Container(width: 160, height: 12, color: Colors.black.withValues(alpha: .6)),
								const SizedBox(height: 8),
								Container(width: 120, height: 10, color: Colors.black.withValues(alpha: .35)),
								const Spacer(),
								Align(
									alignment: Alignment.centerLeft,
									child: ElevatedButton(
										onPressed: () {},
										style: ElevatedButton.styleFrom(
											backgroundColor: primary,
											foregroundColor: Colors.white,
											minimumSize: const Size(44, 44),
											shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
										),
										child: const Text('Get the Playbook'),
									),
								)
							],
						),
					)
				],
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
					mainAxisExtent: 150,
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
															style: const TextStyle(
																	fontSize: 16, fontWeight: FontWeight.w700, color: dark)),
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

StartupLandingContent sampleStartupContent({
	required VoidCallback onPrimary,
	required VoidCallback onSecondary,
}) {
	return StartupLandingContent(
		badge: 'Startup Growth Playbook',
		headline: 'Startup Growth Playbook',
		subtext: 'Fast launch packages for founders — from pitch to first customers.',
		quickChips: const [
			ChipItem('👥 Persona packs'),
			ChipItem('🌐 Landing page templates'),
			ChipItem('📋 SOPs'),
			ChipItem('📊 KPIs'),
		],
		features: const [
			FeatureItem('👤', 'Persona packs', 'Investors, early adopters, B2B clients'),
			FeatureItem('🌐', 'Landing + funnels', 'Templates and demo funnels'),
			FeatureItem('📋', 'SOPs', 'Pitch decks & onboarding'),
			FeatureItem('📊', 'KPIs', 'Funding, MRR, growth rate'),
		],
		onPrimary: onPrimary,
		onSecondary: onSecondary,
	);
}
