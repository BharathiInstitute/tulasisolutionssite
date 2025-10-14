import 'package:flutter/material.dart';
import '../layout/site_scaffold.dart';
import 'resources_sub_nav.dart';

class FaqsPage extends StatelessWidget {
  const FaqsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = _faqList;
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
                  const ResourcesSubNav(current: 'faqs'),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.help_outline, color: Colors.black87),
                      SizedBox(width: 8),
                      Text("Got Questions? We've Got Answers.", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: faqs.length,
                    itemBuilder: (context, index) {
                      final faq = faqs[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ExpansionTile(
                            leading: const Icon(Icons.help_outline, color: Colors.blue),
                            trailing: const Icon(Icons.lightbulb, color: Colors.orange),
                            title: Text(
                              faq['question']!,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text(
                                  faq['answer']!,
                                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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

const List<Map<String, String>> _faqList = [
  {
    'question': "What's included in Starter vs Growth?",
    'answer': 'Starter includes basic setup and strategy guidance, Growth adds monthly reviews, advanced funnels, and ads optimization.'
  },
  {
    'question': 'Do you handle paid ad budgets?',
    'answer': 'Yes, we manage ad spend tracking, recommendations, and optimization. Paid budgets are billed at actuals.'
  },
  {
    'question': 'Can I upgrade anytime?',
    'answer': 'Absolutely! You can upgrade your plan at any time with no downtime.'
  },
];
