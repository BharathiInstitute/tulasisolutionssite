import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/widgets/feature_progress_widgets.dart';

/// A single editable feature row: an optional category + the feature text.
class _FeatureFieldControllers {
  final TextEditingController category;
  final TextEditingController text;

  _FeatureFieldControllers({String category = '', String text = ''})
    : category = TextEditingController(text: category),
      text = TextEditingController(text: text);

  factory _FeatureFieldControllers.fromRaw(String raw) {
    final separatorIndex = raw.indexOf(': ');
    final category = separatorIndex > 0
        ? displayFeatureCategory(raw.substring(0, separatorIndex))
        : '';
    final text = separatorIndex > 0 ? raw.substring(separatorIndex + 2) : raw;
    return _FeatureFieldControllers(category: category, text: text);
  }

  void dispose() {
    category.dispose();
    text.dispose();
  }
}

/// Editable list of feature rows (category + text).
class _FeatureListEditor extends StatelessWidget {
  final List<_FeatureFieldControllers> controllers;
  final PlanType planType;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final String addLabel;

  const _FeatureListEditor({
    required this.controllers,
    required this.planType,
    required this.onAdd,
    required this.onRemove,
    this.addLabel = 'Add feature',
  });

  @override
  Widget build(BuildContext context) {
    final categories = allPlanFeatureCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Features', style: Theme.of(context).textTheme.titleSmall),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(addLabel),
            ),
          ],
        ),
        ...List.generate(controllers.length, (index) {
          final row = controllers[index];
          return StatefulBuilder(
            builder: (context, setRowState) {
              final selection = parseFeatureCategory(row.category.text);
              final selectedCategory = categories.contains(selection.category)
                  ? selection.category
                  : null;
              final subcategories = selectedCategory == null
                  ? const <String>[]
                  : planFeatureSubcategories[selectedCategory] ??
                        const <String>[];
              final selectedSubcategory = subcategories.contains(
                selection.subcategory,
              )
                  ? selection.subcategory
                  : subcategories.firstOrNull;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            key: ValueKey('feature-category-$index'),
                            initialValue: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                            hint: const Text('Select category'),
                            items: [
                              for (final category in categories)
                                DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                ),
                            ],
                            onChanged: (category) {
                              setRowState(() {
                                final options = category == null
                                    ? const <String>[]
                                    : planFeatureSubcategories[category] ??
                                          const <String>[];
                                row.category.text = category == null
                                    ? ''
                                    : encodeFeatureCategory(
                                        category,
                                        options.firstOrNull,
                                      );
                              });
                            },
                          ),
                          if (subcategories.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'feature-subcategory-$index-$selectedCategory',
                              ),
                              initialValue: selectedSubcategory,
                              decoration: const InputDecoration(
                                labelText: 'Subcategory',
                              ),
                              items: [
                                for (final subcategory in subcategories)
                                  DropdownMenuItem(
                                    value: subcategory,
                                    child: Text(subcategory),
                                  ),
                              ],
                              onChanged: (subcategory) {
                                setRowState(() {
                                  row.category.text = encodeFeatureCategory(
                                    selectedCategory!,
                                    subcategory,
                                  );
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: row.text,
                        decoration: InputDecoration(
                          hintText: 'e.g. 6 photos + 6 short videos',
                          labelText: 'Feature ${index + 1}',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: controllers.length > 1
                          ? () => onRemove(index)
                          : null,
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ],
    );
  }
}

class AssignPlanDialog extends ConsumerStatefulWidget {
  final List<Client> clients;
  final List<PlanTemplate> templates;
  final Plan? existing;

  const AssignPlanDialog({
    super.key,
    required this.clients,
    required this.templates,
    this.existing,
  });

  @override
  ConsumerState<AssignPlanDialog> createState() => _AssignPlanDialogState();
}

class _AssignPlanDialogState extends ConsumerState<AssignPlanDialog> {
  late String _clientId;
  String? _templateId;
  late PlanType _type;
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  late List<_FeatureFieldControllers> _featureRows;
  late List<ClientTask> _tasks;
  late DateTime _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _clientId = widget.existing?.clientId ?? widget.clients.first.id;
    _templateId = widget.existing?.templateId;
    _type = widget.existing?.type ?? PlanType.setup;
    _nameController.text = widget.existing?.name ?? '';
    _priceController.text = widget.existing?.price.toStringAsFixed(0) ?? '';
    _featureRows = (widget.existing?.features ?? const [''])
        .map((f) => _FeatureFieldControllers.fromRaw(f))
        .toList();
    _tasks = List<ClientTask>.from(widget.existing?.tasks ?? const []);
    if (_featureRows.isEmpty) {
      _featureRows.add(_FeatureFieldControllers());
    }
    _startDate = widget.existing?.startDate ?? DateTime.now();
    _endDate = widget.existing?.endDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    for (final row in _featureRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _applyTemplate(String? templateId) {
    setState(() {
      _templateId = templateId;
      if (templateId == null) return;
      final template = widget.templates.firstWhere((t) => t.id == templateId);
      _type = template.type;
      _nameController.text = template.name;
      _priceController.text = template.price.toStringAsFixed(0);
      for (final row in _featureRows) {
        row.dispose();
      }
      if (widget.existing != null) {
        final merged = widget.existing!.mergeTemplateTasks(template);
        _tasks = merged.tasks;
        _featureRows = merged.features
            .map((feature) => _FeatureFieldControllers.fromRaw(feature))
            .toList();
      } else {
        _tasks = template.tasks.map(ClientTask.fromTemplate).toList();
        _featureRows = template.features
            .map((f) => _FeatureFieldControllers.fromRaw(f))
            .toList();
      }
      if (_featureRows.isEmpty) {
        _featureRows.add(_FeatureFieldControllers());
      }
    });
  }

  void _addFeatureField() {
    setState(
      () => _featureRows.add(
        _FeatureFieldControllers(
          category: _type == PlanType.subscription
              ? visionAndPlanFeatureCategory
              : '',
        ),
      ),
    );
  }

  void _removeFeatureField(int index) {
    setState(() {
      _featureRows[index].dispose();
      _featureRows.removeAt(index);
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    final price = double.tryParse(_priceController.text.trim());
    if (_nameController.text.trim().isEmpty || price == null) {
      setState(() => _error = 'Enter a plan name and a valid price');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final features = _featureRows
          .where((row) => row.text.text.trim().isNotEmpty)
          .map((row) => encodeFeature(row.category.text, row.text.text))
          .toList();
      final tasksByFeature = {for (final task in _tasks) task.feature: task};
      final tasks = <ClientTask>[
        for (var index = 0; index < features.length; index++)
          tasksByFeature[features[index]] ??
              ClientTask(
                id: const Uuid().v4(),
                category: _featureRows[index].category.text.trim(),
                title: _featureRows[index].text.text.trim(),
                order: index,
                source: _templateId == null
                    ? ClientTaskSource.customIncluded
                    : ClientTaskSource.template,
              ),
      ];
      final plan = Plan(
        id: widget.existing?.id ?? const Uuid().v4(),
        clientId: _clientId,
        templateId: _templateId,
        type: _type,
        name: _nameController.text.trim(),
        price: price,
        features: features,
        tasks: tasks,
        completedFeatures: widget.existing?.completedFeatures ?? const [],
        featureProgress: widget.existing?.featureProgress ?? const {},
        taskWorkflow: widget.existing?.taskWorkflow ?? const {},
        startDate: _startDate,
        endDate: _endDate,
      );
      final service = ref.read(firestoreServiceProvider);
      if (widget.existing != null) {
        await service.updatePlan(plan);
      } else {
        await service.createPlan(plan);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing != null ? 'Change Plan' : 'Assign Plan'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _clientId,
                items: widget.clients
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _clientId = value ?? _clientId),
                decoration: const InputDecoration(labelText: 'Client'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _templateId,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Custom (no template)'),
                  ),
                  ...widget.templates
                      .where((t) => t.type == PlanType.setup)
                      .map(
                        (t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(
                            '[Setup] ${t.name} — ₹${t.price.toStringAsFixed(0)}',
                          ),
                        ),
                      ),
                  ...widget.templates
                      .where((t) => t.type == PlanType.subscription)
                      .map(
                        (t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(
                            '[Subscription] ${t.name} — ₹${t.price.toStringAsFixed(0)}',
                          ),
                        ),
                      ),
                ],
                onChanged: _applyTemplate,
                decoration: InputDecoration(
                  labelText: widget.existing != null
                      ? 'Change to template'
                      : 'From template',
                  helperText: widget.existing != null
                      ? 'Existing task titles are preserved; new items are added.'
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Plan name'),
              ),
              const SizedBox(height: 16),
              Text('Category', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<PlanType>(
                segments: const [
                  ButtonSegment(
                    value: PlanType.setup,
                    label: Text('Setup'),
                    icon: Icon(Icons.build_circle_outlined),
                  ),
                  ButtonSegment(
                    value: PlanType.subscription,
                    label: Text('Subscription'),
                    icon: Icon(Icons.autorenew),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Price (₹) — customizable for this client',
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 16),
              _FeatureListEditor(
                controllers: _featureRows,
                planType: _type,
                onAdd: _addFeatureField,
                onRemove: _removeFeatureField,
                addLabel: 'Add',
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Start: ${DateFormat('MMM d, y').format(_startDate)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(isStart: true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _endDate == null
                      ? 'End: none'
                      : 'End: ${DateFormat('MMM d, y').format(_endDate!)}',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (_endDate != null)
                      IconButton(
                        tooltip: 'Clear end date',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _endDate = null),
                      ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
                onTap: () => _pickDate(isStart: false),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
