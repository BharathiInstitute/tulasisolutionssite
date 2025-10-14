import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GoogleAdsHeroSection extends StatelessWidget {
	const GoogleAdsHeroSection({super.key});

	@override
	Widget build(BuildContext context) {
		final w = MediaQuery.of(context).size.width;
		final isDesktop = w >= 900;

		return Padding(
			padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: isDesktop ? 54 : 30),
			child: Center(
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 1200),
					child: _Content(isDesktop: isDesktop),
				),
			),
		);
	}
}

class _Content extends StatelessWidget {
	const _Content({required this.isDesktop});
	final bool isDesktop;

	@override
	Widget build(BuildContext context) {
		final left = const _TextCol();
		final right = const _PpcMock();
		return isDesktop
				? Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [Expanded(child: left), const SizedBox(width: 28), Expanded(child: right)],
					)
				: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [right, const SizedBox(height: 20), left]);
	}
}

class _TextCol extends StatelessWidget {
	const _TextCol();
	@override
	Widget build(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Row(
					children: [
						Container(
							padding: const EdgeInsets.all(10),
							decoration: BoxDecoration(
								borderRadius: BorderRadius.circular(12),
								gradient: const LinearGradient(colors: [Color(0xFF4285F4), Color(0xFF34A853), Color(0xFFFBBC05), Color(0xFFEA4335)]),
							),
							child: const Icon(Icons.trending_up, color: Colors.white),
						),
						const SizedBox(width: 12),
						Expanded(
							child: Text(
								'High-Intent Traffic with Google Ads',
								style: GoogleFonts.josefinSans(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white),
							),
						),
					],
				),
				const SizedBox(height: 10),
				Text(
					'Get in front of buyers searching right now. From Search to Performance Max—optimized for ROAS, not just clicks.',
					style: GoogleFonts.poppins(fontSize: 14, height: 1.6, color: Colors.white.withValues(alpha: 0.95)),
				),
				const SizedBox(height: 16),
				const _Bullet(text: 'Keyword strategy aligned with real buyer intent'),
				const _Bullet(text: 'Granular structure, SKAGs/intent clusters'),
				const _Bullet(text: 'Ad copy and extensions that earn trust'),
				const _Bullet(text: 'Landing page checks and conversion tracking'),
				const SizedBox(height: 16),
				const _CtaRow(),
			],
		);
	}
}

class _Bullet extends StatelessWidget {
	const _Bullet({required this.text});
	final String text;
	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.symmetric(vertical: 6),
			child: Row(
				children: [
					Container(
						width: 10,
						height: 10,
						decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
					),
					const SizedBox(width: 10),
					Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize: 14, height: 1.45, color: Colors.white.withValues(alpha: 0.98)))),
				],
			),
		);
	}
}

class _CtaRow extends StatelessWidget {
	const _CtaRow();
	@override
	Widget build(BuildContext context) {
		return Wrap(
			spacing: 10,
			runSpacing: 8,
			children: const [
				_PrimaryCta(label: 'Request Audit'),
				_SecondaryCta(label: 'See Sample Structure'),
			],
		);
	}
}

class _PrimaryCta extends StatefulWidget {
	const _PrimaryCta({required this.label});
	final String label;
	@override
	State<_PrimaryCta> createState() => _PrimaryCtaState();
}

class _PrimaryCtaState extends State<_PrimaryCta> {
	bool _hover = false;
	@override
	Widget build(BuildContext context) {
		final bg = _hover ? const Color(0xFF1D4ED8) : const Color(0xFF2563EB);
		return MouseRegion(
			onEnter: (_) => setState(() => _hover = true),
			onExit: (_) => setState(() => _hover = false),
			child: GestureDetector(
				onTap: () {},
				child: AnimatedContainer(
					duration: const Duration(milliseconds: 150),
					padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
					decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 6))]),
					child: Text(widget.label, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
				),
			),
		);
	}
}

class _SecondaryCta extends StatefulWidget {
	const _SecondaryCta({required this.label});
	final String label;
	@override
	State<_SecondaryCta> createState() => _SecondaryCtaState();
}

class _SecondaryCtaState extends State<_SecondaryCta> {
	bool _hover = false;
	@override
	Widget build(BuildContext context) {
		final border = _hover ? Colors.white : Colors.white70;
		return MouseRegion(
			onEnter: (_) => setState(() => _hover = true),
			onExit: (_) => setState(() => _hover = false),
			child: GestureDetector(
				onTap: () {},
				child: AnimatedContainer(
					duration: const Duration(milliseconds: 150),
					padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
					decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(10)),
					child: Text(widget.label, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
				),
			),
		);
	}
}

