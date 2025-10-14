// LeadManagementSection implementation migrated to services/training
// Original sections file now exports this one to preserve legacy imports.
// (Do not re-export back to the sections file to avoid circular exports.)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LeadManagementSection extends StatelessWidget {
	const LeadManagementSection({super.key, this.maxWidth = 1200, this.primaryColor = const Color(0xFF1f6feb)});
	final double maxWidth; final Color primaryColor;
	@override
	Widget build(BuildContext context) {
		return LayoutBuilder(builder: (context, constraints) {
			final isDesktop = constraints.maxWidth >= 900;
			final content = _SectionContent(isDesktop: isDesktop, primary: primaryColor, maxWidth: maxWidth);
			return TweenAnimationBuilder<double>(
				duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic,
				tween: Tween(begin: 24, end: 0),
				builder: (context, dy, child) => Opacity(opacity: (24 - dy) / 24, child: Transform.translate(offset: Offset(0, dy), child: child)),
				child: _BackgroundWrapper(maxWidth: maxWidth, child: content),
			);
		});
	}
}

class _BackgroundWrapper extends StatelessWidget {
	const _BackgroundWrapper({required this.child, required this.maxWidth});
	final Widget child; final double maxWidth;
	@override
	Widget build(BuildContext context) => Container(
		width: double.infinity,
		decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF5F7FA), Color(0xFFE4ECF7)])),
		padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
		child: Stack(children: [
			Positioned(left: 8, top: 12, child: Icon(Icons.phone_in_talk, size: 64, color: Colors.black.withValues(alpha: 0.05))),
			Positioned(right: 12, bottom: 8, child: Icon(Icons.chat_bubble_rounded, size: 72, color: Colors.black.withValues(alpha: 0.05))),
			Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child)),
		]));
}

class _SectionContent extends StatelessWidget {
	const _SectionContent({required this.isDesktop, required this.primary, required this.maxWidth});
	final bool isDesktop; final Color primary; final double maxWidth;
	@override
	Widget build(BuildContext context) {
		final left = LeadTextColumn(primary: primary);
		final right = TimelineVisual(primary: primary);
		return DefaultTextStyle(style: const TextStyle(color: Color(0xFF0F172A)), child: IconTheme(data: const IconThemeData(color: Color(0xFF334155)), child: isDesktop ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 24), Expanded(child: right)]) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 20), right])));
	}
}

class LeadTextColumn extends StatelessWidget {
	const LeadTextColumn({super.key, required this.primary}); final Color primary;
	@override
	Widget build(BuildContext context) {
		final isDesktop = MediaQuery.of(context).size.width >= 900; final headlineSize = isDesktop ? 34.0 : 28.0; final body = const TextStyle(fontSize: 16, height: 1.4, color: Color(0xFF475569));
		return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
			Text('Convert More Leads with Speed', style: TextStyle(fontSize: headlineSize, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
			const SizedBox(height: 10),
			Text('We create a process where every lead gets fast, consistent follow-up.', style: body),
			const SizedBox(height: 18),
			_Features(primary: primary),
			const SizedBox(height: 18),
			_PrimaryCta(label: 'Improve My Lead Process →', color: primary),
			const SizedBox(height: 20),
			_LeadKpiStrip(primary: primary),
		]);
	}
}

class _Features extends StatelessWidget { const _Features({required this.primary}); final Color primary; @override Widget build(BuildContext context) { final items = const [ (icon: 'assets/icons/response.svg', fallback: Icons.timer_outlined, title: 'Response time targets & scripts', alt: 'Response time target icon'), (icon: 'assets/icons/checklist.svg', fallback: Icons.check_circle_outline, title: 'Qualification checklist', alt: 'Qualification checklist icon'), (icon: 'assets/icons/calendar.svg', fallback: Icons.calendar_month_outlined, title: 'Follow-up cadence + calendar', alt: 'Calendar icon'), ]; return LayoutBuilder(builder: (context, c) { final isDesktop = c.maxWidth >= 500; final children = [ for (final it in items) _FeatureCard(primary: primary, iconAsset: it.icon, fallback: it.fallback, title: it.title, semanticsLabel: it.alt), ]; return isDesktop ? Row(children: [for (int i = 0; i < children.length; i++) ...[Expanded(child: children[i]), if (i != children.length - 1) const SizedBox(width: 12)]]) : Column(children: [for (int i = 0; i < children.length; i++) ...[children[i], if (i != children.length - 1) const SizedBox(height: 12)]]); }); } }

