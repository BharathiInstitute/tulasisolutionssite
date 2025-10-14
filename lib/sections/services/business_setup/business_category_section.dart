import 'package:flutter/material.dart';

class BusinessCategorySection extends StatelessWidget {
	const BusinessCategorySection({super.key});

	@override
	Widget build(BuildContext context) {
		final textTheme = Theme.of(context).textTheme;

		return Padding(
			padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
			child: Stack(
				children: [
					// Gradient, rounded, shadowed card with subtle decorative blobs
					Container(
						width: double.infinity,
						decoration: BoxDecoration(
							gradient: const LinearGradient(
								colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
								begin: Alignment.topLeft,
								end: Alignment.bottomRight,
							),
							borderRadius: BorderRadius.zero,
							boxShadow: const [
								BoxShadow(
									color: Color(0x33000000),
									blurRadius: 24,
									offset: Offset(0, 12),
								),
								BoxShadow(
									color: Color(0x1AFFFFFF),
									blurRadius: 12,
									offset: Offset(-6, -6),
								),
							],
						),
						padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								// Header with icon and title
								Row(
									crossAxisAlignment: CrossAxisAlignment.center,
									children: [
										Container(
											width: 48,
											height: 48,
											decoration: const BoxDecoration(
												shape: BoxShape.circle,
												boxShadow: [
													BoxShadow(
														color: Color(0x40FFFFFF),
														blurRadius: 10,
														offset: Offset(-2, -2),
													),
													BoxShadow(
														color: Color(0x33000000),
														blurRadius: 10,
														offset: Offset(2, 4),
													),
												],
												gradient: LinearGradient(
													colors: [Color(0xFFFFFFFF), Color(0xFFE9D5FF)],
													begin: Alignment.topLeft,
													end: Alignment.bottomRight,
												),
											),
											child: const Center(
												child: Icon(
													Icons.category_rounded,
													color: Color(0xFF4C1D95),
													size: 26,
												),
											),
										),
										const SizedBox(width: 14),
										Expanded(
											child: Text(
												'Business Category / Track',
												style: textTheme.headlineSmall?.copyWith(
													color: Colors.white,
													fontWeight: FontWeight.w800,
													letterSpacing: 0.2,
												),
											),
										),
									],
								),
								const SizedBox(height: 14),
								// Explanation
								Text(
									'We map your business to a proven industry track with ready workflows, assets, and KPIs.',
									style: textTheme.bodyLarge?.copyWith(
										color: Colors.white.withValues(alpha: 0.92),
										height: 1.6,
									),
								),
								const SizedBox(height: 20),
								// Includes subtitle
								Text(
									'Includes:',
									style: textTheme.titleMedium?.copyWith(
										color: Colors.white,
										fontWeight: FontWeight.w700,
										letterSpacing: 0.2,
									),
								),
								const SizedBox(height: 12),
								// Bullet points with accent icon circles
								_BulletItem(
									icon: Icons.check_circle_rounded,
									accent: const Color(0xFF22C55E),
									text:
											'Track selection (Retail/Edu/Cosmetics/Printing/Services/Startup)',
								),
								const SizedBox(height: 10),
								_BulletItem(
									icon: Icons.inventory_2_rounded,
									accent: const Color(0xFFA855F7),
									text: 'Starter kit: target personas, value ladder, channel mix',
								),
								const SizedBox(height: 10),
								_BulletItem(
									icon: Icons.assignment_turned_in_rounded,
									accent: const Color(0xFF06B6D4),
									text: 'Compliance & must-have assets checklist',
								),
								const SizedBox(height: 10),
								_BulletItem(
									icon: Icons.trending_up_rounded,
									accent: const Color(0xFFEC4899),
									text: '90-day ramp plan',
								),
							],
						),
					),
					// Decorative abstract shapes (soft circles)
					Positioned(
						right: -20,
						top: -20,
						child: _Blob(
							diameter: 120,
							color: Colors.white.withValues(alpha: 0.08),
						),
					),
					Positioned(
						left: -30,
						bottom: -30,
						child: _Blob(
							diameter: 160,
							color: Colors.white.withValues(alpha: 0.06),
						),
					),
				],
			),
		);
	}
}

class _BulletItem extends StatelessWidget {
	const _BulletItem({
		required this.icon,
		required this.accent,
		required this.text,
	});

	final IconData icon;
	final Color accent;
	final String text;

	@override
	Widget build(BuildContext context) {
		final textTheme = Theme.of(context).textTheme;

		return Row(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Container(
					width: 36,
					height: 36,
					decoration: BoxDecoration(
						shape: BoxShape.circle,
						color: accent.withValues(alpha: 0.18),
						boxShadow: [
							BoxShadow(
								color: accent.withValues(alpha: 0.2),
								blurRadius: 8,
								offset: const Offset(0, 4),
							),
						],
					),
					child: Icon(icon, color: accent, size: 20),
				),
				const SizedBox(width: 12),
				Expanded(
					child: Text(
						text,
						style: textTheme.bodyMedium?.copyWith(
							color: Colors.white,
							height: 1.6,
						),
					),
				),
			],
		);
	}
}

class _Blob extends StatelessWidget {
	const _Blob({required this.diameter, required this.color});
	final double diameter;
	final Color color;

	@override
	Widget build(BuildContext context) {
		return IgnorePointer(
			child: Container(
				width: diameter,
				height: diameter,
				decoration: BoxDecoration(
					shape: BoxShape.circle,
					color: color,
				),
			),
		);
	}
}