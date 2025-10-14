import 'package:flutter/material.dart';

class HrManagementHeroSection extends StatelessWidget {
	const HrManagementHeroSection({super.key});
	@override
	Widget build(BuildContext context) {
		return Container(
			decoration: const BoxDecoration(
				gradient: LinearGradient(
					colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
					begin: Alignment.topLeft,
					end: Alignment.bottomRight,
				),
			),
			padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 54),
			child: Center(
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 1000),
					child: LayoutBuilder(
						builder: (context, c) {
							final isWide = c.maxWidth > 820;
							final column = Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text('People & Performance', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.05)),
									const SizedBox(height: 14),
									Text('Centralized employee data, attendance, leave and performance tracking that scales with your organization.',
											style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70, height: 1.5)),
									const SizedBox(height: 26),
									Wrap(spacing: 10, runSpacing: 10, children: const [
										_HrChip('Onboarding'),
										_HrChip('Attendance'),
										_HrChip('Leaves'),
										_HrChip('Performance'),
										_HrChip('Payroll Prep'),
									]),
									const SizedBox(height: 30),
									SizedBox(
										height: 46,
										child: ElevatedButton(
											style: ElevatedButton.styleFrom(
												backgroundColor: const Color(0xFF6366F1),
												foregroundColor: Colors.white,
												shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
												padding: const EdgeInsets.symmetric(horizontal: 30),
											),
											onPressed: () => ScaffoldMessenger.of(context)
													.showSnackBar(const SnackBar(content: Text('HR module engagement coming soon!'))),
											child: const Text('Streamline HR', style: TextStyle(fontWeight: FontWeight.w600)),
										),
									),
								],
							);

							final panels = const _HrPanels();
							return isWide
									? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
											Expanded(flex: 5, child: column),
											const SizedBox(width: 40),
											Expanded(flex: 6, child: panels),
										])
									: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
											column,
											const SizedBox(height: 40),
											panels,
										]);
						},
					),
				),
			),
		);
	}
}

class _HrChip extends StatelessWidget {
	final String label; const _HrChip(this.label);
	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
			decoration: BoxDecoration(
				color: Colors.white.withValues(alpha: 0.12),
				borderRadius: BorderRadius.circular(999),
				border: Border.all(color: Colors.white24),
			),
			child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
		);
	}
}

class _HrPanels extends StatelessWidget {
	const _HrPanels();
	@override
	Widget build(BuildContext context) {
		return Wrap(
			spacing: 18,
			runSpacing: 18,
			children: const [
				_StatPanel(icon: Icons.group, value: '82', label: 'Employees'),
				_StatPanel(icon: Icons.login, value: '78', label: 'Checked-in'),
				_StatPanel(icon: Icons.beach_access, value: '6', label: 'On Leave'),
				_StatPanel(icon: Icons.rule, value: '12', label: 'Pending Reviews'),
				_AttendancePanel(),
				_LeavePanel(),
			],
		);
	}
}

class _StatPanel extends StatelessWidget {
	final IconData icon; final String value; final String label; const _StatPanel({required this.icon, required this.value, required this.label});
	@override
	Widget build(BuildContext context) {
		return Container(
			width: 150,
			padding: const EdgeInsets.all(14),
			decoration: BoxDecoration(
				color: const Color(0xFF1E1B4B),
				borderRadius: BorderRadius.circular(16),
				border: Border.all(color: const Color(0xFF312E81)),
			),
			child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
				Icon(icon, color: const Color(0xFF6366F1), size: 18),
				const SizedBox(height: 10),
				Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
				const SizedBox(height: 4),
				Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
			]),
		);
	}
}

class _AttendancePanel extends StatelessWidget {
	const _AttendancePanel();
	@override
	Widget build(BuildContext context) {
		final data = const [
			('Mon', 82),
			('Tue', 79),
			('Wed', 81),
			('Thu', 77),
			('Fri', 78),
		];
		return Container(
			width: 310,
			padding: const EdgeInsets.all(16),
			decoration: BoxDecoration(
				color: const Color(0xFF1E1B4B),
				borderRadius: BorderRadius.circular(18),
				border: Border.all(color: const Color(0xFF312E81)),
			),
			child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
				const Text('Attendance %', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
				const SizedBox(height: 14),
				Row(
					crossAxisAlignment: CrossAxisAlignment.end,
					children: [
						for (final d in data)
							Expanded(
								child: Padding(
									padding: const EdgeInsets.symmetric(horizontal: 4),
									child: Column(
										mainAxisAlignment: MainAxisAlignment.end,
										children: [
											Container(
												height: (d.$2 / 100) * 90,
												decoration: BoxDecoration(
													color: const Color(0xFF6366F1),
													borderRadius: BorderRadius.circular(6),
												),
											),
											const SizedBox(height: 6),
											Text(d.$1, style: const TextStyle(color: Colors.white54, fontSize: 11)),
										],
									),
								),
							),
					],
				),
			]),
		);
	}
}

class _LeavePanel extends StatelessWidget {
	const _LeavePanel();
	@override
	Widget build(BuildContext context) {
		final leaves = const [
			('Annual', 38, 80),
			('Sick', 12, 40),
			('Comp Off', 6, 20),
		];
		return Container(
			width: 310,
			padding: const EdgeInsets.all(16),
			decoration: BoxDecoration(
				color: const Color(0xFF1E1B4B),
				borderRadius: BorderRadius.circular(18),
				border: Border.all(color: const Color(0xFF312E81)),
			),
			child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
				const Text('Leave Utilization', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
				const SizedBox(height: 14),
				for (final l in leaves)
					Padding(
						padding: const EdgeInsets.only(bottom: 10),
						child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
							Row(children: [
								Expanded(child: Text(l.$1, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600))),
								Text('${l.$2} used', style: const TextStyle(color: Colors.white, fontSize: 12)),
							]),
							const SizedBox(height: 6),
							LayoutBuilder(
								builder: (context, c2) {
									final pct = l.$3 / 100;
									return Stack(children: [
										Container(
											height: 8,
											decoration: BoxDecoration(
												color: Colors.white12,
												borderRadius: BorderRadius.circular(4),
											),
										),
										AnimatedContainer(
											duration: const Duration(milliseconds: 600),
											curve: Curves.easeOut,
											height: 8,
											width: c2.maxWidth * pct,
											decoration: BoxDecoration(
												gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]),
												borderRadius: BorderRadius.circular(4),
											),
										)
									]);
								},
							),
						]),
					),
			]),
		);
	}
}