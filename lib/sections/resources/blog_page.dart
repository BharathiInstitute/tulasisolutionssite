import 'package:flutter/material.dart';
import '../layout/site_scaffold.dart';
import 'resources_sub_nav.dart';

class BlogPage extends StatelessWidget {
  const BlogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final articles = _blogArticles;
    return SiteScaffold(
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          color: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ResourcesSubNav(current: 'blog'),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.edit, color: Colors.black87),
                      SizedBox(width: 8),
                      Text('Expert Insights & Stories', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Stay updated with the latest tips, strategies, and real-world case studies.',
                    style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(builder: (context, c) {
                    final w = c.maxWidth;
                    final cross = w >= 900 ? 2 : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: articles.length,
                      itemBuilder: (context, index) {
                        final article = articles[index];
                        return _ArticleCard(
                          imageUrl: article['imageUrl']!,
                          title: article['title']!,
                          preview: article['preview']!,
                        );
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.imageUrl, required this.title, required this.preview});
  final String imageUrl;
  final String title;
  final String preview;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                height: 120,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  preview,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const List<Map<String, String>> _blogArticles = [
  {
    'imageUrl': 'https://picsum.photos/seed/ts-1/800/400',
    'title': 'Crafting a Launch Kit that Converts',
    'preview': 'From messaging to mockups—how to ship a kit that drives signups.',
  },
  {
    'imageUrl': 'https://picsum.photos/seed/ts-2/800/400',
    'title': 'Your First 90 Days: A Practical SOP',
    'preview': 'Week-by-week actions, KPIs, and rituals to build traction.',
  },
  {
    'imageUrl': 'https://picsum.photos/seed/ts-3/800/400',
    'title': 'Ad Spend, Smarter: Optimization Checklist',
    'preview': 'Tactics to improve ROAS without increasing budget.',
  },
  {
    'imageUrl': 'https://picsum.photos/seed/ts-4/800/400',
    'title': 'Landing Pages that Sell Services',
    'preview': 'Patterns and components that lift conversion rates.',
  },
];
