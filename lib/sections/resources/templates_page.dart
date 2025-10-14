import 'package:flutter/material.dart';
import '../layout/site_scaffold.dart';
import 'resources_sub_nav.dart';

class TemplatesPage extends StatelessWidget {
  const TemplatesPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                  const ResourcesSubNav(current: 'templates'),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.extension, color: Colors.black87),
                      SizedBox(width: 8),
                      Text('Editable, Ready-to-Use Assets', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Save time with professional templates for social posts, brochures, and proposals.',
                    style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 200,
                    child: PageView.builder(
                      controller: PageController(viewportFraction: 0.7),
                      itemCount: _templatePreviews.length,
                      itemBuilder: (context, index) {
                        final template = _templatePreviews[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: template['color'] as Color,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                template['title'] as String,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TemplateItem(title: 'Social Media Canva templates'),
                      _TemplateItem(title: 'Brochure layouts'),
                      _TemplateItem(title: 'Sales proposal decks'),
                    ],
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

class _TemplateItem extends StatelessWidget {
  final String title;
  const _TemplateItem({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.black54),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

const List<Map<String, dynamic>> _templatePreviews = [
  {'title': 'Social Post Pack', 'color': Colors.teal},
  {'title': 'Brochure Starter', 'color': Colors.deepPurple},
  {'title': 'Proposal Deck', 'color': Colors.amber},
  {'title': 'Carousel Set', 'color': Colors.indigo},
  {'title': 'Brand Kit', 'color': Colors.pink},
];
