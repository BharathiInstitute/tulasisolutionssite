import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// Removed bubbled_box.dart usage.
// Inlined CornerLogo (previously in corner_logo.dart)

class ExpansionPlanningSection extends StatelessWidget {
	const ExpansionPlanningSection({super.key});

	@override
	Widget build(BuildContext context) {
		final w = MediaQuery.of(context).size.width;
		final isDesktop = w >= 900;
		final left = _Left(isDesktop: isDesktop);
		final right = const _Right();

		final content = isDesktop
				? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 28), Expanded(child: right)])
				: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [right, const SizedBox(height: 20), left]);

		return Padding(
			padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: isDesktop ? 48 : 28),
			child: Center(
				child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200), child: content),
			),
		);
	}
}

class _Left extends StatelessWidget {
	const _Left({required this.isDesktop});
	final bool isDesktop;
	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.all(20),
			decoration: BoxDecoration(
				borderRadius: BorderRadius.circular(16),
				gradient: LinearGradient(
					begin: Alignment.topLeft,
					end: Alignment.bottomRight,
					colors: [const Color(0xFF0B6B53).withValues(alpha: .95), const Color(0xFF0B6B53).withValues(alpha: .80)],
				),
				border: Border.all(color: Colors.white.withValues(alpha: .10)),
				boxShadow: const [
					BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 8)),
					BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2)),
				],
			),
			child: Stack(
				clipBehavior: Clip.none,
				children: [
					Positioned(right: 0, top: 0, child: const CornerLogo(icon: Icons.public)),
					Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
				Text('Scale With Confidence', style: GoogleFonts.openSans(fontSize: isDesktop ? 32 : 24, fontWeight: FontWeight.w800)),
				const SizedBox(height: 12),
				Text('We prepare you for multi-store, new locations, or new products.', style: GoogleFonts.openSans(fontSize: isDesktop ? 16 : 14, height: 1.6)),
				const SizedBox(height: 20),
				const _Bullet('Readiness checklist (ops, HR, inventory)'),
				const _Bullet('Launch toolkit (branding, landing pages, ads)'),
				const _Bullet('90-day post-launch support plan'),
				const SizedBox(height: 20),
				Row(children: const [Icon(Icons.public, size: 32, color: Colors.white70), SizedBox(width: 12), Icon(Icons.rocket_launch, size: 32, color: Colors.white70)]),
			]),
				],
			),
		);
	}
}

class _Right extends StatelessWidget {
	const _Right();
	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.all(12),
			decoration: BoxDecoration(
				borderRadius: BorderRadius.circular(16),
				gradient: LinearGradient(
					begin: Alignment.topLeft,
					end: Alignment.bottomRight,
					colors: [const Color(0xFF0B6B53).withValues(alpha: .95), const Color(0xFF0B6B53).withValues(alpha: .80)],
				),
				border: Border.all(color: Colors.white.withValues(alpha: .10)),
				boxShadow: const [
					BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 8)),
					BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2)),
				],
			),
			child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
				ClipRRect(
					borderRadius: BorderRadius.circular(12),
					child: SizedBox(
						height: 200,
						width: double.infinity,
						child: Stack(fit: StackFit.expand, children: [
							Image.asset('assets/images/expansion_map.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.white.withValues(alpha: 0.06))),
							Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.2))),
						]),
					),
				),
				const SizedBox(height: 16),
				Text('Animation of one store → multiple pins on map', style: GoogleFonts.openSans(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.white70)),
			]),
		);
	}
}

class _Bullet extends StatelessWidget {
	const _Bullet(this.text);
	final String text;
	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.symmetric(vertical: 4),
			child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
				const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.check_circle, size: 18, color: Colors.white70)),
				const SizedBox(width: 10),
				Expanded(child: Text(text, style: GoogleFonts.openSans(fontSize: 14))),
			]),
		);
	}
}

class CornerLogo extends StatelessWidget {
	final IconData icon;
	const CornerLogo({super.key, required this.icon});
	@override
	Widget build(BuildContext context) {
		return Container(
			decoration: BoxDecoration(
				color: Colors.white.withValues(alpha: 0.12),
				borderRadius: BorderRadius.circular(8),
			),
			padding: const EdgeInsets.all(6),
			child: Icon(icon, color: Colors.white, size: 22),
		);
	}
}