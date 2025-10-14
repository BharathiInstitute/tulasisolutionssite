import 'package:flutter/material.dart';

class ResponsiveNavBar extends StatelessWidget {
  const ResponsiveNavBar({super.key, required this.title, required this.onItemSelected, this.activeLabel});
  final String title;
  final void Function(int index, String label) onItemSelected;
  final String? activeLabel; // optional current active menu label

  static const items = [
    'Business Setup', 'Branding', 'Marketing', 'Websites', 'Software', 'Automation', 'Training', 'Growth'
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 880; // slightly wider breakpoint for comfort
    return Material(
      color: Colors.black.withValues(alpha: .10),
      elevation: 4,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: isMobile ? _buildMobile(context) : _buildDesktop(context),
        ),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        const Spacer(),
        for (var i = 0; i < items.length; i++)
          _NavButton(
            label: items[i],
            active: items[i] == activeLabel,
            onTap: () => onItemSelected(i, items[i]),
          ),
      ],
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
            runSpacing: 6,
          children: [
            for (var i = 0; i < items.length; i++)
              _NavChip(
                label: items[i],
                active: items[i] == activeLabel,
                onTap: () => onItemSelected(i, items[i]),
              ),
          ],
        )
      ],
    );
  }

}

class _NavButton extends StatefulWidget {
  const _NavButton({required this.label, required this.onTap, required this.active});
  final String label; final VoidCallback onTap; final bool active;
  @override State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hover = false; bool _down = false;
  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.white70;
    final active = widget.active;
    final color = active ? Colors.white : (_hover ? Colors.white : baseColor);
    final weight = active ? FontWeight.w700 : FontWeight.w500;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() { _hover = false; _down = false; }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: active
                  ? Colors.white.withValues(alpha: .18)
                  : (_down ? Colors.white.withValues(alpha: .08) : (_hover ? Colors.white.withValues(alpha: .06) : Colors.transparent)),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: color,
                fontWeight: weight,
                fontSize: 14.5,
                letterSpacing: .3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavChip extends StatefulWidget {
  const _NavChip({required this.label, required this.onTap, required this.active});
  final String label; final VoidCallback onTap; final bool active;
  @override State<_NavChip> createState() => _NavChipState();
}

class _NavChipState extends State<_NavChip> {
  bool _hover = false; bool _down = false;
  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() { _hover = false; _down = false; }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: active
                ? Colors.white.withValues(alpha: .20)
                : (_down ? Colors.white.withValues(alpha: .10) : (_hover ? Colors.white.withValues(alpha: .08) : Colors.white.withValues(alpha: .04))),
            border: Border.all(color: Colors.white.withValues(alpha: active ? .9 : .35)),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13.5,
              letterSpacing: .25,
            ),
          ),
        ),
      ),
    );
  }
}
