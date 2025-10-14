import 'package:flutter/material.dart';
import '../layout/site_scaffold.dart';
// Inlined Leadership & Team section implementation (moved from widgets/about/leadership_team_section.dart)

/// TeamPage: standalone page rendering only the Leadership & Team section.
class TeamPage extends StatelessWidget {
  const TeamPage({super.key});

  Founder get _founder => const Founder(
        name: 'Ananya Rao',
        role: 'Founder & CEO',
        photoUrl: 'https://images.unsplash.com/photo-1607746882042-944635dfe10e?w=800&auto=format&fit=crop',
        shortBio: 'Driving Tulasi\'s vision across design, technology and growth with a product-first mindset.',
        longBio:
            'Ananya founded Tulasi Solutions to unify branding, technology and automation into a single strategic growth partner. With a background in product strategy and full‑stack delivery, she focuses on building sustainable systems that let clients scale faster with less operational friction. She believes in craftsmanship, measurable outcomes and empowering cross‑functional teams to solve meaningful business problems.',
      );

  List<TeamMember> get _team => const [
        TeamMember(
          name: 'Ravi Kumar',
          role: 'Head of Engineering',
          photoUrl: 'https://images.unsplash.com/photo-1595152772835-219674b2a8a6?w=800&auto=format&fit=crop',
          shortBio: 'Architects scalable platforms & reviews every critical deployment.',
          longBio:
              'Ravi leads engineering with a focus on reliability, maintainability and automation. He has delivered cloud-native, multi-tenant solutions across finance, retail and SaaS sectors and is passionate about engineering culture.',
        ),
        TeamMember(
          name: 'Priya Singh',
          role: 'Design & Brand Lead',
          photoUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800&auto=format&fit=crop',
          shortBio: 'Owns brand systems & elevates user experience across products.',
          longBio:
              'Priya blends visual craft with UX systems thinking. She leads brand evolution, accessibility reviews and multi-channel creative direction ensuring consistency and conversion impact.',
        ),
        TeamMember(
          name: 'Arjun Mehta',
          role: 'Automation Strategist',
          photoUrl: 'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=800&auto=format&fit=crop',
          shortBio: 'Implements workflow automation & marketing orchestration.',
          longBio:
              'Arjun specializes in reducing manual repetition through API orchestration and CRM integrations. He helps clients reclaim operational time and unlock compounding growth loops.',
        ),
        TeamMember(
          name: 'Sanya Verma',
          role: 'Growth Marketing Lead',
          photoUrl: 'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=800&auto=format&fit=crop',
          shortBio: 'Data-driven funnels & lifecycle optimization across channels.',
          longBio:
              'Sanya creates iterative experiment frameworks, mapping audience insights to activation, retention and expansion strategies. She is obsessed with cohort analytics and compounding retention.',
        ),
        TeamMember(
          name: 'Karthik Iyer',
          role: 'Full-Stack Engineer',
          photoUrl: 'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=800&auto=format&fit=crop',
          shortBio: 'Builds modular web & app features focused on performance.',
          longBio:
              'Karthik works across Flutter, TypeScript and serverless deployments. He champions code health, telemetry and test coverage in fast iteration cycles.',
        ),
        TeamMember(
          name: 'Neha Patel',
          role: 'Product Operations',
          photoUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=800&auto=format&fit=crop',
          shortBio: 'Improves delivery flow & stakeholder alignment.',
          longBio:
              'Neha keeps strategy connected to execution—facilitating prioritization, capacity planning and continuous feedback loops for predictable releases.',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          LeadershipTeamSection(founder: _founder, team: _team),
        ],
      ),
    );
  }
}

// ===================== Inlined Models & Section =====================

const _bgColor = Color(0xFFF7F4F0);           // Background
const _primaryAccent = Color(0xFF8AA399);     // Primary accent
const _highlightAccent = Color(0xFFFF6B6B);   // CTA / highlight

class Founder {
  final String name;
  final String role;
  final String photoUrl;
  final String shortBio;
  final String longBio;
  const Founder({
    required this.name,
    required this.role,
    required this.photoUrl,
    required this.shortBio,
    required this.longBio,
  });
}

class TeamMember {
  final String name;
  final String role;
  final String photoUrl;
  final String shortBio;
  final String longBio;
  const TeamMember({
    required this.name,
    required this.role,
    required this.photoUrl,
    required this.shortBio,
    required this.longBio,
  });
}

class LeadershipTeamSection extends StatelessWidget {
  final Founder founder;
  final List<TeamMember> team;
  const LeadershipTeamSection({super.key, required this.founder, required this.team});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: const BoxDecoration(color: _bgColor),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(),
              const SizedBox(height: 32),
              _FounderCard(founder: founder),
              const SizedBox(height: 48),
              _TeamGrid(team: team),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_2_rounded, color: _primaryAccent, size: 32),
            const SizedBox(width: 10),
            Text(
              'Meet the People Behind Tulasi',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Our cross-functional team covers design, tech, automation, and growth strategy.',
          style: textTheme.titleMedium?.copyWith(color: Colors.black.withValues(alpha: .70), height: 1.35),
        ),
      ],
    );
  }
}

