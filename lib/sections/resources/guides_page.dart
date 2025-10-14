import 'package:flutter/material.dart';
import '../layout/site_scaffold.dart';
import 'resources_sub_nav.dart';

class GuidesPage extends StatelessWidget {
  const GuidesPage({super.key});

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
                  const ResourcesSubNav(current: 'guides'),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.menu_book_rounded, color: Colors.black87),
                      SizedBox(width: 8),
                      Text('Step-by-Step Business Playbooks', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Download structured guides to implement growth strategies with clarity.',
                    style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  LayoutBuilder(builder: (context, c) {
                    final isNarrow = c.maxWidth < 800;
                    final stackMockups = Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: 40,
                          left: 0,
                          child: _mockCover(width: 120, height: 160, color: Colors.blue.shade300),
                        ),
                        Positioned(
                          top: 20,
                          left: 20,
                          child: _mockCover(width: 120, height: 160, color: Colors.purple.shade300),
                        ),
                        _mockCover(width: 120, height: 160, color: Colors.orange.shade300, strongShadow: true),
                      ],
                    );

                    final list = const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GuideItem(title: 'Launch Kit Guide'),
                        _GuideItem(title: '90-Day Review SOP'),
                        _GuideItem(title: 'Ads Optimization Checklist'),
                      ],
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isNarrow)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(child: SizedBox(width: 160, height: 200, child: stackMockups)),
                              const SizedBox(height: 24),
                              list,
                            ],
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 160, height: 200, child: stackMockups),
                              const SizedBox(width: 32),
                              Expanded(child: list),
                            ],
                          ),
                        const SizedBox(height: 24),
                        Row(
                          children: const [
                            Icon(Icons.checklist_rtl, color: Colors.black54, size: 28),
                            SizedBox(width: 12),
                            Icon(Icons.folder, color: Colors.black54, size: 28),
                          ],
                        ),
                      ],
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

  Widget _mockCover({required double width, required double height, required Color color, bool strongShadow = false}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: strongShadow ? Colors.black26 : Colors.black12,
            blurRadius: strongShadow ? 8 : 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}

class _GuideItem extends StatelessWidget {
  final String title;
  const _GuideItem({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.arrow_right, color: Colors.black54),
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
