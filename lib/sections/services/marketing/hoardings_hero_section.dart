import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HoardingsHeroSection extends StatelessWidget {
	const HoardingsHeroSection({super.key});

	static const _headline = Colors.white;
	static const _body = Colors.white;
	static const _cta = Color(0xFFFF5722); // accent for button

	@override
	Widget build(BuildContext context) {
		final w = MediaQuery.of(context).size.width;
		final isDesktop = w >= 900;

		final left = _LeftText(isDesktop: isDesktop);
		final right = const _BillboardMockups();

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
						children: [right, const SizedBox(height: 20), left],
					);

		return Stack(
			children: [
				Padding(
					padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: isDesktop ? 54 : 30),
					child: Center(
						child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200), child: content),
					),
				),
			],
		);
	}
}

class _LeftText extends StatelessWidget {
	const _LeftText({required this.isDesktop});
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
								color: Colors.white.withValues(alpha: 0.18),
								shape: BoxShape.circle,
								border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
							),
							alignment: Alignment.center,
							child: Text('🏙', style: TextStyle(fontSize: 20, color: Colors.white.withValues(alpha: 0.95))),
						),
						const SizedBox(width: 10),
						Flexible(
							child: Text('Big Message, Big Impact',
								style: GoogleFonts.openSans(color: HoardingsHeroSection._headline, fontSize: isDesktop ? 40 : 28, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
						),
					],
				),
				const SizedBox(height: 10),
				Text(
					'High-visibility outdoor ads designed for maximum readability.',
					style: GoogleFonts.openSans(color: HoardingsHeroSection._body.withValues(alpha: 0.92), fontSize: isDesktop ? 16 : 14, height: 1.6, fontWeight: FontWeight.w500),
				),
				const SizedBox(height: 16),
				const _Feature(text: 'Site mockups'),
				const _Feature(text: 'Legibility checks'),
				const _Feature(text: 'Permit & print coordination guidance'),
				const SizedBox(height: 16),
				const _PrimaryCta(label: 'Book a Hoarding'),
				const SizedBox(height: 12),
				const _BottomIconsRow(items: [
					(Icons.landscape, 'Site mock'),
					(Icons.visibility, 'Legible'),
					(Icons.document_scanner, 'Print'),
				]),
			],
		);
	}
}

class _Feature extends StatelessWidget {
	const _Feature({required this.text});
	final String text;
	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.symmetric(vertical: 6),
			child: Row(children: [
				Container(
					width: 34,
					height: 34,
					decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.85))),
					alignment: Alignment.center,
					child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
				),
				const SizedBox(width: 10),
				Expanded(child: Text(text, style: GoogleFonts.openSans(fontSize: 14, height: 1.45, color: Colors.white.withValues(alpha: 0.95)))),
			]),
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
		final bg = _hover ? const Color(0xFFE64A19) : HoardingsHeroSection._cta;
		return MouseRegion(
			onEnter: (_) => setState(() => _hover = true),
			onExit: (_) => setState(() => _hover = false),
			child: GestureDetector(
				onTap: () {},
					child: AnimatedContainer(
					duration: const Duration(milliseconds: 150),
					padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
					decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 6))]),
						child: Text(widget.label, style: GoogleFonts.openSans(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
				),
			),
		);
	}
}

class _BillboardMockups extends StatelessWidget {
	const _BillboardMockups();
	@override
	Widget build(BuildContext context) {
		return SizedBox(
			height: 360,
			child: Stack(clipBehavior: Clip.none, children: const [
				Positioned(left: 0, top: 40, child: _SideBillboardSmall(angle: -0.05)),
				Positioned(right: 10, top: 10, child: _SideBillboardSmall(angle: 0.06)),
				Positioned(left: 70, bottom: 0, child: _MainBillboard()),
			]),
		);
	}
}

class _MainBillboard extends StatelessWidget {
	const _MainBillboard();
	@override
	Widget build(BuildContext context) {
		final board = Container(
			width: 340,
			height: 200,
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(12),
				boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 24, offset: Offset(0, 14))],
				border: Border.all(color: const Color(0xFFE5E7EB)),
				gradient: const LinearGradient(colors: [Color(0xFFFDFDFC), Color(0xFFF7FAFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
			),
			child: Stack(children: const [
				Positioned(left: 20, top: 18, child: _Line(width: 140)),
				Positioned(left: 20, top: 44, child: _Line(width: 200, light: true)),
			]),
		);

		return Stack(clipBehavior: Clip.none, children: [
			Positioned(left: 40, top: 140, child: Container(width: 10, height: 120, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)))),
			Positioned(right: 40, top: 140, child: Container(width: 10, height: 120, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)))),
			Transform.rotate(angle: -0.01, child: board),
		]);
	}
}

class _SideBillboardSmall extends StatelessWidget {
	const _SideBillboardSmall({required this.angle});
	final double angle;
	@override
	Widget build(BuildContext context) {
		final board = Container(
			width: 160,
			height: 110,
			decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 10))], border: Border.all(color: const Color(0xFFE5E7EB))),
			child: Stack(children: const [
				Positioned(left: 12, top: 10, child: _Line(width: 90)),
				Positioned(left: 12, top: 30, child: _Line(width: 120, light: true)),
			]),
		);
		return Transform.rotate(angle: angle, child: board);
	}
}

class _Line extends StatelessWidget {
	const _Line({required this.width, this.light = false});
	final double width;
	final bool light;
	@override
	Widget build(BuildContext context) {
		return Container(width: width, height: 10, decoration: BoxDecoration(color: light ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)));
	}
}

class _BottomIconsRow extends StatelessWidget {
	const _BottomIconsRow({required this.items});
	final List<(IconData, String)> items;
	@override
	Widget build(BuildContext context) {
		return Wrap(spacing: 12, runSpacing: 8, children: [for (final it in items) _IconPill(icon: it.$1, label: it.$2)]);
	}
}

class _IconPill extends StatelessWidget {
	const _IconPill({required this.icon, required this.label});
	final IconData icon;
	final String label;
	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
			decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)),
			child: Row(mainAxisSize: MainAxisSize.min, children: [
				const Icon(Icons.check_circle, size: 16, color: Colors.white70),
				const SizedBox(width: 6),
						Text(label, style: GoogleFonts.openSans(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
			]),
		);
	}
}