class _FeatureCard extends StatefulWidget { const _FeatureCard({required this.primary, required this.iconAsset, required this.fallback, required this.title, required this.semanticsLabel}); final Color primary; final String iconAsset; final IconData fallback; final String title; final String semanticsLabel; @override State<_FeatureCard> createState() => _FeatureCardState(); }
class _FeatureCardState extends State<_FeatureCard> { bool _hover = false; @override Widget build(BuildContext context) { final card = Material(color: Colors.white, elevation: _hover ? 8 : 2, borderRadius: BorderRadius.circular(12), child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () {}, child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [ _IconOrSvg(path: widget.iconAsset, fallback: widget.fallback, semanticsLabel: widget.semanticsLabel), const SizedBox(width: 12), Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))) ])))); return Semantics(button: true, label: widget.semanticsLabel, child: MouseRegion(onEnter: (_) => setState(() => _hover = true), onExit: (_) => setState(() => _hover = false), child: AnimatedScale(duration: const Duration(milliseconds: 120), scale: _hover ? 1.03 : 1.0, child: card))); } }

class TimelineVisual extends StatefulWidget { const TimelineVisual({super.key, required this.primary}); final Color primary; @override State<TimelineVisual> createState() => _TimelineVisualState(); }
class _TimelineVisualState extends State<TimelineVisual> { int _visibleStages = 0; double _progress = 0; Timer? _timer; final _stages = const [ (label: 'Lead Inquiry', icon: Icons.call_received, alt: 'Lead inquiry icon'), (label: 'Quick Response', icon: Icons.phone_forwarded_outlined, alt: 'Quick response icon'), (label: 'Qualification', icon: Icons.fact_check_outlined, alt: 'Qualification icon'), (label: 'Follow-ups', icon: Icons.forum_outlined, alt: 'Follow-ups icon'), (label: 'Deal Closed 🎉', icon: Icons.emoji_events_outlined, alt: 'Deal closed icon'), ]; @override void initState() { super.initState(); _timer = Timer.periodic(const Duration(milliseconds: 200), (t) { if (!mounted) return; setState(() { if (_visibleStages < _stages.length) { _visibleStages++; _progress = _visibleStages / _stages.length; } else { t.cancel(); } }); }); } @override void dispose() { _timer?.cancel(); super.dispose(); } @override Widget build(BuildContext context) { final primary = widget.primary; return Semantics(label: 'Lead process timeline from inquiry to closed deal', child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))], border: Border.all(color: const Color(0xFFE5E7EB))), child: LayoutBuilder(builder: (context, c) { final double trackWidth = c.maxWidth - 16; final double progressWidth = (trackWidth * _progress).clamp(0.0, trackWidth); return Column(mainAxisSize: MainAxisSize.min, children: [ Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ for (int i = 0; i < _stages.length; i++) _StageBadge(label: _stages[i].label, icon: _stages[i].icon, visible: i < _visibleStages, primary: primary), ]), const SizedBox(height: 14), Stack(children: [ Container(height: 6, width: double.infinity, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(999))), AnimatedContainer(duration: const Duration(milliseconds: 220), curve: Curves.easeOut, height: 6, width: progressWidth, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(999))), ]), ]); }))); } }

