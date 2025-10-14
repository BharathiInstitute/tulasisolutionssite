import 'package:flutter/material.dart';

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
          // Tap anywhere outside the dropdown to close it. This sits behind the panel,
          // so taps inside the panel are handled by the panel content and won't trigger this.
          Positioned.fill(
            child: Listener(
              // Close on wheel scroll outside the dropdown so overlays don't feel sticky when scrolling the page.
              onPointerSignal: (evt) {
                onExit?.call();
              },
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => onExit?.call(),
              ),
            ),
          ),
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
                  // Notify the nav to close when cursor leaves the dropdown
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
                        // Invisible hover bridge above the panel to make entry easier
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
      ('WhatsApp', Icons.chat), // Placeholder for WhatsApp
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

