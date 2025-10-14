import 'package:flutter/material.dart';

class InlineSearch extends StatelessWidget {
  const InlineSearch({super.key, required this.showSearch, required this.controller, required this.onToggle});
  final bool showSearch;
  final TextEditingController controller;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: showSearch ? 220 : 0,
          curve: Curves.easeOutCubic,
          child: showSearch
              ? TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                  onSubmitted: (q) {
                    // TO DO: wire to search route / backend
                    debugPrint('Search submit: $q');
                  },
                )
              : const SizedBox.shrink(),
        ),
        IconButton(
          tooltip: showSearch ? 'Close search' : 'Open search',
          onPressed: onToggle,
          icon: Icon(showSearch ? Icons.close : Icons.search),
          color: scheme.primary,
        ),
      ],
    );
  }
}

class ContactQuickActions extends StatelessWidget {
  const ContactQuickActions({super.key, required this.onTap});
  final void Function(String id) onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'WhatsApp',
          onPressed: () => onTap('WhatsApp'),
          icon: const Icon(Icons.chat),
          color: scheme.primary,
        ),
        FilledButton.tonal(
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          ),
          onPressed: () => onTap('Contact'),
          child: const Text('Contact'),
        ),
      ],
    );
  }
}

class SocialIcons extends StatelessWidget {
  const SocialIcons({super.key});
  @override
  Widget build(BuildContext context) {
    final icons = const [
      Icons.public, // FB placeholder
      Icons.photo_camera_outlined, // Instagram placeholder
      Icons.ondemand_video, // YouTube placeholder
      Icons.alternate_email, // X/Twitter placeholder
      Icons.work_outline, // LinkedIn placeholder
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final icon in icons)
          IconButton(
            onPressed: () {
              // TO DO: wire to social links (optional url_launcher)
              debugPrint('Social tap: $icon');
            },
            icon: Icon(icon),
            tooltip: 'Social',
          ),
      ],
    );
  }
}
