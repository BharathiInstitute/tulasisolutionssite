import 'package:flutter/material.dart';

class PhoneEmailSection extends StatelessWidget {
  const PhoneEmailSection({super.key});
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isNarrow = size.width < 800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: isNarrow
              ? Column(children: const [
                  _InfoCard(icon: Icons.phone, title: 'Phone', value: '+91 12345 67890'),
                  SizedBox(height: 12),
                  _InfoCard(icon: Icons.email_outlined, title: 'Email', value: 'support@tulasisolutions.com'),
                ])
              : Row(
                  children: const [
                    Expanded(child: _InfoCard(icon: Icons.phone, title: 'Phone', value: '+91 12345 67890')),
                    SizedBox(width: 16),
                    Expanded(child: _InfoCard(icon: Icons.email_outlined, title: 'Email', value: 'support@tulasisolutions.com')),
                  ],
                ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.value});
  final IconData icon;
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.black54)),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

