export '../business_setup/business_card_hero_section.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class BusinessCardHeroSection extends StatelessWidget {
	const BusinessCardHeroSection({super.key});

	static const _headline = Color(0xFF443F3F);
	static const _body = Color(0xFFF78CA2);
	static const _gold = Color(0xFFD4AF37);
	static const _subtle = Color(0xFF7D5B4C);
	static const _brandPrimary = Color(0xFF0B63FF); // tweak to your brand

	@override
	Widget build(BuildContext context) {
		final w = MediaQuery.of(context).size.width;
		final isDesktop = w >= 900;

		final left = _TextColumn(isDesktop: isDesktop);
		final right = _Mockups(isDesktop: isDesktop);

		final content = isDesktop
				? Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Expanded(child: left),
							const SizedBox(width: 28),
							Expanded(child: right),
						],
					)
				: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							right,
							const SizedBox(height: 24),
							left,
						],
					);

		return Stack(
			children: [
				// Background painter removed.
				Padding(
					padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: isDesktop ? 48 : 28),
					child: Center(
						child: ConstrainedBox(
							constraints: const BoxConstraints(maxWidth: 1200),
							child: content,
						),
					),
				),
			],
		);
	}
}

class _TextColumn extends StatelessWidget {
	const _TextColumn({required this.isDesktop});
	final bool isDesktop;

	@override
	Widget build(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						Container(
							width: 44,
							height: 44,
							decoration: BoxDecoration(
								color: BusinessCardHeroSection._gold.withValues(alpha: 0.12),
								shape: BoxShape.circle,
								border: Border.all(color: BusinessCardHeroSection._gold.withValues(alpha: 0.7)),
							),
							child: const Icon(FeatherIcons.creditCard, size: 20, color: BusinessCardHeroSection._headline),
						),
						const SizedBox(width: 10),
						Text(
							'First Impressions, Done Right',
							style: GoogleFonts.josefinSans(
								color: BusinessCardHeroSection._headline,
								fontSize: isDesktop ? 38 : 28,
								fontWeight: FontWeight.w800,
								letterSpacing: 0.2,
							),
						),
					],
				),
				const SizedBox(height: 10),
				Text(
					'Professional, print-ready cards aligned with your brand identity.',
					style: GoogleFonts.poppins(
						color: BusinessCardHeroSection._body,
						fontSize: isDesktop ? 16 : 14,
						height: 1.6,
						fontWeight: FontWeight.w500,
					),
				),
				const SizedBox(height: 18),
				const _Feature(icon: FeatherIcons.layout, text: '2 layout options'),
				const _Feature(icon: FeatherIcons.fileText, text: 'Print-ready files'),
				const _Feature(icon: FeatherIcons.link, text: 'QR to website/WhatsApp'),
				const _Feature(icon: FeatherIcons.layers, text: 'Paper & finish recommendations'),
				const SizedBox(height: 16),
				const Wrap(
					spacing: 10,
					runSpacing: 10,
					children: [
						_PrimaryCta(label: 'Order Cards'),
						_GhostCta(label: 'Download Sample'),
					],
				),
			],
		);
	}
}

class _Feature extends StatelessWidget {
	const _Feature({required this.icon, required this.text});
	final IconData icon;
	final String text;

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.symmetric(vertical: 6),
			child: Row(
				children: [
					Container(
						width: 36,
						height: 36,
						decoration: BoxDecoration(
							color: BusinessCardHeroSection._gold.withValues(alpha: 0.12),
							shape: BoxShape.circle,
							border: Border.all(color: BusinessCardHeroSection._gold),
						),
						child: Icon(icon, size: 18, color: BusinessCardHeroSection._headline),
					),
					const SizedBox(width: 10),
					Expanded(
						child: Text(
							text,
							style: GoogleFonts.poppins(
								fontSize: 14,
								color: BusinessCardHeroSection._subtle,
								height: 1.5,
							),
						),
					),
				],
			),
		);
	}
}

class _Mockups extends StatelessWidget {
	const _Mockups({required this.isDesktop});
	final bool isDesktop;

	@override
	Widget build(BuildContext context) {
		return SizedBox(
			height: 320,
			child: Stack(
				alignment: Alignment.center,
				children: [
					Positioned(
						left: isDesktop ? 40 : 24,
						top: 40,
						child: const _LayeredPaper(width: 210, height: 300, rotation: -0.06),
					),
					Positioned(
						right: isDesktop ? 30 : 16,
						top: 16,
						child: const _LayeredPaper(width: 300, height: 180, rotation: 0.05),
					),
					Positioned(
						left: isDesktop ? 50 : 28,
						top: 30,
						child: const _MockCard(width: 210, height: 300, showQr: false),
					),
					Positioned(
						right: isDesktop ? 40 : 24,
						top: 6,
						child: const _MockCard(width: 300, height: 180, showQr: true),
					),
				],
			),
		);
	}
}