class _FounderCard extends StatelessWidget {
  final Founder founder;
  const _FounderCard({required this.founder});
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    final card = _ElevatedCard(
      semanticLabel: 'Founder: ${founder.name}, ${founder.role}',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _CirclePhoto(url: founder.photoUrl, size: 120, alt: founder.name),
                  const SizedBox(width: 28),
                  Expanded(child: _FounderText(founder: founder)),
                ],
              )
            : Column(
                children: [
                  _CirclePhoto(url: founder.photoUrl, size: 110, alt: founder.name),
                  const SizedBox(height: 20),
                  _FounderText(founder: founder),
                ],
              ),
      ),
    );
    return Semantics(container: true, child: card);
  }
}

class _FounderText extends StatelessWidget {
  final Founder founder;
  const _FounderText({required this.founder});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(founder.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_rounded, size: 18, color: _primaryAccent),
            const SizedBox(width: 6),
            Text(founder.role, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 14),
        Text(founder.shortBio, style: const TextStyle(fontSize: 15.5, height: 1.4, color: Colors.black87)),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _highlightAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onPressed: () => _showFounderDialog(context, founder),
          icon: const Icon(Icons.read_more_rounded),
          label: const Text('Read more'),
        )
      ],
    );
  }
}

void _showFounderDialog(BuildContext context, Founder founder) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .55),
    builder: (ctx) => _FounderDialog(founder: founder),
  );
}

class _FounderDialog extends StatelessWidget {
  final Founder founder;
  const _FounderDialog({required this.founder});
  @override
  Widget build(BuildContext context) {
    final f = founder;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CirclePhoto(url: f.photoUrl, size: 64, alt: f.name),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(f.role, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(f.longBio, style: const TextStyle(fontSize: 15.5, height: 1.48)),
            const SizedBox(height: 20),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Close'),
        ),
      ],
    );
  }
}

class _TeamGrid extends StatelessWidget {
  final List<TeamMember> team;
  const _TeamGrid({required this.team});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final cols = w >= 1100 ? 3 : (w >= 700 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
            mainAxisExtent: 270,
          mainAxisSpacing: 22,
          crossAxisSpacing: 22,
        ),
        itemCount: team.length,
        itemBuilder: (context, i) => _TeamMemberCard(member: team[i]),
      );
    });
  }
}

class _TeamMemberCard extends StatefulWidget {
  final TeamMember member;
  const _TeamMemberCard({required this.member});
  @override
  State<_TeamMemberCard> createState() => _TeamMemberCardState();
}

class _TeamMemberCardState extends State<_TeamMemberCard> {
  bool _hover = false;
  bool _focused = false;
  void _openDetails() => _showMemberDialog(context, widget.member);
  @override
  Widget build(BuildContext context) {
    final scale = _hover ? 1.02 : 1.0;
    return FocusableActionDetector(
      onShowFocusHighlight: (f) => setState(() => _focused = f),
      onFocusChange: (f) => setState(() => _focused = f),
      mouseCursor: SystemMouseCursors.click,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: _openDetails,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            transform: Matrix4.identity()..scale(scale),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hover ? .18 : .08),
                  blurRadius: _hover ? 20 : 12,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(color: _focused ? _highlightAccent : Colors.black.withValues(alpha: .05), width: _focused ? 2 : 1),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _CirclePhoto(url: widget.member.photoUrl, size: 70, alt: widget.member.name),
                const SizedBox(height: 14),
                Text(widget.member.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.work_outline_rounded, size: 16, color: _primaryAccent),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.member.role,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    widget.member.shortBio,
                    style: const TextStyle(fontSize: 13.5, height: 1.35, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _openDetails,
                  style: TextButton.styleFrom(foregroundColor: _highlightAccent),
                  child: const Text('View'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showMemberDialog(BuildContext context, TeamMember member) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .55),
    builder: (ctx) => _MemberDialog(member: member),
  );
}

class _MemberDialog extends StatelessWidget {
  final TeamMember member;
  const _MemberDialog({required this.member});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CirclePhoto(url: member.photoUrl, size: 56, alt: member.name),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(member.role, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(member.longBio, style: const TextStyle(fontSize: 14.5, height: 1.48)),
            const SizedBox(height: 14),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Close'),
        ),
      ],
    );
  }
}

class _ElevatedCard extends StatefulWidget {
  final Widget child;
  final String? semanticLabel;
  const _ElevatedCard({required this.child, this.semanticLabel});
  @override
  State<_ElevatedCard> createState() => _ElevatedCardState();
}

class _ElevatedCardState extends State<_ElevatedCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final scale = _hover ? 1.015 : 1.0;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      transform: Matrix4.identity()..scale(scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _hover ? .20 : .10),
            blurRadius: _hover ? 30 : 18,
            offset: const Offset(0, 14),
          ),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: .05)),
      ),
      child: widget.child,
    );
    return Semantics(
      label: widget.semanticLabel,
      container: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: card,
      ),
    );
  }
}

class _CirclePhoto extends StatelessWidget {
  final String url;
  final double size;
  final String alt;
  const _CirclePhoto({required this.url, required this.size, required this.alt});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Photo of $alt',
      image: true,
      child: ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, _, __) {
            final initials = alt.isNotEmpty ? alt.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join() : '?';
            return Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              color: _primaryAccent.withValues(alpha: .15),
              child: Text(initials, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryAccent)),
            );
          },
        ),
      ),
    );
  }
}
