// Clean migrated copy from lib/industries/education_landing.dart
// (Original kept temporarily until all imports updated.)
import 'dart:math' as math;
import 'package:flutter/material.dart';

class EducationLandingContent {
	final String badge;
	final String headline;
	final String subtext;
	final List<ChipItem> quickChips;
	final List<FeatureItem> features;
	final VoidCallback onPrimary;
	final VoidCallback onSecondary;
	const EducationLandingContent({
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
	final IconData icon;
	final String label;
	const ChipItem(this.icon, this.label);
}

class FeatureItem {
	final IconData icon;
	final String title;
	final String desc;
	const FeatureItem(this.icon, this.title, this.desc);
}

class EducationPlaybookLanding extends StatefulWidget {
	const EducationPlaybookLanding({super.key, required this.data, this.reduceMotion = false});
	final EducationLandingContent data;
	final bool reduceMotion;

	@override
	State<EducationPlaybookLanding> createState() => _EducationPlaybookLandingState();
}

class _EducationPlaybookLandingState extends State<EducationPlaybookLanding>
		with SingleTickerProviderStateMixin {
	late final AnimationController _float = AnimationController(
		vsync: this,
		duration: const Duration(seconds: 3),
	)..repeat(reverse: true);
	bool _hoveringMock = false;

	@override
	void dispose() {
		_float.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final width = MediaQuery.sizeOf(context).width;
		final isDesktop = width >= 1024;
	final isMobile = width < 600;
		const gold = Color(0xFFD4AF37);
		const mutedBg = Color(0xFFF7F8FA);

		final content = _HeroTextColumn(data: widget.data, isDesktop: isDesktop);
		final mockup = _DeviceMockup(
			gold: gold,
			hovering: _hoveringMock,
			controller: widget.reduceMotion ? null : _float,
			onHoverChanged: (v) => setState(() => _hoveringMock = v),
		);

		return Container(
			color: mutedBg,
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
												Expanded(child: content),
												const SizedBox(width: 24),
												Expanded(child: mockup),
											],
										)
									: Column(
											crossAxisAlignment:
													isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
											children: [
												content,
												const SizedBox(height: 20),
												mockup,
											],
									),
						),
					),

					// Features
					Padding(
						padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
						child: ConstrainedBox(
							constraints: const BoxConstraints(maxWidth: 1200),
							child: _IncludedFeaturesGrid(items: widget.data.features),
						),
					),
				],
			),
		);
	}
}

class _HeroTextColumn extends StatefulWidget {
	const _HeroTextColumn({required this.data, required this.isDesktop});
	final EducationLandingContent data;
	final bool isDesktop;
	@override
	State<_HeroTextColumn> createState() => _HeroTextColumnState();
}

