import 'package:flutter/material.dart';

// Simple emoji-based services grid. Optional onTapService handler is kept
// for compatibility with existing pages. If not provided, we try pushNamed.
class FeaturedServicesSection extends StatelessWidget {
  const FeaturedServicesSection({super.key, this.onTapService});

  final void Function(String service)? onTapService;

  final List<Service> services = const [
    Service(id: 'branding', title: 'Branding', subtitle: 'Logos, identity & guides', emoji: '🎨', route: '/branding'),
    Service(id: 'marketing', title: 'Marketing', subtitle: 'Ads, growth & strategy', emoji: '📢', route: '/marketing'),
    Service(id: 'website', title: 'Website', subtitle: 'Fast & responsive sites', emoji: '🌐', route: '/website'),
    Service(id: 'software', title: 'Software', subtitle: 'Custom apps & integrations', emoji: '⚙️', route: '/software'),
    Service(id: 'automation', title: 'Automation', subtitle: 'Workflows & automations', emoji: '🤖', route: '/automation'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxis = constraints.maxWidth >= 1000
              ? 5
              : (constraints.maxWidth >= 700 ? 3 : 1);
          return GridView.count(
            crossAxisCount: crossAxis,
            shrinkWrap: true,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
            physics: const NeverScrollableScrollPhysics(),
            children: services
                .map((s) => _ServiceCard(
                      service: s,
                      onTap: () {
                        if (onTapService != null) {
                          onTapService!(s.title);
                        } else {
                          // Fallback to Navigator routes if wired
                          Navigator.pushNamed(context, s.route);
                        }
                      },
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class _ServiceCard extends StatefulWidget {
  const _ServiceCard({required this.service, required this.onTap});
  final Service service;
  final VoidCallback onTap;

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform:
            hovering ? Matrix4.translationValues(0, -6, 0) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: hovering ? 18 : 8,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
                      color: Colors.white),
                  child: Text(widget.service.emoji,
                      style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(widget.service.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(widget.service.subtitle,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Service {
  final String id, title, subtitle, emoji, route;
  const Service({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.route,
  });
}
