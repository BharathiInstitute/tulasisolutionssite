import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/models/website_brief.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';

class ClientWebsiteBriefScreen extends ConsumerWidget {
  final String? planId;

  const ClientWebsiteBriefScreen({super.key, this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(currentClientProvider);
    return AppShell(
      isAdmin: false,
      currentRoute: '/client/website-brief',
      title: 'Website Brief',
      body: clientAsync.when(
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) =>
            CustomErrorWidget(message: 'Could not load your profile: $error'),
        data: (client) {
          if (client == null) {
            return const Center(child: Text('Client profile not found'));
          }
          return ref
              .watch(plansProvider(client.id))
              .when(
                loading: () => const LoadingWidget(),
                error: (error, stackTrace) =>
                    CustomErrorWidget(message: 'Could not load plans: $error'),
                data: (plans) {
                  if (plans.isEmpty) {
                    return const Center(
                      child: Text(
                        'A plan is required before creating a brief.',
                      ),
                    );
                  }
                  final plan =
                      plans.where((item) => item.id == planId).firstOrNull ??
                      plans.first;
                  return ref
                      .watch(websiteBriefProvider(plan.id))
                      .when(
                        loading: () => const LoadingWidget(),
                        error: (error, stackTrace) => CustomErrorWidget(
                          message: 'Could not load website brief: $error',
                        ),
                        data: (brief) => WebsiteBriefEditor(
                          key: ValueKey(plan.id),
                          plan: plan,
                          client: client,
                          initialBrief: brief,
                          allPlans: plans,
                        ),
                      );
                },
              );
        },
      ),
    );
  }
}

class WebsiteBriefEditor extends ConsumerStatefulWidget {
  final Plan plan;
  final Client client;
  final WebsiteBrief? initialBrief;
  final List<Plan> allPlans;
  final bool adminMode;
  final VoidCallback? onDone;

  const WebsiteBriefEditor({
    super.key,
    required this.plan,
    required this.client,
    required this.initialBrief,
    required this.allPlans,
    this.adminMode = false,
    this.onDone,
  });

  @override
  ConsumerState<WebsiteBriefEditor> createState() => _WebsiteBriefEditorState();
}

class _WebsiteBriefEditorState extends ConsumerState<WebsiteBriefEditor> {
  static const _steps = [
    ('Basics', Icons.storefront_outlined),
    ('Goals', Icons.flag_outlined),
    ('Pages', Icons.web_outlined),
    ('Features', Icons.widgets_outlined),
    ('Design', Icons.palette_outlined),
    ('References', Icons.link_outlined),
    ('Content', Icons.folder_outlined),
    ('Domain', Icons.language_outlined),
    ('Timeline', Icons.event_outlined),
    ('Review', Icons.fact_check_outlined),
  ];

  late Map<String, dynamic> _sections;
  int _step = 0;
  Timer? _autosave;
  bool _saving = false;
  bool _dirty = false;
  String _saveState = 'Saved';

  WebsiteBriefStatus get _status =>
      widget.initialBrief?.status ?? WebsiteBriefStatus.clientDraft;
  bool get _editable => widget.adminMode
      ? _status != WebsiteBriefStatus.approved
      : widget.initialBrief?.clientCanEdit ?? true;

  @override
  void initState() {
    super.initState();
    _sections = _deepCopy(widget.initialBrief?.sections ?? const {});
  }

