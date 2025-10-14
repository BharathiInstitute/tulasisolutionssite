/*
	CrmTrainingSection Implementation moved to services/training
	Original file now exports this one.
*/
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';

class CrmTrainingSection extends StatelessWidget {
	const CrmTrainingSection({
		super.key,
		this.primaryColor,
		this.maxWidth = 1200,
		this.onBookDemoTap,
		this.onSeeSampleTap,
	});

	final Color? primaryColor;
	final double maxWidth;
	final VoidCallback? onBookDemoTap;
	final VoidCallback? onSeeSampleTap;

	Color _primary(BuildContext context) => primaryColor ?? Theme.of(context).colorScheme.primary;

	@override
	Widget build(BuildContext context) {
		return LayoutBuilder(
			builder: (context, constraints) {
				final isDesktop = constraints.maxWidth >= 900;
				final content = _SectionContent(
					isDesktop: isDesktop,
					primary: _primary(context),
					onBookDemoTap: onBookDemoTap,
					onSeeSampleTap: onSeeSampleTap,
					maxWidth: maxWidth,
				);
				return TweenAnimationBuilder<double>(
					duration: const Duration(milliseconds: 450),
					curve: Curves.easeOutCubic,
					tween: Tween(begin: 30, end: 0),
					builder: (context, dy, child) => Opacity(
						opacity: (30 - dy) / 30,
						child: Transform.translate(offset: Offset(0, dy), child: child),
					),
					child: _backgroundWrapper(content),
				);
			},
		);
	}

	Widget _backgroundWrapper(Widget child) => Container(
				color: const Color(0xFFF7F7F7),
				padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
				child: Center(
					child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
				),
			);
}

class _SectionContent extends StatelessWidget {
	const _SectionContent({
		required this.isDesktop,
		required this.primary,
		required this.onBookDemoTap,
		required this.onSeeSampleTap,
		required this.maxWidth,
	});
	final bool isDesktop;
	final Color primary;
	final VoidCallback? onBookDemoTap;
	final VoidCallback? onSeeSampleTap;
	final double maxWidth;
	@override
	Widget build(BuildContext context) {
		final left = _TextColumn(primary: primary, onBookDemoTap: onBookDemoTap, onSeeSampleTap: onSeeSampleTap, isDesktop: isDesktop);
		final right = _ScreenshotCard(primary: primary, isDesktop: isDesktop);
		return DefaultTextStyle(
			style: const TextStyle(color: Color(0xFF0F172A)),
			child: IconTheme(
				data: const IconThemeData(color: Color(0xFF334155)),
				child: isDesktop
						? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 28), Expanded(child: right)])
						: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 20), right]),
			),
		);
	}
}

class _TextColumn extends StatelessWidget {
	const _TextColumn({required this.primary, required this.onBookDemoTap, required this.onSeeSampleTap, required this.isDesktop});
	final Color primary; final VoidCallback? onBookDemoTap; final VoidCallback? onSeeSampleTap; final bool isDesktop;
	@override
	Widget build(BuildContext context) {
		final headlineSize = isDesktop ? 34.0 : 28.0;
		final body = const TextStyle(fontSize: 16, height: 1.4, color: Color(0xFF0F172A));
		return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
			Text('Master Your CRM with Ease', style: TextStyle(fontSize: headlineSize, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
			const SizedBox(height: 10),
			Text('We train your team to use the CRM efficiently — from pipelines to reports, on desktop and mobile.', style: body, textScaler: MediaQuery.of(context).textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.4)),
			const SizedBox(height: 18),
			_FeaturesRow(primary: primary, isDesktop: isDesktop),
			const SizedBox(height: 18),
			Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
				_PrimaryCtaButton(label: 'Book a Demo', color: primary, onTap: onBookDemoTap),
				_TextLink(label: 'See training sample', onTap: onSeeSampleTap),
			]),
			const SizedBox(height: 20),
			_KpiStrip(primary: primary),
		]);
	}
}

class _FeaturesRow extends StatelessWidget {
	const _FeaturesRow({required this.primary, required this.isDesktop});
	final Color primary; final bool isDesktop;
	@override
	Widget build(BuildContext context) {
		final children = [
			CrmFeatureCard(iconAsset: 'assets/icons/role.svg', fallbackIcon: Icons.groups_2_outlined, title: 'Role-wise training', summary: 'Tailored sessions for Sales, Ops, and Owners.', details: 'Live, role-specific walkthroughs and checklists for each team.'),
			CrmFeatureCard(iconAsset: 'assets/icons/pipeline.svg', fallbackIcon: Icons.timeline_outlined, title: 'Pipelines, tasks, reports & mobile', summary: 'Hands-on training for pipelines, task flows, and mobile apps.', details: 'From lead to closed won, on desktop and mobile with best practices.'),
			CrmFeatureCard(iconAsset: 'assets/icons/doc_video.svg', fallbackIcon: Icons.video_library_outlined, title: 'SOP docs + short training videos', summary: 'Step-by-step SOPs plus short video demos for quick onboarding.', details: 'Reusable SOP templates and 2–3 min video demos for each step.'),
		];
		return isDesktop
				? Row(children: [for (int i = 0; i < children.length; i++) ...[Expanded(child: children[i]), if (i != children.length - 1) const SizedBox(width: 12)]])
				: Column(children: [for (int i = 0; i < children.length; i++) ...[children[i], if (i != children.length - 1) const SizedBox(height: 12)]]);
	}
}

