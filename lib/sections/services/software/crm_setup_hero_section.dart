// CRM Setup hero implementation migrated to services/software
import 'package:flutter/material.dart';

class CrmSetupHeroSection extends StatelessWidget {
	const CrmSetupHeroSection({super.key});
	@override
	Widget build(BuildContext context) {
		final width = MediaQuery.of(context).size.width; final isWide = width > 1000;
		return Stack(children: [
			Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.15))),
			Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1250), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40), child: isWide ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: const [Expanded(flex:5, child: _CrmLeft()), SizedBox(width:40), Expanded(flex:6, child: _CrmMock())]) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [_CrmMock(), SizedBox(height:32), _CrmLeft()]))))
		]);
	}
}

class _CrmLeft extends StatelessWidget { const _CrmLeft(); @override Widget build(BuildContext context) { final title = Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.1); final body = Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70, height: 1.5); return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text('📇', style: TextStyle(fontSize: 30)), const SizedBox(height: 16), Text('CRM Setup & Smart Pipelines', style: title), const SizedBox(height: 14), Text('Centralize leads, track deals, and automate follow-ups without heavy tools.', style: body), const SizedBox(height: 16), const _Point(text: 'Lead capture & quick qualification'), const _Point(text: 'Pipeline stages with drag & drop'), const _Point(text: 'Task + reminder automation'), const _Point(text: 'Reporting & velocity tracking'), const SizedBox(height: 22), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () {}, child: const Text('Streamline CRM')), const SizedBox(height: 16), Wrap(spacing: 12, runSpacing: 8, children: const [_Tag(icon: Icons.view_kanban, label: 'Pipeline'), _Tag(icon: Icons.person_search, label: 'Leads'), _Tag(icon: Icons.auto_fix_high, label: 'Automation'), _Tag(icon: Icons.bar_chart, label: 'Reports')]), ]); } }
class _Point extends StatelessWidget { final String text; const _Point({required this.text}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom:8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [ const Icon(Icons.check_circle_rounded, color: Color(0xFF6366F1), size: 20), const SizedBox(width:8), Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.4))) ])); }
class _CrmMock extends StatelessWidget { const _CrmMock(); @override Widget build(BuildContext context) { return Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: Colors.white, border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 28, offset: Offset(0,14))]), child: SizedBox(height: 480, child: Row(children: const [Expanded(flex:3, child: _PipelineBoard()), VerticalDivider(width:1, color: Color(0xFFE2E8F0)), Expanded(flex:2, child: _LeadDetailPanel())]))); } }
class _PipelineBoard extends StatelessWidget { const _PipelineBoard(); @override Widget build(BuildContext context) { final columns = [('New',3,const Color(0xFFEEF2FF)), ('Qualified',5,const Color(0xFFE0F2FE)), ('Proposal',2,const Color(0xFFF1F5F9)), ('Won',4,const Color(0xFFF0FDF4))]; return Padding(padding: const EdgeInsets.all(12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [ for (final c in columns) ...[ Expanded(child: _KanbanColumn(title: c.$1, count: c.$2, color: c.$3)), if (c != columns.last) const SizedBox(width:12) ] ])); } }
class _KanbanColumn extends StatelessWidget {
	final String title; final int count; final Color color;
	const _KanbanColumn({required this.title, required this.count, required this.color});
	@override
	Widget build(BuildContext context) {
		return Container(
			decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
			padding: const EdgeInsets.all(10),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Row(children: [
						Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
						const SizedBox(width: 6),
						Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
						const Spacer(),
						Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(999)), child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))
					]),
					const SizedBox(height: 10),
					Expanded(
						child: ListView.builder(
							physics: const NeverScrollableScrollPhysics(),
							itemCount: count,
							itemBuilder: (context, i) => Padding(
								padding: const EdgeInsets.only(bottom: 8),
								child: Container(
									padding: const EdgeInsets.all(10),
									decoration: BoxDecoration(color: color.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
									child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
										Text('Opportunity ${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
										const SizedBox(height: 4),
										Row(children: const [Icon(Icons.account_circle, size: 14, color: Color(0xFF64748B)), SizedBox(width: 4), Text('Lead assigned', style: TextStyle(fontSize: 11, color: Color(0xFF64748B)))]),
									]),
								),
							),
						),
					)
				],
			),
		);
	}
}
class _LeadDetailPanel extends StatelessWidget {
	const _LeadDetailPanel();
	@override
	Widget build(BuildContext context) {
		final activities = <(String, IconData)>[
			('Email opened', Icons.mark_email_read),
			('Call logged', Icons.call),
			('Proposal sent', Icons.file_open),
			('Reminder set', Icons.alarm),
		];
		return Column(children: [
			Container(
				padding: const EdgeInsets.all(14),
				decoration: const BoxDecoration(
					border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
					color: Color(0xFFF8FAFC),
				),
				child: Row(children: const [
					Icon(Icons.person, size: 18, color: Color(0xFF1E293B)),
					SizedBox(width: 6),
					Text('Lead Detail', style: TextStyle(fontWeight: FontWeight.w700)),
					Spacer(),
					Icon(Icons.more_horiz, size: 18, color: Color(0xFF475569)),
				]),
			),
			Expanded(
				child: Padding(
					padding: const EdgeInsets.all(12),
					child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
						Container(
							padding: const EdgeInsets.all(12),
							decoration: BoxDecoration(
								color: Colors.white,
								borderRadius: BorderRadius.circular(12),
								border: Border.all(color: const Color(0xFFE2E8F0)),
							),
							child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
								Text('Acme Corporation', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
								SizedBox(height: 4),
								Text('Stage: Qualified', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
								SizedBox(height: 4),
								Text('Value: ₹1,80,000', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
							]),
						),
						const SizedBox(height: 12),
						Expanded(
							child: Container(
								decoration: BoxDecoration(
									color: Colors.white,
									borderRadius: BorderRadius.circular(12),
									border: Border.all(color: const Color(0xFFE2E8F0)),
								),
								padding: const EdgeInsets.all(12),
								child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
									Row(children: const [
										Icon(Icons.history, size: 16, color: Color(0xFF1E293B)),
										SizedBox(width: 6),
										Text('Activity Timeline', style: TextStyle(fontWeight: FontWeight.w600)),
									]),
									const SizedBox(height: 10),
									Expanded(
										child: ListView.builder(
											physics: const NeverScrollableScrollPhysics(),
											itemCount: activities.length,
											itemBuilder: (context, i) => Padding(
												padding: const EdgeInsets.only(bottom: 10),
												child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
													Icon(activities[i].$2, size: 16, color: const Color(0xFF64748B)),
													const SizedBox(width: 8),
													Expanded(
														child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
															Text('Activity', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
															SizedBox(height: 2),
															Text('2h ago', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
														]),
													)
												]),
											),
										),
									),
								]),
							),
						),
					]),
				),
			),
		]);
	}
}
class _Tag extends StatelessWidget { final IconData icon; final String label; const _Tag({required this.icon, required this.label}); @override Widget build(BuildContext context) { return Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:6), decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size:16, color: Colors.white70), const SizedBox(width:6), Text(label, style: const TextStyle(fontSize:12, fontWeight: FontWeight.w600, color: Colors.white70))])); } }