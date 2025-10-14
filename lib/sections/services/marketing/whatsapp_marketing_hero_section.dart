import 'package:flutter/material.dart';

class WhatsAppMarketingHeroSection extends StatelessWidget {
	const WhatsAppMarketingHeroSection({super.key});
	@override
	Widget build(BuildContext context) {
		return Container(
			color: const Color(0xFF0B6B53),
			alignment: Alignment.center,
			child: const Text('WhatsApp Marketing', style: TextStyle(color: Colors.white)),
		);
	}
}