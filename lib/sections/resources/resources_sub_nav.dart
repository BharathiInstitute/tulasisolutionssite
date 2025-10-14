import 'package:flutter/material.dart';

/// Public reusable sub-navigation for resource section pages.
class ResourcesSubNav extends StatelessWidget {
  const ResourcesSubNav({super.key, required this.current});
  final String current; // 'blog' | 'guides' | 'templates' | 'faqs' | 'cases'
  static const _items = [
    ('Blog', Icons.edit, '/resources/blog', 'blog'),
    ('Guides', Icons.menu_book_rounded, '/resources/guides', 'guides'),
    ('Templates', Icons.extension, '/resources/templates', 'templates'),
    ('FAQs', Icons.help_outline, '/resources/faqs', 'faqs'),
    ('Case Studies', Icons.insights, '/resources/cases', 'cases'),
  ];
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Resources section navigation',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final item in _items)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _ResourcesSubNavItem(
                  label: item.$1,
                  icon: item.$2,
                  route: item.$3,
                  active: current == item.$4,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResourcesSubNavItem extends StatelessWidget {
  const _ResourcesSubNavItem({required this.label, required this.icon, required this.route, required this.active});
  final String label; final IconData icon; final String route; final bool active;
  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.black87;
    final activeColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: active ? null : () => Navigator.of(context).pushReplacementNamed(route),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: .14) : const Color(0xFFD6F4D8),
          border: Border.all(color: active ? activeColor.withValues(alpha: .4) : Colors.black12),
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: active ? activeColor : baseColor),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: active ? activeColor : baseColor)),
          ],
        ),
      ),
    );
  }
}