class _PpcMock extends StatelessWidget {
	const _PpcMock();
	@override
	Widget build(BuildContext context) {
		return _PpcBoard();
	}
}

class _PpcBoard extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.all(16),
			decoration: BoxDecoration(
				color: const Color(0xFF0B1220),
				borderRadius: BorderRadius.circular(16),
				border: Border.all(color: const Color(0xFF1F2937)),
				boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 26, offset: Offset(0, 16))],
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: const [
					_BoardHeader(),
					SizedBox(height: 12),
					_MetricsRow(),
					SizedBox(height: 12),
					_CampaignsTable(),
				],
			),
		);
	}
}

class _BoardHeader extends StatelessWidget {
	const _BoardHeader();
	@override
	Widget build(BuildContext context) {
		return Row(
			children: [
				Text('Google Ads Overview', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
				const Spacer(),
				_Tag('Search'),
				const SizedBox(width: 6),
				_Tag('PMax'),
				const SizedBox(width: 6),
				_Tag('Remarketing'),
			],
		);
	}
}

class _Tag extends StatelessWidget {
	const _Tag(this.t);
	final String t;
	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
			decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(999)),
			child: Text(t, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
		);
	}
}

class _MetricsRow extends StatelessWidget {
	const _MetricsRow();
	@override
	Widget build(BuildContext context) {
		return Row(
			children: const [
				Expanded(child: _MetricCard('Impr.', '148k')),
				SizedBox(width: 10),
				Expanded(child: _MetricCard('Clicks', '8,320')),
				SizedBox(width: 10),
				Expanded(child: _MetricCard('CPC', '₹14.3')),
				SizedBox(width: 10),
				Expanded(child: _MetricCard('Conv.', '412')),
			],
		);
	}
}

class _MetricCard extends StatelessWidget {
	const _MetricCard(this.title, this.value);
	final String title;
	final String value;
	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.all(12),
			decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))),
			child: Row(
				children: [
					Container(width: 8, height: 40, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF4285F4), Color(0xFF34A853)]), borderRadius: BorderRadius.circular(999))),
					const SizedBox(width: 10),
					Expanded(
						child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
							Text(title, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
							const SizedBox(height: 4),
							Text(value, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
						]),
					),
				],
			),
		);
	}
}

class _CampaignsTable extends StatelessWidget {
	const _CampaignsTable();
	@override
	Widget build(BuildContext context) {
		return Container(
			decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))),
			child: Column(
				children: const [
					_RowHeader(),
					_RowItem('Search – Shoes (SKAG)', '₹32,140', '3.2%', '₹12.4', '142'),
					_RowItem('PMax – Retail', '₹58,900', '2.4%', '₹16.2', '213'),
					_RowItem('RLSA – Brand', '₹8,120', '5.1%', '₹9.7', '57'),
				],
			),
		);
	}
}

class _RowHeader extends StatelessWidget {
	const _RowHeader();
	@override
	Widget build(BuildContext context) {
		return _RowBase(
			isHeader: true,
			name: 'Campaign',
			spend: 'Spend',
			ctr: 'CTR',
			cpc: 'CPC',
			conv: 'Conv.',
		);
	}
}

class _RowItem extends StatelessWidget {
	const _RowItem(this.name, this.spend, this.ctr, this.cpc, this.conv);
	final String name;
	final String spend;
	final String ctr;
	final String cpc;
	final String conv;
	@override
	Widget build(BuildContext context) {
		return _RowBase(name: name, spend: spend, ctr: ctr, cpc: cpc, conv: conv);
	}
}

class _RowBase extends StatelessWidget {
	const _RowBase({this.isHeader = false, required this.name, required this.spend, required this.ctr, required this.cpc, required this.conv});
	final bool isHeader;
	final String name;
	final String spend;
	final String ctr;
	final String cpc;
	final String conv;
	@override
	Widget build(BuildContext context) {
		final style = GoogleFonts.poppins(color: Colors.white.withValues(alpha: isHeader ? 0.7 : 0.95), fontWeight: isHeader ? FontWeight.w700 : FontWeight.w600);
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
			decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
			child: Row(
				children: [
					Expanded(flex: 5, child: Text(name, style: style)),
					Expanded(flex: 2, child: Text(spend, style: style)),
					Expanded(flex: 2, child: Text(ctr, style: style)),
					Expanded(flex: 2, child: Text(cpc, style: style)),
					Expanded(flex: 2, child: Text(conv, style: style)),
				],
			),
		);
	}
}
