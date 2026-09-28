import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/chat/chat.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/app_drawer.dart';

class TemplateManagementScreen extends ConsumerStatefulWidget {
  const TemplateManagementScreen({super.key});

  @override
  ConsumerState<TemplateManagementScreen> createState() =>
      _TemplateManagementScreenState();
}

class _TemplateManagementScreenState
    extends ConsumerState<TemplateManagementScreen> {
  List<MessageTemplate>? _templates;
  List<MessageTemplate>? _pendingTemplates;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTemplates());
  }

  Future<void> _loadTemplates() async {
    final msg91 = ref.read(chatProvider).msg91Service;
    if (msg91 == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        msg91.getTemplates(channel: 'whatsapp'),
        msg91.getPendingWhatsAppTemplates(),
      ]);
      if (!mounted) return;
      setState(() {
        _templates = results[0];
        _pendingTemplates = results[1];
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not load templates: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateDialog() async {
    final msg91 = ref.read(chatProvider).msg91Service;
    if (msg91 == null) return;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateTemplateDialog(msg91: msg91),
    );
    if (submitted == true) await _loadTemplates();
  }

  @override
  Widget build(BuildContext context) {

    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/templates',
      title: 'WhatsApp Templates',
      actions: [
        IconButton(
          onPressed: _loading ? null : _loadTemplates,
          tooltip: 'Refresh from MSG91',
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Template'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!, textAlign: TextAlign.center))
                : _templates == null
                ? Center(
                    child: FilledButton.icon(
                      onPressed: _loadTemplates,
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('Load Templates'),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    children: [
                      Text('Templates are synced directly from MSG91.', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      _StatusHeading(
                        title: 'Approved and Sendable',
                        count: _templates!.length,
                      ),
                      ..._templates!.map((template) => _TemplateTile(template: template)),
                      if (_templates!.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 56),
                            child: Text('No approved templates with sendable message text were found.'),
                          ),
                        ),
                      if (_pendingTemplates?.isNotEmpty == true) ...[
                        const SizedBox(height: 24),
                        _StatusHeading(
                          title: 'Awaiting Approval',
                          count: _pendingTemplates!.length,
                        ),
                        ..._pendingTemplates!.map(
                          (template) => _TemplateTile(template: template),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusHeading extends StatelessWidget {
  final String title;
  final int count;
  const _StatusHeading({required this.title, required this.count});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(width: 8),
      Chip(label: Text('$count')),
    ]),
  );
}

class _TemplateTile extends StatelessWidget {
  final MessageTemplate template;
  const _TemplateTile({required this.template});

  @override
  Widget build(BuildContext context) {
    final status = template.status.toLowerCase();
    final color = status == 'approved'
        ? Colors.green
        : status.contains('reject')
        ? Colors.red
        : Colors.orange;
    return Card(
      child: ListTile(
        title: Text(template.name),
        subtitle: Text(
          template.content.isEmpty ? 'No body returned by MSG91' : template.content,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Chip(
          label: Text(template.status),
          labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _CreateTemplateDialog extends StatefulWidget {
  final MSG91Service msg91;
  const _CreateTemplateDialog({required this.msg91});

  @override
  State<_CreateTemplateDialog> createState() => _CreateTemplateDialogState();
}

class _CreateTemplateDialogState extends State<_CreateTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _body = TextEditingController(
    text: 'Hi {{1}}, welcome to Tulasi Solutions.',
  );
  final _footer = TextEditingController();
  final _ctaUrl = TextEditingController();
  final _ctaLabel = TextEditingController(text: 'Visit Website');
  final _headerImageUrl = TextEditingController();
  String _category = 'marketing';
  String _language = 'en';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _body.dispose();
    _footer.dispose();
    _ctaUrl.dispose();
    _ctaLabel.dispose();
    _headerImageUrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; _error = null; });
    try {
      await widget.msg91.submitWhatsAppTemplate(
        name: _name.text.trim().toLowerCase(),
        body: _body.text.trim(),
        footer: _footer.text.trim(),
        ctaUrl: _ctaUrl.text.trim(),
        ctaLabel: _ctaLabel.text.trim(),
        headerImageUrl: _headerImageUrl.text.trim(),
        category: _category,
        language: _language,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template submitted to MSG91 and is awaiting approval.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        final message = '$error';
        setState(() {
          _error = message.contains('already English content for this template')
              ? 'This template name already exists in MSG91. Use a new unique name, for example hello_tulasi_2026.'
              : message;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Submit WhatsApp Template'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Template name',
                helperText: 'Must be unique in MSG91.',
              ),
              validator: (value) => value == null || !RegExp(r'^[a-z0-9_]+$').hasMatch(value.trim())
                  ? 'Use lowercase letters, numbers, and underscores only'
                  : null,
            ),
            TextFormField(
              controller: _body,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Message body', hintText: 'Hi {{1}}, your appointment is confirmed.'),
              validator: (value) => value == null || value.trim().isEmpty ? 'Message body is required' : null,
            ),
            TextFormField(controller: _footer, decoration: const InputDecoration(labelText: 'Footer (optional)')),
            TextFormField(
              controller: _headerImageUrl,
              decoration: const InputDecoration(
                labelText: 'Header image URL (optional)',
                helperText: 'Public HTTPS image used in the WhatsApp template header.',
              ),
              validator: (value) {
                final url = value?.trim() ?? '';
                if (url.isEmpty) return null;
                final uri = Uri.tryParse(url);
                return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
                    ? null
                    : 'Enter a valid HTTPS image URL';
              },
            ),
            TextFormField(
              controller: _ctaUrl,
              decoration: const InputDecoration(labelText: 'CTA URL (optional)'),
              validator: (value) {
                final url = value?.trim() ?? '';
                if (url.isEmpty) return null;
                final uri = Uri.tryParse(url);
                return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
                    ? null
                    : 'Enter a valid HTTPS URL';
              },
            ),
            TextFormField(
              controller: _ctaLabel,
              decoration: const InputDecoration(labelText: 'CTA button label'),
              validator: (value) {
                if (_ctaUrl.text.trim().isEmpty) return null;
                final label = value?.trim() ?? '';
                return label.isEmpty || label.length > 25
                    ? 'Use 1-25 characters'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(initialValue: _category, decoration: const InputDecoration(labelText: 'Category'), items: const [DropdownMenuItem(value: 'utility', child: Text('Utility')), DropdownMenuItem(value: 'marketing', child: Text('Marketing')), DropdownMenuItem(value: 'authentication', child: Text('Authentication'))], onChanged: (value) => setState(() => _category = value!))),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<String>(initialValue: _language, decoration: const InputDecoration(labelText: 'Language'), items: const [DropdownMenuItem(value: 'en', child: Text('English')), DropdownMenuItem(value: 'hi', child: Text('Hindi')), DropdownMenuItem(value: 'te', child: Text('Telugu'))], onChanged: (value) => setState(() => _language = value!))),
            ]),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ]),
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: _submitting ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _submitting ? null : _submit, child: Text(_submitting ? 'Submitting...' : 'Submit for Approval')),
    ],
  );
}