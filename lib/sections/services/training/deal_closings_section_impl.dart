// DealClosingsSection implementation migrated to services/training
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DealClosingsSection extends StatelessWidget {
	const DealClosingsSection({super.key, this.maxWidth = 1200, this.primaryColor = const Color(0xFF4f46e5)});
	final double maxWidth; final Color primaryColor;
	@override Widget build(BuildContext context) { return LayoutBuilder(builder: (context, constraints) { final isDesktop = constraints.maxWidth >= 900; final content = _SectionContent(isDesktop: isDesktop, primary: primaryColor); return TweenAnimationBuilder<double>(duration: const Duration(milliseconds: 420), curve: Curves.easeOut, tween: Tween(begin: 28, end: 0), builder: (context, dy, child) => Opacity(opacity: (28 - dy) / 28, child: Transform.translate(offset: Offset(0, dy), child: child)), child: _GradientBackground(child: Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: content)))); }); }
}

class _GradientBackground extends StatefulWidget { const _GradientBackground({required this.child}); final Widget child; @override State<_GradientBackground> createState() => _GradientBackgroundState(); }
class _GradientBackgroundState extends State<_GradientBackground> with SingleTickerProviderStateMixin { late final AnimationController _float; @override void initState() { super.initState(); _float = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(); } @override void dispose() { _float.dispose(); super.dispose(); } @override Widget build(BuildContext context) { return AnimatedBuilder(animation: _float, builder: (context, child) { final t = _float.value * 2 * math.pi; final y1 = math.sin(t) * 6; final y2 = math.cos(t + 1) * 8; final y3 = math.sin(t + 2) * 5; return Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30), decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF111827), Color(0xFF1e293b)])), child: Stack(children: [ Positioned(left: 24, top: 20 + y1, child: _Badge(size: 54, icon: Icons.verified_outlined)), Positioned(right: 32, top: 60 + y2, child: _Badge(size: 62, icon: Icons.handshake_outlined)), Positioned(left: 64, bottom: 30 + y3, child: _Badge(size: 58, icon: Icons.trending_up_outlined)), child!, ])); }); } }
class _Badge extends StatelessWidget { const _Badge({required this.size, required this.icon}); final double size; final IconData icon; @override Widget build(BuildContext context) => Icon(icon, size: size, color: Colors.white.withValues(alpha: 0.10)); }

class _SectionContent extends StatelessWidget { const _SectionContent({required this.isDesktop, required this.primary}); final bool isDesktop; final Color primary; @override Widget build(BuildContext context) { final left = ClosingsTextColumn(primary: primary, isDesktop: isDesktop); final right = _PipelineVisual(primary: primary); return DefaultTextStyle(style: const TextStyle(color: Colors.white), child: IconTheme(data: const IconThemeData(color: Colors.white70), child: isDesktop ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 32), Expanded(child: right)]) : Column(children: [left, const SizedBox(height: 28), right]))); } }

class ClosingsTextColumn extends StatelessWidget { const ClosingsTextColumn({super.key, required this.primary, required this.isDesktop}); final Color primary; final bool isDesktop; @override Widget build(BuildContext context) { final headlineSize = isDesktop ? 36.0 : 30.0; final sub = const TextStyle(fontSize: 16, color: Color(0xFFD1D5DB)); return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text('Predictable Conversions', style: TextStyle(fontSize: headlineSize, fontWeight: FontWeight.w800, color: Colors.white)), const SizedBox(height: 12), Text('Structure, objection handling, and smart automation to close deals faster.', style: sub), const SizedBox(height: 20), const _DealFeatureGrid(), const SizedBox(height: 20), _PrimaryCta(label: 'Explore Closings →', color: primary), const SizedBox(height: 22), _DealKpiStrip(primary: primary) ]); } }

class _DealFeatureGrid extends StatelessWidget { const _DealFeatureGrid(); @override Widget build(BuildContext context) { final data = const [ (icon: 'assets/icons/phone.svg', fallback: Icons.headset_mic_outlined, title: 'Call outcome tracking', desc: 'Script + result logging in one tap.'), (icon: 'assets/icons/email.svg', fallback: Icons.email_outlined, title: 'Smart templated replies', desc: 'Adaptive objections responses.'), (icon: 'assets/icons/automation.svg', fallback: Icons.timeline_outlined, title: 'Deal stage automations', desc: 'Auto tasks & escalations.'), (icon: 'assets/icons/check.svg', fallback: Icons.verified_user_outlined, title: 'Win-loss insights', desc: 'Reasons tracked & analyzed.'), ]; return LayoutBuilder(builder: (context, c) { final isWide = c.maxWidth >= 500; final children = [for (final f in data) _FeatureCard(icon: f.icon, fallback: f.fallback, title: f.title, desc: f.desc)]; if (isWide) { return Wrap(spacing: 14, runSpacing: 14, children: children.map((e) => SizedBox(width: (c.maxWidth - 14) / 2, child: e)).toList()); } return Column(children: [for (int i = 0; i < children.length; i++) ...[children[i], if (i != children.length - 1) const SizedBox(height: 14)]]); }); } }

