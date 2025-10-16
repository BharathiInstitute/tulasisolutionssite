// AccountsManagementHeroSection implementation migrated to services/software.
// Original file now becomes a thin export shim to preserve legacy imports.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AccountsManagementHeroSection extends StatelessWidget {
	const AccountsManagementHeroSection({super.key});
	@override
	Widget build(BuildContext context) {
		final size = MediaQuery.of(context).size;
		final isDesktop = size.width >= 900;
		return Stack(children: [
			Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.10))),
			Center(
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 1200),
					child: Padding(
						padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
						child: isDesktop
								? Row(crossAxisAlignment: CrossAxisAlignment.center, children: const [Expanded(flex: 5, child: _LeftContent()), SizedBox(width: 24), Expanded(flex: 6, child: _RightMockup())])
								: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [_RightMockup(), SizedBox(height: 24), _LeftContent()]),
					),
				),
			),
		]);
	}
}

class _LeftContent extends StatelessWidget {
	const _LeftContent();
	@override
	Widget build(BuildContext context) {
		final titleStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: Colors.white, height: 1.15);
		final bodyStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70, height: 1.5);
		return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
			const Text('💰', style: TextStyle(fontSize: 28)),
			const SizedBox(height: 12),
			Text('Clean Books, Faster Decisions', style: titleStyle),
			const SizedBox(height: 12),
			Text('Automated accounting that keeps you compliant and cashflow-ready.', style: bodyStyle),
			const SizedBox(height: 16),
			const _FeaturePoint(text: 'Chart of accounts, invoicing, GST basics'),
			const _FeaturePoint(text: 'Expense control & approvals'),
			const _FeaturePoint(text: 'P&L / Cashflow snapshots'),
			const _FeaturePoint(text: 'Export-ready CA tools'),
			const SizedBox(height: 20),
			SizedBox(
				height: 48,
				child: ElevatedButton(
					style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B63FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 2, padding: const EdgeInsets.symmetric(horizontal: 20)),
					onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('We\'ll automate your accounts!'))),
					child: const Text('Automate Accounts', style: TextStyle(fontWeight: FontWeight.w600)),
				),
			),
			const SizedBox(height: 12),
			const _BottomIconsRow(items: [
				(Icons.request_quote, 'GST'),
				(Icons.receipt_long, 'Invoices'),
				(Icons.summarize, 'P&L'),
				(Icons.savings, 'Cashflow'),
			]),
		]);
	}
}

class _FeaturePoint extends StatelessWidget {
	final String text; const _FeaturePoint({required this.text});
	@override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle, color: Color(0xFF0B63FF), size: 20), const SizedBox(width: 8), Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.4))),]));
}

class _RightMockup extends StatelessWidget { const _RightMockup(); @override Widget build(BuildContext context) { return LayoutBuilder(builder: (context, constraints) { final height = math.min(430.0, constraints.maxWidth * 0.72); return Align(alignment: Alignment.centerRight, child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE5E7EB)), boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, 8))]), child: SizedBox(height: height, child: const _AccountingDashboard()))); }); } }

class _AccountingDashboard extends StatelessWidget { const _AccountingDashboard(); @override Widget build(BuildContext context) { return Column(children: const [Expanded(child: Row(children: [Expanded(flex: 2, child: _PieChartCard()), SizedBox(width: 12), Expanded(flex: 3, child: _PLSummaryCard())])), SizedBox(height: 12), Expanded(child: _RecentInvoicesCard())]); } }

class _PieChartCard extends StatelessWidget { const _PieChartCard(); @override Widget build(BuildContext context) { return Container(decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))), padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: const [Icon(Icons.pie_chart, size: 16, color: Color(0xFF0F172A)), SizedBox(width: 6), Text('Income vs Expense')]), const SizedBox(height: 8), Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: CustomPaint(painter: _PiePainter(segments: const [_PieSegment(0.62, Color(0xFF10B981)), _PieSegment(0.38, Color(0xFFEF4444)),])))))],)); } }

class _PieSegment { final double value; final Color color; const _PieSegment(this.value, this.color); }
class _PiePainter extends CustomPainter { final List<_PieSegment> segments; const _PiePainter({required this.segments}); @override void paint(Canvas canvas, Size size) { final rect = Offset.zero & size; final center = rect.center; final radius = math.min(size.width, size.height) / 2; var startAngle = -math.pi / 2; for (final s in segments) { final sweep = s.value * 2 * math.pi; final paint = Paint()..color = s.color..style = PaintingStyle.fill; canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep, true, paint); startAngle += sweep; } canvas.drawCircle(center, radius * 0.55, Paint()..color = Colors.white); } @override bool shouldRepaint(covariant _PiePainter oldDelegate) => oldDelegate.segments != segments; }

