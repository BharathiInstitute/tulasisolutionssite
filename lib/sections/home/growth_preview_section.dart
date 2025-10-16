import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../pages/growth_page.dart';

/// Compact preview of Growth Dashboard placed on Home page.
class GrowthPreviewSection extends StatelessWidget {
  const GrowthPreviewSection({super.key});

  static const _bgGradient = [Color(0xFF0B1220), Color(0xFF162132)];
  static const _accent = Color(0xFF22D3EE);
  static const _accent2 = Color(0xFF0B63FF);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 800;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 0 : 0, vertical: 12),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 28, vertical: isMobile ? 28 : 40),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: _bgGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 26, offset: Offset(0, 14)),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [_accent2, _accent]),
                ),
                child: const Icon(FeatherIcons.trendingUp, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Growth Dashboard Preview',
                      style: GoogleFonts.openSans(
                        fontSize: isMobile ? 26 : 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Monthly reviews, strategy planning and sales targets unified. Track progress & improvements over time.',
                      style: GoogleFonts.openSans(
                        fontSize: isMobile ? 14 : 16,
                        color: Colors.white.withValues(alpha: 0.75),
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _MiniMetricRow(isMobile: isMobile),
          const SizedBox(height: 30),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _MiniCard(
                icon: FeatherIcons.target,
                title: 'Sales Targets',
                desc: 'Quota & progress tracking.',
                onTap: () => _openSection(context, GrowthSection.salesTargets),
              ),
              _MiniCard(
                icon: FeatherIcons.activity,
                title: 'Strategy Planning',
                desc: 'Roadmap & priorities.',
                onTap: () => _openSection(context, GrowthSection.strategyPlanning),
              ),
              _MiniCard(
                icon: FeatherIcons.calendar,
                title: 'Monthly Review',
                desc: 'Wins & next actions.',
                onTap: () => _openSection(context, GrowthSection.monthlyReview),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _PrimaryButton(
            label: 'Open Full Growth Dashboard →',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GrowthPage())),
          ),
        ],
      ),
    );
  }

  void _openSection(BuildContext context, GrowthSection section) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GrowthPage(initialSection: section)),
    );
  }
}

class _MiniMetricRow extends StatelessWidget {
  const _MiniMetricRow({required this.isMobile});
  final bool isMobile;
  @override
  Widget build(BuildContext context) {
    final metrics = const [
      ('Traffic', '13.2k', '+15%'),
      ('Leads', '220', '+8%'),
      ('Sales', '75', '+12%'),
    ];
    return LayoutBuilder(
      builder: (ctx, c) {
        final horizontal = c.maxWidth > 600;
        final children = metrics
            .map((m) => _MetricChip(label: m.$1, value: m.$2, trend: m.$3))
            .toList();
        return horizontal
            ? Row(
                children: [
                  for (int i = 0; i < children.length; i++) ...[
                    Expanded(child: children[i]),
                    if (i != children.length - 1) const SizedBox(width: 14),
                  ],
                ],
              )
            : Column(
                children: [
                  for (int i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i != children.length - 1) const SizedBox(height: 14),
                  ],
                ],
              );
      },
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value, required this.trend});
  final String label;
  final String value;
  final String trend;
  @override
  Widget build(BuildContext context) {
    final positive = trend.startsWith('+');
    final trendColor = positive ? Colors.greenAccent : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Row(
            children: [
              Icon(positive ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: trendColor),
              const SizedBox(width: 2),
              Text(trend.replaceAll('-', ''), style: TextStyle(color: trendColor, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatefulWidget {
  const _MiniCard({required this.icon, required this.title, required this.desc, required this.onTap});
  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onTap;
  @override
  State<_MiniCard> createState() => _MiniCardState();
}

class _MiniCardState extends State<_MiniCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.white.withValues(alpha: _hover ? 0.18 : 0.08);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 260,
            constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: [if (_hover) const BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon, color: Colors.white, size: 20),
              const SizedBox(height: 12),
              Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(widget.desc, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hover = false;
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _hover ? const [GrowthPreviewSection._accent2, GrowthPreviewSection._accent] : const [GrowthPreviewSection._accent, GrowthPreviewSection._accent2]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 8)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