  @override
  void dispose() {
    _autosave?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _deepCopy(Map<String, dynamic> source) {
    dynamic copy(dynamic value) {
      if (value is Map) {
        return value.map((key, item) => MapEntry(key.toString(), copy(item)));
      }
      if (value is List) return value.map(copy).toList();
      return value;
    }

    return Map<String, dynamic>.from(copy(source) as Map);
  }

  Map<String, dynamic> _section(String key) =>
      Map<String, dynamic>.from(_sections[key] as Map? ?? const {});

  void _setField(String section, String field, dynamic value) {
    if (!_editable) return;
    setState(() {
      _sections[section] = {..._section(section), field: value};
      _dirty = true;
      _saveState = 'Unsaved changes';
    });
    _autosave?.cancel();
    _autosave = Timer(const Duration(seconds: 2), _saveDraft);
  }

  void _toggleListValue(String section, String field, String value) {
    final values = List<String>.from(_section(section)[field] as List? ?? []);
    values.contains(value) ? values.remove(value) : values.add(value);
    _setField(section, field, values);
  }

  WebsiteBrief _currentBrief({WebsiteBriefStatus? status, String? reviewNote}) {
    final now = DateTime.now();
    final existing = widget.initialBrief;
    return WebsiteBrief(
      id: widget.plan.id,
      clientId: widget.client.id,
      planId: widget.plan.id,
      planName: widget.plan.name,
      status: status ?? existing?.status ?? WebsiteBriefStatus.clientDraft,
      sections: _deepCopy(_sections),
      reviewNote: reviewNote ?? existing?.reviewNote ?? '',
      requestedSections: existing?.requestedSections ?? const [],
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      submittedAt: status == WebsiteBriefStatus.submitted
          ? now
          : existing?.submittedAt,
      approvedAt: status == WebsiteBriefStatus.approved
          ? now
          : existing?.approvedAt,
      approvedBy: status == WebsiteBriefStatus.approved
          ? FirebaseAuth.instance.currentUser?.uid
          : existing?.approvedBy,
    );
  }

  Future<void> _saveDraft() async {
    if (!_dirty || !_editable || _saving) return;
    await _save();
  }

  Future<bool> _save({WebsiteBriefStatus? status, String? reviewNote}) async {
    _autosave?.cancel();
    setState(() {
      _saving = true;
      _saveState = 'Saving...';
    });
    try {
      final brief = _currentBrief(status: status, reviewNote: reviewNote);
      if (status == WebsiteBriefStatus.approved) {
        await ref
            .read(firestoreServiceProvider)
            .approveWebsiteBriefVersion(brief);
      } else {
        await ref.read(firestoreServiceProvider).saveWebsiteBrief(brief);
      }
      if (mounted) {
        setState(() {
          _saving = false;
          _dirty = false;
          _saveState = 'Saved';
        });
      }
      return true;
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveState = 'Save failed';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save brief: $error')));
      }
      return false;
    }
  }

