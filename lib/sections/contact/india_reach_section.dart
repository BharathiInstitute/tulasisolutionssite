import 'package:flutter/material.dart';

class IndiaReachSection extends StatelessWidget {
  const IndiaReachSection({super.key});
  @override
  Widget build(BuildContext context) {
    final areas = const ['Retail', 'Education', 'Cosmetics', 'Printing', 'Services', 'Startups'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      color: Colors.grey.shade50,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.location_on, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('We Work With Businesses Across India', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Office: 123, Business Street, City, State, PIN', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final a in areas)
                    Chip(
                      label: Text(a),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.black.withValues(alpha: .08)),
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
