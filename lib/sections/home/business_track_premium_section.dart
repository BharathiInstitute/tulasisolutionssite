import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class BusinessTrackPremiumSection extends StatelessWidget {
	const BusinessTrackPremiumSection({super.key});

	static const _gold = Color(0xFFD4AF37);
	static const _headline = Color(0xFF443F3F);
	static const _body = Color(0xFFF78CA2);
	static const _sublabel = Color(0xFF7D5B4C);

	@override
	Widget build(BuildContext context) {
		final width = MediaQuery.of(context).size.width;
		final isMobile = width < 700;

		return Container(
			width: double.infinity,
			decoration: const BoxDecoration(
				// Step/path abstract background using layered gradients
				gradient: LinearGradient(
					colors: [Color(0xFFFFFFFF), Color(0xFFF3F4F6)],
					begin: Alignment.topCenter,
					end: Alignment.bottomCenter,
				),
			),
			child: CustomPaint(
				painter: _StepPathPainter(),
				child: Padding(
					padding: EdgeInsets.symmetric(
						horizontal: isMobile ? 16 : 32,
						vertical: isMobile ? 28 : 48,
					),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.center,
						children: [
							// Headline
							Text(
								'Choose Your Business Track',
								textAlign: TextAlign.center,
								style: GoogleFonts.openSans(
									fontSize: isMobile ? 28 : 40,
									fontWeight: FontWeight.w700,
									color: _headline,
									letterSpacing: 0.2,
								),
							),
							const SizedBox(height: 10),
							// Supporting text
							ConstrainedBox(
								constraints: const BoxConstraints(maxWidth: 920),
								child: Text(
									'We map your business to a proven industry playbook with ready workflows, assets, and KPIs.',
									textAlign: TextAlign.center,
									style: GoogleFonts.openSans(
										fontSize: isMobile ? 14 : 16,
										color: _body,
										height: 1.6,
										fontWeight: FontWeight.w500,
									),
								),
							),
							const SizedBox(height: 28),

							// Features card grid
							_FeaturesCard(isMobile: isMobile),

							const SizedBox(height: 24),

							// Track selection grid
							_TrackGrid(isMobile: isMobile),

							const SizedBox(height: 28),

							// CTA button
							_CtaButton(),
						],
					),
				),
			),
		);
	}
}

class _FeaturesCard extends StatelessWidget {
	const _FeaturesCard({required this.isMobile});
	final bool isMobile;

	@override
	Widget build(BuildContext context) {
		final features = const [
			(
				FeatherIcons.checkCircle,
				'Track selection (Retail, Education, Cosmetics, Printing, Services, Startup)'
			),
			(FeatherIcons.package, 'Starter kit: personas, value ladder, channel mix'),
			(FeatherIcons.clipboard, 'Compliance & must-have assets checklist'),
			(FeatherIcons.trendingUp, '90-day ramp plan'),
		];

		return Container(
			width: double.infinity,
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(16),
				boxShadow: const [
					BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, 10)),
				],
				border: Border.all(color: const Color(0xFFF1F5F9)),
			),
			padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 20),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(
						'What\'s Included',
						style: GoogleFonts.openSans(
							fontSize: isMobile ? 18 : 22,
							fontWeight: FontWeight.w700,
							color: BusinessTrackPremiumSection._sublabel,
						),
					),
					const SizedBox(height: 12),
					for (final f in features) ...[
						_FeatureRow(icon: f.$1, text: f.$2),
						const SizedBox(height: 10),
					],
				],
			),
		);
	}
}

class _FeatureRow extends StatelessWidget {
	const _FeatureRow({required this.icon, required this.text});
	final IconData icon;
	final String text;

	@override
	Widget build(BuildContext context) {
		return Row(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Container(
					width: 32,
					height: 32,
					decoration: BoxDecoration(
						shape: BoxShape.circle,
						color: const Color(0xFFFFF7E5),
						border: Border.all(color: BusinessTrackPremiumSection._gold, width: 1),
					),
					child: Icon(icon, size: 16, color: BusinessTrackPremiumSection._gold),
				),
				const SizedBox(width: 12),
				Expanded(
					child: Text(
						text,
							style: GoogleFonts.openSans(
							fontSize: 14,
							color: BusinessTrackPremiumSection._sublabel,
							height: 1.6,
						),
					),
				),
			],
		);
	}
}

class _TrackGrid extends StatelessWidget {
	const _TrackGrid({required this.isMobile});
	final bool isMobile;

