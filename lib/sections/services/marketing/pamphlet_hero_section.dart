import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class PamphletHeroSection extends StatelessWidget {
	const PamphletHeroSection({super.key});

	static const _headline = Color(0xFFFFFFFF);
	static const _body = Color(0xFFFFFFFF);
	static const _gold = Color(0xFFD4AF37);
	static const _brandPrimary = Color(0xFF0B63FF);

	@override
	Widget build(BuildContext context) {
		final w = MediaQuery.of(context).size.width;
		final isDesktop = w >= 900;

		final left = _LeftText(isDesktop: isDesktop);
		final right = const _FlyerMockups();

		final content = isDesktop
				? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 28), Expanded(child: right)])
				: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [right, const SizedBox(height: 20), left]);

		return Stack(children: [
			Padding(
				padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: isDesktop ? 48 : 28),
				child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200), child: content)),
			),
		]);
	}
}

class _LeftText extends StatelessWidget {
	const _LeftText({required this.isDesktop});
	final bool isDesktop;
	@override
	Widget build(BuildContext context) {
		return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
			Row(mainAxisSize: MainAxisSize.min, children: [
				Container(
					width: 44,
					height: 44,
					decoration: BoxDecoration(color: PamphletHeroSection._gold.withValues(alpha: 0.18), shape: BoxShape.circle, border: Border.all(color: PamphletHeroSection._gold.withValues(alpha: 0.85))),
					child: const Icon(FeatherIcons.file, size: 20, color: Colors.white),
				),
				const SizedBox(width: 10),
				Flexible(
					child: Text('Local Reach That Converts',
						style: GoogleFonts.josefinSans(color: PamphletHeroSection._headline, fontSize: isDesktop ? 40 : 28, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
				),
			]),
			const SizedBox(height: 10),
			Text('Distribute eye-catching pamphlets with offers and CTAs to capture attention fast.',
				style: GoogleFonts.poppins(color: PamphletHeroSection._body.withValues(alpha: 0.92), fontSize: isDesktop ? 16 : 14, height: 1.6, fontWeight: FontWeight.w500)),
			const SizedBox(height: 16),
			_Feature(icon: FeatherIcons.check, text: 'Offer framing, headlines, QR + CTA'),
			_Feature(icon: FeatherIcons.arrowRightCircle, text: 'Print sizes & distribution plan'),
			const SizedBox(height: 16),
			_PrimaryCta(label: 'Order Pamphlets', onTap: () {}),
		]);
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
			child: Row(children: [
				Container(
					width: 34,
					height: 34,
					decoration: BoxDecoration(color: PamphletHeroSection._gold.withValues(alpha: 0.12), shape: BoxShape.circle, border: Border.all(color: PamphletHeroSection._gold)),
					child: Icon(icon, size: 16, color: Colors.white),
				),
				const SizedBox(width: 10),
				Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize: 14, height: 1.45, color: Colors.white.withValues(alpha: 0.95)))),
			]),
		);
	}
}

class _PrimaryCta extends StatefulWidget {
	const _PrimaryCta({required this.label, required this.onTap});
	final String label;
	final VoidCallback onTap;
	@override
	State<_PrimaryCta> createState() => _PrimaryCtaState();
}

class _PrimaryCtaState extends State<_PrimaryCta> {
	bool _hover = false;
	@override
	Widget build(BuildContext context) {
		final bg = _hover ? const Color(0xFF094FCC) : PamphletHeroSection._brandPrimary;
		return MouseRegion(
			onEnter: (_) => setState(() => _hover = true),
			onExit: (_) => setState(() => _hover = false),
			child: GestureDetector(
				onTap: widget.onTap,
				child: AnimatedContainer(
					duration: const Duration(milliseconds: 150),
					padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
					decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 6))]),
					child: Text(widget.label, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
				),
			),
		);
	}
}

class _FlyerMockups extends StatelessWidget {
	const _FlyerMockups();
	@override
	Widget build(BuildContext context) {
		return SizedBox(
			height: 340,
			child: Stack(clipBehavior: Clip.none, children: const [
				Positioned(left: 0, top: 70, child: _OpenPamphlet()),
				Positioned(right: 10, top: 10, child: _FoldedPamphlet()),
				Positioned(left: 40, bottom: 0, child: _StackedFlyers()),
			]),
		);
	}
}

class _OpenPamphlet extends StatelessWidget {
	const _OpenPamphlet();
	@override
	Widget build(BuildContext context) {
		final base = Container(
			width: 340,
			height: 200,
			decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB)), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 12))], gradient: const LinearGradient(colors: [Color(0xFFFDFDFC), Color(0xFFF8FAFF)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
		);
		return Stack(children: [
			Transform.rotate(angle: -0.02, child: base),
			Positioned(left: 170, top: 10, bottom: 10, child: Container(width: 1, color: const Color(0xFFE2E8F0))),
			const Positioned(left: 20, top: 20, child: _TitleLine(width: 120)),
			const Positioned(right: 20, top: 20, child: _TitleLine(width: 120)),
		]);
	}
}

class _FoldedPamphlet extends StatelessWidget {
	const _FoldedPamphlet();
	@override
	Widget build(BuildContext context) {
		final base = Container(
			width: 140,
			height: 220,
			decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB)), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 12))], gradient: const LinearGradient(colors: [Color(0xFFFFFBF2), Color(0xFFF8FAFF)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
		);
		return Stack(children: [
			Transform.rotate(angle: 0.05, child: base),
			const Positioned(left: 16, top: 18, child: _ColorSwatch()),
			const Positioned(left: 44, top: 20, child: _TitleLine(width: 70)),
		]);
	}
}

class _StackedFlyers extends StatelessWidget {
	const _StackedFlyers();
	@override
	Widget build(BuildContext context) {
		Widget tile(double offset, Color stroke) => Transform.translate(
			offset: Offset(offset, -offset),
			child: Container(width: 220, height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: stroke), boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 14, offset: Offset(0, 8))])),
		);
		return Stack(children: [
			tile(12, const Color(0xFFE5E7EB)),
			tile(6, const Color(0xFFE2E8F0)),
			tile(0, PamphletHeroSection._gold.withValues(alpha: 0.6)),
		]);
	}
}

class _TitleLine extends StatelessWidget {
	const _TitleLine({required this.width});
	final double width;
	@override
	Widget build(BuildContext context) => Container(width: width, height: 10, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)));
}

class _ColorSwatch extends StatelessWidget {
	const _ColorSwatch();
	@override
	Widget build(BuildContext context) => Container(width: 20, height: 20, decoration: BoxDecoration(color: PamphletHeroSection._gold, borderRadius: BorderRadius.circular(4)));
}