  Future<void> _submit() async {
    if (_completionPercent < 55) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete the main brief sections before submitting.'),
        ),
      );
      return;
    }
    await _save(status: WebsiteBriefStatus.submitted);
  }

  Future<void> _finishAdminEditing() async {
    if (_dirty && !await _save()) return;
    widget.onDone?.call();
  }

  Future<void> _requestChanges() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request changes'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'What should be changed?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null || note.isEmpty) return;
    await _save(status: WebsiteBriefStatus.changesRequested, reviewNote: note);
  }

  int get _completionPercent => _currentBrief().completionPercent;

  @override
  Widget build(BuildContext context) {
    final brief = _currentBrief();
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 920;
        final form = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              plan: widget.plan,
              plans: widget.allPlans,
              status: _status,
              completion: _completionPercent,
              saveState: _saveState,
            ),
            if (widget.adminMode) ...[
              const SizedBox(height: 12),
              Material(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.support_agent_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Filling this brief for ${widget.client.name} during a call',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if ((widget.initialBrief?.reviewNote ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Material(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.feedback_outlined),
                      const SizedBox(width: 10),
                      Expanded(child: Text(widget.initialBrief!.reviewNote)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (!desktop) _mobileStepSelector(),
            _buildStep(brief),
            const SizedBox(height: 20),
            _footer(),
          ],
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: desktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 210, child: _stepNavigation()),
                        const SizedBox(width: 24),
                        Expanded(child: form),
                      ],
                    )
                  : form,
            ),
          ),
        );
      },
    );
  }

  Widget _stepNavigation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < _steps.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              dense: true,
              selected: _step == index,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              leading: Icon(_steps[index].$2, size: 20),
              title: Text(_steps[index].$1),
              onTap: () => setState(() => _step = index),
            ),
          ),
      ],
    );
  }

  Widget _mobileStepSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<int>(
        initialValue: _step,
        decoration: const InputDecoration(labelText: 'Brief section'),
        items: [
          for (var index = 0; index < _steps.length; index++)
            DropdownMenuItem(value: index, child: Text(_steps[index].$1)),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _step = value);
        },
      ),
    );
  }

  Widget _buildStep(WebsiteBrief brief) {
    return switch (_step) {
      0 => _basics(),
      1 => _goals(),
      2 => _pages(),
      3 => _features(),
      4 => _design(),
      5 => _references(),
      6 => _content(),
      7 => _domain(),
      8 => _timeline(),
      _ => _review(brief),
    };
  }

  Widget _sectionFrame(String title, String subtitle, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 18),
        ...children,
      ],
    );
  }

  Widget _textField(
    String section,
    String field,
    String label, {
    int lines = 1,
    String? hint,
  }) {
    return TextFormField(
      key: ValueKey('$section-$field-${_section(section)[field]}'),
      initialValue: _section(section)[field]?.toString() ?? '',
      enabled: _editable,
      minLines: lines,
      maxLines: lines,
      decoration: InputDecoration(labelText: label, hintText: hint),
      onChanged: (value) => _setField(section, field, value),
    );
  }

  Widget _choiceWrap(String section, String field, List<String> choices) {
    final selected = List<String>.from(
      _section(section)[field] as List? ?? const [],
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final choice in choices)
          FilterChip(
            label: Text(choice),
            selected: selected.contains(choice),
            onSelected: _editable
                ? (_) => _toggleListValue(section, field, choice)
                : null,
          ),
      ],
    );
  }

  Widget _basics() => _sectionFrame(
    'Business Basics',
    'Tell us what your business does and who it serves.',
    [
      Row(
        children: [
          Expanded(
            child: _textField('basics', 'businessName', 'Business name'),
          ),
          const SizedBox(width: 12),
          Expanded(child: _textField('basics', 'industry', 'Industry')),
        ],
      ),
      const SizedBox(height: 14),
      _textField('basics', 'description', 'Describe your business', lines: 4),
      const SizedBox(height: 14),
      _textField(
        'basics',
        'services',
        'Products or services',
        lines: 3,
        hint: 'Enter one item per line',
      ),
      const SizedBox(height: 14),
      _textField('basics', 'customers', 'Target customers', lines: 3),
    ],
  );

  Widget _goals() => _sectionFrame(
    'Website Goals',
    'Choose the outcomes this website should support.',
    [
      _choiceWrap('goals', 'selected', const [
        'Generate leads',
        'Sell products',
        'Accept bookings',
        'Showcase services',
        'Build credibility',
        'Customer support',
        'Client portal',
        'Share information',
      ]),
      const SizedBox(height: 18),
      _textField('goals', 'primaryAction', 'Primary call to action'),
      const SizedBox(height: 14),
      _textField('goals', 'success', 'How will you measure success?', lines: 3),
    ],
  );

  Widget _pages() => _sectionFrame(
    'Website Pages',
    'Select the pages required for the first version.',
    [
      _choiceWrap('pages', 'selected', const [
        'Home',
        'About',
        'Services',
        'Products',
        'Pricing',
        'Gallery',
        'Testimonials',
        'FAQ',
        'Blog',
        'Contact',
      ]),
      const SizedBox(height: 18),
      _textField('pages', 'custom', 'Custom pages and page notes', lines: 4),
    ],
  );

  Widget _features() => _sectionFrame(
    'Features',
    'Select the functions visitors and staff will need.',
    [
      _choiceWrap('features', 'selected', const [
        'Contact form',
        'WhatsApp',
        'Booking',
        'Payments',
        'Product catalogue',
        'Shopping cart',
        'User login',
        'Client portal',
        'Search',
        'Reviews',
        'Newsletter',
        'Google Maps',
        'Multiple languages',
        'Analytics',
      ]),
      const SizedBox(height: 18),
      _textField('features', 'custom', 'Other feature requirements', lines: 4),
      const SizedBox(height: 14),
      _textField(
        'features',
        'platform',
        'Preferred platform',
        hint: 'WordPress, Shopify, custom, or recommend one',
      ),
    ],
  );

  Widget _design() => _sectionFrame(
    'Design Direction',
    'Define the visual character of the website.',
    [
      _choiceWrap('design', 'styles', const [
        'Modern',
        'Minimal',
        'Corporate',
        'Luxury',
        'Bold',
        'Playful',
        'Editorial',
        'Traditional',
      ]),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(child: _textField('design', 'primaryColor', 'Primary HEX')),
          const SizedBox(width: 10),
          Expanded(
            child: _textField('design', 'secondaryColor', 'Secondary HEX'),
          ),
          const SizedBox(width: 10),
          Expanded(child: _textField('design', 'accentColor', 'Accent HEX')),
        ],
      ),
      const SizedBox(height: 14),
      _textField(
        'design',
        'typography',
        'Typography preference',
        hint: 'Clean, professional, bold, friendly, or recommend fonts',
      ),
      const SizedBox(height: 14),
      _textField('design', 'notes', 'Design notes', lines: 4),
    ],
  );

  Widget _references() => _sectionFrame(
    'Reference Websites',
    'Share examples and explain what should inspire the design.',
    [
      _textField(
        'references',
        'urls',
        'Website URLs',
        lines: 4,
        hint: 'Enter one URL per line',
      ),
      const SizedBox(height: 14),
      _textField('references', 'likes', 'What do you like?', lines: 3),
      const SizedBox(height: 14),
      _textField('references', 'dislikes', 'What do you dislike?', lines: 3),
    ],
  );

  Widget _content() => _sectionFrame(
    'Content and Assets',
    'Tell us what is ready and link to shared files.',
    [
      _choiceWrap('content', 'available', const [
        'Logo',
        'Brand guide',
        'Product photos',
        'Team photos',
        'Videos',
        'Website text',
        'Price list',
        'Testimonials',
        'Legal policies',
      ]),
      const SizedBox(height: 18),
      _textField(
        'content',
        'assetLinks',
        'Google Drive or Dropbox links',
        lines: 3,
      ),
      const SizedBox(height: 14),
      _textField(
        'content',
        'missing',
        'Missing content or help needed',
        lines: 3,
      ),
    ],
  );

  Widget _domain() => _sectionFrame(
    'Domain and Hosting',
    'Provide account details without sharing passwords.',
    [
      Row(
        children: [
          Expanded(child: _textField('domain', 'domainName', 'Domain name')),
          const SizedBox(width: 12),
          Expanded(
            child: _textField('domain', 'registrar', 'Domain registrar'),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _textField('domain', 'hosting', 'Current hosting'),
      const SizedBox(height: 14),
      _textField('domain', 'businessEmail', 'Business email'),
      const SizedBox(height: 14),
      _textField('domain', 'migration', 'Migration and DNS notes', lines: 3),
      const SizedBox(height: 10),
      const Text('Do not enter passwords, API keys, or other secrets here.'),
    ],
  );

  Widget _timeline() => _sectionFrame(
    'Timeline and Approval',
    'Set expectations for launch and decision-making.',
    [
      Row(
        children: [
          Expanded(
            child: _textField('timeline', 'launchDate', 'Target launch date'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _textField('timeline', 'decisionMaker', 'Decision-maker'),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _textField('timeline', 'reviewers', 'Additional reviewers'),
      const SizedBox(height: 14),
      _textField(
        'timeline',
        'milestones',
        'Milestones and constraints',
        lines: 4,
      ),
    ],
  );

  Widget _review(WebsiteBrief brief) {
    return _sectionFrame(
      'Review Website Brief',
      'Check the requirements before sending them to Tulasi Solutions.',
      [
        for (var index = 0; index < _steps.length - 1; index++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _sectionHasData(_sectionKey(index))
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: _sectionHasData(_sectionKey(index))
                  ? Colors.green
                  : Colors.grey,
            ),
            title: Text(_steps[index].$1),
            subtitle: Text(_sectionSummary(_sectionKey(index))),
            trailing: IconButton(
              tooltip: 'Edit ${_steps[index].$1}',
              onPressed: _editable ? () => setState(() => _step = index) : null,
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        const SizedBox(height: 12),
        if (widget.adminMode)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saving ? null : _finishAdminEditing,
              icon: const Icon(Icons.check),
              label: const Text('Finish call notes'),
            ),
          )
        else if (_status == WebsiteBriefStatus.awaitingApproval)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _saving ? null : _requestChanges,
                child: const Text('Request changes'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _saving
                    ? null
                    : () => _save(status: WebsiteBriefStatus.approved),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Approve brief'),
              ),
            ],
          )
        else if (_editable)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: const Icon(Icons.send_outlined),
              label: Text(
                _status == WebsiteBriefStatus.changesRequested
                    ? 'Resubmit brief'
                    : 'Submit brief',
              ),
            ),
          )
        else
          _StatusMessage(status: _status),
      ],
    );
  }

  String _sectionKey(int index) => const [
    'basics',
    'goals',
    'pages',
    'features',
    'design',
    'references',
    'content',
    'domain',
    'timeline',
  ][index];

  bool _sectionHasData(String key) {
    final values = _section(key).values;
    return values.any((value) {
      if (value is String) return value.trim().isNotEmpty;
      if (value is List) return value.isNotEmpty;
      return value != null;
    });
  }

  String _sectionSummary(String key) {
    final values = _section(key).values.where((value) {
      if (value is String) return value.trim().isNotEmpty;
      if (value is List) return value.isNotEmpty;
      return value != null;
    }).length;
    return values == 0 ? 'Not started' : '$values fields completed';
  }

  Widget _footer() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _step == 0 ? null : () => setState(() => _step--),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Previous'),
        ),
        const Spacer(),
        if (_editable)
          TextButton.icon(
            onPressed: _saving ? null : () => _save(),
            icon: const Icon(Icons.save_outlined),
            label: Text(widget.adminMode ? 'Save changes' : 'Save draft'),
          ),
        const SizedBox(width: 8),
        if (_step < _steps.length - 1)
          FilledButton.icon(
            onPressed: () async {
              if (_dirty) await _save();
              if (mounted) setState(() => _step++);
            },
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continue'),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final Plan plan;
  final List<Plan> plans;
  final WebsiteBriefStatus status;
  final int completion;
  final String saveState;

  const _Header({
    required this.plan,
    required this.plans,
    required this.status,
    required this.completion,
    required this.saveState,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text('$completion% complete • $saveState'),
                ],
              ),
            ),
            _BriefStatusChip(status: status),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: completion / 100),
      ],
    );
  }
}

class _BriefStatusChip extends StatelessWidget {
  final WebsiteBriefStatus status;

  const _BriefStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      WebsiteBriefStatus.clientDraft => ('Draft', Colors.grey),
      WebsiteBriefStatus.submitted => ('Submitted', Colors.blue),
      WebsiteBriefStatus.changesRequested => (
        'Changes requested',
        Colors.orange,
      ),
      WebsiteBriefStatus.awaitingApproval => (
        'Awaiting approval',
        Colors.amber,
      ),
      WebsiteBriefStatus.approved => ('Approved', Colors.green),
    };
    return Chip(
      avatar: Icon(Icons.circle, size: 10, color: color),
      label: Text(label),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final WebsiteBriefStatus status;

  const _StatusMessage({required this.status});

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      WebsiteBriefStatus.submitted => 'Submitted for staff review',
      WebsiteBriefStatus.approved => 'This brief is approved and locked',
      _ => 'Waiting for the next review step',
    };
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
