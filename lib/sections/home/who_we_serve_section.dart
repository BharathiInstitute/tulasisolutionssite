import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';

class WhoWeServeSection extends StatelessWidget {
  const WhoWeServeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.width < 1000 && size.width >= 700;
    final isMobile = size.width < 700;

  final bg = Theme.of(context).scaffoldBackgroundColor;
    const titleColor = Color(0xFF443F3F);
  const subtitleColor = Color(0xFF7D5B4C);

    final industries = <_IndustryData>[
      _IndustryData('Retail', FeatherIcons.shoppingBag),
      _IndustryData('Education', FeatherIcons.bookOpen),
      _IndustryData('Cosmetics', FeatherIcons.droplet),
      _IndustryData('Printing', FeatherIcons.printer),
      _IndustryData('Services', FeatherIcons.settings),
      _IndustryData('Startups', FeatherIcons.send),
    ];

    final cols = isMobile ? 1 : (isTablet ? 2 : 3);

    return Container(
  color: bg,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 184, // slight additional right nudge on desktop
        isMobile ? 44 : 60,
        isMobile ? 16 : 0, // align closer to the right edge on desktop
        // Reduce bottom padding to tighten space before next section
        isMobile ? 16 : 28,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Stack(
            children: [
              // Corner accent gradients
              // Decorative accent blobs removed per request

              // Content: two-column on desktop, stacked on mobile
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Who We Serve',
                          textAlign: TextAlign.left,
                          style: GoogleFonts.openSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ready playbooks per industry.',
                          textAlign: TextAlign.left,
                          style: GoogleFonts.openSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: subtitleColor,
                          ),
                        ),
                        const SizedBox(height: 28),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.black.withValues(alpha: .06)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 12, offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                            child: GridView.builder(
                              itemCount: industries.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                mainAxisExtent: 180,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemBuilder: (context, i) => _IndustryCard(data: industries[i]),
                            ),
                          ),
                        ),
                        // Tighten trailing space on mobile
                        const SizedBox(height: 0),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: headline/subtitle only (keep in original place)
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(84, 80, 24, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              Text(
                                'Who We Serve',
                                textAlign: TextAlign.left,
                                style: GoogleFonts.openSans(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ready playbooks per industry.',
                                textAlign: TextAlign.left,
                                style: GoogleFonts.openSans(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: subtitleColor,
                                ),
                              ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 72),
                        // Right: move industry cards grid here (image removed)
                        Expanded(
                          flex: 1,
                          child: Align(
                            alignment: Alignment.topRight,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.black.withValues(alpha: .06)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 12, offset: const Offset(0, 6)),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                                child: GridView.builder(
                                  itemCount: industries.length,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    mainAxisExtent: 180,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                                  itemBuilder: (context, i) => _IndustryCard(data: industries[i]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IndustryCard extends StatefulWidget {
  const _IndustryCard({required this.data});
  final _IndustryData data;

  @override
  State<_IndustryCard> createState() => _IndustryCardState();
}

class _IndustryCardState extends State<_IndustryCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              final route = _routeForLabel(widget.data.label);
              Navigator.of(context).pushNamed(route);
            },
            onHover: (h) => setState(() => _hover = h),
            borderRadius: BorderRadius.circular(14),
            splashColor: gold.withValues(alpha: 0.12),
            hoverColor: gold.withValues(alpha: 0.06),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _hover ? gold : gold.withValues(alpha: 0.18), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _hover ? 0.08 : 0.05),
                    blurRadius: _hover ? 16 : 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [gold.withValues(alpha: 0.25), Colors.transparent],
                        radius: 0.8,
                      ),
                    ),
                    child: Icon(
                      widget.data.icon,
                      size: 28,
                      color: gold,
                      shadows: _hover
                          ? [
                              Shadow(color: gold.withValues(alpha: 0.5), blurRadius: 14),
                              Shadow(color: gold.withValues(alpha: 0.2), blurRadius: 8),
                            ]
                          : const [],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.data.label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.openSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: gold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _routeForLabel(String label) {
  switch (label.toLowerCase()) {
    case 'retail':
      return '/industries/retail';
    case 'education':
      return '/industries/education';
    case 'cosmetics':
      return '/industries/cosmetics';
    case 'printing':
      return '/industries/printing';
    case 'services':
      return '/industries/services';
    case 'startups':
      return '/industries/startup';
    default:
      return '/industries';
  }
}

class _IndustryData {
  const _IndustryData(this.label, this.icon);
  final String label;
  final IconData icon;
}

// Image widget removed per request; grid moved to right column.
