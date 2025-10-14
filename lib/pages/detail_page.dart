import 'package:flutter/material.dart';
import '../sections/layout/site_scaffold.dart';

// Generic detail page to open for any menu option without a dedicated page.
class DetailPage extends StatelessWidget {
  const DetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final title = (ModalRoute.of(context)?.settings.arguments as String?) ?? 'Details';
    return SiteScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This is a placeholder page for the selected option. You can replace this with a dedicated page later.',
                  style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