class _FeatureCard extends StatefulWidget { const _FeatureCard({required this.icon, required this.fallback, required this.title, required this.desc}); final String icon; final IconData fallback; final String title; final String desc; @override State<_FeatureCard> createState() => _FeatureCardState(); }
class _FeatureCardState extends State<_FeatureCard> { bool _hover = false; @override Widget build(BuildContext context) { return MouseRegion(onEnter: (_) => setState(() => _hover = true), onExit: (_) => setState(() => _hover = false), child: AnimatedContainer(duration: const Duration(milliseconds: 160), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.15)), boxShadow: [if (_hover) BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 16, offset: const Offset(0, 8))]), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [ _IconOrSvg(path: widget.icon, fallback: widget.fallback, color: const Color(0xFF9CA3AF), semanticsLabel: widget.title), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(widget.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)), const SizedBox(height: 6), Text(widget.desc, style: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1))), ])) ]))); } }

class _PipelineVisual extends StatefulWidget { const _PipelineVisual({required this.primary}); final Color primary; @override State<_PipelineVisual> createState() => _PipelineVisualState(); }
class _PipelineVisualState extends State<_PipelineVisual> with SingleTickerProviderStateMixin { late final AnimationController _ctrl; @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward(); } @override void dispose() { _ctrl.dispose(); super.dispose(); } @override Widget build(BuildContext context) { final stages = [ _Stage(icon: Icons.person_add_alt_1_outlined, label: 'Qualified'), _Stage(svg: 'assets/icons/phone.svg', fallback: Icons.phone_outlined, label: 'Discovery'), _Stage(svg: 'assets/icons/email.svg', fallback: Icons.email_outlined, label: 'Proposal'), _Stage(svg: 'assets/icons/automation.svg', fallback: Icons.settings_suggest_outlined, label: 'Negotiation'), _Stage(icon: Icons.verified_outlined, label: 'Closed Won'), ]; return Semantics(label: 'Deal pipeline visualization from qualified to closed won', child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.15))), child: AnimatedBuilder(animation: _ctrl, builder: (context, _) { return Column(children: [ for (int i = 0; i < stages.length; i++) ...[ _PipelineStage(stage: stages[i], primary: widget.primary, t: _interval(_ctrl.value, i, stages.length)), if (i != stages.length - 1) _VerticalConnector(t: _interval(_ctrl.value, i, stages.length), color: widget.primary), ] ]); }))); }
	double _interval(double v, int i, int total) { final start = (i * 0.14).clamp(0.0, 1.0); final end = (start + 0.45).clamp(0.0, 1.0); if (v <= start) return 0; if (v >= end) return 1; return (v - start) / (end - start); }
}
class _VerticalConnector extends StatelessWidget { const _VerticalConnector({required this.t, required this.color}); final double t; final Color color; @override Widget build(BuildContext context) { return SizedBox(height: 34, child: Center(child: SizedBox(width: 5, child: Stack(children: [ Container(width: 5, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(99))), Align(alignment: Alignment.topCenter, child: AnimatedContainer(duration: const Duration(milliseconds: 160), curve: Curves.easeOut, height: 34 * t, width: 5, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)))), ])))); } }
class _PipelineStage extends StatelessWidget { const _PipelineStage({required this.stage, required this.primary, required this.t}); final _Stage stage; final Color primary; final double t; @override Widget build(BuildContext context) { final pulse = 1.0 + 0.05 * math.sin(t * math.pi); return AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: t.clamp(0.0, 1.0), child: AnimatedScale(scale: pulse, duration: const Duration(milliseconds: 200), child: Row(children: [ Container(width: 58, height: 58, decoration: BoxDecoration(color: primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99), border: Border.all(color: primary.withValues(alpha: 0.40))), alignment: Alignment.center, child: _IconOrSvg(path: stage.svg, fallback: stage.fallback ?? stage.icon ?? Icons.circle_outlined, color: Colors.white, semanticsLabel: '${stage.label} icon')), const SizedBox(width: 14), Expanded(child: Text(stage.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))), ]))); } }

