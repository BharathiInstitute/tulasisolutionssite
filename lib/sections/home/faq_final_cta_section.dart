import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class FaqFinalCtaSection extends StatelessWidget {
  const FaqFinalCtaSection({super.key, this.onBookNow});

  final VoidCallback? onBookNow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width >= 1000;

    final faqs = const <({String q, String a})>[
      (q: "What’s included in the Starter plan?", a: "Brand identity basics, a fast landing page, and a simple growth plan to get you moving."),
      (q: "Can you integrate with our existing tools?", a: "Yes. We integrate CRM, payments, analytics, WhatsApp and more based on your stack."),
      (q: "How quickly can we launch?", a: "Most launches happen in 2–4 weeks depending on scope and content readiness."),
      (q: "Do you offer ongoing support?", a: "We provide retainers for continuous improvements, campaigns and monthly reviews."),
    ];

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Frequently Asked Questions',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: isDesktop ? 28 : 22,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        ...faqs.map((item) => _FaqTile(q: item.q, a: item.a)),
        const SizedBox(height: 28),
        _FinalCta(
          color: scheme.primary,
          onBookNow: onBookNow,
        ),
      ],
    );

    final imageWidget = const _FaqImage();

    return Container(
      width: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: CustomPaint(
        painter: _SubtleDotsPainter(color: Colors.black.withValues(alpha: 0.03)),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1300),
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left textual content
                        Expanded(child: leftColumn),
                        const SizedBox(width: 56),
                        // Right image corner
                        SizedBox(
                          width: 420,
                          child: imageWidget,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        leftColumn,
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 320,
                          child: imageWidget,
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

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.q, required this.a});
  final String q;
  final String a;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: const Icon(Icons.help_outline, color: Colors.black87),
            title: Text(
              q,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  a,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinalCta extends StatelessWidget {
  const _FinalCta({required this.color, this.onBookNow});
  final Color color;
  final VoidCallback? onBookNow;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 720;
    final text = Text(
      'Still exploring? Book a free 30‑min consult.',
      textAlign: isNarrow ? TextAlign.center : TextAlign.left,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    );

    final button = ElevatedButton(
      onPressed: onBookNow,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
      ),
      child: const Text('Book Now'),
    );

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: isNarrow
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, color: Colors.white),
                const SizedBox(height: 8),
                text,
                const SizedBox(height: 12),
                button,
              ],
            )
          : Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: text),
                const SizedBox(width: 12),
                button,
              ],
            ),
    );
  }
}

class _SubtleDotsPainter extends CustomPainter {
  _SubtleDotsPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 18.0;
    const radius = 1.2;
    for (double y = spacing / 2; y < size.height; y += spacing) {
      for (double x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SubtleDotsPainter oldDelegate) => oldDelegate.color != color;
}

class _FaqImage extends StatefulWidget {
  const _FaqImage();
  @override
  State<_FaqImage> createState() => _FaqImageState();
}

class _FaqImageState extends State<_FaqImage> {
  String? _resolvedAsset; // actual existing asset path
  Object? _error;
  bool _loading = true;

  static const List<String> _candidates = [
    'assets/faq.final.cta.section.png',
    'assets/faq_final_cta_section.png',
    'assets/faq.final.cta.section.jpg',
    'assets/faq_final_cta_section.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final map = json.decode(manifestContent) as Map<String, dynamic>;
      debugPrint('FAQ Image: AssetManifest contains \'${map.length}\' entries');
      String? found;
      for (final c in _candidates) {
        if (map.keys.contains(c)) {
          found = c;
          break;
        }
      }
      if (found == null) {
        debugPrint('FAQ Image NOT found among candidates: $_candidates');
      } else {
        debugPrint('FAQ Image resolved to: $found');
      }
      if (mounted) {
        setState(() {
          _resolvedAsset = found;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
      debugPrint('FAQ Image manifest load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget inner;
    if (_loading) {
      inner = const Center(child: CircularProgressIndicator(strokeWidth: 3));
    } else if (_error != null) {
      inner = _errorBox('Manifest error');
    } else if (_resolvedAsset == null) {
      inner = _errorBox('Not in manifest');
    } else {
      inner = Image.asset(
        _resolvedAsset!,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (c, e, s) => _errorBox('Decode fail'),
      );
    }

    return Semantics(
      label: 'FAQ Illustration',
      image: true,
      child: RepaintBoundary(
        child: AspectRatio(
          aspectRatio: 1.05,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: inner,
          ),
        ),
      ),
    );
  }

  Widget _errorBox(String msg) => Container(
        color: Colors.grey[300],
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
            children:[
              const Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.black45),
              const SizedBox(height:8),
              Text(msg, style: const TextStyle(fontSize: 12, color: Colors.black54))
            ]
        ),
      );
}

