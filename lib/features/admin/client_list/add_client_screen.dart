import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';

/// Shows a popup dialog to create a new client, optionally pre-selecting
/// [initialStage] (e.g. when opened from the Setup or Subscription panel).
Future<void> showAddClientDialog(
  BuildContext context, {
  ClientStage? initialStage,
}) {
  return showDialog(
    context: context,
    builder: (context) => AddClientDialog(initialStage: initialStage),
  );
}

class AddClientDialog extends ConsumerStatefulWidget {
  final ClientStage? initialStage;

  const AddClientDialog({super.key, this.initialStage});

  @override
  ConsumerState<AddClientDialog> createState() => _AddClientDialogState();
}

class _AddClientDialogState extends ConsumerState<AddClientDialog> {
  final _nameController = TextEditingController();
  final _ownerController = TextEditingController();
  final _categoryController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _managerController = TextEditingController();
  final _followUpNotesController = TextEditingController();
  late ClientStage _stage;
  DateTime? _followUpAt;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stage = widget.initialStage ?? ClientStage.reach;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
    _categoryController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _managerController.dispose();
    _followUpNotesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      setState(() => _error = 'Name and email are required');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final client = Client(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        ownerName: _ownerController.text.trim().isEmpty
            ? null
            : _ownerController.text.trim(),
        category: _categoryController.text.trim(),
        contactEmail: _emailController.text.trim().toLowerCase(),
        contactPhone: _phoneController.text.trim(),
        assignedManager: _managerController.text.trim().isEmpty
            ? null
            : _managerController.text.trim(),
        stage: _stage,
        createdDate: DateTime.now(),
        followUpAt: _followUpAt,
        followUpNotes: _followUpNotesController.text.trim().isEmpty
            ? null
            : _followUpNotesController.text.trim(),
      );
      await ref.read(firestoreServiceProvider).createClient(client);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${client.name}" created successfully')),
        );
        ref.invalidate(clientsListProvider);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create client: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Client'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Business name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ownerController,
                decoration: const InputDecoration(labelText: 'Owner name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category (e.g. Retail, Restaurant)',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Contact email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Contact phone'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _managerController,
                decoration: const InputDecoration(
                  labelText: 'Assigned manager (optional)',
                ),
              ),
              const SizedBox(height: 16),
              _FollowUpFields(
                followUpAt: _followUpAt,
                notesController: _followUpNotesController,
                onDateChanged: (date) => setState(() => _followUpAt = date),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ClientStage>(
                initialValue: _stage,
                items: ClientStage.values
                    .map(
                      (stage) => DropdownMenuItem(
                        value: stage,
                        child: Text(stage.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _stage = value ?? _stage),
                decoration: const InputDecoration(labelText: 'Stage'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
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
              : const Text('Create Client'),
        ),
      ],
    );
  }
}

class _FollowUpFields extends StatelessWidget {
  final DateTime? followUpAt;
  final TextEditingController notesController;
  final ValueChanged<DateTime?> onDateChanged;

  const _FollowUpFields({
    required this.followUpAt,
    required this.notesController,
    required this.onDateChanged,
  });

  Future<void> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year, now.month + 2, now.day),
      initialDate: followUpAt ?? now,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: followUpAt != null
          ? TimeOfDay.fromDateTime(followUpAt!)
          : TimeOfDay.now(),
    );
    if (time == null) return;
    onDateChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = followUpAt == null
        ? 'Set follow-up date and time'
        : 'Follow-up: ${followUpAt!.day}/${followUpAt!.month}/${followUpAt!.year} '
              '${followUpAt!.hour.toString().padLeft(2, '0')}:${followUpAt!.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.alarm_add_outlined),
          title: Text(label),
          subtitle: const Text('Choose a day this week or month'),
          trailing: followUpAt == null
              ? const Icon(Icons.calendar_month_outlined)
              : IconButton(
                  tooltip: 'Clear follow-up',
                  onPressed: () => onDateChanged(null),
                  icon: const Icon(Icons.clear),
                ),
          onTap: () => _pickDateTime(context),
        ),
        Wrap(
          spacing: 8,
          children: [
            _quickDateButton(context, 'Today', DateTime.now()),
            _quickDateButton(
              context,
              'This week',
              DateTime.now().add(const Duration(days: 7)),
            ),
            _quickDateButton(
              context,
              'This month',
              DateTime.now().add(const Duration(days: 30)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: notesController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Follow-up notes',
            hintText: 'What should be discussed?',
            prefixIcon: Icon(Icons.sticky_note_2_outlined),
          ),
        ),
      ],
    );
  }

  Widget _quickDateButton(BuildContext context, String label, DateTime date) {
    final now = TimeOfDay.now();
    return OutlinedButton(
      onPressed: () => onDateChanged(
        DateTime(date.year, date.month, date.day, now.hour, now.minute),
      ),
      child: Text(label),
    );
  }
}
