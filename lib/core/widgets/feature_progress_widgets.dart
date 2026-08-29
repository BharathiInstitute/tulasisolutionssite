import 'package:flutter/material.dart';

/// Features on a [Plan] or [PlanTemplate] are stored as "Category: feature
/// text" so they can be grouped under sub-headers when displayed. A feature
/// with no "Category: " prefix falls under [defaultFeatureCategory].
const String defaultFeatureCategory = 'General';

({String category, String text}) parseFeature(String raw) {
  final separatorIndex = raw.indexOf(': ');
  if (separatorIndex <= 0) {
    return (category: defaultFeatureCategory, text: raw);
  }
  return (
    category: raw.substring(0, separatorIndex),
    text: raw.substring(separatorIndex + 2),
  );
}

String encodeFeature(String category, String text) {
  final trimmedCategory = category.trim();
  if (trimmedCategory.isEmpty || trimmedCategory == defaultFeatureCategory) {
    return text.trim();
  }
  return '$trimmedCategory: ${text.trim()}';
}

Map<String, List<String>> groupFeaturesByCategory(List<String> features) {
  final grouped = <String, List<String>>{};
  for (final raw in features) {
    final parsed = parseFeature(raw);
    grouped.putIfAbsent(parsed.category, () => []).add(parsed.text);
  }
  return grouped;
}

/// Same grouping as [groupFeaturesByCategory] but keeps the raw
/// "Category: text" string as the value so it can be used as a stable key
/// for tracking completion (checkbox state) per feature.
Map<String, List<String>> groupRawFeaturesByCategory(List<String> features) {
  final grouped = <String, List<String>>{};
  for (final raw in features) {
    final parsed = parseFeature(raw);
    grouped.putIfAbsent(parsed.category, () => []).add(raw);
  }
  return grouped;
}

/// Renders a feature list grouped under collapsible category sub-headers
/// (read-only, no completion tracking) — used for Plan Templates.
class GroupedFeatureList extends StatelessWidget {
  final List<String> features;

  const GroupedFeatureList({super.key, required this.features});

  @override
  Widget build(BuildContext context) {
    final grouped = groupFeaturesByCategory(features);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in grouped.entries)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(
                entry.key,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: Text('${entry.value.length}'),
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: entry.value
                      .map((f) => Chip(label: Text(f)))
                      .toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Renders a feature list with per-feature tracking controls, grouped under
/// collapsible category sub-headers showing "done/total (percent)" progress.
///
/// Features containing quantities use a count slider. Other features use a
/// simple completion checkbox.
class TrackableFeatureList extends StatelessWidget {
  final List<String> features;
  final List<String> completedFeatures;
  final void Function(String rawFeature, bool done) onToggle;
  final void Function(String rawFeature, int percent)? onProgressChange;
  final Map<String, int>? featureProgress;

  const TrackableFeatureList({
    super.key,
    required this.features,
    required this.completedFeatures,
    required this.onToggle,
    this.onProgressChange,
    this.featureProgress,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = groupRawFeaturesByCategory(features);
    final completedSet = completedFeatures.toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in grouped.entries)
          Builder(
            builder: (context) {
              final done = entry.value
                  .where((raw) => completedSet.contains(raw))
                  .length;
              final total = entry.value.length;
              final percent = total == 0 ? 0 : (done / total * 100).round();
              return Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: done == total
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: Text('$done/$total ($percent%)'),
                  children: [
                    for (final raw in entry.value)
                      _TrackableFeatureRow(
                        rawFeature: raw,
                        isDone: completedSet.contains(raw),
                        progress:
                            featureProgress?[raw] ??
                            (completedSet.contains(raw) ? 100 : 0),
                        onToggle: onToggle,
                        onProgressChange: onProgressChange,
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// A single trackable feature row: "Done" checkbox + per-feature progress
/// slider (0–100), each updateable independently.
class _TrackableFeatureRow extends StatelessWidget {
  final String rawFeature;
  final bool isDone;
  final int progress;
  final void Function(String rawFeature, bool done) onToggle;
  final void Function(String rawFeature, int percent)? onProgressChange;

  const _TrackableFeatureRow({
    required this.rawFeature,
    required this.isDone,
    required this.progress,
    required this.onToggle,
    required this.onProgressChange,
  });

  @override
  Widget build(BuildContext context) {
    final targetCount = _countTarget(parseFeature(rawFeature).text);
    final isCountFeature = targetCount != null;
    final currentCount = isCountFeature
        ? ((progress * targetCount) / 100).round().clamp(0, targetCount)
        : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(parseFeature(rawFeature).text)),
              const SizedBox(width: 8),
              Text(
                isCountFeature ? '$currentCount/$targetCount' : 'Done',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (isCountFeature)
            Slider(
              value: currentCount.toDouble(),
              min: 0,
              max: targetCount.toDouble(),
              divisions: targetCount,
              label: '$currentCount/$targetCount',
              onChanged: onProgressChange == null
                  ? null
                  : (value) => onProgressChange!(
                      rawFeature,
                      ((value / targetCount) * 100).round(),
                    ),
            )
          else
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: isDone,
              title: const Text('Mark complete'),
              onChanged: (value) => onToggle(rawFeature, value ?? false),
            ),
        ],
      ),
    );
  }

  int? _countTarget(String text) {
    final countable = RegExp(
      r'(?:reels?|videos?|designs?|photos?|pieces?|sessions?)',
      caseSensitive: false,
    );
    final quantities = <int>[];
    for (final match in countable.allMatches(text)) {
      final before = text.substring(0, match.start);
      final number = RegExp(r'(\d+)\s*[-+]?\s*$').firstMatch(before);
      final value = int.tryParse(number?.group(1) ?? '');
      if (value != null && value > 0) quantities.add(value);
    }
    if (quantities.isEmpty) return null;
    return quantities.fold<int>(0, (sum, value) => sum + value);
  }
}