class _StageBadge extends StatelessWidget { const _StageBadge({required this.label, required this.icon, required this.visible, required this.primary}); final String label; final IconData icon; final bool visible; final Color primary; @override Widget build(BuildContext context) { return AnimatedOpacity(duration: const Duration(milliseconds: 240), opacity: visible ? 1 : 0, child: AnimatedSlide(duration: const Duration(milliseconds: 240), offset: visible ? Offset.zero : const Offset(0, 0.2), child: Column(children: [ Container(width: 44, height: 44, decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999), border: Border.all(color: primary.withValues(alpha: 0.4))), alignment: Alignment.center, child: Icon(icon, color: primary)), const SizedBox(height: 8), SizedBox(width: 84, child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)))) ]))); } }

class _IconOrSvg extends StatelessWidget { const _IconOrSvg({required this.path, required this.fallback, required this.semanticsLabel}); final String path; final IconData fallback; final String semanticsLabel; @override Widget build(BuildContext context) { return Semantics(label: semanticsLabel, image: true, child: SizedBox(width: 28, height: 28, child: SvgPicture.asset(path, width: 28, height: 28, fit: BoxFit.contain, colorFilter: const ColorFilter.mode(Color(0xFF0F172A), BlendMode.srcIn), placeholderBuilder: (_) => Icon(fallback, color: const Color(0xFF0F172A))))); } }

class _PrimaryCta extends StatefulWidget { const _PrimaryCta({required this.label, required this.color}); final String label; final Color color; @override State<_PrimaryCta> createState() => _PrimaryCtaState(); }
class _PrimaryCtaState extends State<_PrimaryCta> { bool _down = false; @override Widget build(BuildContext context) { return Semantics(button: true, label: widget.label, child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTapDown: (_) => setState(() => _down = true), onTapCancel: () => setState(() => _down = false), onTapUp: (_) => setState(() => _down = false), onTap: () {}, child: AnimatedScale(scale: _down ? 0.98 : 1, duration: const Duration(milliseconds: 100), child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 6))]), child: const Text('Improve My Lead Process →', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))))))); } }

class _LeadKpiStrip extends StatelessWidget { const _LeadKpiStrip({required this.primary}); final Color primary; @override Widget build(BuildContext context) { final isWide = MediaQuery.of(context).size.width >= 640; final items = const [_LeadKpi(label: 'First Response', value: '5m', hint: 'Median reply time'), _LeadKpi(label: 'Qualification Rate', value: '68%', hint: 'Leads entering pipeline'), _LeadKpi(label: 'Follow-up Coverage', value: '96%', hint: 'Touches executed on schedule')]; final children = [for (final k in items) Expanded(child: _LeadKpiCard(kpi: k, primary: primary))]; return Semantics(label: 'Lead management performance KPIs', child: isWide ? Row(children: [for (int i = 0; i < children.length; i++) ...[children[i], if (i != children.length - 1) const SizedBox(width: 12)]]) : Column(children: [for (int i = 0; i < children.length; i++) ...[children[i], if (i != children.length - 1) const SizedBox(height: 12)]])); } }
class _LeadKpi { const _LeadKpi({required this.label, required this.value, required this.hint}); final String label; final String value; final String hint; }
class _LeadKpiCard extends StatefulWidget { const _LeadKpiCard({required this.kpi, required this.primary}); final _LeadKpi kpi; final Color primary; @override State<_LeadKpiCard> createState() => _LeadKpiCardState(); }
class _LeadKpiCardState extends State<_LeadKpiCard> { bool _hover = false; @override Widget build(BuildContext context) { return MouseRegion(onEnter: (_) => setState(() => _hover = true), onExit: (_) => setState(() => _hover = false), child: AnimatedContainer(duration: const Duration(milliseconds: 160), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.primary.withValues(alpha: 0.35)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _hover ? 0.10 : 0.05), blurRadius: _hover ? 20 : 12, offset: const Offset(0, 6))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.kpi.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))), const SizedBox(height: 6), Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(widget.kpi.value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: widget.primary)), const SizedBox(width: 6), Expanded(child: Text(widget.kpi.hint, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))))])]))); } }