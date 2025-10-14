import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReelsHeroSection extends StatelessWidget {
	const ReelsHeroSection({super.key});

	static const _headline = Colors.white;
	static const _body = Colors.white;
	static const _cta = Color(0xFFFF0069); // accent for button

	@override
	Widget build(BuildContext context) {
		final w = MediaQuery.of(context).size.width;
		final isDesktop = w >= 900;

		final left = _LeftText(isDesktop: isDesktop);
		final right = const _PhoneMockups();

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
					child: Text('🎥', style: TextStyle(fontSize: 20, color: Colors.white.withValues(alpha: 0.95))),
				),
				const SizedBox(width: 10),
				Flexible(
					child: Text('Short-Form Content That Sells',
						style: GoogleFonts.josefinSans(color: ReelsHeroSection._headline, fontSize: isDesktop ? 40 : 28, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
				),
			]),
			const SizedBox(height: 10),
			Text('Engaging reels optimized for conversions and reach.',
				style: GoogleFonts.poppins(color: ReelsHeroSection._body.withValues(alpha: 0.95), fontSize: isDesktop ? 16 : 14, height: 1.6, fontWeight: FontWeight.w500)),
			const SizedBox(height: 16),
			const _Feature(text: '10-reel content calendar / month'),
			const _Feature(text: 'Scripts, hooks, cuts, captions'),
			const _Feature(text: 'Posting SOP + analytics review'),
			const SizedBox(height: 16),
			const _PrimaryCta(label: 'Get Reels Package'),
			const SizedBox(height: 12),
			const _BottomIconsRow(items: [
				(Icons.play_circle_fill, 'Hooks'),
				(Icons.subtitles, 'Captions'),
				(Icons.closed_caption, 'Subtitles'),
				(Icons.query_stats, 'Insights'),
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
					child: const Icon(Icons.arrow_right_alt, size: 18, color: Colors.white),
				),
				const SizedBox(width: 10),
				Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize: 14, height: 1.45, color: Colors.white.withValues(alpha: 0.98)))),
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
		final bg = _hover ? const Color(0xFFE0005D) : ReelsHeroSection._cta;
		return MouseRegion(
			onEnter: (_) => setState(() => _hover = true),
			onExit: (_) => setState(() => _hover = false),
			child: GestureDetector(
				onTap: () {},
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

class _PhoneMockups extends StatelessWidget {
	const _PhoneMockups();
	@override
	Widget build(BuildContext context) {
		return SizedBox(
			height: 420,
			child: Stack(clipBehavior: Clip.none, children: const [
				Positioned(left: 10, top: 40, child: _PhoneSmall(angle: -0.06)),
				Positioned(right: 10, top: 10, child: _PhoneSmall(angle: 0.05)),
				Positioned(left: 80, bottom: 0, child: _PhoneMain()),
			]),
		);
	}
}

class _PhoneMain extends StatelessWidget {
	const _PhoneMain();
	@override
	Widget build(BuildContext context) {
		return _PhoneFrame(width: 260, height: 520 * 0.8, child: const _ReelScreen());
	}
}

class _PhoneSmall extends StatelessWidget {
	const _PhoneSmall({required this.angle});
	final double angle;
	@override
	Widget build(BuildContext context) {
		final frame = _PhoneFrame(width: 150, height: 300 * 0.78, child: const _ReelScreen(dim: true));
		return Transform.rotate(angle: angle, child: frame);
	}
}

class _PhoneFrame extends StatelessWidget {
	const _PhoneFrame({required this.width, required this.height, required this.child});
	final double width;
	final double height;
	final Widget child;
	@override
	Widget build(BuildContext context) {
		return Container(
			width: width,
			height: height,
			decoration: BoxDecoration(color: const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(32), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 26, offset: Offset(0, 16))], border: Border.all(color: const Color(0xFF1F2937), width: 2)),
			child: ClipRRect(
				borderRadius: BorderRadius.circular(28),
				child: Stack(children: [
					Positioned.fill(child: Container(color: const Color(0xFF101114), child: child)),
					Positioned(top: 6, left: (width / 2) - 30, child: Container(width: 60, height: 6, decoration: BoxDecoration(color: const Color(0x33111111), borderRadius: BorderRadius.circular(3)))),
				]),
			),
		);
	}
}

class _ReelScreen extends StatelessWidget {
	const _ReelScreen({this.dim = false});
	final bool dim;
	@override
	Widget build(BuildContext context) {
		final overlay = dim ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08);
		return Stack(children: [
			Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0B63FF), Color(0xFFFF0069)], begin: Alignment.topLeft, end: Alignment.bottomRight)))),
			Positioned.fill(child: Container(color: overlay)),
			Center(child: Container(width: 54, height: 54, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, size: 34, color: Color(0xFF0A0A0A)))),
			Positioned(
				right: 10,
				bottom: 20,
				child: Column(children: const [
					_EngageIcon(icon: Icons.favorite_border),
					SizedBox(height: 14),
					_EngageIcon(icon: Icons.mode_comment_outlined),
					SizedBox(height: 14),
					_EngageIcon(icon: Icons.send_outlined),
				]),
			),
			Positioned(
				left: 12,
				bottom: 18,
				right: 60,
				child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
					Container(width: 120, height: 10, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(4))),
					const SizedBox(height: 6),
					Container(width: 180, height: 8, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(4))),
				]),
			),
		]);
	}
}

class _EngageIcon extends StatelessWidget {
	const _EngageIcon({required this.icon});
	final IconData icon;
	@override
	Widget build(BuildContext context) {
		return Container(width: 38, height: 38, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 4))]), child: Icon(icon, size: 20, color: const Color(0xFF0A0A0A)));
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
		return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)), child: Row(mainAxisSize: MainAxisSize.min, children: [
			Icon(icon, size: 16, color: Colors.white70),
			const SizedBox(width: 6),
			Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
		]));
	}
}
