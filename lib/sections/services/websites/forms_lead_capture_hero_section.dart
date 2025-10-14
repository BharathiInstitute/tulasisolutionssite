import 'package:flutter/material.dart';

/// Rich hero section showcasing a multi-step lead capture form preview.
/// (Implementation relocated into services/websites.)
class FormsLeadCaptureHeroSection extends StatelessWidget {
	const FormsLeadCaptureHeroSection({super.key});
	@override
	Widget build(BuildContext context) {
		final isWide = MediaQuery.sizeOf(context).width >= 880;
		final gradient = const LinearGradient(
			begin: Alignment.topLeft,
			end: Alignment.bottomRight,
			colors: [Color(0xFF0F2534), Color.fromARGB(255, 50, 111, 161), Color(0xFF1B4761)],
		);
		final content = _LeadCaptureContent(isWide: isWide);
		return Semantics(
			container: true,
			label: 'Lead capture forms hero section',
			child: Container(
				padding: EdgeInsets.symmetric(horizontal: isWide ? 56 : 28, vertical: isWide ? 72 : 48),
				decoration: BoxDecoration(
					gradient: gradient,
					borderRadius: BorderRadius.circular(32),
					border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
					boxShadow: [
						BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 50, offset: const Offset(0, 26)),
					],
				),
				child: isWide
						? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
								const Expanded(flex: 5, child: _HeroCopy()),
								const SizedBox(width: 40),
								Expanded(flex: 4, child: content),
							])
						: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
								const _HeroCopy(),
								const SizedBox(height: 36),
								content,
							]),
			),
		);
	}
}

class _HeroCopy extends StatelessWidget {
	const _HeroCopy();
	@override
	Widget build(BuildContext context) {
		final textTheme = Theme.of(context).textTheme;
		return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
			Row(children: [
				Container(
					padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
					decoration: BoxDecoration(
						color: Colors.white.withValues(alpha: 0.10),
						borderRadius: BorderRadius.circular(999),
						border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
					),
					child: const Text('FORMS · LEAD CAPTURE', style: TextStyle(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w600, color: Colors.white)),
				),
			]),
			const SizedBox(height: 22),
			Text('Convert Visitors into Qualified Leads', style: textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.05)),
			const SizedBox(height: 20),
			ConstrainedBox(
				constraints: const BoxConstraints(maxWidth: 640),
				child: Text(
					'Embed frictionless multi‑step forms that validate in real‑time, auto‑enrich contact data, and sync instantly with your CRM & automation journeys.',
					style: textTheme.titleMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85), height: 1.35, fontWeight: FontWeight.w500),
				),
			),
			const SizedBox(height: 26),
			Wrap(spacing: 12, runSpacing: 12, children: const [
				_Chip(text: 'Real‑time validation'),
				_Chip(text: 'Progressive profiling'),
				_Chip(text: 'Auto enrichment'),
				_Chip(text: 'Spam protection'),
				_Chip(text: 'CRM Sync'),
			]),
			const SizedBox(height: 34),
			Row(children: [
				FilledButton.icon(
					style: FilledButton.styleFrom(
						backgroundColor: const Color(0xFF2DD4BF),
						foregroundColor: const Color(0xFF041E2C),
						padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
					),
					onPressed: () {},
					icon: const Icon(Icons.flash_on_rounded),
					label: const Text('Get a Demo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
				),
				const SizedBox(width: 18),
				OutlinedButton(
					style: OutlinedButton.styleFrom(
						foregroundColor: Colors.white,
						padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
						side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
					),
					onPressed: () {},
					child: const Text('See Templates', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
				),
			]),
		]);
	}
}

class _Chip extends StatelessWidget {
	final String text; const _Chip({required this.text});
	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
			decoration: BoxDecoration(
				color: Colors.white.withValues(alpha: 0.10),
				borderRadius: BorderRadius.circular(999),
				border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
			),
			child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
		);
	}
}

class _LeadCaptureContent extends StatefulWidget {
	final bool isWide; const _LeadCaptureContent({required this.isWide});
	@override State<_LeadCaptureContent> createState() => _LeadCaptureContentState();
}

