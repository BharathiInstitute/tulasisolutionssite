import 'package:flutter/material.dart';

class BookingCalendarSection extends StatelessWidget {
  const BookingCalendarSection({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        border: Border(top: BorderSide(color: Colors.black.withValues(alpha: .06))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.calendar_today, color: Color(0xFF1D4ED8)),
                  SizedBox(width: 8),
                  Text('Pick a Time That Works for You', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: scheme.primary.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 8)),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text('Calendar widget placeholder'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.event_available),
                label: const Text('Book Free Demo'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