class _Stage { _Stage({this.icon, this.svg, required this.label, this.fallback}); final IconData? icon; final String? svg; final String label; final IconData? fallback; }
class _IconOrSvg extends StatelessWidget { const _IconOrSvg({required this.path, required this.fallback, required this.color, required this.semanticsLabel}); final String? path; final IconData fallback; final Color color; final String semanticsLabel; @override Widget build(BuildContext context) { if (path == null) { return Semantics(label: semanticsLabel, image: true, child: Icon(fallback, color: color)); } return Semantics(label: semanticsLabel, image: true, child: SvgPicture.asset(path!, width: 26, height: 26, fit: BoxFit.contain, colorFilter: ColorFilter.mode(color, BlendMode.srcIn), placeholderBuilder: (_) => Icon(fallback, color: color))); } }

class _PrimaryCta extends StatefulWidget { const _PrimaryCta({required this.label, required this.color}); final String label; final Color color; @override State<_PrimaryCta> createState() => _PrimaryCtaState(); }
class _PrimaryCtaState extends State<_PrimaryCta> { bool _down = false; @override Widget build(BuildContext context) { return Semantics(button: true, label: widget.label, child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTapDown: (_) => setState(() => _down = true), onTapCancel: () => setState(() => _down = false), onTapUp: (_) => setState(() => _down = false), onTap: () {}, child: AnimatedScale(scale: _down ? 0.97 : 1, duration: const Duration(milliseconds: 110), child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13), decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6))]), child: Text(widget.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))))))); } }

class _DealKpiStrip extends StatelessWidget { const _DealKpiStrip({required this.primary}); final Color primary; @override Widget build(BuildContext context) { final isWide = MediaQuery.of(context).size.width >= 700; final items = const [_DealKpi(label: 'Close Rate', value: '+28%', hint: 'Improvement after scripts'), _DealKpi(label: 'Cycle Time', value: '-31%', hint: 'Faster from qualify to close'), _DealKpi(label: 'Avg. Deal Value', value: '+18%', hint: 'Upsell + cross-sell framework')]; final children = [for (final k in items) Expanded(child: _DealKpiCard(kpi: k, primary: primary))]; return Semantics(label: 'Deal closing performance KPIs', child: isWide ? Row(children: [for (int i = 0; i < children.length; i++) ...[children[i], if (i != children.length - 1) const SizedBox(width: 14)]]) : Column(children: [for (int i = 0; i < children.length; i++) ...[children[i], if (i != children.length - 1) const SizedBox(height: 14)]])); } }
class _DealKpi { const _DealKpi({required this.label, required this.value, required this.hint}); final String label; final String value; final String hint; }
class _DealKpiCard extends StatefulWidget { const _DealKpiCard({required this.kpi, required this.primary}); final _DealKpi kpi; final Color primary; @override State<_DealKpiCard> createState() => _DealKpiCardState(); }
class _DealKpiCardState extends State<_DealKpiCard> {
	bool _hover = false;
	@override
	Widget build(BuildContext context) {
		return MouseRegion(
			onEnter: (_) => setState(() => _hover = true),
			onExit: (_) => setState(() => _hover = false),
			child: AnimatedContainer(
				duration: const Duration(milliseconds: 170),
				padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
				decoration: BoxDecoration(
					color: Colors.white.withValues(alpha: 0.08),
					borderRadius: BorderRadius.circular(14),
					border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
					boxShadow: [
						if (_hover)
							BoxShadow(
								color: widget.primary.withValues(alpha: 0.30),
								blurRadius: 22,
								spreadRadius: 1,
							),
					],
				),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Text(
							widget.kpi.label,
							style: const TextStyle(
								fontSize: 12,
								fontWeight: FontWeight.w600,
								color: Colors.white70,
							),
						),
						const SizedBox(height: 6),
						Row(
							crossAxisAlignment: CrossAxisAlignment.end,
							children: [
								Text(
									widget.kpi.value,
									style: TextStyle(
										fontSize: 22,
										fontWeight: FontWeight.w800,
										color: widget.primary,
									),
								),
								const SizedBox(width: 8),
								Expanded(
									child: Text(
										widget.kpi.hint,
										style: const TextStyle(
											fontSize: 11,
											color: Color(0xFFCBD5E1),
										),
									),
								),
							],
						),
					],
				),
			),
		);
	}
}
