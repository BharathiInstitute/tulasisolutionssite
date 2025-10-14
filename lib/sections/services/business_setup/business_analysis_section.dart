export '../business_setup/business_analysis_section.dart';
// Implementation relocated from sections/business_setup to services/business_setup.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class BusinessAnalysisSection extends StatelessWidget {
	const BusinessAnalysisSection({super.key});

	static const _gold = Color(0xFFD4AF37);
	static const _headline = Color(0xFF443F3F);
	static const _body = Color(0xFFF78CA2);
	static const _sublabel = Color(0xFF7D5B4C);

	@override
	Widget build(BuildContext context) {
		final width = MediaQuery.of(context).size.width;
		final isMobile = width < 800;
		return Stack(children: [
			Container(
				width: double.infinity,
				padding: EdgeInsets.symmetric(
					horizontal: isMobile ? 16 : 32,
					vertical: isMobile ? 28 : 48,
				),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.center,
					children: [
						Row(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								_iconCircle(FeatherIcons.search),
								const SizedBox(width: 10),
								_iconCircle(FeatherIcons.barChart2),
								const SizedBox(width: 12),
								Flexible(
									child: Text('360° Business Audit', textAlign: TextAlign.center, style: GoogleFonts.josefinSans(fontSize: isMobile ? 28 : 40, fontWeight: FontWeight.w700, color: _headline)),
								),
							],
						),
						const SizedBox(height: 10),
						ConstrainedBox(
							constraints: const BoxConstraints(maxWidth: 920),
							child: Text('We review every touchpoint—brand, funnel, operations—for hidden leaks.', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: isMobile ? 14 : 16, color: _body, height: 1.6, fontWeight: FontWeight.w500)),
						),
						const SizedBox(height: 28),
						Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: _IncludedCard(isMobile: isMobile))),
					],
				),
			),
		]);
	}

	Widget _iconCircle(IconData i) => Container(
				width: 42,
				height: 42,
				decoration: BoxDecoration(
					shape: BoxShape.circle,
					color: _gold.withValues(alpha: 0.12),
					border: Border.all(color: _gold.withValues(alpha: 0.6)),
				),
				child: Icon(i, size: 20, color: _headline),
			);
}

class _IncludedCard extends StatelessWidget {
	const _IncludedCard({required this.isMobile});
	final bool isMobile;
	@override
	Widget build(BuildContext context) {
		final items = const [
			(FeatherIcons.globe, 'Website/SEO/Ads/Content audit'),
			(FeatherIcons.gitMerge, 'CRM & sales flow review'),
			(FeatherIcons.settings, 'Ops: HR, inventory, accounts'),
			(FeatherIcons.list, 'Priority backlog'),
		];
		final cross = isMobile ? 1 : 2;
		final spacing = isMobile ? 12.0 : 16.0;
		return Container(
			width: double.infinity,
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(16),
				border: Border.all(color: BusinessAnalysisSection._gold.withValues(alpha: 0.5), width: 1),
				boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 10))],
			),
			padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 22, vertical: isMobile ? 16 : 22),
			child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
				Text('What\'s Included', style: GoogleFonts.josefinSans(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.w700, color: BusinessAnalysisSection._sublabel)),
				const SizedBox(height: 12),
				GridView.builder(
					shrinkWrap: true,
						physics: const NeverScrollableScrollPhysics(),
					itemCount: items.length,
					gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
						crossAxisCount: cross,
						mainAxisSpacing: spacing,
						crossAxisSpacing: spacing,
						childAspectRatio: isMobile ? 4 : 4.5,
					),
					itemBuilder: (context, i) {
						final it = items[i];
						return _FeatureRow(icon: it.$1, text: it.$2, vertical: isMobile);
					},
				),
			]),
		);
	}
}

class _FeatureRow extends StatelessWidget {
	const _FeatureRow({required this.icon, required this.text, required this.vertical});
	final IconData icon; final String text; final bool vertical;
	@override
	Widget build(BuildContext context) {
		final circle = Container(
			width: 40,
			height: 40,
			decoration: BoxDecoration(
				shape: BoxShape.circle,
				color: BusinessAnalysisSection._gold.withValues(alpha: 0.12),
				border: Border.all(color: BusinessAnalysisSection._gold, width: 1),
			),
			child: Icon(icon, color: BusinessAnalysisSection._headline, size: 20),
		);
		final textWidget = Text(text, style: GoogleFonts.poppins(fontSize: 14, color: BusinessAnalysisSection._sublabel, height: 1.6));
		if (vertical) {
			return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [circle, const SizedBox(height: 8), textWidget]);
		}
		return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [circle, const SizedBox(width: 12), Expanded(child: textWidget)]);
	}
}