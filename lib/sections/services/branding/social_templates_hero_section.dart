import 'package:flutter/material.dart';

class SocialTemplatesHeroSection extends StatelessWidget {
	const SocialTemplatesHeroSection({super.key});
	@override
	Widget build(BuildContext context) {
		return AspectRatio(
			aspectRatio: 16/7,
			child: Container(
				color: const Color(0xFF0B6B53),
				alignment: Alignment.center,
				child: const Text('Social Templates', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
			),
		);
	}
}