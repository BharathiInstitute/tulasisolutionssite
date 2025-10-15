import 'package:flutter/material.dart';
import 'dropdowns.dart';

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
  // Callback provided by the item that owns the current overlay to mark itself
  // as closed when another item opens.
  VoidCallback? _markPrevClosed;
  int? _openIndex;

  void _onOverlayOpened(OverlayEntry entry, VoidCallback markSelfClosed) {
    // Ask previous owner to mark itself closed; if none, remove previous overlay here.
    if (_markPrevClosed != null) {
      _markPrevClosed!.call();
    } else {
      _currentOverlay?.remove();
    }
    // Debug
    // ignore: avoid_print
    print('DesktopNavBar: overlay opened');
    _currentOverlay = entry;
    _markPrevClosed = markSelfClosed;
  }

  void _onOverlayClosed() {
    // Debug
    // ignore: avoid_print
    print('DesktopNavBar: overlay closed');
    // Child owns removing the overlay entry; just clear references here.
    _currentOverlay = null;
    _markPrevClosed = null;
    _openIndex = null;
  }

  @override
  void dispose() {
    // Ensure any lingering overlay is removed on dispose
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
    // Collect Services children for auto-open logic
    final servicesItem = items.firstWhere(
      (e) => (e['title'] as String) == 'Services',
      orElse: () => const {},
    );
    // If activeTitle is a direct child group OR one of its nested children we still want to open the mega menu.
    // Gather all nested leaf titles.
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
                  // Always clickable: navigate / mark active even if it has children
                  widget.onMenuTap(title);
                  widget.onActiveChange(title);
                },
            onItemSelected: (t) {
              // Debug: log desktop nav item selection
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

  // Items open dropdowns only when they have children.
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
  // Notifies parent that an overlay opened; provides a callback to mark this
  // item closed if another item opens later.
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
    // Display group headings with children as a grid of columns (2–4 based on width)
    return LayoutBuilder(builder: (context, c) {
  // Keep mega menu compact: 1–2 columns only, based on overall screen width
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
  // Removed auto-open logic to ensure menu is always clickable and overlays never block events.

  void _markSelfClosed() {
    // Used by parent when another item opens its overlay.
    _entry?.remove();
    _entry = null;
    _menuOpen = false;
  }

  void _hideMenu() {
    if (!_menuOpen) return; // idempotent
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
    return CompositedTransformTarget(
      link: _link,
      child: Semantics(
        button: true,
        label: 'Menu item: ${widget.title}',
        child: MouseRegion(
          onEnter: (_) {
            setState(() => _hovering = true);
            // Do not auto-open dropdowns on hover; open only via explicit interactions if needed.
          },
          onExit: (_) {
            setState(() => _hovering = false);
            if (widget.hasChildren && _menuOpen) {
              // Delay slightly to allow moving into overlay without closing instantly.
              Future.delayed(const Duration(milliseconds: 120), () {
                if (!_hovering && mounted) {
                  // Only hide if still not hovering over item (overlay exit handled elsewhere).
                }
              });
            }
          },
          cursor: SystemMouseCursors.click,
          child: InkWell(
            onTap: () {
              if (widget.hasChildren) {
                // Toggle dropdown for items like Services instead of navigating away
                _toggleOverlay(context);
              } else {
                // Navigate directly for leaf items
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
                  if (widget.hasChildren) ...[
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
    {
      // Build and show dropdown content
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
      // Ensure parent highlights this as open
      try {
        widget.onToggleOpen();
      } catch (_) {}
    }
  }
}
