import 'package:flutter/material.dart';
import 'data/menu_data.dart';
import 'desktop_nav.dart';
import 'search_contact_social.dart';

class HeaderBar extends StatefulWidget {
  const HeaderBar({
    super.key,
    required this.onMenuTap,
    required this.activeTitle,
    required this.onActiveChange,
    this.elevation = 0,
  });

  final void Function(String id) onMenuTap;
  final String? activeTitle;
  final ValueChanged<String?> onActiveChange;
  final double elevation;

  @override
  State<HeaderBar> createState() => _HeaderBarState();
}

class _HeaderBarState extends State<HeaderBar> {
  bool _showSearch = false;
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
  final isDesktop = width > 980;

    final bg = Colors.white;
  final borderColor = Colors.black.withValues(alpha: 0.06);

    return Material(
      elevation: widget.elevation,
      color: bg,
      surfaceTintColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            bottom: BorderSide(color: borderColor, width: 1),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Semantics(
            container: true,
            label: 'Top navigation bar',
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 76),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (!isDesktop)
                      Builder(
                        builder: (context) => IconButton(
                          tooltip: 'Open menu',
                          onPressed: () => Scaffold.of(context).openDrawer(),
                          icon: const Icon(Icons.menu),
                        ),
                      ),
                    const _Logo(),
                    const SizedBox(width: 16),
                    if (isDesktop)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: DesktopNavBar(
                            menuData: menuData,
                            onMenuTap: widget.onMenuTap,
                            activeTitle: widget.activeTitle,
                            onActiveChange: widget.onActiveChange,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    InlineSearch(
                      showSearch: _showSearch,
                      controller: _searchCtrl,
                      onToggle: () => setState(() => _showSearch = !_showSearch),
                    ),
                    const SizedBox(width: 8),
                    ContactQuickActions(onTap: (id) {
                      // Debug: log menu id before forwarding
                      // ignore: avoid_print
                      print('HeaderBar: tapped $id');
                      widget.onMenuTap(id);
                      widget.onActiveChange(id);
                    }),
                    const SizedBox(width: 8),
                    const SocialIcons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.auto_awesome, color: scheme.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          'TULASI SOLUTIONS',
          style: TextStyle(
            fontSize: 16,
            letterSpacing: 1.1,
            color: scheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
