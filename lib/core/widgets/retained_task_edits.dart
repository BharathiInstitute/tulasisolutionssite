import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RetainedTaskEdits extends StatelessWidget {
  final Map<String, String> edits;
  final bool latestLoaded;

  const RetainedTaskEdits({
    super.key,
    required this.edits,
    this.latestLoaded = true,
  });

  @override
  Widget build(BuildContext context) {
    if (edits.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      initiallyExpanded: true,
      title: const Text('Your retained edits'),
      subtitle: Text(
        latestLoaded
            ? 'Latest data is loaded. Copy the text you want to keep into the fields below, then review before saving. Approval actions are not replayed.'
            : 'These edits are not confirmed saved. Copy the text you want to keep; closing this view does not discard it.',
      ),
      children: [
        for (final entry in edits.entries)
          ListTile(
            title: Text(entry.key),
            subtitle: SelectableText(
              entry.value.isEmpty ? '(Cleared)' : entry.value,
            ),
            trailing: IconButton(
              tooltip: 'Copy ${entry.key}',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () async {
                try {
                  await Clipboard.setData(ClipboardData(text: entry.value));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied retained text.')),
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Could not copy retained text: $error. You can select and copy it manually.',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ),
      ],
    );
  }
}
