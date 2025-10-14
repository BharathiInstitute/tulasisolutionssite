import 'package:flutter/material.dart';

/// Clean minimal SalesTargetSettingSection (old complex UI removed).
class SalesTargetSettingSection extends StatelessWidget {
	const SalesTargetSettingSection({super.key});

	@override
		Widget build(BuildContext context) {
			final targets = _sampleTargets();
			final totalTarget = targets.fold<int>(0, (s, t) => s + t.target);
			final totalAchieved = targets.fold<int>(0, (s, t) => s + t.achieved);
			final pct = totalTarget == 0 ? 0.0 : totalAchieved / totalTarget;
			return Padding(
				padding: const EdgeInsets.all(16),
				child: Center(
					child: ConstrainedBox(
						constraints: const BoxConstraints(maxWidth: 800),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							mainAxisSize: MainAxisSize.min,
							children: [
								Row(children: const [
									Icon(Icons.flag, size: 20, color: Color(0xFF0f172a)),
									SizedBox(width: 8),
									Text('Sales Target Setting', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0f172a))),
								]),
								const SizedBox(height: 6),
								const Text('Quick view of rep targets vs achieved.', style: TextStyle(color: Color(0xFF475569))),
								const SizedBox(height: 18),
								_TeamBar(pct: pct, totalTarget: totalTarget, totalAchieved: totalAchieved),
								const SizedBox(height: 24),
								const _HeaderRow(),
								const Divider(height: 18),
								for (final t in targets) _RepRow(target: t),
							],
						),
					),
				),
			);
		}
		List<_Target> _sampleTargets() => const [
			_Target(rep: 'Ava', target: 100, achieved: 118),
			_Target(rep: 'Ravi', target: 100, achieved: 92),
			_Target(rep: 'Mia', target: 100, achieved: 85),
			_Target(rep: 'Liam', target: 100, achieved: 76),
			_Target(rep: 'Zoe', target: 100, achieved: 64),
		];
	}

	class _TeamBar extends StatelessWidget {
	const _TeamBar({required this.pct, required this.totalTarget, required this.totalAchieved});
	final double pct;
	final int totalTarget;
	final int totalAchieved;
	@override
	Widget build(BuildContext context) {
		final pctStr = (pct * 100).clamp(0, 999).toStringAsFixed(0);
		final color = pct >= 1 ? const Color(0xFF16a34a) : const Color(0xFF1f6feb);
		return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
			Text('Team Progress: $pctStr%', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0f172a))),
			const SizedBox(height: 8),
			ClipRRect(
				borderRadius: BorderRadius.circular(8),
				child: LinearProgressIndicator(
					value: pct.clamp(0.0, 1.2),
					minHeight: 14,
					backgroundColor: const Color(0xFFE2E8F0),
					valueColor: AlwaysStoppedAnimation(color),
				),
			),
			const SizedBox(height: 4),
			Text('$totalAchieved of $totalTarget achieved', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
		]);
	}
}

class _HeaderRow extends StatelessWidget {
		const _HeaderRow();
		@override
		Widget build(BuildContext context) {
			return Row(children: const [
				Expanded(child: Text('Rep', style: TextStyle(fontWeight: FontWeight.bold))),
				Expanded(child: Text('Target', style: TextStyle(fontWeight: FontWeight.bold))),
				Expanded(child: Text('Achieved', style: TextStyle(fontWeight: FontWeight.bold))),
			]);
		}
}

class _RepRow extends StatelessWidget {
	final _Target target;
	const _RepRow({required this.target});
	@override
	Widget build(BuildContext context) {
		return Row(children: [
			Expanded(child: Text(target.rep)),
			Expanded(child: Text('${target.target}')),
			Expanded(child: Text('${target.achieved}')),
		]);
	}
}

class _Target {
	final String rep;
	final int target;
	final int achieved;
	const _Target({required this.rep, required this.target, required this.achieved});
}