class _MockCard extends StatelessWidget {
	const _MockCard({required this.width, required this.height, required this.showQr});
	final double width;
	final double height;
	final bool showQr;

	@override
	Widget build(BuildContext context) {
		return Container(
			width: width,
			height: height,
			padding: const EdgeInsets.all(14),
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(12),
				border: Border.all(color: const Color(0xFFE5E7EB)),
				boxShadow: const [
					BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 10)),
				],
				gradient: const LinearGradient(
					colors: [Color(0xFFFFFBF2), Color(0xFFF8FAFF)],
					begin: Alignment.topLeft,
					end: Alignment.bottomRight,
				),
			),
			child: Stack(
				children: [
					Align(
						alignment: Alignment.topLeft,
						child: Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								Container(
									width: 18,
									height: 18,
									decoration: BoxDecoration(
										color: BusinessCardHeroSection._gold,
										borderRadius: BorderRadius.circular(4),
									),
								),
								const SizedBox(width: 8),
								Text(
									'Your Brand',
									style: GoogleFonts.poppins(
										fontSize: 12,
										fontWeight: FontWeight.w600,
										color: BusinessCardHeroSection._headline,
									),
								),
							],
						),
					),
					if (showQr)
						Align(
							alignment: Alignment.bottomRight,
							child: Container(
								width: 42,
								height: 42,
								decoration: BoxDecoration(
									color: Colors.white,
									borderRadius: BorderRadius.circular(6),
									border: Border.all(color: const Color(0xFFE5E7EB)),
								),
								child: const Icon(Icons.qr_code_2, size: 28, color: Color(0xFF475569)),
							),
						),
				],
			),
		);
	}
}

class _LayeredPaper extends StatelessWidget {
	const _LayeredPaper({required this.width, required this.height, required this.rotation});
	final double width;
	final double height;
	final double rotation;

	@override
	Widget build(BuildContext context) {
		return Transform.rotate(
			angle: rotation,
			child: Container(
				width: width,
				height: height,
				decoration: BoxDecoration(
					color: const Color(0xFFF8FAFC),
					borderRadius: BorderRadius.circular(12),
					boxShadow: const [
						BoxShadow(color: Color(0x22000000), blurRadius: 14, offset: Offset(0, 8)),
					],
				),
			),
		);
	}
}

class _PrimaryCta extends StatefulWidget {
	const _PrimaryCta({required this.label});
	final String label;

	@override
	State<_PrimaryCta> createState() => _PrimaryCtaState();
}

class _PrimaryCtaState extends State<_PrimaryCta> {
	bool _hover = false;
	@override
	Widget build(BuildContext context) {
		final bg = _hover ? const Color(0xFF094FCC) : BusinessCardHeroSection._brandPrimary;
		return MouseRegion(
			onEnter: (_) => setState(() => _hover = true),
			onExit: (_) => setState(() => _hover = false),
			child: GestureDetector(
				onTap: () {},
				child: AnimatedContainer(
					duration: const Duration(milliseconds: 150),
					padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
					decoration: BoxDecoration(
						color: bg,
						borderRadius: BorderRadius.circular(10),
						boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 6))],
					),
					child: Text(
						widget.label,
						style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
					),
				),
			),
		);
	}
}

class _GhostCta extends StatefulWidget {
	const _GhostCta({required this.label});
	final String label;

	@override
	State<_GhostCta> createState() => _GhostCtaState();
}

class _GhostCtaState extends State<_GhostCta> {
	bool _hover = false;
	@override
	Widget build(BuildContext context) {
		final border = _hover ? BusinessCardHeroSection._gold : const Color(0xFFE5E7EB);
		return MouseRegion(
			onEnter: (_) => setState(() => _hover = true),
			onExit: (_) => setState(() => _hover = false),
			child: GestureDetector(
				onTap: () {},
				child: AnimatedContainer(
					duration: const Duration(milliseconds: 150),
					padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
					decoration: BoxDecoration(
						color: Colors.white,
						borderRadius: BorderRadius.circular(10),
						border: Border.all(color: border),
					),
					child: Text(
						widget.label,
						style: GoogleFonts.poppins(color: const Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 14),
					),
				),
			),
		);
	}
}

// Previous background painter removed (kept note after move)