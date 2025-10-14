import 'package:flutter/material.dart';

/// Simplified placeholder for SMS automation hero section.
class SmsAutomationHeroSection extends StatelessWidget {
	const SmsAutomationHeroSection({super.key});

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.all(28),
			decoration: BoxDecoration(
				color: const Color(0xFF0A4D68),
				borderRadius: BorderRadius.circular(24),
			),
			child: const Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				mainAxisSize: MainAxisSize.min,
				children: [
					Text('SMS Automation', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
					SizedBox(height: 12),
					Text('OTP, alerts & failover messaging.', style: TextStyle(color: Colors.white70)),
				],
			),
		);
	}
}