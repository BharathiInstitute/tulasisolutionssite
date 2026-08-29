import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';

class AddEditGoalScreen extends ConsumerStatefulWidget {
  final String clientId;
  final Goal? existingGoal;

  const AddEditGoalScreen({
    super.key,
    required this.clientId,
    this.existingGoal,
  });

  @override
  ConsumerState<AddEditGoalScreen> createState() => _AddEditGoalScreenState();
}

class _AddEditGoalScreenState extends ConsumerState<AddEditGoalScreen> {
  late TextEditingController _baselineController;
  late TextEditingController _liftPercentageController;
  late TextEditingController _targetController;
  late TextEditingController _progressController;

  GoalType _selectedType = GoalType.leads;
  String _selectedPeriod = 'Monthly';
  GoalStage _selectedStage = GoalStage.draft;
  bool _guaranteeLinked = false;
  DateTime? _targetDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _baselineController = TextEditingController(
      text: widget.existingGoal?.baselineValue.toString() ?? '',
    );
    _liftPercentageController = TextEditingController(
      text: widget.existingGoal != null
          ? (widget.existingGoal!.liftPercentage * 100).toStringAsFixed(0)
          : '',
    );
    _targetController = TextEditingController(
      text: widget.existingGoal?.targetValue.toString() ?? '',
    );
    _progressController = TextEditingController(
      text: widget.existingGoal?.progressValue?.toString() ?? '',
    );

    if (widget.existingGoal != null) {
      _selectedType = widget.existingGoal!.type;
      _selectedPeriod = widget.existingGoal!.period;
      _selectedStage = widget.existingGoal!.stage;
      _guaranteeLinked = widget.existingGoal!.guaranteeLinked;
      _targetDate = widget.existingGoal!.targetDate;
    }
  }

  @override
  void dispose() {
    _baselineController.dispose();
    _liftPercentageController.dispose();
    _targetController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _calculateTarget() {
    final baseline = double.tryParse(_baselineController.text) ?? 0;
    final liftPercent =
        (double.tryParse(_liftPercentageController.text) ?? 0) / 100;
    final target = baseline * (1 + liftPercent);

    _targetController.text = target.toStringAsFixed(2);
  }

  Future<void> _saveGoal() async {
    if (_baselineController.text.isEmpty ||
        _liftPercentageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final baseline = double.parse(_baselineController.text);
      final liftPercent = (double.parse(_liftPercentageController.text)) / 100;
      final target = double.parse(_targetController.text);
      final progress = _progressController.text.isNotEmpty
          ? double.parse(_progressController.text)
          : null;

      final goal = Goal(
        id: widget.existingGoal?.id ?? const Uuid().v4(),
        clientId: widget.clientId,
        type: _selectedType,
        baselineValue: baseline,
        liftPercentage: liftPercent,
        targetValue: target,
        period: _selectedPeriod,
        stage: _selectedStage,
        progressValue: progress,
        guaranteeLinked: _guaranteeLinked,
        createdDate: widget.existingGoal?.createdDate ?? DateTime.now(),
        targetDate: _targetDate,
      );

      if (widget.existingGoal != null) {
        await ref.read(firestoreServiceProvider).updateGoal(goal);
      } else {
        await ref.read(firestoreServiceProvider).createGoal(goal);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingGoal != null
                  ? 'Goal updated successfully'
                  : 'Goal created successfully',
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingGoal != null ? 'Edit Goal' : 'Add Goal'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Goal Type
            Text('Goal Type', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<GoalType>(
              initialValue: _selectedType,
              items: GoalType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedType = value!);
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Baseline Value
            Text(
              'Baseline Value (Current)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _baselineController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              onChanged: (_) => _calculateTarget(),
              decoration: InputDecoration(
                hintText: 'e.g., 20',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Lift Percentage
            Text(
              'Lift Percentage',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _liftPercentageController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    onChanged: (_) => _calculateTarget(),
                    decoration: InputDecoration(
                      hintText: 'e.g., 30',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '%',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tier Recommendations',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Growth Partner: 15–25% | Scale Partner: 30–50% | Equity Partner: 50%+',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Target Value (Auto-calculated)
            Text(
              'Target Value (Auto-calculated)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _targetController,
              enabled: false,
              decoration: InputDecoration(
                hintText: 'Auto-calculated',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.withValues(alpha: 0.1),
              ),
            ),
            const SizedBox(height: 24),

            // Period
            Text('Period', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedPeriod,
              items: ['Monthly', 'Quarterly']
                  .map(
                    (period) =>
                        DropdownMenuItem(value: period, child: Text(period)),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedPeriod = value!);
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Stage
            Text('Goal Stage', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<GoalStage>(
              initialValue: _selectedStage,
              items: GoalStage.values
                  .map(
                    (stage) => DropdownMenuItem(
                      value: stage,
                      child: Text(stage.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedStage = value!);
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Progress Value (if goal is active)
            if (_selectedStage == GoalStage.active ||
                _selectedStage == GoalStage.underReview ||
                _selectedStage == GoalStage.achieved ||
                _selectedStage == GoalStage.missedGuaranteeApplied) ...[
              Text(
                'Current Progress',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _progressController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter current value',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Target Date
            Text(
              'Target Completion Date (Optional)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _targetDate != null
                        ? _targetDate.toString().split(' ')[0]
                        : 'No date selected',
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _targetDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => _targetDate = date);
                    }
                  },
                  child: const Text('Pick Date'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Guarantee Linked
            Card(
              child: CheckboxListTile(
                value: _guaranteeLinked,
                onChanged: (value) {
                  setState(() => _guaranteeLinked = value ?? false);
                },
                title: const Text('Link to Guarantee'),
                subtitle: const Text('Missing target triggers fee waiver'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveGoal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        widget.existingGoal != null
                            ? 'Update Goal'
                            : 'Create Goal',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
