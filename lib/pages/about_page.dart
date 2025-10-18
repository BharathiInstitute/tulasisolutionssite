import 'package:flutter/material.dart';
import '../sections/layout/site_scaffold.dart';
import '../utils/url.dart' as url;
import '../sections/about/company.dart' show CompanySection;
import '../sections/about/team.dart' show TeamSection;
import '../sections/about/careers.dart' show CareersSectionWrapper;

/// Minimal About page acting only as a directory to deeper pages (Company, Team, Careers).
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _toolsKey = GlobalKey();
  final GlobalKey _companyKey = GlobalKey();
  final GlobalKey _teamKey = GlobalKey();
  final GlobalKey _careersKey = GlobalKey();
  // Previously nullable; made non-nullable to satisfy lint (stores last processed deep-link section id).
  String _lastArg = '';

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut, alignment: 0.08);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Accept route arguments and also web URL query/fragment for deep link
    final arg = ModalRoute.of(context)?.settings.arguments;
    final uri = Uri.base; // works on web; harmless on mobile
  // The fallback expression (`uri.queryParameters['section'] ?? uri.fragment`) is always
  // non-null because `Uri.fragment` returns a non-nullable String. Therefore we can
  // safely make this local variable non-nullable to satisfy the lint
  // `unnecessary_nullable_for_final_variable_declarations`.
  final String section = (arg is String && arg.isNotEmpty)
      ? arg
      : (uri.queryParameters['section'] ?? uri.fragment);
  if (section.isEmpty || section == _lastArg) return; // treat empty as absent
  _lastArg = section;
  final lower = section.toLowerCase();
  if (lower.contains('tools')) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_toolsKey));
    } else if (lower.contains('company')) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_companyKey));
    } else if (lower.contains('team')) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_teamKey));
    } else if (lower.contains('career')) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_careersKey));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      body: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Directory section removed. Page jumps into sections directly.
            // Embedded sections with anchors
            Container(key: _companyKey, child: const CompanySection()),
            const SizedBox(height: 24),
            Container(key: _teamKey, child: const TeamSection()),
            const SizedBox(height: 8),
            Container(key: _careersKey, child: const CareersSectionWrapper()),
            // Tools & Partners section
            _ToolsPartnersSection(key: _toolsKey),
          ],
        ),
        ),
      ),
    );
  }
}

// Removed header/cards/back widgets

class _ToolsPartnersSection extends StatelessWidget {
  const _ToolsPartnersSection({super.key});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final textTheme = Theme.of(context).textTheme;

    // Brand tiles without bundled logo assets (colored placeholders only)
    final logos = <_LogoItem>[
      _LogoItem('Google', Colors.blue, url: 'https://about.google/'),
      _LogoItem('Meta', const Color(0xFF1877F2), url: 'https://about.meta.com/'),
      _LogoItem('WhatsApp API', const Color(0xFF25D366), url: 'https://business.whatsapp.com/'),
      _LogoItem('Razorpay', const Color(0xFF072654), url: 'https://razorpay.com/'),
      _LogoItem('Firebase', const Color(0xFFFFC107), url: 'https://firebase.google.com/'),
      _LogoItem('Canva', const Color(0xFF00C4CC), url: 'https://www.canva.com/'),
      _LogoItem('HubSpot', const Color(0xFFFF7A59), url: 'https://www.hubspot.com/'),
    ];

