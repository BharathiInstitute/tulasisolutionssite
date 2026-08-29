import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';
import 'package:intl/intl.dart';

class ContentLogScreen extends ConsumerStatefulWidget {
  final String clientId;

  const ContentLogScreen({super.key, required this.clientId});

  @override
  ConsumerState<ContentLogScreen> createState() => _ContentLogScreenState();
}

class _ContentLogScreenState extends ConsumerState<ContentLogScreen> {
  @override
  Widget build(BuildContext context) {
    final contentLogsAsync = ref.watch(contentLogsProvider(widget.clientId));

    return contentLogsAsync.when(
      data: (logs) {
        // Calculate monthly stats
        final thisMonth = DateTime.now();
        final monthLogs = logs
            .where(
              (log) =>
                  log.month == thisMonth.month && log.year == thisMonth.year,
            )
            .toList();

        final totalImages = monthLogs.fold<int>(
          0,
          (sum, log) => sum + log.imagesDelivered,
        );
        final totalReels = monthLogs.fold<int>(
          0,
          (sum, log) => sum + log.reelsDelivered,
        );
        final totalRevisions = monthLogs.fold<int>(
          0,
          (sum, log) => sum + log.revisionRounds,
        );

        final targetImages = 12; // Default target
        final targetReels = 12;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Content Delivery Log',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddContentDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Summary Cards
              Text(
                '${DateFormat('MMMM yyyy').format(thisMonth)} Summary',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Images',
                      '$totalImages / $targetImages',
                      (totalImages / targetImages).clamp(0, 1).toDouble(),
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'Reels',
                      '$totalReels / $targetReels',
                      (totalReels / targetReels).clamp(0, 1).toDouble(),
                      Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.refresh, color: Colors.orange),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Revision Rounds Used',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '$totalRevisions',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Monthly Timeline
              Text(
                'Content Timeline',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (monthLogs.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No content entries for this month',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: monthLogs.length,
                  itemBuilder: (context, index) {
                    final log = monthLogs[index];
                    return _buildContentLogCard(context, log, ref);
                  },
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: LoadingWidget()),
      error: (error, stackTrace) =>
          CustomErrorWidget(message: 'Error loading content logs: $error'),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    double progress,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentLogCard(
    BuildContext context,
    ContentLog log,
    WidgetRef ref,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Week ${log.weekNumber}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Text('Edit'),
                      onTap: () => _showEditContentDialog(context, log, ref),
                    ),
                    PopupMenuItem(
                      child: const Text('Delete'),
                      onTap: () => _showDeleteConfirmation(context, log, ref),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLogStat('Images', log.imagesDelivered, Colors.blue),
                _buildLogStat('Reels', log.reelsDelivered, Colors.purple),
                _buildLogStat('Revisions', log.revisionRounds, Colors.orange),
              ],
            ),
            if (log.notes != null && log.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${log.notes}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogStat(String label, int value, Color color) {
    return Column(
      children: [
        Icon(Icons.check_circle, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value.toString(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
        ),
      ],
    );
  }

  void _showAddContentDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) =>
          _ContentLogDialog(clientId: widget.clientId, ref: ref),
    );
  }

  void _showEditContentDialog(
    BuildContext context,
    ContentLog log,
    WidgetRef ref,
  ) {
    showDialog(
      context: context,
      builder: (context) => _ContentLogDialog(
        clientId: widget.clientId,
        ref: ref,
        existingLog: log,
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    ContentLog log,
    WidgetRef ref,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: const Text('Remove this content log entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(firestoreServiceProvider)
                    .deleteContentLog(widget.clientId, log.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Entry deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ContentLogDialog extends ConsumerStatefulWidget {
  final String clientId;
  final WidgetRef ref;
  final ContentLog? existingLog;

  const _ContentLogDialog({
    required this.clientId,
    required this.ref,
    this.existingLog,
  });

  @override
  ConsumerState<_ContentLogDialog> createState() => _ContentLogDialogState();
}

class _ContentLogDialogState extends ConsumerState<_ContentLogDialog> {
  late TextEditingController _imagesController;
  late TextEditingController _reelsController;
  late TextEditingController _revisionsController;
  late TextEditingController _notesController;
  late int _selectedWeek;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _imagesController = TextEditingController(
      text: widget.existingLog?.imagesDelivered.toString() ?? '',
    );
    _reelsController = TextEditingController(
      text: widget.existingLog?.reelsDelivered.toString() ?? '',
    );
    _revisionsController = TextEditingController(
      text: widget.existingLog?.revisionRounds.toString() ?? '',
    );
    _notesController = TextEditingController(
      text: widget.existingLog?.notes ?? '',
    );
    _selectedWeek = widget.existingLog?.weekNumber ?? 1;
  }

  @override
  void dispose() {
    _imagesController.dispose();
    _reelsController.dispose();
    _revisionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveContentLog() async {
    if (_imagesController.text.isEmpty ||
        _reelsController.text.isEmpty ||
        _revisionsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final log = ContentLog(
        id: widget.existingLog?.id ?? const Uuid().v4(),
        clientId: widget.clientId,
        month: now.month,
        year: now.year,
        weekNumber: _selectedWeek,
        imagesDelivered: int.parse(_imagesController.text),
        reelsDelivered: int.parse(_reelsController.text),
        revisionRounds: int.parse(_revisionsController.text),
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        createdDate: widget.existingLog?.createdDate ?? now,
      );

      if (widget.existingLog != null) {
        await ref.read(firestoreServiceProvider).updateContentLog(log);
      } else {
        await ref.read(firestoreServiceProvider).createContentLog(log);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingLog != null ? 'Entry updated' : 'Entry created',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existingLog != null ? 'Edit Content Log' : 'Add Content Log',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _selectedWeek,
              items: List.generate(
                4,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text('Week ${i + 1}'),
                ),
              ),
              onChanged: (value) => setState(() => _selectedWeek = value ?? 1),
              decoration: const InputDecoration(
                labelText: 'Week',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _imagesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Images Delivered',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reelsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Reels Delivered',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _revisionsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Revision Rounds',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
          onPressed: _isLoading ? null : _saveContentLog,
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
