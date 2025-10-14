import 'package:flutter/material.dart';

/// Simplified placeholder for Email automation hero section.
class EmailAutomationHeroSection extends StatelessWidget {
	const EmailAutomationHeroSection({super.key});

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.all(28),
			decoration: BoxDecoration(
				color: const Color(0xFF1A73E8),
				borderRadius: BorderRadius.circular(24),
			),
			child: const Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				mainAxisSize: MainAxisSize.min,
				children: [
					Text('Email Automation', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
					SizedBox(height: 12),
					Text('Sequences, segmentation & deliverability.', style: TextStyle(color: Colors.white70)),
				],
			),
		);
	}
}