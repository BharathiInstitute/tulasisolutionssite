import 'package:flutter/material.dart';

/// A simple contact form section that accepts optional controllers and keys.
///
/// If callers don't provide controllers or a form key, this widget will create
/// them internally and dispose them when removed from the tree.
class ContactFormSection extends StatefulWidget {
  const ContactFormSection({
    super.key,
    this.anchorKey,
    this.formKey,
    this.nameCtrl,
    this.businessCtrl,
    this.emailCtrl,
    this.phoneCtrl,
    this.messageCtrl,
  });

  final Key? anchorKey;
  final GlobalKey<FormState>? formKey;
  final TextEditingController? nameCtrl;
  final TextEditingController? businessCtrl;
  final TextEditingController? emailCtrl;
  final TextEditingController? phoneCtrl;
  final TextEditingController? messageCtrl;

  @override
  State<ContactFormSection> createState() => _ContactFormSectionState();
}

class _ContactFormSectionState extends State<ContactFormSection> {
  late final GlobalKey<FormState> _formKey;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _businessCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _messageCtrl;
  bool _agree = false;

  // Track whether controllers were provided by the caller so we only dispose
  // the ones we created.
  late final bool _disposeName;
  late final bool _disposeBusiness;
  late final bool _disposeEmail;
  late final bool _disposePhone;
  late final bool _disposeMessage;

  @override
  void initState() {
    super.initState();
    _formKey = widget.formKey ?? GlobalKey<FormState>();
    _disposeName = widget.nameCtrl == null;
    _disposeBusiness = widget.businessCtrl == null;
    _disposeEmail = widget.emailCtrl == null;
    _disposePhone = widget.phoneCtrl == null;
    _disposeMessage = widget.messageCtrl == null;

    _nameCtrl = widget.nameCtrl ?? TextEditingController();
    _businessCtrl = widget.businessCtrl ?? TextEditingController();
    _emailCtrl = widget.emailCtrl ?? TextEditingController();
    _phoneCtrl = widget.phoneCtrl ?? TextEditingController();
    _messageCtrl = widget.messageCtrl ?? TextEditingController();
  }

  @override
  void dispose() {
    if (_disposeName) _nameCtrl.dispose();
    if (_disposeBusiness) _businessCtrl.dispose();
    if (_disposeEmail) _emailCtrl.dispose();
    if (_disposePhone) _phoneCtrl.dispose();
    if (_disposeMessage) _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Accent color similar to screenshot_17 style
    const accent = Color(0xFF0EA5E9); // cyan-500

    InputDecoration dec(String label) => InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent.withValues(alpha: 0.5), width: 1.2)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: accent, width: 1.6)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        );

    return Form(
      key: _formKey,
      child: Container(
        key: widget.anchorKey,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(controller: _nameCtrl, decoration: dec('Name')),
            const SizedBox(height: 12),
            TextFormField(controller: _businessCtrl, decoration: dec('Business')),
            const SizedBox(height: 12),
            TextFormField(controller: _emailCtrl, decoration: dec('Email Address')),
            const SizedBox(height: 12),
            TextFormField(controller: _phoneCtrl, decoration: dec('Phone')),
            const SizedBox(height: 12),
            TextFormField(controller: _messageCtrl, decoration: dec('Message'), maxLines: 4),
            const SizedBox(height: 14),
            CheckboxListTile(
              value: _agree,
              onChanged: (v) => setState(() => _agree = v ?? false),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I accept terms & conditions', style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _agree
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form submitted (placeholder)')));
                      }
                    : null,
                borderRadius: BorderRadius.circular(28),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF2563EB)]),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text(
                        'Submit & Get Call Back',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Illustration for "Contact Form — Send Us a Message" hero
class ContactFormHero extends StatelessWidget {
  const ContactFormHero({super.key, this.onScrollToForm});
  final VoidCallback? onScrollToForm;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          child: AspectRatio(
            aspectRatio: 1200 / 500,
            child: Container(color: Theme.of(context).scaffoldBackgroundColor),
          ),
        ),
        if (onScrollToForm != null)
          Align(
            alignment: Alignment.center,
            child: FilledButton(
              onPressed: onScrollToForm,
              child: const Text('Send us a message'),
            ),
          ),
      ],
    );
  }
}

class ContactFormCardSection extends StatelessWidget {
  const ContactFormCardSection({
    super.key,
    this.anchorKey,
  });

  final Key? anchorKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final w = MediaQuery.sizeOf(context).width;
    final bool isMobile = w < 700;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          // Allow heading/subtitle to be wider so subtitle can be one line
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('📝', style: TextStyle(fontSize: isMobile ? 24 : 26, color: scheme.primary)),
                  const SizedBox(width: 8),
                  Text(
                    'Send Us a Message',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: isMobile ? 30 : 34,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0D1B2A),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us a bit about your needs. We typically respond within a few hours.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF284B63),
                    ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ContactFormSection(anchorKey: anchorKey),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContactFooterSection extends StatelessWidget {
  const ContactFooterSection({super.key});
  @override
  Widget build(BuildContext context) {
    final linkStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      color: const Color(0xFF0F1A2B),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text('Services', style: linkStyle),
                  Text('Industries', style: linkStyle),
                  Text('Pricing', style: linkStyle),
                  Text('Portfolio', style: linkStyle),
                  // Resources removed
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  const Text('⚖️', style: TextStyle(color: Colors.white70)),
                  Text('Privacy', style: linkStyle),
                  Text('Terms', style: linkStyle),
                  Text('Refund/Cancel', style: linkStyle),
                  const SizedBox(width: 12),
                  const Text('🔗', style: TextStyle(color: Colors.white70)),
                  Text('WhatsApp', style: linkStyle),
                  Text('Email', style: linkStyle),
                ],
              ),
              const SizedBox(height: 12),
              Text('© Tulasi Solutions — All rights reserved', style: linkStyle),
            ],
          ),
        ),
      ),
    );
  }
}