class _HeroTextColumnState extends State<_HeroTextColumn>
		with SingleTickerProviderStateMixin {
	late final AnimationController _in = AnimationController(
		vsync: this,
		duration: const Duration(milliseconds: 600),
	)..forward();

	@override
	void dispose() {
		_in.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		const gold = Color(0xFFD4AF37);
		const body = Color(0xFF475569);
	const dark = Color(0xFF0F172A);
		final isDesktop = widget.isDesktop;
	final scale = MediaQuery.textScalerOf(context).scale(1.0);
		final headlineSize = isDesktop ? 52.0 : 30.0;

		return FadeTransition(
			opacity: CurvedAnimation(parent: _in, curve: Curves.easeOutCubic),
			child: SlideTransition(
				position:
						Tween<Offset>(begin: const Offset(0, .06), end: Offset.zero).animate(_in),
				child: Column(
					crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
					children: [
						// Badge
						Container(
							padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
							decoration: BoxDecoration(
								color: gold.withValues(alpha: .12),
								borderRadius: BorderRadius.circular(999),
							),
							child: Text(widget.data.badge,
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
								color: dark,
								fontFamily: 'Poppins',
							),
						),
						const SizedBox(height: 10),
						Text(
							widget.data.subtext,
							textAlign: isDesktop ? TextAlign.left : TextAlign.center,
							style: TextStyle(fontSize: 16 * scale, color: body),
						),
						const SizedBox(height: 16),
						Wrap(
							spacing: 12,
							runSpacing: 8,
							alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
							children: [
								Semantics(
									button: true,
									label: 'Get the Playbook',
									child: ElevatedButton(
										onPressed: widget.data.onPrimary,
										style: ElevatedButton.styleFrom(
											backgroundColor: dark,
											foregroundColor: Colors.white,
											minimumSize: const Size(48, 48),
											padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
											shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
											elevation: 2,
										),
										child: const Text('Get the Playbook'),
									),
								),
								OutlinedButton(
									onPressed: widget.data.onSecondary,
									style: OutlinedButton.styleFrom(
										minimumSize: const Size(48, 48),
										padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
										shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
									),
									child: const Text('See sample persona'),
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
												border: Border.all(color: Colors.black.withValues(alpha: .1)),
											),
											child: Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													Icon(c.icon, size: 16, color: gold),
													const SizedBox(width: 6),
													Text(c.label, style: const TextStyle(fontSize: 13)),
												],
											),
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
		required this.gold,
		required this.hovering,
		required this.controller,
		required this.onHoverChanged,
	});
	final Color gold;
	final bool hovering;
	final AnimationController? controller;
	final ValueChanged<bool> onHoverChanged;

	@override
	Widget build(BuildContext context) {
		final base = _MockupBody(gold: gold);
		final shadow = [
			BoxShadow(
	color: Colors.black.withValues(alpha: hovering ? .2 : .12),
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
	const _MockupBody({required this.gold});
	final Color gold;
	@override
	Widget build(BuildContext context) {
		// Laptop/tablet frame with rounded corners and inner placeholder screen
		return ClipRRect(
			borderRadius: BorderRadius.circular(18),
			child: Container(
				color: Colors.white,
				child: AspectRatio(
					aspectRatio: 16 / 10,
					child: Stack(
						fit: StackFit.expand,
						children: [
							// Background classroom-like subtle illustration via gradient
							Container(
								decoration: const BoxDecoration(
									gradient: LinearGradient(
										begin: Alignment.topLeft,
										end: Alignment.bottomRight,
										colors: [Color(0xFFEEF2FF), Color(0xFFFDF2F8)],
									),
								),
							),
							// "Screen" content placeholder
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
											child: _StudentPortalPlaceholder(gold: gold),
													), // end Container (inner screen)
												), // end ClipRRect
												), // end Padding
											), // end Align
											], // end children stack
										), // end Stack
									), // end AspectRatio
								), // end outer Container
							); // end ClipRRect
	}
}

class _StudentPortalPlaceholder extends StatelessWidget {
	const _StudentPortalPlaceholder({required this.gold});
	final Color gold;
	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.all(12.0),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Row(
						children: [
							Container(width: 80, height: 10, color: Colors.black.withValues(alpha: .75)),
							const Spacer(),
							Container(width: 60, height: 10, color: gold),
						],
					),
					const SizedBox(height: 12),
					Expanded(
						child: GridView.count(
							crossAxisCount: 3,
							crossAxisSpacing: 8,
							mainAxisSpacing: 8,
							physics: const NeverScrollableScrollPhysics(),
							children: List.generate(6, (i) {
								return Container(
									decoration: BoxDecoration(
										color: Colors.black.withValues(alpha: .04),
										borderRadius: BorderRadius.circular(10),
									),
									child: Center(
										child: Container(
											width: 40,
											height: 6,
											color: Colors.black.withValues(alpha: .3),
										),
									),
								);
							}),
						),
					),
				],
			),
		);
	}
}

class _IncludedFeaturesGrid extends StatelessWidget {
	const _IncludedFeaturesGrid({required this.items});
	final List<FeatureItem> items;
	@override
	Widget build(BuildContext context) {
		return LayoutBuilder(builder: (context, c) {
			final width = c.maxWidth;
			int cols = 1;
			if (width >= 1024) {
				cols = 4;
			} else if (width >= 700) {
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
		const dark = Color(0xFF0F172A);
		return FadeTransition(
			opacity: _in,
			child: SlideTransition(
				position: Tween<Offset>(begin: const Offset(0, .05), end: Offset.zero).animate(_in),
				child: Semantics(
					button: true,
					label: widget.item.title,
					child: FocusTraversalGroup(
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
												child: Icon(widget.item.icon, color: Colors.black.withValues(alpha: .6)),
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
			),
		);
	}
}

// Factory for sample data
EducationLandingContent sampleEducationContent({
	required VoidCallback onPrimary,
	required VoidCallback onSecondary,
}) {
	return EducationLandingContent(
		badge: '🎓 Education Growth Playbook',
		headline: 'Education Growth Playbook',
		subtext: 'Digital-first systems for schools, academies, and training institutes.',
		quickChips: const [
	ChipItem(Icons.groups_2_outlined, 'Persona packs'),
	ChipItem(Icons.web_asset_outlined, 'Website layouts'),
	ChipItem(Icons.rule_folder_outlined, 'SOPs'),
	ChipItem(Icons.stacked_line_chart, 'KPIs'),
		],
		features: const [
	FeatureItem(Icons.groups_2_outlined, 'Persona packs', 'Students, parents, institutions'),
	FeatureItem(Icons.web_asset_outlined, 'Website layouts', 'Courses, admissions, testimonials'),
	FeatureItem(Icons.rule_folder_outlined, 'SOPs for admissions', 'Admissions & follow-ups'),
	FeatureItem(Icons.stacked_line_chart, 'KPIs', 'Enrollments, retention, referrals'),
		],
		onPrimary: onPrimary,
		onSecondary: onSecondary,
	);
}