class _PLSummaryCard extends StatelessWidget { const _PLSummaryCard(); @override Widget build(BuildContext context) { return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))), padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: const [Icon(Icons.stacked_line_chart, size: 16, color: Color(0xFF0F172A)), SizedBox(width: 6), Text('P&L Summary', style: TextStyle(fontWeight: FontWeight.w700))]), const SizedBox(height: 10), Row(children: const [_Kpi(label: 'Revenue', value: '₹12.5L', color: Color(0xFF10B981)), SizedBox(width: 16), _Kpi(label: 'Expenses', value: '₹7.6L', color: Color(0xFFEF4444)), SizedBox(width: 16), _Kpi(label: 'Net', value: '₹4.9L', color: Color(0xFF1D4ED8))]), const Spacer(), const Text('Cashflow Snapshot', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 6), ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(height: 60, child: CustomPaint(painter: _AreaChartPainter()))),])); } }
class _Kpi extends StatelessWidget { final String label; final String value; final Color color; const _Kpi({required this.label, required this.value, required this.color}); @override Widget build(BuildContext context) { return Expanded(child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))), const SizedBox(height: 4), Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700)),]))); } }
class _AreaChartPainter extends CustomPainter { @override void paint(Canvas canvas, Size size) { final bg = Paint()..color = const Color(0xFFF8FAFC); canvas.drawRect(Offset.zero & size, bg); final path = Path(); path.moveTo(0, size.height * 0.7); path.quadraticBezierTo(size.width * 0.2, size.height * 0.5, size.width * 0.35, size.height * 0.65); path.quadraticBezierTo(size.width * 0.5, size.height * 0.85, size.width * 0.65, size.height * 0.55); path.quadraticBezierTo(size.width * 0.8, size.height * 0.3, size.width, size.height * 0.45); path.lineTo(size.width, size.height); path.lineTo(0, size.height); path.close(); final fill = Paint()..color = const Color(0xFF1D4ED8).withValues(alpha: 0.2); canvas.drawPath(path, fill); final stroke = Paint()..color = const Color(0xFF1D4ED8)..style = PaintingStyle.stroke..strokeWidth = 2; final line = Path(); line.moveTo(0, size.height * 0.7); line.quadraticBezierTo(size.width * 0.2, size.height * 0.5, size.width * 0.35, size.height * 0.65); line.quadraticBezierTo(size.width * 0.5, size.height * 0.85, size.width * 0.65, size.height * 0.55); line.quadraticBezierTo(size.width * 0.8, size.height * 0.3, size.width, size.height * 0.45); canvas.drawPath(line, stroke); } @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false; }
class _RecentInvoicesCard extends StatelessWidget { const _RecentInvoicesCard(); @override Widget build(BuildContext context) { final invoices = const [('INV-1007', 'Acme Co', '₹45,000', true), ('INV-1008', 'Globex', '₹18,500', false), ('INV-1009', 'Soylent', '₹72,300', true), ('INV-1010', 'Initech', '₹30,000', false)]; return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))), padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: const [Icon(Icons.receipt_long, size: 16, color: Color(0xFF0F172A)), SizedBox(width: 6), Text('Recent Invoices', style: TextStyle(fontWeight: FontWeight.w700))]), const SizedBox(height: 8), Expanded(child: ListView.separated(physics: const NeverScrollableScrollPhysics(), itemCount: invoices.length, separatorBuilder: (_, __) => const Divider(height: 12), itemBuilder: (context, i) { final (id, client, amount, paid) = invoices[i]; return Row(children: [Expanded(child: Text(id, style: const TextStyle(color: Color(0xFF334155)))), Expanded(child: Text(client, style: const TextStyle(color: Color(0xFF334155)))), Expanded(child: Text(amount, style: const TextStyle(fontWeight: FontWeight.w600))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: paid ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(999)), child: Text(paid ? 'Paid' : 'Due', style: TextStyle(color: paid ? const Color(0xFF10B981) : const Color(0xFFF59E0B), fontSize: 12))),]); })),])); } }
class _BottomIconsRow extends StatelessWidget { const _BottomIconsRow({required this.items}); final List<(IconData, String)> items; @override Widget build(BuildContext context) { return Wrap(spacing: 12, runSpacing: 8, children: [for (final it in items) _IconPill(icon: it.$1, label: it.$2)]); } }
class _IconPill extends StatelessWidget { const _IconPill({required this.icon, required this.label}); final IconData icon; final String label; @override Widget build(BuildContext context) { return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: Colors.white70), const SizedBox(width: 6), Text(label, style: GoogleFonts.openSans(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600))])); } }
