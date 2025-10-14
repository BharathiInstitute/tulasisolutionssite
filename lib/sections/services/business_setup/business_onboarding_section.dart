import 'package:flutter/material.dart';

class BusinessOnboardingSection extends StatelessWidget {
const BusinessOnboardingSection({super.key});



@override
Widget build(BuildContext context) {
final width = MediaQuery.of(context).size.width;
final isMobile = width < 800;

return Stack(
children: [
// Background: subtle sky gradient with a launch glow and smoke
Positioned.fill(
child: CustomPaint(
painter: _RocketLaunchPainter(),
),
),
Container(
width: double.infinity,
padding: EdgeInsets.symmetric(
horizontal: isMobile ? 16 : 32,
vertical: isMobile ? 28 : 48,
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.center,
children: [
// ...existing code...
],
),
),
],
);
}
}

// ...existing code for _IncludedCard, _Feature, _FeatureRow, _CtaButton...

class _RocketLaunchPainter extends CustomPainter {
	@override
	void paint(Canvas canvas, Size size) {
		// Sky gradient base
		final rect = Offset.zero & size;
		final sky = Paint()
			..shader = const LinearGradient(
				begin: Alignment.topCenter,
				end: Alignment.bottomCenter,
				colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
			).createShader(rect);
		canvas.drawRect(rect, sky);

		// Spotlight glow
		final glowShader = RadialGradient(
			colors: [const Color(0xFFFFFFFF).withValues(alpha: 0.35), Colors.transparent],
			radius: 0.55,
			center: const Alignment(0, -0.6),
		).createShader(rect);
		final glowPaint = Paint()..shader = glowShader;
		canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.12), size.width * 0.45, glowPaint);

		// Simple rocket plume
		final plume = Path()
			..moveTo(size.width * 0.5, size.height * 0.20)
			..quadraticBezierTo(size.width * 0.55, size.height * 0.45, size.width * 0.5, size.height * 0.70)
			..quadraticBezierTo(size.width * 0.45, size.height * 0.45, size.width * 0.5, size.height * 0.20)
			..close();
		final plumePaint = Paint()
			..shader = const LinearGradient(
				colors: [Color(0xFFFFE29D), Color(0xFFFFA99D)],
				begin: Alignment.topCenter,
				end: Alignment.bottomCenter,
			).createShader(rect)
			..blendMode = BlendMode.screen
			..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
		canvas.drawPath(plume, plumePaint);

		// Smoke circles
	final smokePaint = Paint()..color = const Color(0xFFE2E8F0).withValues(alpha: 0.6);
		for (int i = 0; i < 6; i++) {
			final dx = size.width * (0.25 + i * 0.1);
			final dy = size.height * (0.75 + (i % 2) * 0.05);
			canvas.drawCircle(Offset(dx, dy), 22 + i * 3.0, smokePaint);
		}
	}

	@override
	bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}