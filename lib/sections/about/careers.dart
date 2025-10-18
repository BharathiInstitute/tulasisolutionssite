import 'package:flutter/material.dart';
import '../layout/site_scaffold.dart';
import '../../utils/url.dart' as url;

// ------------------------------------------------------------
// Inlined CareersSection & related models (moved from widgets/)
// ------------------------------------------------------------

// Color & style constants
const _applyAccent = Color(0xFFFF6B6B);

// Data models
class JobOpening {
  final String title;
  final String description;
  final String? applyUrl; // if null -> open form modal
  const JobOpening({required this.title, required this.description, this.applyUrl});
}

class CultureValue {
  final IconData icon;
  final String label;
  const CultureValue({required this.icon, required this.label});
}

/// CareersSection: responsive & accessible.
class CareersSection extends StatelessWidget {
  final List<JobOpening> openings;
  final List<CultureValue> values;
  final String? illustrationAsset; // optional background illustration asset path
  const CareersSection({super.key, required this.openings, required this.values, this.illustrationAsset});

  @override
  Widget build(BuildContext context) {
    return Container(
  color: Theme.of(context).scaffoldBackgroundColor,
  padding: const EdgeInsets.only(top: 28, bottom: 40, left: 24, right: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _Header(),
              const SizedBox(height: 28),
              _CultureValues(values: values),
              const SizedBox(height: 40),
              _OpenRolesGrid(openings: openings),
              const SizedBox(height: 24),
              _GlobalApplyCta(hasExternal: openings.any((o) => o.applyUrl != null)),
            ],
          ),
        ),
      ),
    );
  }
}

/// CareersSectionWrapper: embeddable, provides default openings/values.
class CareersSectionWrapper extends StatelessWidget {
  const CareersSectionWrapper({super.key});

  List<JobOpening> get _openings => const [
        JobOpening(
          title: 'Senior Flutter Engineer',
          description: 'Build high-performance cross-platform apps. Optimize architecture & mentor juniors.',
        ),
        JobOpening(
          title: 'UI/UX Designer',
          description: 'Design accessible, conversion-focused user journeys across web + mobile.',
          applyUrl: 'https://example.com/apply/designer',
        ),
      ];

  List<CultureValue> get _values => const [
        CultureValue(icon: Icons.school_rounded, label: 'Learning'),
        CultureValue(icon: Icons.emoji_objects_rounded, label: 'Creativity'),
      ];

  @override
  Widget build(BuildContext context) {
    return CareersSection(openings: _openings, values: _values);
  }
}

// ---------------- Header ----------------
class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    const titleColor = Color(0xFF0D1B2A);
    const subtitleColor = Color(0xFF284B63);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final double titleSize = screenWidth >= 900 ? 36 : 30;
    final double subtitleSize = screenWidth >= 900 ? 18 : 16;
    return Semantics(
      container: true,
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Transform.translate(
            offset: const Offset(-12, 0),
            child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🚀', style: TextStyle(fontSize: 40)),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Grow With Us',
                  style: (theme.headlineMedium ?? const TextStyle()).copyWith(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    height: 1.05,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'We\'re always looking for passionate designers, developers, marketers, and strategists.',
            style: (theme.titleMedium ?? const TextStyle()).copyWith(
              fontSize: subtitleSize,
              color: subtitleColor,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------- Culture Values Chips ----------------
class _CultureValues extends StatelessWidget {
  final List<CultureValue> values;
  const _CultureValues({required this.values});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final v in values)
          _ValueChip(icon: v.icon, label: v.label, color: scheme.primary),
      ],
    );
  }
}

class _ValueChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ValueChip({required this.icon, required this.label, required this.color});
  @override
  State<_ValueChip> createState() => _ValueChipState();
}

class _ValueChipState extends State<_ValueChip> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: c.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: c.withValues(alpha: .35), width: 1.4),
          boxShadow: [
            if (_hover)
              BoxShadow(
                color: Colors.black.withValues(alpha: .18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: .12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: c, size: 18),
            const SizedBox(width: 8),
            Text(widget.label, style: TextStyle(fontWeight: FontWeight.w600, color: c)),
          ],
        ),
      ),
    );
  }
}

// ---------------- Open Roles Grid ----------------
class _OpenRolesGrid extends StatelessWidget {
  final List<JobOpening> openings;
  const _OpenRolesGrid({required this.openings});
  @override
  Widget build(BuildContext context) {
    if (openings.isEmpty) {
      return const Text('No open roles right now. Check back soon!', style: TextStyle(color: Colors.black87));
    }
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      int cols = w >= 1100 ? 3 : (w >= 750 ? 2 : 1);
      if (openings.length < cols) cols = openings.length.clamp(1, cols);
  const tileWidth = 380.0;
      const spacing = 22.0;
      final gridMaxWidth = (cols * tileWidth) + ((cols - 1) * spacing);
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: gridMaxWidth),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisExtent: 230,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: openings.length,
            itemBuilder: (context, i) => _RoleCard(opening: openings[i]),
          ),
        ),
      );
    });
  }
}

