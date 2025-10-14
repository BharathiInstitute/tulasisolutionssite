import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Simplified placeholder for Customer Journey hero section.
class CustomerJourneyHeroSection extends StatelessWidget {
	const CustomerJourneyHeroSection({super.key});

	@override
	Widget build(BuildContext context) {
		final isWide = MediaQuery.of(context).size.width > 840;
		return Container(
			padding: const EdgeInsets.all(28),
			decoration: BoxDecoration(
				color: const Color(0xFF1E293B),
				borderRadius: BorderRadius.circular(28),
			),
			child: Flex(
				direction: isWide ? Axis.horizontal : Axis.vertical,
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Expanded(
						flex: isWide ? 5 : 0,
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text('Customer Journey Mapping',
									style: GoogleFonts.josefinSans(
										fontSize: isWide ? 38 : 30,
										fontWeight: FontWeight.w800,
										color: Colors.white,
									)),
								const SizedBox(height: 14),
								Text(
									'Visualize stages and attach automations at key touchpoints to reduce drop-offs.',
									style: GoogleFonts.poppins(
										color: Colors.white70,
										fontSize: 14,
										height: 1.5,
									),
								),
								const SizedBox(height: 22),
								Wrap(
									spacing: 10,
									runSpacing: 10,
									children: const [
										_Tag('Awareness → Repeat'),
										_Tag('Trigger Rules'),
										_Tag('Funnel KPIs'),
										_Tag('Automation Links'),
									],
								),
							],
						),
					),
					if (isWide) const SizedBox(width: 30) else const SizedBox(height: 30),
					Expanded(
						flex: isWide ? 4 : 0,
						child: AspectRatio(
							aspectRatio: 16 / 11,
							child: DecoratedBox(
								decoration: BoxDecoration(
									color: const Color(0xFF334155),
									borderRadius: BorderRadius.circular(20),
								),
								child: const Center(
									child: Text('Journey Canvas', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
								),
							),
						),
					),
				],
			),
		);
	}
}

class _Tag extends StatelessWidget {
	const _Tag(this.label);
	final String label;
	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
			decoration: BoxDecoration(
				color: const Color(0xFF475569),
				borderRadius: BorderRadius.circular(999),
			),
			child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
		);
	}
}