import 'package:flutter/material.dart';

class MobileDrawer extends StatelessWidget {
  const MobileDrawer({super.key, required this.menuData, required this.onMenuTap, this.activeTitle});
  final List<Map<String, dynamic>> menuData;
  final void Function(String id) onMenuTap;
  final String? activeTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
  // Drawer content reflects top-level with nested accordions.

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.auto_awesome, color: scheme.primary),
              title: const Text('TULASI SOLUTIONS', style: TextStyle(fontWeight: FontWeight.w800)),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: menuData.map((item) {
                  final title = item['title'] as String;
                  final children = (item['children'] as List<dynamic>?)?.cast<Map<String, dynamic>>();
                  final isActive = activeTitle == title;
                  // Determine if a services child / grandchild is active so we can auto-expand
                  bool servicesNeedsOpen = false;
                  if (title == 'Services' && activeTitle != null) {
                    for (final group in (children ?? const [])) {
                      if (group['title'] == activeTitle) {
                        servicesNeedsOpen = true;
                        break;
                      }
                      final gc = (group['children'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
                      if (gc.any((c) => c['title'] == activeTitle)) {
                        servicesNeedsOpen = true;
                        break;
                      }
                    }
                  }
                  if (title == 'Pricing') {
                    return ExpansionTile(
                      title: Text(title, style: isActive ? TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold) : null),
                      children: [
                        ListTile(title: const Text('View Pricing'), onTap: () => onMenuTap('Pricing')),
                      ],
                    );
                  } else if (children != null && children.isNotEmpty) {
                    final bool isServices = title == 'Services';
                    return ExpansionTile(
                      title: Text(title, style: isActive ? TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold) : null),
                      initiallyExpanded: isServices && servicesNeedsOpen,
                      children: children
                          .map((c) => ListTile(
                                title: Text(c['title'] as String, style: activeTitle == c['title'] ? TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold) : null),
                                onTap: () => onMenuTap(c['title'] as String),
                              ))
                          .toList(),
                    );
                  } else {
                    return ListTile(
                      title: Text(title, style: isActive ? TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold) : null),
                      onTap: () => onMenuTap(title),
                    );
                  }
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onMenuTap('WhatsApp'),
                      icon: const Icon(Icons.chat),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => onMenuTap('Contact'),
                      child: const Text('Contact'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
