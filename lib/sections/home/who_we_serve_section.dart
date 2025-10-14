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

    const bg = Color(0xFFF8F8F8);
    const titleColor = Color(0xFF443F3F);
    const subtitleColor = Color(0xFF7D5B4C);
    const gold = Color(0xFFD4AF37);

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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 80 : 100),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Stack(
            children: [
              // Corner accent gradients
              Positioned(
                left: -80,
                top: -60,
                child: _AccentBlob(start: Colors.blue.withValues(alpha: 0.12), end: Colors.purple.withValues(alpha: 0.10), size: 180),
              ),
              Positioned(
                right: -60,
                bottom: -60,
                child: _AccentBlob(start: gold.withValues(alpha: 0.10), end: Colors.transparent, size: 160),
              ),

              // Content: two-column on desktop, stacked on mobile
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Who We Serve',
                          textAlign: TextAlign.left,
                          style: GoogleFonts.lora(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ready playbooks per industry.',
                          textAlign: TextAlign.left,
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: subtitleColor,
                          ),
                        ),
                        const SizedBox(height: 28),
                        GridView.builder(
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
                        const SizedBox(height: 24),
                        const _WhoWeServeImage(maxHeight: 360, radius: 28),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: headline + grid
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Who We Serve',
                                textAlign: TextAlign.left,
                                style: GoogleFonts.lora(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ready playbooks per industry.',
                                textAlign: TextAlign.left,
                                style: GoogleFonts.nunito(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: subtitleColor,
                                ),
                              ),
                              const SizedBox(height: 28),
                              GridView.builder(
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
                            ],
                          ),
                        ),
                        const SizedBox(width: 28),
                        // Right: main image anchored to the right edge
                        Expanded(
                          flex: 5,
                          child: Align(
                            alignment: Alignment.topRight,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: const _WhoWeServeImage(maxHeight: 480, radius: 32),
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
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
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
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: gold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IndustryData {
  const _IndustryData(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _AccentBlob extends StatelessWidget {
  const _AccentBlob({required this.start, required this.end, required this.size});
  final Color start;
  final Color end;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
      ),
    );
  }
}

class _WhoWeServeImage extends StatelessWidget {
  const _WhoWeServeImage({required this.maxHeight, required this.radius});
  final double maxHeight; final double radius;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final targetWidth = (constraints.maxWidth.isFinite ? constraints.maxWidth : 520.0) * dpr;
        final cacheWidth = targetWidth.clamp(300, 1600).round();

        return AspectRatio(
          aspectRatio: 1.0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.asset(
              'assets/who.we.serve.section.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              cacheWidth: cacheWidth,
              errorBuilder: (ctx, err, stack) => Container(
                color: Colors.grey.shade100,
                alignment: Alignment.center,
                child: Icon(Icons.broken_image, color: Colors.grey.shade400, size: 48),
              ),
            ),
          ),
        );
      },
    );
  }
}
