import 'package:flutter/material.dart';

/// Simplified placeholder for WhatsApp automation hero section.
/// Original rich UI removed during refactor and can be restored later.
class WhatsAppAutomationHeroSection extends StatelessWidget {
	const WhatsAppAutomationHeroSection({super.key});

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.all(28),
			decoration: BoxDecoration(
				color: const Color(0xFF0B5F3C),
				borderRadius: BorderRadius.circular(24),
				border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				mainAxisSize: MainAxisSize.min,
				children: const [
					Text('WhatsApp Automation', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
					SizedBox(height: 12),
					Text('Automate welcome, recovery and notification flows.', style: TextStyle(color: Colors.white70)),
				],
			),
		);
	}
}