class _LeadCaptureContentState extends State<_LeadCaptureContent> {
	int _step = 0; // 0: info, 1: details, 2: confirm, 3: done
	final _nameCtrl = TextEditingController();
	final _emailCtrl = TextEditingController();
	final _needCtrl = TextEditingController();
	final _formKey = GlobalKey<FormState>();
	bool _submitting = false;
	@override void dispose() { _nameCtrl.dispose(); _emailCtrl.dispose(); _needCtrl.dispose(); super.dispose(); }
	void _next() { if (_step == 1) { if (!_formKey.currentState!.validate()) return; } setState(() => _step = (_step + 1).clamp(0, 3)); }
	void _back() => setState(() => _step = (_step - 1).clamp(0, 3));
	Future<void> _submit() async { if (!_formKey.currentState!.validate()) return; setState(() => _submitting = true); await Future.delayed(const Duration(milliseconds: 900)); if (!mounted) return; setState(() { _submitting = false; _step = 3; }); }
	Widget _progress() { final total = 3; final pct = (_step >= total ? total : _step) / total; return ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: Colors.white.withValues(alpha: 0.10), valueColor: const AlwaysStoppedAnimation(Color(0xFF2DD4BF)),)); }
	@override Widget build(BuildContext context) { final card = AnimatedSwitcher(duration: const Duration(milliseconds: 300), transitionBuilder: (c, anim) => FadeTransition(opacity: anim, child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(anim), child: c)), child: _step == 3 ? _Success(onReset: () => setState(() => _step = 0)) : _formSteps(),); return Semantics(label: 'Lead capture form preview', child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 38, offset: const Offset(0, 18))],), child: Column(mainAxisSize: MainAxisSize.min, children: [ Row(children: [ const Icon(Icons.forum_outlined, color: Color(0xFF041E2C)), const SizedBox(width: 8), Expanded(child: Text('Example Multi‑Step Form', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF041E2C)))), Text('Step ${(_step + 1).clamp(1, 3)} of 3', style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.55))), ],), const SizedBox(height: 14), _progress(), const SizedBox(height: 22), card, ],),),); }
	Widget _formSteps() { return Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [ if (_step == 0) ...[ Text('What brings you here?', style: _h()), const SizedBox(height: 10), Text('Choose a goal so we can tailor the next step.', style: _sub()), const SizedBox(height: 22), Wrap(spacing: 12, runSpacing: 12, children: [ _goal('Generate more leads'), _goal('Reduce spam submissions'), _goal('Better data quality'), _goal('Faster routing'), ],), ], if (_step == 1) ...[ Text('Tell us about you', style: _h()), const SizedBox(height: 10), TextFormField(controller: _nameCtrl, autocorrect: false, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,), const SizedBox(height: 14), TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Work Email', border: OutlineInputBorder()), validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,), ], if (_step == 2) ...[ Text('One last detail', style: _h()), const SizedBox(height: 10), TextFormField(controller: _needCtrl, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Describe your current form / challenge', border: OutlineInputBorder(),), validator: (v) => (v == null || v.trim().length < 8) ? 'Please provide at least 8 characters' : null,), ], const SizedBox(height: 24), Row(children: [ Expanded(child: Row(children: [ if (_step > 0) OutlinedButton(onPressed: _back, child: const Text('Back')), ],),), if (_step == 2) FilledButton(onPressed: _submitting ? null : _submit, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16)), child: _submitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit'),) else FilledButton(onPressed: _next, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16)), child: Text(_step == 0 ? 'Continue' : 'Next'),), ],), ],),); }
	Widget _goal(String label) { return Semantics(button: true, label: label, child: GestureDetector(onTap: _next, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: const Color(0xFF14324A).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF14324A).withValues(alpha: 0.35)),), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),),),); }
	TextStyle _h() => const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF041E2C));
	TextStyle _sub() => TextStyle(fontSize: 13.5, color: Colors.black.withValues(alpha: 0.65), height: 1.3);
}

class _Success extends StatelessWidget {
	final VoidCallback onReset; const _Success({required this.onReset});
	@override
	Widget build(BuildContext context) {
		return Column(key: const ValueKey('success'), children: [
			Container(width: 72, height: 72, decoration: BoxDecoration(color: const Color(0xFF2DD4BF).withValues(alpha: 0.15), shape: BoxShape.circle,), child: const Icon(Icons.check_rounded, color: Color(0xFF0E7464), size: 40),),
			const SizedBox(height: 22),
			const Text('Submitted!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF041E2C))),
			const SizedBox(height: 8),
			Text('We\'ll review your details and reach out shortly.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: Colors.black.withValues(alpha: 0.55))),
			const SizedBox(height: 28),
			FilledButton(onPressed: onReset, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16)), child: const Text('Submit Another'),),
		]);
	}
}