class _RoleCard extends StatefulWidget {
  final JobOpening opening;
  const _RoleCard({required this.opening});
  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _hover = false;
  bool _focus = false;
  void _apply() {
    final o = widget.opening;
    if (o.applyUrl != null) {
      // Open external link via shared util wrapper (avoids coupling to url_launcher here)
      url.launchExternal(o.applyUrl!).then((ok) {
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open link')),
          );
        }
      });
    } else {
      _showApplyDialog(context, o);
    }
  }
  @override
  Widget build(BuildContext context) {
    final scale = _hover ? 1.02 : 1.0;
    return FocusableActionDetector(
      onShowFocusHighlight: (f) => setState(() => _focus = f),
      onFocusChange: (f) => setState(() => _focus = f),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: _apply,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.identity()..scale(scale),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hover ? .22 : .12),
                  blurRadius: _hover ? 26 : 16,
                  offset: const Offset(0, 12),
                ),
              ],
              border: Border.all(color: _focus ? _applyAccent : Colors.black.withValues(alpha: .06), width: _focus ? 2 : 1),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.opening.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black87)),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    widget.opening.description,
                    style: const TextStyle(fontSize: 14.5, height: 1.4, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: _ApplyButton(onPressed: _apply, label: 'Apply', small: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Global Apply CTA ----------------
class _GlobalApplyCta extends StatelessWidget {
  final bool hasExternal;
  const _GlobalApplyCta({required this.hasExternal});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: _ApplyButton(
        onPressed: () => _showGeneralApplyDialog(context),
        label: hasExternal ? 'Apply / General Interest' : 'Apply Now',
      ),
    );
  }
}

// Apply button component
class _ApplyButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;
  final bool small;
  const _ApplyButton({required this.onPressed, required this.label, this.small = false});
  @override
  State<_ApplyButton> createState() => _ApplyButtonState();
}

class _ApplyButtonState extends State<_ApplyButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: _hover ? 1.04 : 1.0,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _applyAccent,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: widget.small ? 16 : 24, vertical: widget.small ? 10 : 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          onPressed: widget.onPressed,
          icon: const Icon(Icons.edit_note_rounded), // 📝 form icon alternative
          label: Text(widget.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: widget.small ? 13 : 15)),
        ),
      ),
    );
  }
}

// ---------------- Apply Dialogs ----------------
void _showApplyDialog(BuildContext context, JobOpening opening) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .55),
    builder: (ctx) => _ApplyDialog(opening: opening),
  );
}

void _showGeneralApplyDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .55),
    builder: (ctx) => const _ApplyDialog(),
  );
}

class _ApplyDialog extends StatefulWidget {
  final JobOpening? opening;
  const _ApplyDialog({this.opening});
  @override
  State<_ApplyDialog> createState() => _ApplyDialogState();
}

class _ApplyDialogState extends State<_ApplyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context).pop();
    final rolePart = widget.opening != null ? ' for ${widget.opening!.title}' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Application submitted$rolePart!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final opening = widget.opening;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.edit_note_rounded, color: _applyAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(opening == null ? 'General Application' : 'Apply: ${opening.title}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: InputDecoration(labelText: opening == null ? 'Role(s) of interest / Notes' : 'Notes (optional)'),
                  minLines: 2,
                  maxLines: 5,
                ),
                const SizedBox(height: 18),
                // Resume placeholder (Skipping file upload integration for now)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withValues(alpha: .15)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.upload_file_rounded, color: Colors.black54),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('Resume upload coming soon', style: TextStyle(color: Colors.black54)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: _applyAccent, foregroundColor: Colors.white),
          child: _submitting
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Submit'),
        ),
      ],
    );
  }
}

/// CareersPage: dedicated careers listing / hiring page.
class CareersPage extends StatelessWidget {
  const CareersPage({super.key});

  List<JobOpening> get _openings => const [
        JobOpening(
          title: 'Senior Flutter Engineer',
          description: 'Build high-performance cross-platform apps. Optimize architecture & mentor juniors.',
        ),
        JobOpening(
          title: 'UI/UX Designer',
          description: 'Design accessible, conversion-focused user journeys across web + mobile.',
          applyUrl: 'https://example.com/apply/designer',
        ),
        JobOpening(
          title: 'Growth Marketing Strategist',
          description: 'Own funnel experiments, lifecycle campaigns and cohort retention insights.',
        ),
        JobOpening(
          title: 'Automation Engineer',
          description: 'Integrate APIs, build workflow automation & internal tooling efficiencies.',
        ),
        JobOpening(
          title: 'Brand Content Specialist',
          description: 'Craft compelling multi-channel narratives & long-form marketing assets.',
        ),
      ];

  List<CultureValue> get _values => const [
        CultureValue(icon: Icons.school_rounded, label: 'Learning'),
        CultureValue(icon: Icons.emoji_objects_rounded, label: 'Creativity'),
        CultureValue(icon: Icons.auto_fix_high_rounded, label: 'Innovation'),
        CultureValue(icon: Icons.handshake_rounded, label: 'Ownership'),
      ];

  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          CareersSection(openings: _openings, values: _values),
        ],
      ),
    );
  }
}