class CrmFeatureCard extends StatefulWidget {
	const CrmFeatureCard({super.key, required this.iconAsset, required this.fallbackIcon, required this.title, required this.summary, required this.details});
	final String iconAsset; final IconData fallbackIcon; final String title; final String summary; final String details;
	@override State<CrmFeatureCard> createState() => _CrmFeatureCardState();
}
class _CrmFeatureCardState extends State<CrmFeatureCard> {
	bool _hover = false; bool _expanded = false; void _toggle() => setState(() => _expanded = !_expanded);
	@override Widget build(BuildContext context) {
		final base = Container(
			decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))], border: Border.all(color: const Color(0xFFE5E7EB))),
			padding: const EdgeInsets.all(14),
			child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
				Row(children: [
					_IconOrSvg(path: widget.iconAsset, fallback: widget.fallbackIcon), const SizedBox(width: 12),
					Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
						Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A))), const SizedBox(height: 4),
						Text(widget.summary, style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
					])),
					const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
				]),
				AnimatedCrossFade(firstChild: const SizedBox.shrink(), secondChild: Padding(padding: const EdgeInsets.only(top: 8), child: Text(widget.details, style: const TextStyle(fontSize: 14, color: Color(0xFF334155)))), crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst, duration: const Duration(milliseconds: 300)),
			]),
		);
		final lifted = AnimatedContainer(duration: const Duration(milliseconds: 150), transform: Matrix4.identity()..translate(0.0, _hover ? -6.0 : 0.0), child: base);
		return Semantics(label: '${widget.title}. ${widget.summary}', button: true, child: FocusableActionDetector(
			onShowHoverHighlight: (v) => setState(() => _hover = v),
			shortcuts: {LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent(), LogicalKeySet(LogicalKeyboardKey.space): ActivateIntent()},
			actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (i) { _toggle(); return null; })},
			child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: _toggle, child: lifted)),
		));
	}
}

class _ScreenshotCard extends StatelessWidget {
	const _ScreenshotCard({required this.primary, required this.isDesktop});
	final Color primary; final bool isDesktop;
	@override Widget build(BuildContext context) {
		final badge = Positioned(left: 12, top: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999), border: Border.all(color: primary.withValues(alpha: 0.4))), child: Text('Training preview', style: TextStyle(color: primary, fontWeight: FontWeight.w700, fontSize: 12))));
		final screenshot = ClipRRect(borderRadius: BorderRadius.circular(12), child: Stack(children: [
			Container(height: isDesktop ? 320 : 240, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 6))])),
			Positioned.fill(child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3), child: Image.asset('assets/images/crm_screenshot_blur.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE5E7EB))))),
	Positioned(left: 0, right: 0, bottom: 0, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.45)], begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))), child: Row(children: [
				_VideoThumb(primary: primary, label: 'Video 1'), const SizedBox(width: 8), _VideoThumb(primary: primary, label: 'Video 2'), const Spacer(), const Text('Live demo — blurred for privacy', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))
			]))),
	Semantics(label: 'CRM dashboard preview — blurred for privacy', image: true, child: const SizedBox.shrink()),
		]));
		final trainer = Positioned(right: 12, bottom: -20, child: _SvgIllustration(path: 'assets/illustrations/trainer.svg', size: isDesktop ? 120 : 90));
		return Stack(clipBehavior: Clip.none, children: [badge, screenshot, trainer]);
	}
}

class _VideoThumb extends StatelessWidget {
	const _VideoThumb({required this.primary, required this.label});
	final Color primary; final String label;
	@override Widget build(BuildContext context) {
		return Semantics(
			button: true,
			label: 'Open training video sample',
			child: InkWell(
				onTap: () {
					showDialog(
						context: context,
						builder: (context) => Dialog(
							backgroundColor: Colors.white,
							child: Container(
								width: 560,
								height: 320,
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.stretch,
									children: [
										Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
										const SizedBox(height: 12),
										Expanded(
											child: Container(
												decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
												alignment: Alignment.center,
												child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 64),
											),
										),
										const SizedBox(height: 12),
										Align(
											alignment: Alignment.centerRight,
											child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
										),
									],
								),
							),
						),
					);
				},
				child: Container(
					width: 90,
					height: 56,
					decoration: BoxDecoration(
						color: Colors.white.withValues(alpha: 0.85),
						borderRadius: BorderRadius.circular(8),
						border: Border.all(color: primary.withValues(alpha: 0.5)),
					),
					alignment: Alignment.center,
					child: Icon(Icons.play_arrow_rounded, color: primary),
				),
			),
		);
	}
}

