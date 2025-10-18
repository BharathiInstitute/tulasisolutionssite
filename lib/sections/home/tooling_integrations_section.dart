import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ToolingIntegrationsSection extends StatefulWidget {
  const ToolingIntegrationsSection({super.key, this.onTapTool});

  final void Function(String toolId)? onTapTool; // optional navigation/callback

  @override
  State<ToolingIntegrationsSection> createState() => _ToolingIntegrationsSectionState();
}

class _ToolingIntegrationsSectionState extends State<ToolingIntegrationsSection> with TickerProviderStateMixin {
  late final AnimationController _reveal;

  final _tools = const <_ToolItem>[
    _ToolItem(id: 'hubspot', label: 'HubSpot', alt: 'HubSpot CRM'),
    _ToolItem(id: 'googleSuite', label: 'Google Suite', alt: 'Google Suite'),
    _ToolItem(id: 'razorpay', label: 'Razorpay', alt: 'Razorpay Payments'),
    _ToolItem(id: 'whatsapp', label: 'WhatsApp API', alt: 'WhatsApp API'),
    _ToolItem(id: 'analytics', label: 'Analytics', alt: 'Analytics Platform'),
  ];

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
  final isDesktop = w >= 1000;
  final isTablet = w >= 600 && w < 1000;

    // Columns by breakpoint
  // Increase columns on wide desktop so all items fit on one row when possible
  final int cols = isDesktop
    ? (w >= 1400
      ? 5
      : (w >= 1280
        ? 4
        : 3))
    : (isTablet
      ? (w >= 800 ? 3 : 2)
      : (w >= 380 ? 2 : 1));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: isDesktop ? 24 : 16,
        right: isDesktop ? 24 : 16,
        // Reduce top padding to bring section closer to previous
        top: isDesktop ? 28 : (isTablet ? 24 : 20),
        bottom: isDesktop ? 72 : (isTablet ? 60 : 52),
      ),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Tooling & Integrations',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: isDesktop ? 30 : (isTablet ? 26 : 22), fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                'Seamlessly connect your workflows with leading tools like CRM, payments, analytics, and more.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: isDesktop ? 16 : (isTablet ? 15 : 14), color: Colors.grey[700]),
              ),
              const SizedBox(height: 26),
              GridView.builder(
                itemCount: _tools.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                cacheExtent: 800,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.4,
                ),
                itemBuilder: (context, i) {
                  final t = _tools[i];
                  final start = (i * 0.08).clamp(0.0, 0.7);
                  final end = (start + 0.4).clamp(0.0, 1.0);
                  final fade = CurvedAnimation(parent: _reveal, curve: Interval(start, end, curve: Curves.easeOut));
                  return FadeTransition(
                    opacity: fade,
                    // Removed continuous per-frame floating animation to reduce CPU usage & jank.
                    child: RepaintBoundary(
                      child: Align(
                        alignment: Alignment.center,
                        child: FractionallySizedBox(
                          widthFactor: 0.82,
                          heightFactor: 0.82,
                          child: _ToolCard(
                            item: t,
                            onTap: () => widget.onTapTool?.call(t.id),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatefulWidget {
  const _ToolCard({required this.item, this.onTap});
  final _ToolItem item;
  final VoidCallback? onTap;

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final shadow = BoxShadow(
      color: Colors.black.withValues(alpha: _hover ? 0.12 : 0.08),
      blurRadius: _hover ? 18 : 12,
      spreadRadius: 0,
      offset: const Offset(0, 8),
    );

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [shadow],
      ),
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Semantics(
          button: true,
          label: widget.item.alt,
          child: _LogoImage(item: widget.item, hover: _hover),
        ),
      ),
    );

    final interactive = InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedScale(
        scale: _hover ? 1.03 : 1,
        duration: const Duration(milliseconds: 120),
        child: card,
      ),
    );

    if (!kIsWeb) return interactive;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: interactive,
    );
  }
}

class _LogoImage extends StatelessWidget {
  const _LogoImage({required this.item, required this.hover});
  final _ToolItem item;
  final bool hover;

  @override
  Widget build(BuildContext context) {
    // Try asset image; fall back to initials/icon-like text if not available
    // Icon/text placeholder instead of image asset
    final baseColor = Colors.indigo.shade600;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      constraints: const BoxConstraints(minWidth: 64, minHeight: 34),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [
            baseColor.withValues(alpha: .07),
            baseColor.withValues(alpha: hover ? .18 : .12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
  border: Border.all(color: baseColor.withValues(alpha: .25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.extension, color: baseColor.withValues(alpha: .9), size: 20),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              item.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: baseColor.withValues(alpha: .95),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolItem {
  const _ToolItem({required this.id, required this.label, required this.alt});
  final String id; final String label; final String alt;
}
