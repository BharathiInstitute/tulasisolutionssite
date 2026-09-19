import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tulasisolutionssite/core/models/brand_brief.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';

class ClientBrandBriefScreen extends ConsumerWidget {
  final String? planId;

  const ClientBrandBriefScreen({super.key, this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      isAdmin: false,
      currentRoute: '/client/brand-brief',
      title: 'Brand Identity Brief',
      body: ref
          .watch(currentClientProvider)
          .when(
            loading: () => const LoadingWidget(),
            error: (error, stackTrace) => CustomErrorWidget(
              message: 'Could not load your profile: $error',
            ),
            data: (client) {
              if (client == null) {
                return const Center(child: Text('Client profile not found'));
              }
              return ref
                  .watch(plansProvider(client.id))
                  .when(
                    loading: () => const LoadingWidget(),
                    error: (error, stackTrace) => CustomErrorWidget(
                      message: 'Could not load plans: $error',
                    ),
                    data: (plans) {
                      if (plans.isEmpty) {
                        return const Center(
                          child: Text(
                            'A plan is required before creating a brief.',
                          ),
                        );
                      }
                      final plan =
                          plans
                              .where((item) => item.id == planId)
                              .firstOrNull ??
                          plans.first;
                      return ref
                          .watch(brandBriefProvider(plan.id))
                          .when(
                            loading: () => const LoadingWidget(),
                            error: (error, stackTrace) => CustomErrorWidget(
                              message: 'Could not load brand brief: $error',
                            ),
                            data: (brief) => BrandBriefEditor(
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

class BrandBriefEditor extends ConsumerStatefulWidget {
  final Plan plan;
  final Client client;
  final BrandBrief? initialBrief;
  final List<Plan> allPlans;
  final bool adminMode;
  final VoidCallback? onDone;

  const BrandBriefEditor({
    super.key,
    required this.plan,
    required this.client,
    required this.initialBrief,
    required this.allPlans,
    this.adminMode = false,
    this.onDone,
  });

  @override
  ConsumerState<BrandBriefEditor> createState() => _BrandBriefEditorState();
}

class _BrandBriefEditorState extends ConsumerState<BrandBriefEditor> {
  static const _sections = <_SectionSpec>[
    _SectionSpec(
      keyName: 'business',
      title: 'Brand Basics',
      subtitle:
          'Define the business and the central idea the identity represents.',
      icon: Icons.storefront_outlined,
      fields: [
        _FieldSpec('brandName', 'Brand name'),
        _FieldSpec('tagline', 'Tagline or slogan'),
        _FieldSpec('businessSummary', 'What does the business do?', lines: 4),
        _FieldSpec('offer', 'Main products or services', lines: 3),
        _FieldSpec('brandStory', 'Origin or story behind the brand', lines: 4),
      ],
    ),
    _SectionSpec(
      keyName: 'audience',
      title: 'Audience & Market',
      subtitle: 'Clarify who the brand needs to reach and where it competes.',
      icon: Icons.groups_outlined,
      fields: [
        _FieldSpec('targetAudience', 'Ideal customers', lines: 4),
        _FieldSpec('geography', 'Locations or markets served'),
        _FieldSpec('competitors', 'Competitors and their links', lines: 4),
        _FieldSpec(
          'difference',
          'What should make this brand different?',
          lines: 3,
        ),
      ],
    ),
    _SectionSpec(
      keyName: 'personality',
      title: 'Personality & Voice',
      subtitle: 'Choose how the brand should feel, sound, and behave.',
      icon: Icons.record_voice_over_outlined,
      fields: [
        _FieldSpec(
          'traits',
          'Brand traits',
          choices: [
            'Professional',
            'Friendly',
            'Bold',
            'Premium',
            'Playful',
            'Minimal',
            'Traditional',
            'Innovative',
            'Trustworthy',
            'Energetic',
          ],
        ),
        _FieldSpec('tone', 'Tone of voice', lines: 3),
        _FieldSpec('values', 'Core values', lines: 3),
        _FieldSpec('avoid', 'Words, styles, or impressions to avoid', lines: 3),
      ],
    ),
    _SectionSpec(
      keyName: 'logo',
      title: 'Logo Direction',
      subtitle: 'Capture the first instructions for the logo design set.',
      icon: Icons.draw_outlined,
      fields: [
        _FieldSpec(
          'startingPoint',
          'Current logo status',
          choices: [
            'Need a new logo',
            'Refresh existing logo',
            'Keep existing logo',
            'Not sure',
          ],
        ),
        _FieldSpec(
          'logoTypes',
          'Preferred logo types',
          choices: [
            'Wordmark',
            'Lettermark',
            'Symbol',
            'Combination mark',
            'Emblem',
            'Mascot',
            'Designer recommendation',
          ],
        ),
        _FieldSpec('logoText', 'Exact name and tagline to appear'),
        _FieldSpec(
          'symbolIdeas',
          'Symbols, ideas, or meaning to explore',
          lines: 4,
        ),
        _FieldSpec(
          'restrictions',
          'Colors, symbols, or styles to avoid',
          lines: 3,
        ),
      ],
    ),
    _SectionSpec(
      keyName: 'visualSystem',
      title: 'Colors & Typography',
      subtitle: 'Set the visual system for consistent brand use.',
      icon: Icons.palette_outlined,
      fields: [
        _FieldSpec(
          'colorMood',
          'Color direction',
          choices: [
            'Bright',
            'Muted',
            'Warm',
            'Cool',
            'Natural',
            'Monochrome',
            'Premium',
            'Designer recommendation',
          ],
        ),
        _FieldSpec('primaryColor', 'Primary color or HEX'),
        _FieldSpec('secondaryColor', 'Secondary color or HEX'),
        _FieldSpec('accentColor', 'Accent color or HEX'),
        _FieldSpec(
          'typography',
          'Font preferences or typography mood',
          lines: 3,
        ),
        _FieldSpec(
          'accessibility',
          'Contrast or accessibility requirements',
          lines: 2,
        ),
      ],
    ),
    _SectionSpec(
      keyName: 'assets',
      title: 'Existing Assets',
      subtitle: 'List what is available and link to shared source files.',
      icon: Icons.folder_outlined,
      fields: [
        _FieldSpec(
          'available',
          'Available assets',
          choices: [
            'Existing logo files',
            'Product photos',
            'Team photos',
            'Videos',
            'Illustrations',
            'Icons',
            'Packaging',
            'Print material',
            'Social templates',
            'Brand guide',
          ],
        ),
        _FieldSpec('assetLinks', 'Google Drive or Dropbox links', lines: 4),
        _FieldSpec('photography', 'Photography or image direction', lines: 3),
        _FieldSpec('missing', 'Assets that need to be created', lines: 3),
      ],
    ),
    _SectionSpec(
      keyName: 'references',
      title: 'Design References',
      subtitle:
          'Share brands and designs that should guide the first concepts.',
      icon: Icons.link_outlined,
      fields: [
        _FieldSpec(
          'referenceLinks',
          'Brand, Pinterest, Behance, or design links',
          lines: 5,
        ),
        _FieldSpec('likes', 'What do you like in these references?', lines: 4),
        _FieldSpec(
          'dislikes',
          'What should not be copied or repeated?',
          lines: 3,
        ),
      ],
    ),
    _SectionSpec(
      keyName: 'motion',
      title: 'Motion & Video Brand Kit',
      subtitle: 'Define how the brand should move, sound, and appear in video.',
      icon: Icons.movie_creation_outlined,
      fields: [
        _FieldSpec(
          'videoFormats',
          'Video formats used',
          choices: [
            'Instagram Reels',
            'YouTube',
            'Shorts',
            'Stories',
            'Ads',
            'Presentations',
            'Explainer videos',
            'Event screens',
          ],
        ),
        _FieldSpec(
          'motionAssets',
          'Motion assets needed',
          choices: [
            'Animated logo',
            'Intro',
            'Outro',
            'Lower thirds',
            'Title cards',
            'Caption style',
            'Transitions',
            'End card',
            'Thumbnail system',
          ],
        ),
        _FieldSpec(
          'animationStyle',
          'Animation and transition style',
          lines: 3,
        ),
        _FieldSpec(
          'captionStyle',
          'Caption and on-screen text direction',
          lines: 3,
        ),
        _FieldSpec('audio', 'Music, sound, and voice direction', lines: 3),
        _FieldSpec('videoReferences', 'Reference video links', lines: 4),
      ],
    ),
    _SectionSpec(
      keyName: 'deliverables',
      title: 'Deliverables & Approval',
      subtitle:
          'Confirm the files, applications, timeline, and decision-maker.',
      icon: Icons.inventory_2_outlined,
      fields: [
        _FieldSpec(
          'deliverables',
          'Required deliverables',
          choices: [
            'Primary logo',
            'Logo variations',
            'Color palette',
            'Font system',
            'Brand guidelines',
            'Social templates',
            'Business card',
            'Letterhead',
            'Email signature',
            'Motion brand kit',
          ],
        ),
        _FieldSpec('applications', 'Where will the brand be used?', lines: 4),
        _FieldSpec('deadline', 'Target completion date'),
        _FieldSpec('decisionMaker', 'Final decision-maker'),
        _FieldSpec('reviewers', 'Other reviewers'),
      ],
    ),
  ];

  late Map<String, dynamic> _values;
  int _step = 0;
  Timer? _autosave;
  bool _saving = false;
  bool _dirty = false;
  String _saveState = 'Saved';

  BrandBriefStatus get _status =>
      widget.initialBrief?.status ?? BrandBriefStatus.clientDraft;
  bool get _editable => widget.adminMode
      ? _status != BrandBriefStatus.approved
      : widget.initialBrief?.clientCanEdit ?? true;

  @override
  void initState() {
    super.initState();
    _values = _deepCopy(widget.initialBrief?.sections ?? const {});
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
      Map<String, dynamic>.from(_values[key] as Map? ?? const {});

  void _setField(String section, String field, dynamic value) {
    if (!_editable) return;
    setState(() {
      _values[section] = {..._section(section), field: value};
      _dirty = true;
      _saveState = 'Unsaved changes';
    });
    _autosave?.cancel();
    _autosave = Timer(const Duration(seconds: 2), _saveDraft);
  }

  void _toggleChoice(String section, String field, String value) {
    final selected = List<String>.from(_section(section)[field] as List? ?? []);
    selected.contains(value) ? selected.remove(value) : selected.add(value);
    _setField(section, field, selected);
  }

  BrandBrief _current({BrandBriefStatus? status, String? reviewNote}) {
    final now = DateTime.now();
    final existing = widget.initialBrief;
    return BrandBrief(
      id: widget.plan.id,
      clientId: widget.client.id,
      planId: widget.plan.id,
      planName: widget.plan.name,
      status: status ?? existing?.status ?? BrandBriefStatus.clientDraft,
      sections: _deepCopy(_values),
      reviewNote: reviewNote ?? existing?.reviewNote ?? '',
      requestedSections: existing?.requestedSections ?? const [],
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      submittedAt: status == BrandBriefStatus.submitted
          ? now
          : existing?.submittedAt,
      approvedAt: status == BrandBriefStatus.approved
          ? now
          : existing?.approvedAt,
      approvedBy: status == BrandBriefStatus.approved
          ? FirebaseAuth.instance.currentUser?.uid
          : existing?.approvedBy,
    );
  }

  Future<void> _saveDraft() async {
    if (_dirty && _editable && !_saving) await _save();
  }

  Future<bool> _save({BrandBriefStatus? status, String? reviewNote}) async {
    _autosave?.cancel();
    setState(() {
      _saving = true;
      _saveState = 'Saving...';
    });
    try {
      final brief = _current(status: status, reviewNote: reviewNote);
      if (status == BrandBriefStatus.approved) {
        await ref
            .read(firestoreServiceProvider)
            .approveBrandBriefVersion(brief);
      } else {
        await ref.read(firestoreServiceProvider).saveBrandBrief(brief);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save brand brief: $error')),
        );
      }
      return false;
    }
  }

  Future<void> _submit() async {
    if (_current().completionPercent < 55) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete the main sections before submitting.'),
        ),
      );
      return;
    }
    await _save(status: BrandBriefStatus.submitted);
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
    await _save(status: BrandBriefStatus.changesRequested, reviewNote: note);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 920;
        final form = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
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
                  child: Text(widget.initialBrief!.reviewNote),
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (!desktop) _mobileSelector(),
            _step == _sections.length
                ? _review()
                : _sectionForm(_sections[_step]),
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
                        SizedBox(width: 220, child: _navigation()),
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

  Widget _header() {
    final completion = _current().completionPercent;
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
                    widget.plan.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text('$completion% complete • $_saveState'),
                ],
              ),
            ),
            _BrandStatusChip(status: _status),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: completion / 100),
      ],
    );
  }

  Widget _navigation() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index <= _sections.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: ListTile(
            dense: true,
            selected: _step == index,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            leading: Icon(
              index == _sections.length
                  ? Icons.fact_check_outlined
                  : _sections[index].icon,
              size: 20,
            ),
            title: Text(
              index == _sections.length ? 'Review' : _sections[index].title,
            ),
            onTap: () => setState(() => _step = index),
          ),
        ),
    ],
  );

  Widget _mobileSelector() => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<int>(
      initialValue: _step,
      decoration: const InputDecoration(labelText: 'Brief section'),
      items: [
        for (var index = 0; index <= _sections.length; index++)
          DropdownMenuItem(
            value: index,
            child: Text(
              index == _sections.length ? 'Review' : _sections[index].title,
            ),
          ),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _step = value);
      },
    ),
  );

  Widget _sectionForm(_SectionSpec section) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(section.title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text(section.subtitle),
      const SizedBox(height: 18),
      for (var index = 0; index < section.fields.length; index++) ...[
        _field(section.keyName, section.fields[index]),
        if (index < section.fields.length - 1) const SizedBox(height: 14),
      ],
    ],
  );

  Widget _field(String section, _FieldSpec field) {
    if (field.choices != null) {
      final selected = List<String>.from(
        _section(section)[field.keyName] as List? ?? const [],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in field.choices!)
                FilterChip(
                  label: Text(choice),
                  selected: selected.contains(choice),
                  onSelected: _editable
                      ? (_) => _toggleChoice(section, field.keyName, choice)
                      : null,
                ),
            ],
          ),
        ],
      );
    }
    return TextFormField(
      key: ValueKey(
        '$section-${field.keyName}-${_section(section)[field.keyName]}',
      ),
      initialValue: _section(section)[field.keyName]?.toString() ?? '',
      enabled: _editable,
      minLines: field.lines,
      maxLines: field.lines,
      decoration: InputDecoration(labelText: field.label),
      onChanged: (value) => _setField(section, field.keyName, value),
    );
  }

  Widget _review() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Review Brand Identity Brief',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 4),
      const Text('Check the identity and motion instructions before review.'),
      const SizedBox(height: 14),
      for (var index = 0; index < _sections.length; index++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            _hasSectionData(_sections[index].keyName)
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            color: _hasSectionData(_sections[index].keyName)
                ? Colors.green
                : Colors.grey,
          ),
          title: Text(_sections[index].title),
          subtitle: Text(_sectionSummary(_sections[index].keyName)),
          trailing: IconButton(
            tooltip: 'Edit ${_sections[index].title}',
            onPressed: _editable ? () => setState(() => _step = index) : null,
            icon: const Icon(Icons.edit_outlined),
          ),
        ),
      const SizedBox(height: 12),
      if (widget.adminMode)
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    if (_dirty && !await _save()) return;
                    widget.onDone?.call();
                  },
            icon: const Icon(Icons.check),
            label: const Text('Finish call notes'),
          ),
        )
      else if (_status == BrandBriefStatus.awaitingApproval)
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(
              onPressed: _saving ? null : _requestChanges,
              child: const Text('Request changes'),
            ),
            FilledButton.icon(
              onPressed: _saving
                  ? null
                  : () => _save(status: BrandBriefStatus.approved),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Approve brand brief'),
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
              _status == BrandBriefStatus.changesRequested
                  ? 'Resubmit brief'
                  : 'Submit brief',
            ),
          ),
        )
      else
        Material(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              _status == BrandBriefStatus.approved
                  ? 'This brand brief is approved and locked'
                  : 'Submitted for staff review',
              textAlign: TextAlign.center,
            ),
          ),
        ),
    ],
  );

  bool _hasSectionData(String key) => _section(key).values.any((value) {
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.isNotEmpty;
    return value != null;
  });

  String _sectionSummary(String key) {
    final count = _section(key).values.where((value) {
      if (value is String) return value.trim().isNotEmpty;
      if (value is List) return value.isNotEmpty;
      return value != null;
    }).length;
    return count == 0 ? 'Not started' : '$count fields completed';
  }

  Widget _footer() => Row(
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
      if (_step < _sections.length)
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

class _SectionSpec {
  final String keyName;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_FieldSpec> fields;

  const _SectionSpec({
    required this.keyName,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.fields,
  });
}

class _FieldSpec {
  final String keyName;
  final String label;
  final int lines;
  final List<String>? choices;

  const _FieldSpec(this.keyName, this.label, {this.lines = 1, this.choices});
}

class _BrandStatusChip extends StatelessWidget {
  final BrandBriefStatus status;

  const _BrandStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      BrandBriefStatus.clientDraft => ('Draft', Colors.grey),
      BrandBriefStatus.submitted => ('Submitted', Colors.blue),
      BrandBriefStatus.changesRequested => ('Changes requested', Colors.orange),
      BrandBriefStatus.awaitingApproval => ('Awaiting approval', Colors.amber),
      BrandBriefStatus.approved => ('Approved', Colors.green),
    };
    return Chip(
      avatar: Icon(Icons.circle, size: 10, color: color),
      label: Text(label),
    );
  }
}
