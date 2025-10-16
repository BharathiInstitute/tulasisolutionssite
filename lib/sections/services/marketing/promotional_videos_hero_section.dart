import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PromotionalVideosHeroSection extends StatelessWidget {
	const PromotionalVideosHeroSection({super.key});

	static const _headline = Colors.white;
	static const _body = Colors.white;
	static const _cta = Color(0xFF0B63FF); // accent for button

	@override
	Widget build(BuildContext context) {
		final w = MediaQuery.of(context).size.width;
		final isDesktop = w >= 900;

		final left = _LeftText(isDesktop: isDesktop);
		final right = const _DeviceMockups();

		final content = isDesktop
				? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 28), Expanded(child: right)])
				: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [right, const SizedBox(height: 20), left]);

		return Stack(children: [
			Padding(
				padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: isDesktop ? 54 : 30),
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
					decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.85))),
					alignment: Alignment.center,
					child: Text('📹', style: TextStyle(fontSize: 20, color: Colors.white.withValues(alpha: 0.95))),
				),
				const SizedBox(width: 10),
				Flexible(
					child: Text('Showcase Your Brand in Motion',
						style: GoogleFonts.openSans(color: PromotionalVideosHeroSection._headline, fontSize: isDesktop ? 40 : 28, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
				),
			]),
			const SizedBox(height: 10),
			Text('From concept to final cut, 30–90s videos that tell your story.',
				style: GoogleFonts.openSans(color: PromotionalVideosHeroSection._body.withValues(alpha: 0.95), fontSize: isDesktop ? 16 : 14, height: 1.6, fontWeight: FontWeight.w500)),
			const SizedBox(height: 16),
			const _Feature(text: 'Concept, storyboard, VO/music'),
			const _Feature(text: 'Shoot/edit or stock edit'),
			const _Feature(text: 'Multiple aspect ratios (YT, Insta, FB)'),
			const SizedBox(height: 16),
			const _PrimaryCta(label: 'Create Video Ad'),
			const SizedBox(height: 12),
			const _BottomIconsRow(items: [
				(Icons.movie_filter, 'Story'),
				(Icons.mic, 'VO/Music'),
				(Icons.cut, 'Edit'),
				(Icons.aspect_ratio, 'Ratios'),
			]),
		]);
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
				Expanded(child: Text(text, style: GoogleFonts.openSans(fontSize: 14, height: 1.45, color: Colors.white.withValues(alpha: 0.98)))),
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
		final bg = _hover ? const Color(0xFF094FCC) : PromotionalVideosHeroSection._cta;
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

class _DeviceMockups extends StatelessWidget {
	const _DeviceMockups();
	@override
	Widget build(BuildContext context) {
		return SizedBox(
			height: 430,
			child: Stack(clipBehavior: Clip.none, children: const [
				Positioned(left: 0, bottom: 20, child: _LaptopMock(angle: -0.01)),
				Positioned(right: 30, top: 10, child: _PhoneMock(angle: 0.04)),
			]),
		);
	}
}

class _PhoneMock extends StatelessWidget {
	const _PhoneMock({required this.angle});
	final double angle;
	@override
	Widget build(BuildContext context) {
		final frame = _PVPhoneFrame(width: 190, height: 380 * 0.85, child: const _VideoScreen(vertical: true));
		return Transform.rotate(angle: angle, child: frame);
	}
}

class _LaptopMock extends StatelessWidget {
	const _LaptopMock({required this.angle});
	final double angle;
	@override
	Widget build(BuildContext context) {
		final laptop = _PVLaptopFrame(width: 360, height: 220, child: const _VideoScreen(vertical: false));
		return Transform.rotate(angle: angle, child: laptop);
	}
}

class _PVPhoneFrame extends StatelessWidget {
	const _PVPhoneFrame({required this.width, required this.height, required this.child});
	final double width;
	final double height;
	final Widget child;
	@override
	Widget build(BuildContext context) {
		return Container(
			width: width,
			height: height,
			decoration: BoxDecoration(color: const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 22, offset: Offset(0, 14))], border: Border.all(color: const Color(0xFF1F2937), width: 2)),
			child: ClipRRect(
				borderRadius: BorderRadius.circular(24),
				child: Stack(children: [
					Positioned.fill(child: Container(color: const Color(0xFF101114), child: child)),
					Positioned(top: 6, left: (width / 2) - 28, child: Container(width: 56, height: 6, decoration: BoxDecoration(color: const Color(0x33111111), borderRadius: BorderRadius.circular(3)))),
				]),
			),
		);
	}
}

class _PVLaptopFrame extends StatelessWidget {
	const _PVLaptopFrame({required this.width, required this.height, required this.child});
	final double width;
	final double height;
	final Widget child;
	@override
	Widget build(BuildContext context) {
		return Column(mainAxisSize: MainAxisSize.min, children: [
			Container(
				width: width,
				height: height,
				decoration: BoxDecoration(color: const Color(0xFF0E1116), borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 16))], border: Border.all(color: const Color(0xFF1F2937), width: 2)),
				child: ClipRRect(
					borderRadius: BorderRadius.circular(10),
					child: Stack(children: [
						Positioned.fill(child: Container(color: const Color(0xFF0C0D11), child: child)),
						Positioned(top: 6, right: 8, child: _WindowDots()),
					]),
				),
			),
			Container(width: width * 0.9, height: 10, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(color: const Color(0xFF141821), borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))])),
		]);
	}
}

class _WindowDots extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		Widget dot(Color c) => Container(width: 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(color: c, shape: BoxShape.circle));
		return Row(children: [dot(const Color(0xFFFF5F56)), dot(const Color(0xFFFFBD2E)), dot(const Color(0xFF27C93F))]);
	}
}

class _VideoScreen extends StatelessWidget {
	const _VideoScreen({required this.vertical});
	final bool vertical;
	@override
	Widget build(BuildContext context) {
		final aspect = vertical ? const Size(9, 16) : const Size(16, 9);
		return FittedBox(
			fit: BoxFit.cover,
			child: Container(
				width: aspect.width * 20,
				height: aspect.height * 20,
				decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0B63FF), Color(0xFFFF0069)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
				child: Stack(children: [
					Positioned.fill(child: Container(color: Colors.white.withValues(alpha: 0.06))),
					Center(
						child: Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4))]), child: const Icon(Icons.play_arrow_rounded, size: 34, color: Color(0xFF0A0A0A))),
					),
					Positioned(
						left: 16,
						bottom: 16,
						right: 16,
						child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
							Container(width: 160, height: 10, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(4))),
							const SizedBox(height: 6),
							Container(width: 220, height: 8, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4))),
						]),
					),
				]),
			),
		);
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
				Icon(icon, size: 16, color: Colors.white70),
				const SizedBox(width: 6),
				Text(label, style: GoogleFonts.openSans(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
			]),
		);
	}
}