	@override
	Widget build(BuildContext context) {
		final items = const [
			('📍', 'Retail'),
			('🎓', 'Education'),
			('💄', 'Cosmetics'),
			('🖨', 'Printing'),
			('⚙', 'Services'),
			('🚀', 'Startup'),
		];

		final crossAxisCount = isMobile ? 1 : 3;
		final spacing = isMobile ? 12.0 : 14.0;
		return LayoutBuilder(
			builder: (context, constraints) {
				return GridView.builder(
					padding: EdgeInsets.zero,
					shrinkWrap: true,
					physics: const NeverScrollableScrollPhysics(),
					itemCount: items.length,
					gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
						crossAxisCount: crossAxisCount,
						mainAxisSpacing: spacing,
						crossAxisSpacing: spacing,
						childAspectRatio: isMobile ? 4.2 : 3.4,
					),
					itemBuilder: (context, i) {
						final data = items[i];
						return _HoverCard(
							emoji: data.$1,
							label: data.$2,
						);
					},
				);
			},
		);
	}
}

class _HoverCard extends StatefulWidget {
	const _HoverCard({required this.emoji, required this.label});
	final String emoji;
	final String label;

	@override
	State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
	bool _hover = false;

	@override
	Widget build(BuildContext context) {
		return MouseRegion(
			onEnter: (_) => setState(() => _hover = true),
			onExit: (_) => setState(() => _hover = false),
			child: AnimatedContainer(
				duration: const Duration(milliseconds: 160),
				curve: Curves.easeOut,
				transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
				decoration: BoxDecoration(
					color: Colors.white,
					borderRadius: BorderRadius.circular(14),
					border: Border.all(
						color: _hover ? BusinessTrackPremiumSection._gold : const Color(0xFFE5E7EB),
						width: _hover ? 2 : 1,
					),
					boxShadow: [
						if (_hover)
							const BoxShadow(
								color: Color(0x22000000),
								blurRadius: 18,
								offset: Offset(0, 10),
							),
					],
				),
				padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
				child: Row(
					children: [
						Text(widget.emoji, style: const TextStyle(fontSize: 20)),
						const SizedBox(width: 10),
						Expanded(
							child: Text(
								widget.label,
								style: GoogleFonts.openSans(
									fontSize: 15,
									fontWeight: FontWeight.w600,
									color: BusinessTrackPremiumSection._headline,
								),
							),
						),
						const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
					],
				),
			),
		);
	}
}

class _CtaButton extends StatefulWidget {
	@override
	State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton> {
	bool _hover = false;
	@override
	Widget build(BuildContext context) {
		return MouseRegion(
			onEnter: (_) => setState(() => _hover = true),
			onExit: (_) => setState(() => _hover = false),
			child: AnimatedContainer(
				duration: const Duration(milliseconds: 160),
				curve: Curves.easeOut,
				decoration: BoxDecoration(
					color: _hover ? const Color(0xFFB8932F) : BusinessTrackPremiumSection._gold,
					borderRadius: BorderRadius.circular(28),
					boxShadow: const [
						BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 8)),
					],
				),
				padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
					child: Text(
					'Get My Track Plan',
						style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
				),
			),
		);
	}
}

class _StepPathPainter extends CustomPainter {
	@override
	void paint(Canvas canvas, Size size) {
		final paint = Paint()
			..style = PaintingStyle.stroke
			..strokeWidth = 2
			..color = const Color(0xFFE5E7EB);

		// Draw subtle step/branching paths
		final path = Path();
		final stepH = size.height / 6;
		final left = 40.0;
		final right = size.width - 40.0;

		for (int i = 1; i <= 4; i++) {
			final y = stepH * i + 20;
			path.moveTo(left, y);
			path.lineTo(size.width * 0.35, y);
			path.cubicTo(size.width * 0.45, y, size.width * 0.55, y + 30, size.width * 0.65, y + 30);
			path.lineTo(right, y + 30);
		}

		canvas.drawPath(path, paint);

		// Add soft nodes
		final nodePaint = Paint()
			..style = PaintingStyle.fill
			..color = const Color(0xFFF3F4F6);
		for (int i = 1; i <= 4; i++) {
			final y = stepH * i + 20;
			canvas.drawCircle(Offset(size.width * 0.35, y), 4, nodePaint);
			canvas.drawCircle(Offset(size.width * 0.65, y + 30), 4, nodePaint);
		}
	}

	@override
	bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}