import 'package:flutter/material.dart';
import '../sections/layout/site_scaffold.dart';

class PortfolioPage extends StatelessWidget {
  const PortfolioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      backgroundColor: Colors.transparent,
      body: const SingleChildScrollView(
        physics: ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IntroSection(),
            SizedBox(height: 50),
            _BeforeAfterSection(),
            SizedBox(height: 50),
            _KpiDeltasSection(),
            SizedBox(height: 50),
            _ClientQuotesSection(),
            SizedBox(height: 50),
            _IndustriesTagsSection(),
            SizedBox(height: 50),
            _FinalCtaSection(),
          ],
        ),
      ),
    );
  }
}

// Intro + Grid
class _IntroSection extends StatelessWidget {
  const _IntroSection();
  @override
  Widget build(BuildContext context) {
    final items = _samplePortfolioItems;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 16),
  decoration: const BoxDecoration(color: Colors.transparent),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.emoji_events, size: 32, color: Colors.amber),
                  SizedBox(width: 10),
                  Text('Proof of Outcomes', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              Text('Real businesses. Real growth. Real results.',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade700)),
              const SizedBox(height: 30),
              LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth;
                final crossAxisCount = w >= 1100 ? 3 : (w >= 720 ? 2 : 1);
        return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
          // Increased to avoid content overflow on some platforms/font scales
          mainAxisExtent: 260,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _PortfolioCard(item: items[index]),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortfolioItem {
  const _PortfolioItem({required this.title, required this.industry, required this.result, required this.color});
  final String title;
  final String industry;
  final String result;
  final Color color;
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({required this.item});
  final _PortfolioItem item;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Visual placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 110,
                  color: item.color.withValues(alpha: .15),
                  alignment: Alignment.center,
                  child: Icon(Icons.image, color: item.color, size: 38),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.business, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.industry,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up, size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(item.result, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _samplePortfolioItems = <_PortfolioItem>[
  _PortfolioItem(title: 'GlowMart', industry: 'Retail', result: 'Leads ↑ 250%', color: Colors.pink),
  _PortfolioItem(title: 'Nexa Academy', industry: 'Education', result: 'Admissions ↑ 3x', color: Colors.blue),
  _PortfolioItem(title: 'BellaCare', industry: 'Cosmetics', result: 'CPL ↓ 40%', color: Colors.purple),
  _PortfolioItem(title: 'PrintoHub', industry: 'Printing', result: 'Orders ↑ 2.2x', color: Colors.indigo),
  _PortfolioItem(title: 'FixIt Pro', industry: 'Services', result: 'Conversions ↑ 2x', color: Colors.orange),
  _PortfolioItem(title: 'StartIQ', industry: 'Startup', result: 'MRR ↑ 3.5x', color: Colors.teal),
];

// Before & After Section
class _BeforeAfterSection extends StatelessWidget {
  const _BeforeAfterSection();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.all(30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.refresh, size: 32, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text('Transformation That Shows', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                'See how Tulasi Solutions changed performance metrics across branding, websites, and campaigns.',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(builder: (context, c) {
                final isNarrow = c.maxWidth < 800;
                final children = [
                  const Expanded(
                    child: _ImageAssetBox(label: 'Before'),
                  ),
                  const SizedBox(width: 10, height: 10),
                  const Expanded(
                    child: _ImageAssetBox(label: 'After'),
                  ),
                ];
                if (isNarrow) {
                  return Column(children: [children[0], const SizedBox(height: 10), children[2]]);
                }
                return Row(children: children);
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageAssetBox extends StatelessWidget {
  const _ImageAssetBox({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blueGrey.withValues(alpha: .15),
                    Colors.lightBlueAccent.withValues(alpha: .18),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.image, size: 54, color: Colors.blueGrey.withValues(alpha: .45)),
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// KPI Deltas Section
class _KpiDeltasSection extends StatelessWidget {
  const _KpiDeltasSection();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.show_chart, size: 32, color: Colors.green),
                  SizedBox(width: 10),
                  Text('Numbers That Matter', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 15),
              Text('We measure results in traffic, leads, conversions, and ROI.',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade800)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: const [
                  _KpiCard(title: 'Leads ↑ 250%', subtitle: 'in 3 months'),
                  _KpiCard(title: 'Conversion rate doubled', subtitle: ''),
                  _KpiCard(title: 'Cost per lead ↓ 40%', subtitle: ''),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(minWidth: 220),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insights, color: Colors.green),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// Client Quotes
class _ClientQuotesSection extends StatelessWidget {
  const _ClientQuotesSection();
  @override
  Widget build(BuildContext context) {
    final testimonials = _sampleTestimonials;
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.all(30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.chat_bubble, size: 32, color: Colors.orange),
                  SizedBox(width: 10),
                  Text('What Our Clients Say', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: PageView.builder(
                  itemCount: testimonials.length,
                  controller: PageController(viewportFraction: .9),
                  itemBuilder: (context, index) => _TestimonialCard(testimonial: testimonials[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Testimonial {
  const _Testimonial(this.quote, this.name, this.company);
  final String quote;
  final String name;
  final String company;
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.testimonial});
  final _Testimonial testimonial;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('“${testimonial.quote}”', style: const TextStyle(fontStyle: FontStyle.italic)),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Text('${testimonial.name}, ${testimonial.company}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _sampleTestimonials = <_Testimonial>[
  _Testimonial('Tulasi doubled our conversions within a quarter.', 'Priya S', 'Acme Retail'),
  _Testimonial('Clear strategy and crisp execution. Funnels work!', 'Rahul M', 'HealthPlus'),
  _Testimonial('From chaos to clarity—automations and dashboards.', 'Nandini K', 'LogiTrans'),
];

// Industries Tags
class _IndustriesTagsSection extends StatelessWidget {
  const _IndustriesTagsSection();
  @override
  Widget build(BuildContext context) {
    const tags = [
      'Retail', 'Education', 'Cosmetics', 'Printing', 'Services', 'Startups',
    ];
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.label, size: 32, color: Colors.purple),
                  SizedBox(width: 10),
                  Text('Industries We’ve Grown', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                'Our playbooks deliver across Retail, Education, Cosmetics, Printing, Services, and Startups.',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: tags
                    .map((tag) => Chip(
                          label: Text(tag),
                          avatar: const Icon(Icons.business, size: 18),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Final CTA
class _FinalCtaSection extends StatelessWidget {
  const _FinalCtaSection();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(50),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade100, Colors.white]),
      ),
      child: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.rocket_launch),
          label: const Text('Book Free Demo', style: TextStyle(fontSize: 20)),
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Book Free Demo')));
          },
        ),
      ),
    );
  }
}
