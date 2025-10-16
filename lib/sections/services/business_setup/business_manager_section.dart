import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class BusinessManagerSection extends StatelessWidget {
	const BusinessManagerSection({super.key});

	static const _gold = Color(0xFFD4AF37);
	static const _headline = Color(0xFF443F3F);
	static const _body = Color(0xFFF78CA2);
	static const _sublabel = Color(0xFF7D5B4C);

	@override
	Widget build(BuildContext context) {
		final width = MediaQuery.of(context).size.width;
		final isMobile = width < 800;

		return Container(
			width: double.infinity,
			decoration: const BoxDecoration(
				gradient: LinearGradient(
					colors: [Color(0xFFFFFFFF), Color(0xFFF7FAFC)],
					begin: Alignment.topCenter,
					end: Alignment.bottomCenter,
				),
			),
			child: CustomPaint(
				painter: _WorkspacePainter(),
				child: Padding(
					padding: EdgeInsets.symmetric(
						horizontal: isMobile ? 16 : 32,
						vertical: isMobile ? 28 : 48,
					),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.center,
						children: [
							// Headline with manager icon
							Row(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									Container(
										width: 42,
										height: 42,
										decoration: BoxDecoration(
											shape: BoxShape.circle,
											color: _gold.withValues(alpha: 0.12),
											border: Border.all(color: _gold.withValues(alpha: 0.5)),
										),
										child: const Icon(FeatherIcons.user, color: _headline, size: 20),
									),
									const SizedBox(width: 12),
									Flexible(
										child: Text(
											'Your Dedicated Manager',
											textAlign: TextAlign.center,
											style: GoogleFonts.openSans(
												fontSize: isMobile ? 28 : 40,
												fontWeight: FontWeight.w700,
												color: _headline,
												letterSpacing: 0.2,
											),
										),
									),
								],
							),
							const SizedBox(height: 10),
							ConstrainedBox(
								constraints: const BoxConstraints(maxWidth: 920),
								child: Text(
									'One point of contact to coordinate branding, dev, ads, and growth.',
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

							// Card with what's included
							_IncludedCard(isMobile: isMobile),

							const SizedBox(height: 28),

							// CTA
							_CtaButton(),
						],
					),
				),
			),
		);
	}
}

class _IncludedCard extends StatelessWidget {
	const _IncludedCard({required this.isMobile});
	final bool isMobile;

	@override
	Widget build(BuildContext context) {
		final items = const [
			(FeatherIcons.calendar, 'Weekly stand-ups & notes'),
			(FeatherIcons.clipboard, 'Task board + SLA monitoring'),
			(FeatherIcons.users, 'Cross-team coordination (design, dev, ads)'),
			(FeatherIcons.alertCircle, 'Escalation path & quality checks'),
		];

		final cross = isMobile ? 1 : 2;
		final spacing = isMobile ? 10.0 : 14.0;

		return Container(
			width: double.infinity,
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(16),
	border: Border.all(color: BusinessManagerSection._gold.withValues(alpha: 0.35), width: 1),
				boxShadow: const [
					BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 10)),
				],
			),
			padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 22, vertical: isMobile ? 16 : 20),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(
						'What\'s Included',
								style: GoogleFonts.openSans(
							fontSize: isMobile ? 18 : 22,
							fontWeight: FontWeight.w700,
							color: BusinessManagerSection._sublabel,
						),
					),
					const SizedBox(height: 12),
					GridView.builder(
						shrinkWrap: true,
						physics: const NeverScrollableScrollPhysics(),
						itemCount: items.length,
						gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
							crossAxisCount: cross,
							mainAxisSpacing: spacing,
							crossAxisSpacing: spacing,
							childAspectRatio: isMobile ? 4.0 : 4.2,
						),
						itemBuilder: (context, i) {
							final it = items[i];
							return _FeatureTile(icon: it.$1, text: it.$2);
						},
					),
				],
			),
		);
	}
}

class _FeatureTile extends StatelessWidget {
	const _FeatureTile({required this.icon, required this.text});
	final IconData icon;
	final String text;

	@override
	Widget build(BuildContext context) {
		return Row(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Container(
					width: 36,
					height: 36,
					decoration: BoxDecoration(
						shape: BoxShape.circle,
						color: BusinessManagerSection._gold.withValues(alpha: 0.12),
						border: Border.all(color: BusinessManagerSection._gold, width: 1),
					),
					child: Icon(icon, color: BusinessManagerSection._headline, size: 18),
				),
				const SizedBox(width: 12),
				Expanded(
					child: Text(
						text,
									style: GoogleFonts.openSans(
							fontSize: 14,
							color: BusinessManagerSection._sublabel,
							height: 1.6,
						),
					),
				),
			],
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
					color: _hover ? const Color(0xFFB8932F) : BusinessManagerSection._gold,
					borderRadius: BorderRadius.circular(28),
					boxShadow: const [
						BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 8)),
					],
				),
				padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
					child: Text(
					'Talk to Your Manager',
						style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
				),
			),
		);
	}
}

class _WorkspacePainter extends CustomPainter {
	@override
	void paint(Canvas canvas, Size size) {
		// Subtle grid panels to evoke a workspace/dashboard
		final bg = Paint()..color = const Color(0xFFFFFFFF);
		canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

		final panelPaint = Paint()..color = const Color(0xFFF1F5F9);
		final stroke = Paint()
			..style = PaintingStyle.stroke
			..strokeWidth = 1
			..color = const Color(0xFFE5E7EB);

		// Draw several light panels
		const double pad = 24;
		final panelWidth = (size.width - pad * 3) / 2;
		final panelHeight = 80.0;
		for (int r = 0; r < 3; r++) {
			for (int c = 0; c < 2; c++) {
				final left = pad + c * (panelWidth + pad);
				final top = pad + r * (panelHeight + 16);
				final rect = RRect.fromRectAndRadius(
					Rect.fromLTWH(left, top, panelWidth, panelHeight),
					const Radius.circular(10),
				);
				canvas.drawRRect(rect, panelPaint);
				canvas.drawRRect(rect, stroke);
			}
		}
	}

	@override
	bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}