class _IconOrSvg extends StatelessWidget { const _IconOrSvg({required this.path, required this.fallback}); final String path; final IconData fallback; @override Widget build(BuildContext context) { return SizedBox(width: 32, height: 32, child: SvgPicture.asset(path, width: 32, height: 32, fit: BoxFit.contain, colorFilter: const ColorFilter.mode(Color(0xFF0F172A), BlendMode.srcIn), placeholderBuilder: (_) => const Icon(Icons.work_outline))); } }
class _SvgIllustration extends StatelessWidget { const _SvgIllustration({required this.path, required this.size}); final String path; final double size; @override Widget build(BuildContext context) { return SizedBox(width: size, height: size, child: SvgPicture.asset(path, fit: BoxFit.contain, placeholderBuilder: (_) => Container(width: size, height: size, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: const Icon(Icons.work_outline, color: Color(0xFF475569))))); } }

class _PrimaryCtaButton extends StatefulWidget { const _PrimaryCtaButton({required this.label, required this.color, this.onTap}); final String label; final Color color; final VoidCallback? onTap; @override State<_PrimaryCtaButton> createState() => _PrimaryCtaButtonState(); }
class _PrimaryCtaButtonState extends State<_PrimaryCtaButton> { bool _down = false; @override Widget build(BuildContext context) { final scale = _down ? 0.98 : 1.0; return Semantics(button: true, label: widget.label, child: FocusableActionDetector(shortcuts: {LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent(), LogicalKeySet(LogicalKeyboardKey.space): ActivateIntent()}, actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (i) { widget.onTap?.call(); return null; })}, child: MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTapDown: (_) => setState(() => _down = true), onTapCancel: () => setState(() => _down = false), onTapUp: (_) => setState(() => _down = false), onTap: widget.onTap, child: AnimatedScale(scale: scale, duration: const Duration(milliseconds: 100), child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 6))]), child: const Text('Book a Demo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)))))))); } }

class _TextLink extends StatelessWidget { const _TextLink({required this.label, this.onTap}); final String label; final VoidCallback? onTap; @override Widget build(BuildContext context) { return Semantics(button: true, label: label, child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: Text(label, style: const TextStyle(decoration: TextDecoration.underline, color: Color(0xFF0F172A), fontWeight: FontWeight.w600))))); } }

class _KpiStrip extends StatelessWidget { const _KpiStrip({required this.primary}); final Color primary; @override Widget build(BuildContext context) { final isWide = MediaQuery.of(context).size.width >= 700; final items = const [_Kpi(label: 'Avg. Onboarding Time', value: '7 days', hint: 'From kickoff to live usage'), _Kpi(label: 'Team Adoption', value: '92%', hint: 'Users active weekly after training'), _Kpi(label: 'Process Accuracy', value: '+38%', hint: 'Improvement in correct pipeline usage')]; final children = [for (final k in items) Expanded(child: _KpiCard(kpi: k, primary: primary))]; return Semantics(label: 'Training performance KPIs', child: AnimatedOpacity(duration: const Duration(milliseconds: 400), opacity: 1, child: isWide ? Row(children: [for (int i = 0; i < children.length; i++) ...[children[i], if (i != children.length - 1) const SizedBox(width: 12)]]) : Column(children: [for (int i = 0; i < children.length; i++) ...[children[i], if (i != children.length - 1) const SizedBox(height: 12)]]))); } }
class _Kpi { const _Kpi({required this.label, required this.value, required this.hint}); final String label; final String value; final String hint; }
class _KpiCard extends StatefulWidget { const _KpiCard({required this.kpi, required this.primary}); final _Kpi kpi; final Color primary; @override State<_KpiCard> createState() => _KpiCardState(); }
class _KpiCardState extends State<_KpiCard> { bool _hover = false; @override Widget build(BuildContext context) { final border = widget.primary.withValues(alpha: 0.35); return MouseRegion(onEnter: (_) => setState(() => _hover = true), onExit: (_) => setState(() => _hover = false), child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: border), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _hover ? 0.10 : 0.04), blurRadius: _hover ? 22 : 12, offset: const Offset(0, 6))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.kpi.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))), const SizedBox(height: 6), Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(widget.kpi.value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: widget.primary)), const SizedBox(width: 6), Expanded(child: Text(widget.kpi.hint, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))))])]))); } }