    return Container(
      color: bg,
      width: double.infinity,
  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1800),
          child: Stack(
            children: [
              // subtle background logo cloud
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.06,
                    child: _LogoCloud(),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Headline with subtle icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('🔗 ', style: TextStyle(fontSize: 28)),
                      Text('⚙️ ', style: TextStyle(fontSize: 28)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Builder(builder: (context) {
                    final w = MediaQuery.sizeOf(context).width;
                    final titleSize = w >= 900 ? 40.0 : 32.0;
                    return Text(
                      'Powered by the Best',
                      textAlign: TextAlign.center,
                      style: (textTheme.displaySmall ?? const TextStyle()).copyWith(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0D1B2A),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: Builder(builder: (context) {
                        final w = MediaQuery.sizeOf(context).width;
                        final subSize = w >= 900 ? 18.0 : 16.0;
                        return Text(
                          'We integrate and partner with global platforms to bring cutting-edge solutions.',
                          textAlign: TextAlign.center,
                          style: (textTheme.titleMedium ?? const TextStyle()).copyWith(
                            fontSize: subSize,
                            color: const Color(0xFF284B63),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Responsive grid of logos
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      const tileWidth = 190.0;
                      const spacing = 12.0;
                      // Compute how many tiles fit per row for the available width.
                      int cols = ((width + spacing) / (tileWidth + spacing)).floor().clamp(1, logos.length);
                      // Cap cols by total items so we can keep to a single row when there is enough width.
                      final maxGridWidth = (cols * tileWidth) + ((cols - 1) * spacing);
                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxGridWidth),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              crossAxisSpacing: spacing,
                              mainAxisSpacing: spacing,
                              childAspectRatio: 4.0,
                            ),
                            itemCount: logos.length,
                            itemBuilder: (context, i) => _LogoTile(item: logos[i]),
                          ),
                        ),
                      );
                    },
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

class _LogoItem {
  const _LogoItem(this.label, this.color, {this.url});
  final String label;
  final Color color;
  final String? url;
}

class _LogoTile extends StatefulWidget {
  const _LogoTile({required this.item});
  final _LogoItem item;

  @override
  State<_LogoTile> createState() => _LogoTileState();
}

class _LogoTileState extends State<_LogoTile> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: _hover ? 1.03 : 1.0,
        child: InkWell(
          onTap: () {
            final link = widget.item.url;
            if (link != null && link.isNotEmpty) {
              url.launchExternal(link);
            }
          },
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.black.withValues(alpha: 0.03),
          highlightColor: Colors.black.withValues(alpha: 0.02),
          child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hover ? 0.14 : 0.08),
                blurRadius: _hover ? 16 : 12,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LogoImage(item: widget.item),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    widget.item.label,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0D1B2A)),
                    overflow: TextOverflow.ellipsis,
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

class _LogoImage extends StatelessWidget {
  const _LogoImage({required this.item});
  final _LogoItem item;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(6);
    final box = DecoratedBox(
      decoration: BoxDecoration(color: item.color.withValues(alpha: 0.12), borderRadius: borderRadius),
      child: SizedBox(width: 30, height: 30),
    );
    // With logo assets removed, render a simple colored placeholder box
    return ClipRRect(borderRadius: borderRadius, child: box);
  }
}

class _LogoCloud extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Lightweight geometric cloud made of faint rounded rectangles
    return CustomPaint(
      painter: _LogoCloudPainter(),
    );
  }
}

class _LogoCloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0D1B2A).withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    final rndRects = <RRect>[];
    final w = size.width;
    final h = size.height;

    void add(double x, double y, double rw, double rh, double r) {
      rndRects.add(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, rw, rh), Radius.circular(r)));
    }

    // Create a scattered cloud of rounded rects
    add(w * .05, h * .10, 120, 48, 16);
    add(w * .20, h * .18, 160, 56, 18);
    add(w * .38, h * .12, 110, 44, 14);
    add(w * .60, h * .16, 150, 52, 18);
    add(w * .78, h * .10, 130, 50, 16);

    add(w * .12, h * .40, 150, 56, 20);
    add(w * .32, h * .36, 120, 46, 14);
    add(w * .52, h * .38, 170, 58, 20);
    add(w * .72, h * .34, 130, 48, 16);

    add(w * .08, h * .68, 140, 52, 18);
    add(w * .28, h * .70, 160, 56, 20);
    add(w * .50, h * .66, 130, 50, 16);
    add(w * .70, h * .72, 150, 56, 20);
    add(w * .86, h * .68, 110, 44, 14);

    for (final r in rndRects) {
      canvas.drawRRect(r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
