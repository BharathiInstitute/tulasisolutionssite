import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GmbHeroSection extends StatelessWidget {
	const GmbHeroSection({super.key});

	static const _headline = Colors.white;
	static const _body = Colors.white;
	static const _cta = Color(0xFF0B63FF); // CTA accent

	@override
	Widget build(BuildContext context) {
		final w = MediaQuery.of(context).size.width;
		final isDesktop = w >= 900;

		final left = _LeftText(isDesktop: isDesktop);
		final right = const _PhoneMockup();

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
							const SizedBox(height: 20),
							left,
						],
					);

		return Stack(
			children: [
				Padding(
					padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: isDesktop ? 54 : 30),
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
							child: Text('📍', style: TextStyle(fontSize: 20, color: Colors.white.withValues(alpha: 0.95))),
						),
						const SizedBox(width: 10),
						Flexible(
							child: Text(
								'Your Local Discovery Engine',
								style: GoogleFonts.josefinSans(
									color: GmbHeroSection._headline,
									fontSize: isDesktop ? 40 : 28,
									fontWeight: FontWeight.w800,
									letterSpacing: 0.2,
								),
							),
						),
					],
				),
				const SizedBox(height: 10),
				Text(
					'Appear on maps & local search with a fully optimized GMB profile.',
					style: GoogleFonts.poppins(
						color: GmbHeroSection._body.withValues(alpha: 0.95),
						fontSize: isDesktop ? 16 : 14,
						height: 1.6,
						fontWeight: FontWeight.w500,
					),
				),
				const SizedBox(height: 16),
				const _Feature(text: 'Profile setup/optimization'),
				const _Feature(text: 'Weekly posts, Q&A, reviews playbook'),
				const _Feature(text: 'Photo/video updates + keyword plan'),
				const SizedBox(height: 16),
				const _PrimaryCta(label: 'Optimize GMB Profile'),
				const SizedBox(height: 12),
				const _BottomIconsRow(items: [
					(Icons.place_outlined, 'Maps'),
					(Icons.reviews, 'Reviews'),
					(Icons.post_add, 'Posts'),
					(Icons.photo_camera, 'Photos'),
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
			child: Row(
				children: [
					Container(
						width: 34,
						height: 34,
						decoration: BoxDecoration(
							color: Colors.white.withValues(alpha: 0.18),
							shape: BoxShape.circle,
							border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
						),
						alignment: Alignment.center,
						child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
					),
					const SizedBox(width: 10),
					Expanded(
						child: Text(
							text,
							style: GoogleFonts.poppins(fontSize: 14, height: 1.45, color: Colors.white.withValues(alpha: 0.98)),
						),
					),
				],
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
		final bg = _hover ? const Color(0xFF094FCC) : GmbHeroSection._cta;
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

class _PhoneMockup extends StatelessWidget {
	const _PhoneMockup();
	@override
	Widget build(BuildContext context) {
		return SizedBox(
			height: 420,
			child: Stack(
				children: const [
					Positioned(left: 80, bottom: 0, child: _PhoneFrame()),
				],
			),
		);
	}
}

class _PhoneFrame extends StatelessWidget {
	const _PhoneFrame();
	@override
	Widget build(BuildContext context) {
		const width = 240.0;
		const height = 480.0;
		return Container(
			width: width,
			height: height,
			decoration: BoxDecoration(
				color: const Color(0xFF0A0A0A),
				borderRadius: BorderRadius.circular(28),
				boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 26, offset: Offset(0, 16))],
				border: Border.all(color: const Color(0xFF1F2937), width: 2),
			),
			child: ClipRRect(
				borderRadius: BorderRadius.circular(24),
				child: Stack(
					children: [
						Positioned.fill(
							child: Container(
								color: const Color(0xFF101114),
								child: const _GmbScreen(),
							),
						),
						Positioned(
							top: 6,
							left: (width / 2) - 28,
							child: Container(width: 56, height: 6, decoration: BoxDecoration(color: const Color(0x33111111), borderRadius: BorderRadius.circular(3))),
						),
					],
				),
			),
		);
	}
}

class _GmbScreen extends StatelessWidget {
	const _GmbScreen();
	@override
	Widget build(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Container(height: 110, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0B63FF), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
				const SizedBox(height: 10),
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 12),
					child: Row(
						children: [
							Container(width: 18, height: 18, decoration: const BoxDecoration(color: Color(0xFFFFC107), shape: BoxShape.circle)),
							const SizedBox(width: 8),
							Container(width: 120, height: 12, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(4))),
							const SizedBox(width: 6),
							Container(width: 60, height: 10, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4))),
						],
					),
				),
				const SizedBox(height: 10),
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 12),
					child: Container(
						height: 80,
						decoration: BoxDecoration(
							borderRadius: BorderRadius.circular(12),
							gradient: const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF10B981)], begin: Alignment.topLeft, end: Alignment.bottomRight),
						),
					),
				),
				const SizedBox(height: 10),
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 12),
					child: Row(
						children: [
							_pill(70), const SizedBox(width: 8), _pill(80), const SizedBox(width: 8), _pill(60),
						],
					),
				),
				const SizedBox(height: 10),
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 12),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Container(width: 140, height: 10, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(4))),
							const SizedBox(height: 6),
							Container(width: 200, height: 8, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(4))),
						],
					),
				),
			],
		);
	}

	Widget _pill(double w) => Container(
				width: w,
				height: 28,
				decoration: BoxDecoration(
					color: Colors.white.withValues(alpha: 0.12),
					borderRadius: BorderRadius.circular(20),
					border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
				),
			);
}

class _BottomIconsRow extends StatelessWidget {
	const _BottomIconsRow({required this.items});
	final List<(IconData, String)> items;

	@override
	Widget build(BuildContext context) {
		return Wrap(
			spacing: 12,
			runSpacing: 8,
			children: [
				for (final it in items) _IconPill(icon: it.$1, label: it.$2),
			],
		);
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
			decoration: BoxDecoration(
				color: Colors.white.withValues(alpha: 0.12),
				borderRadius: BorderRadius.circular(999),
				border: Border.all(color: Colors.white24),
			),
			child: Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					Icon(icon, size: 16, color: Colors.white70),
					const SizedBox(width: 6),
					Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
				],
			),
		);
	}
}