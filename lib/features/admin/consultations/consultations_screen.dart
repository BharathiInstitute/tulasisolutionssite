import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';

class ConsultationsScreen extends ConsumerWidget {
  const ConsultationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consultationsAsync = ref.watch(allConsultationsProvider);
    final clientsAsync = ref.watch(clientsListProvider);

    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/consultations',
      title: 'Clients',
      floatingActionButton: clientsAsync.maybeWhen(
        data: (clients) => FloatingActionButton.extended(
          onPressed: clients.isEmpty
              ? null
              : () => _showConsultationDialog(context, ref, clients),
          icon: const Icon(Icons.add),
          label: const Text('Schedule'),
        ),
        orElse: () => null,
      ),
      body: consultationsAsync.when(
        data: (consultations) {
          if (consultations.isEmpty) {
            return const Center(child: Text('No consultations scheduled yet'));
          }
          return clientsAsync.when(
            data: (clients) {
              final clientNames = {for (final c in clients) c.id: c.name};
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: consultations.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final consultation = consultations[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.event),
                      title: Text(
                        clientNames[consultation.clientId] ?? 'Unknown client',
                      ),
                      subtitle: Text(
                        DateFormat(
                          'MMM d, y • h:mm a',
                        ).format(consultation.dateTime),
                      ),
                      trailing: Chip(
                        label: Text(consultation.status.displayName),
                      ),
                      onTap: () => _showConsultationDialog(
                        context,
                        ref,
                        clients,
                        existing: consultation,
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const LoadingWidget(),
            error: (error, stackTrace) =>
                CustomErrorWidget(message: 'Error loading clients: $error'),
          );
        },
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) =>
            CustomErrorWidget(message: 'Error loading consultations: $error'),
      ),
    );
  }

  void _showConsultationDialog(
    BuildContext context,
    WidgetRef ref,
    List<Client> clients, {
    Consultation? existing,
  }) {
    showDialog(
      context: context,
      builder: (context) =>
          _ConsultationDialog(clients: clients, existing: existing),
    );
  }
}

class _ConsultationDialog extends ConsumerStatefulWidget {
  final List<Client> clients;
  final Consultation? existing;

  const _ConsultationDialog({required this.clients, this.existing});

  @override
  ConsumerState<_ConsultationDialog> createState() =>
      _ConsultationDialogState();
}

class _ConsultationDialogState extends ConsumerState<_ConsultationDialog> {
  late String _clientId;
  late DateTime _dateTime;
  late ConsultationStatus _status;
  late TextEditingController _notesController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _clientId = widget.existing?.clientId ?? widget.clients.first.id;
    _dateTime =
        widget.existing?.dateTime ??
        DateTime.now().add(const Duration(days: 1));
    _status = widget.existing?.status ?? ConsultationStatus.scheduled;
    _notesController = TextEditingController(
      text: widget.existing?.notes ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final consultation = Consultation(
        id: widget.existing?.id ?? const Uuid().v4(),
        clientId: _clientId,
        dateTime: _dateTime,
        status: _status,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );
      final service = ref.read(firestoreServiceProvider);
      if (widget.existing != null) {
        await service.updateConsultation(consultation);
      } else {
        await service.createConsultation(consultation);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing != null ? 'Edit Consultation' : 'Schedule Consultation',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              decoration: const InputDecoration(
                labelText: 'Client',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(DateFormat('MMM d, y • h:mm a').format(_dateTime)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDateTime,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ConsultationStatus>(
              initialValue: _status,
              items: ConsultationStatus.values
                  .map(
                    (s) =>
                        DropdownMenuItem(value: s, child: Text(s.displayName)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _status = value ?? _status),
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
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
