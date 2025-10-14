import 'package:flutter/material.dart';

class CaseStudiesTestimonials extends StatelessWidget {
  CaseStudiesTestimonials({super.key});
  final CaseStudy caseStudy = CaseStudy(
    title: "E-commerce Growth",
    beforeTraffic: 5000,
    afterTraffic: 18000,
    beforeLeads: 200,
    afterLeads: 950,
    beforeConversions: 40,
    afterConversions: 220,
  );

  final Testimonial testimonial = Testimonial(
    quote: "Working with this team doubled our sales within 3 months. Amazing experience!",
    clientName: "Anita Sharma",
    company: "GlowMart",
    rating: 5,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.withValues(alpha: 0.2), Colors.purple.withValues(alpha: 0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Background collage (safe fallback if asset missing)
          // Removed external asset background; subtle pattern placeholder
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DotsPainter(),
              ),
            ),
          ),
          // Foreground content
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _CaseStudyCard(data: caseStudy)),
                  SizedBox(width: isWide ? 20 : 0, height: isWide ? 0 : 20),
                  Expanded(child: _TestimonialCard(data: testimonial)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CaseStudyCard extends StatelessWidget {
  const _CaseStudyCard({required this.data});
  final CaseStudy data;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📊 ${data.title}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _StatRow(label: "Traffic", before: data.beforeTraffic, after: data.afterTraffic),
            _StatRow(label: "Leads", before: data.beforeLeads, after: data.afterLeads),
            _StatRow(label: "Conversions", before: data.beforeConversions, after: data.afterConversions),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.before, required this.after});
  final String label;
  final int before;
  final int after;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text("$label:", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        Text("Before: $before", style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        const SizedBox(width: 12),
        Text("After: $after", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.data});
  final Testimonial data;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("🗣", style: TextStyle(fontSize: 30)),
            const SizedBox(height: 12),
            Text(
              "\"${data.quote}\"",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(data.rating, (i) => const Icon(Icons.star, color: Colors.amber, size: 18)),
            ),
            const SizedBox(height: 12),
            Text("${data.clientName}, ${data.company}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class CaseStudy {
  final String title;
  final int beforeTraffic;
  final int afterTraffic;
  final int beforeLeads;
  final int afterLeads;
  final int beforeConversions;
  final int afterConversions;
  CaseStudy({
    required this.title,
    required this.beforeTraffic,
    required this.afterTraffic,
    required this.beforeLeads,
    required this.afterLeads,
    required this.beforeConversions,
    required this.afterConversions,
  });
}

class Testimonial {
  final String quote;
  final String clientName;
  final String company;
  final int rating;
  Testimonial({required this.quote, required this.clientName, required this.company, required this.rating});
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
  ..color = Colors.white.withValues(alpha: .08)
      ..style = PaintingStyle.fill;
    const double gap = 42;
    for (double y = 0; y < size.height; y += gap) {
      for (double x = (y / gap).floor().isEven ? 0 : gap / 2; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 2.2, paint);
      }
    }
    // subtle diagonal gradient overlay
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
  colors: [Colors.transparent, Colors.white.withValues(alpha: .05)],
    );
    final gradientPaint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
