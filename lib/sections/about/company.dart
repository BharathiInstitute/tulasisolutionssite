import 'package:flutter/material.dart';
import '../layout/site_scaffold.dart';

// Accent palette reused across About subsections
const _missionBg = Color(0xFFF7F4F0);
const _accent = Color(0xFF8AA399);     // Timeline markers
const _highlight = Color(0xFFFF6B6B);  // Active / hover highlight

class CompanyPage extends StatelessWidget {
  const CompanyPage({super.key});

  MissionData get _data => const MissionData(
        headline: 'Our Mission',
        subtext: 'To simplify growth for businesses by providing an end-to-end digital and operational stack.',
        story:
            'Founded to bridge the gap between traditional businesses and digital-first strategies, we\'ve helped clients scale with clarity and speed.',
        milestones: [
          MissionMilestone(year: '2019', title: 'Ideation', description: 'Identified fragmentation in SMB digital ops.', icon: Icons.lightbulb_outline),
          MissionMilestone(year: '2020', title: 'First Clients', description: 'Delivered early multi-channel growth pilots.', icon: Icons.group_outlined),
            MissionMilestone(year: '2021', title: 'Automation Layer', description: 'Added process + marketing automation modules.', icon: Icons.extension_outlined),
          MissionMilestone(year: '2023', title: 'Industry Frameworks', description: 'Launched tailored onboarding playbooks.', icon: Icons.domain_outlined),
          MissionMilestone(year: '2025', title: 'Unified Ops OS', description: 'Evolving into a central growth command center.', icon: Icons.hub_outlined),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return SiteScaffold(
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final isMobile = constraints.maxWidth < 760;
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MissionHeader(data: data),
                      const SizedBox(height: 48),
                      _MissionStoryCard(story: data.story),
                      const SizedBox(height: 60),
                      _MissionTimeline(data: data, isMobile: isMobile),
                      const SizedBox(height: 70),
                      _BackNav(),
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}

// ==================== DATA MODELS ====================
class MissionData {
  final String headline;
  final String subtext;
  final String story;
  final List<MissionMilestone> milestones;
  const MissionData({
    required this.headline,
    required this.subtext,
    required this.story,
    required this.milestones,
  });
}

class MissionMilestone {
  final String year;
  final String title;
  final String description;
  final IconData? icon;
  const MissionMilestone({
    required this.year,
    required this.title,
    required this.description,
    this.icon,
  });
}

// ==================== HEADER ====================
class _MissionHeader extends StatelessWidget {
  const _MissionHeader({required this.data});
  final MissionData data;
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 42)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                data.headline,
                style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          data.subtext,
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500, color: Colors.black.withValues(alpha: .75)),
        ),
      ],
    );
  }
}

// ==================== STORY CARD ====================
class _MissionStoryCard extends StatelessWidget {
  const _MissionStoryCard({required this.story});
  final String story;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _missionBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: .07)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Text(
        story,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, height: 1.5),
      ),
    );
  }
}

// ==================== TIMELINE ====================
class _MissionTimeline extends StatefulWidget {
  const _MissionTimeline({required this.data, required this.isMobile});
  final MissionData data;
  final bool isMobile;
  @override
  State<_MissionTimeline> createState() => _MissionTimelineState();
}

class _MissionTimelineState extends State<_MissionTimeline> {
  int _hoverIndex = -1;
  @override
  Widget build(BuildContext context) {
    return widget.isMobile
        ? _VerticalTimeline(
            milestones: widget.data.milestones,
            hoverIndex: _hoverIndex,
            onHover: (i) => setState(() => _hoverIndex = i),
          )
        : _HorizontalTimeline(
            milestones: widget.data.milestones,
            hoverIndex: _hoverIndex,
            onHover: (i) => setState(() => _hoverIndex = i),
          );
  }
}

class _HorizontalTimeline extends StatelessWidget {
  const _HorizontalTimeline({required this.milestones, required this.hoverIndex, required this.onHover});
  final List<MissionMilestone> milestones;
  final int hoverIndex;
  final ValueChanged<int> onHover;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Company milestones timeline horizontal',
      child: SizedBox(
        height: 240,
        child: LayoutBuilder(
          builder: (ctx, box) {
            const cardWidth = 140.0; // ensure full visibility
            final spacing = (box.maxWidth - cardWidth) / (milestones.length - 1);
            return Stack(
              clipBehavior: Clip.none, // allow any slight overflow (should not overflow after calc)
              children: [
                Positioned(
                  top: 110,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                for (var i = 0; i < milestones.length; i++)
                  Positioned(
                    left: spacing * i,
                    top: 80,
                    width: cardWidth,
                    child: _MilestoneNode(
                      milestone: milestones[i],
                      index: i,
                      hovered: i == hoverIndex,
                      onHover: onHover,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VerticalTimeline extends StatelessWidget {
  const _VerticalTimeline({required this.milestones, required this.hoverIndex, required this.onHover});
  final List<MissionMilestone> milestones;
  final int hoverIndex;
  final ValueChanged<int> onHover;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < milestones.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  _Dot(
                    index: i,
                    hovered: hoverIndex == i,
                    onHover: onHover,
                    icon: milestones[i].icon,
                  ),
                  if (i != milestones.length - 1)
                    Container(width: 3, height: 54, decoration: BoxDecoration(color: _accent.withValues(alpha: .35))),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _MilestoneCard(
                  milestone: milestones[i],
                  index: i,
                  hovered: hoverIndex == i,
                  onHover: onHover,
                ),
              )
            ],
          ),
          const SizedBox(height: 26),
        ]
      ],
    );
  }
}

class _MilestoneNode extends StatelessWidget {
  const _MilestoneNode({required this.milestone, required this.index, required this.hovered, required this.onHover});
  final MissionMilestone milestone;
  final int index;
  final bool hovered;
  final ValueChanged<int> onHover;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Dot(index: index, hovered: hovered, onHover: onHover, icon: milestone.icon),
        const SizedBox(height: 14),
        _MilestoneCard(milestone: milestone, index: index, hovered: hovered, onHover: onHover),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.index, required this.hovered, required this.onHover, this.icon});
  final int index;
  final bool hovered;
  final ValueChanged<int> onHover;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final size = hovered ? 30.0 : 22.0;
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (v) => onHover(v ? index : -1),
      child: GestureDetector(
        onTap: () => onHover(hovered ? -1 : index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hovered ? _highlight : _accent,
            boxShadow: [if (hovered) BoxShadow(color: _highlight.withValues(alpha: .45), blurRadius: 20, spreadRadius: 2)],
          ),
          child: icon == null ? null : Icon(icon, size: hovered ? 18 : 16, color: Colors.white),
        ),
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.milestone, required this.index, required this.hovered, required this.onHover});
  final MissionMilestone milestone;
  final int index;
  final bool hovered;
  final ValueChanged<int> onHover;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Milestone ${milestone.year}: ${milestone.title}',
      button: true,
      child: MouseRegion(
        onEnter: (_) => onHover(index),
        onExit: (_) => onHover(-1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hovered ? _highlight : Colors.black.withValues(alpha: .08), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: hovered ? .20 : .10),
                blurRadius: hovered ? 24 : 12,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(milestone.year, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 6),
              Text(milestone.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              Text(milestone.description, style: const TextStyle(fontSize: 14, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
  onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back),
  label: const Text('Back'),
      ),
    );
  }
}
