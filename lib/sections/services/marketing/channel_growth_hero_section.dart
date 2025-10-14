import 'package:flutter/material.dart';

class ChannelGrowthHeroSection extends StatelessWidget {
	const ChannelGrowthHeroSection({super.key});
	@override
	Widget build(BuildContext context) {
		return Container(
			color: const Color(0xFF0B6B53),
			alignment: Alignment.center,
			child: const Text('Channel Growth', style: TextStyle(color: Colors.white)),
		);
	}
}