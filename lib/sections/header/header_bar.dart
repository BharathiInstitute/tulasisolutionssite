import 'package:flutter/material.dart';
import 'data/menu_data.dart';
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

// ===== Inlined Desktop Navigation and Dropdowns (moved from desktop_nav.dart) =====

// Overlay entry factory for dropdown panels
OverlayEntry createDropdownOverlay({
  required LayerLink targetLink,
  required Widget child,
  BoxConstraints constraints = const BoxConstraints(
    minWidth: 240,
    maxWidth: 760,
    maxHeight: 420,
  ),
  VoidCallback? onExit,
  EdgeInsets hoverBuffer = const EdgeInsets.fromLTRB(0, 6, 6, 6),
  double topHoverBridgeHeight = 16,
}) {
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      return Stack(
        children: [
          CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 44),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 160),
              builder: (context, v, c) => Opacity(
                opacity: v,
                child: Transform.translate(
                  offset: Offset(0, (1 - v) * -6),
                  child: c,
                ),
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                opaque: false,
                onExit: (_) {
                  onExit?.call();
                },
                child: Align(
                  alignment: Alignment.topLeft,
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Padding(
                    padding: hoverBuffer,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: topHoverBridgeHeight, width: 1),
                        Material(
                          color: Colors.white,
                          surfaceTintColor: Colors.white,
                          elevation: 6,
                          borderRadius: BorderRadius.circular(10),
                          child: ConstrainedBox(
                            constraints: constraints,
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: child,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
  return entry;
}

class DefaultDropdownList extends StatelessWidget {
  const DefaultDropdownList({super.key, required this.title, required this.items, required this.onTap});
  final String title;
  final List<Map<String, dynamic>> items;
  final void Function(String) onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownHeader(title: title),
            const SizedBox(height: 6),
            ...items.map((e) {
              final t = e['title'] as String;
              return InkWell(
                mouseCursor: SystemMouseCursors.click,
                onTap: () => onTap(t),
                borderRadius: BorderRadius.circular(8),
                hoverColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_right, color: scheme.primary, size: 16),
                      const SizedBox(width: 6),
                      Text(t, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class DropdownHeader extends StatelessWidget {
  const DropdownHeader({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
      ),
    );
  }
}

class MegaMenuGrid extends StatelessWidget {
  const MegaMenuGrid({super.key, required this.heading, required this.items, required this.onTap});
  final String heading;
  final List<String> items;
  final void Function(String) onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 520),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownHeader(title: heading),
            const SizedBox(height: 6),
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth > 640 ? 3 : 2;
              return GridView.builder(
                itemCount: items.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisExtent: 40,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 2,
                ),
                itemBuilder: (context, i) {
                  final t = items[i];
                  return InkWell(
                    onTap: () => onTap(t),
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 6, color: scheme.primary),
                        const SizedBox(width: 8),
                        Flexible(child: Text(t, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

class IndustriesMenuContent extends StatelessWidget {
  const IndustriesMenuContent({super.key, required this.title, required this.onTap});
  final String title;
  final void Function(String) onTap;

  List<String> _extractIndustries() {
    final start = title.indexOf('(');
    final end = title.lastIndexOf(')');
    if (start == -1 || end == -1 || end <= start) return const [];
    final inner = title.substring(start + 1, end);
    return inner.split(',').map((s) => s.trim()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final industries = _extractIndustries();
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DropdownHeader(title: 'Industries'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: industries.map((i) {
              return InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Text(i, style: const TextStyle(fontSize: 13)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class PricingMenuContent extends StatelessWidget {
  const PricingMenuContent({super.key, required this.onTap});
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tiles = const [
      ('Starter', '₹3,000', 'per month'),
      ('Growth', '₹5,000', 'per month'),
      ('Expansion', '₹10,000', 'per month'),
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 520),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DropdownHeader(
              title: 'Pricing (Starter ₹3,000 / Growth ₹5,000 / Expansion ₹10,000 per month)'),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 680 ? 3 : 1;
            return GridView.builder(
              itemCount: tiles.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisExtent: 140,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, i) {
                final (name, price, per) = tiles[i];
                return InkWell(
                  onTap: () => onTap('$name $price'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
                      color: Colors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            )),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(price,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                )),
                            const SizedBox(width: 6),
                            Text(per, style: const TextStyle(fontSize: 12)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Select', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
          const SizedBox(height: 4),
          Text(
            'TO DO: wire pricing actions to routes / checkout',
            style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

class ContactMenuContent extends StatelessWidget {
  const ContactMenuContent({super.key, required this.onTap});
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Form', Icons.input),
      ('WhatsApp', Icons.chat),
      ('Phone', Icons.phone),
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DropdownHeader(title: 'Contact'),
          ...items.map((e) {
            final (t, icon) = e;
            return InkWell(
              onTap: () => onTap('Contact:$t'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                    Text(t, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          Text(
            'TO DO: wire to form / WhatsApp / tel: using url_launcher (optional).',
            style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

class DesktopNavBar extends StatefulWidget {
  const DesktopNavBar({
    super.key,
    required this.menuData,
    required this.onMenuTap,
    required this.activeTitle,
    required this.onActiveChange,
  });

  final List<Map<String, dynamic>> menuData;
  final void Function(String id) onMenuTap;
  final String? activeTitle;
  final ValueChanged<String?> onActiveChange;

  @override
  State<DesktopNavBar> createState() => _DesktopNavBarState();
}

class _DesktopNavBarState extends State<DesktopNavBar> {
  OverlayEntry? _currentOverlay;
  VoidCallback? _markPrevClosed;
  int? _openIndex;

  void _onOverlayOpened(OverlayEntry entry, VoidCallback markSelfClosed) {
    if (_markPrevClosed != null) {
      _markPrevClosed!.call();
    } else {
      _currentOverlay?.remove();
    }
    // ignore: avoid_print
    print('DesktopNavBar: overlay opened');
    _currentOverlay = entry;
    _markPrevClosed = markSelfClosed;
  }

  void _onOverlayClosed() {
    // ignore: avoid_print
    print('DesktopNavBar: overlay closed');
    _currentOverlay = null;
    _markPrevClosed = null;
    _openIndex = null;
  }

  @override
  void dispose() {
    try {
      _currentOverlay?.remove();
    } catch (_) {}
    _currentOverlay = null;
    _markPrevClosed = null;
    _openIndex = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.menuData;
    final servicesItem = items.firstWhere(
      (e) => (e['title'] as String) == 'Services',
      orElse: () => const {},
    );
    final nested = <String>{};
    if (servicesItem.isNotEmpty) {
      for (final g in (servicesItem['children'] as List<dynamic>? ?? const [])) {
        final gm = g as Map<String, dynamic>;
        nested.add(gm['title'] as String);
        for (final c in (gm['children'] as List<dynamic>? ?? const [])) {
          final cm = c as Map<String, dynamic>;
          nested.add(cm['title'] as String);
        }
      }
    }
    return FocusTraversalGroup(
      child: Wrap(
        spacing: 4,
        children: List.generate(items.length, (i) {
          final item = items[i];
          final String title = item['title'] as String;
          final List<dynamic>? children = item['children'] as List<dynamic>?;
          final isActive = widget.activeTitle == title;

          final hasChildren = (children != null && children.isNotEmpty);
          return _NavItem(
            title: title,
            children: children?.cast<Map<String, dynamic>>(),
            hasChildren: hasChildren,
            isActive: isActive,
            isOpen: _openIndex == i,
            autoOpen: false,
            onTap: () {
              widget.onMenuTap(title);
              widget.onActiveChange(title);
            },
            onItemSelected: (t) {
              // ignore: avoid_print
              print('DesktopNavBar: item selected -> $t');
              widget.onMenuTap(t);
              widget.onActiveChange(t);
            },
            onOverlayOpened: _onOverlayOpened,
            onOverlayClosed: _onOverlayClosed,
            onToggleOpen: () {
              setState(() {
                _openIndex = (_openIndex == i) ? null : i;
              });
            },
          );
        }),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.title,
    required this.children,
    required this.hasChildren,
    required this.isActive,
    required this.isOpen,
    required this.autoOpen,
    required this.onTap,
    required this.onItemSelected,
    required this.onOverlayOpened,
    required this.onOverlayClosed,
    required this.onToggleOpen,
  });

  final String title;
  final List<Map<String, dynamic>>? children;
  final bool hasChildren;
  final bool isActive;
  final bool isOpen;
  final bool autoOpen;
  final VoidCallback onTap;
  final ValueChanged<String> onItemSelected;
  final void Function(OverlayEntry entry, VoidCallback markSelfClosed) onOverlayOpened;
  final VoidCallback onOverlayClosed;
  final VoidCallback onToggleOpen;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _ServicesMegaMenu extends StatelessWidget {
  const _ServicesMegaMenu({required this.groups, required this.onTap});
  final List<Map<String, dynamic>> groups;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final screenW = MediaQuery.sizeOf(context).width;
      final cols = screenW >= 900 ? 2 : 1;
      final perCol = (groups.length / cols).ceil();
      final columns = <List<Map<String, dynamic>>>[];
      for (int i = 0; i < groups.length; i += perCol) {
        columns.add(groups.sublist(i, (i + perCol).clamp(0, groups.length)));
      }
      return Scrollbar(
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        radius: const Radius.circular(8),
        thickness: 8,
        child: SingleChildScrollView(
          primary: false,
          physics: const ClampingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final col in columns)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 200, maxWidth: 230),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final group in col) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 6.0, bottom: 6.0),
                            child: Text(
                              group['title'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          ...((group['children'] as List<dynamic>? ?? const [])
                              .cast<Map<String, dynamic>>()
                              .map((child) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 5),
                                    child: InkWell(
                                      mouseCursor: SystemMouseCursors.click,
                                      onTap: () => onTap(child['title'] as String),
                                      borderRadius: BorderRadius.circular(6),
                                      hoverColor: Colors.transparent,
                                      splashColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.chevron_right, size: 15),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              child['title'] as String,
                                              style: const TextStyle(fontSize: 13.0),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ))
                              .toList()),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _NavItemState extends State<_NavItem> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  bool _menuOpen = false;
  bool _hovering = false;

  void _markSelfClosed() {
    _entry?.remove();
    _entry = null;
    _menuOpen = false;
  }

  void _hideMenu() {
    if (!_menuOpen) return;
    try {
      _entry?.remove();
    } catch (_) {}
    _entry = null;
    _menuOpen = false;
    widget.onOverlayClosed();
  }

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = Colors.black87;
    final activeColor = scheme.primary;
    final bool showBg = widget.isActive || _hovering;
    final Color bgColor = showBg
        ? scheme.primary.withValues(alpha: widget.isActive ? 0.10 : 0.06)
        : Colors.transparent;
    final Color textColor = widget.isActive
        ? activeColor
        : _hovering
            ? activeColor
            : baseColor;
    final bool isIndustries = widget.title == 'Industries';
    final bool dropdownEligible = widget.hasChildren && !isIndustries;
    return CompositedTransformTarget(
      link: _link,
      child: Semantics(
        button: true,
        label: 'Menu item: ${widget.title}',
        child: MouseRegion(
          onEnter: (_) {
            setState(() => _hovering = true);
          },
          onExit: (_) {
            setState(() => _hovering = false);
            if (dropdownEligible && _menuOpen) {
              Future.delayed(const Duration(milliseconds: 120), () {
                if (!_hovering && mounted) {}
              });
            }
          },
          cursor: SystemMouseCursors.click,
          child: InkWell(
            onTap: () {
              if (dropdownEligible) {
                _toggleOverlay(context);
              } else {
                widget.onTap();
                _hideMenu();
              }
            },
            borderRadius: BorderRadius.circular(8),
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 140),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w500,
                      color: textColor,
                      decoration: _hovering && !widget.isActive ? TextDecoration.underline : TextDecoration.none,
                      decorationThickness: 2,
                    ),
                    child: Text(widget.title),
                  ),
                  if (dropdownEligible) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _toggleOverlay(context),
                      borderRadius: BorderRadius.circular(6),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: textColor.withValues(alpha: .75),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleOverlay(BuildContext context) {
    if (_menuOpen) {
      _hideMenu();
      return;
    }
    final isServices = widget.title == 'Services' && (widget.children?.isNotEmpty ?? false);
    Widget content = isServices
        ? _ServicesMegaMenu(
            groups: widget.children!,
            onTap: (t) {
              widget.onItemSelected(t);
              _hideMenu();
            },
          )
        : DefaultDropdownList(
            title: widget.title,
            items: widget.children ?? const [],
            onTap: (t) {
              widget.onItemSelected(t);
              _hideMenu();
            },
          );

    final constraints = (widget.title == 'Services')
        ? const BoxConstraints(minWidth: 240, maxWidth: 760, maxHeight: 420)
        : const BoxConstraints(minWidth: 220, maxWidth: 360, maxHeight: 420);

    final entry = createDropdownOverlay(
      targetLink: _link,
      constraints: constraints,
      onExit: _hideMenu,
      child: content,
    );
    widget.onOverlayOpened(entry, _markSelfClosed);
    Overlay.of(context, rootOverlay: true).insert(entry);
    _entry = entry;
    _menuOpen = true;
    try {
      widget.onToggleOpen();
    } catch (_) {}
  }
}
