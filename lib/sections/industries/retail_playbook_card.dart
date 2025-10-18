// Rewritten clean RetailPlaybookCard widget (replaces corrupted content)
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
// Local bullet model for retail playbook
class BulletItem {
  final String text;
  /// Can be an IconData, an emoji String, or null (treated as a generic dot)
  final Object? icon;
  const BulletItem({required this.text, required this.icon});
}

class RetailPlaybookCard extends StatefulWidget {
  const RetailPlaybookCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.bullets,
    this.imageAsset,
    required this.onPrimaryTap,
    required this.onSecondaryTap,
  });

  final String title;
  final String subtitle;
  final List<BulletItem> bullets;
  final String? imageAsset;
  final VoidCallback onPrimaryTap;
  final VoidCallback onSecondaryTap;

  @override
  State<RetailPlaybookCard> createState() => _RetailPlaybookCardState();
}

class _RetailPlaybookCardState extends State<RetailPlaybookCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  bool _hovered = false;
  Offset _pointer = Offset.zero;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 900;
    const gold = Color(0xFFD4AF37);
    const primaryText = Color(0xFF111827);
    const secondaryText = Color(0xFF4B5563);

    final left = _LeftContent(
      title: widget.title,
      subtitle: widget.subtitle,
      bullets: widget.bullets,
      onPrimaryTap: widget.onPrimaryTap,
      onSecondaryTap: widget.onSecondaryTap,
      primaryText: primaryText,
      secondaryText: secondaryText,
      gold: gold,
      isWide: isWide,
    );

    final right = MouseRegion(
      onHover: (e) => setState(() => _pointer = e.localPosition),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        scale: _hovered ? 1.03 : 1.0,
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: _controller,
            curve: const Interval(.35, 1, curve: Curves.easeOut),
          ),
          child: _RightVisual(
            gold: gold,
            imageAsset: widget.imageAsset,
            hovered: _hovered,
            pointer: _pointer,
          ),
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: _hovered
            ? (Matrix4.identity()..translate(0.0, -6.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovered ? 0.15 : 0.08),
              blurRadius: _hovered ? 22 : 14,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(color: Colors.black.withValues(alpha: .05)),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 52 : 28,
          vertical: isWide ? 52 : 32,
        ),
        child: LayoutBuilder(
          builder: (context, _) {
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 3, child: left),
                  const SizedBox(width: 34),
                  Expanded(flex: 2, child: right),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                left,
                const SizedBox(height: 28),
                right,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LeftContent extends StatelessWidget {
  const _LeftContent({
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.onPrimaryTap,
    required this.onSecondaryTap,
    required this.primaryText,
    required this.secondaryText,
    required this.gold,
    required this.isWide,
  });

  final String title;
  final String subtitle;
  final List<BulletItem> bullets;
  final VoidCallback onPrimaryTap;
  final VoidCallback onSecondaryTap;
  final Color primaryText;
  final Color secondaryText;
  final Color gold;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final headlineSize = isWide ? 40.0 : 30.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: gold.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('🛒', semanticsLabel: 'Retail icon'),
            ),
            const SizedBox(width: 12),
            Container(width: 32, height: 2, color: gold),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: TextStyle(
            fontSize: headlineSize * scale,
            fontWeight: FontWeight.w700,
            color: primaryText,
            height: 1.05,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 16 * scale,
            color: secondaryText,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 26),
        ...bullets.asMap().entries.map((entry) {
          final i = entry.key;
          final b = entry.value;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 260 + i * 80),
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, (1 - v) * 10),
                child: child,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.of(context).pushNamed('/industries'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: gold.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: _iconFor(b.icon, color: gold, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        b.text,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        Wrap(
          spacing: 14,
          runSpacing: 10,
          children: [
            FilledButton(
              onPressed: onPrimaryTap,
              style: FilledButton.styleFrom(
                backgroundColor: primaryText,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('See Playbook'),
            ),
            TextButton(
              onPressed: onSecondaryTap,
              child: const Text('Contact sales'),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _RightVisual extends StatelessWidget {
  const _RightVisual({
    required this.gold,
    required this.imageAsset,
    required this.hovered,
    required this.pointer,
  });

  final Color gold;
  final String? imageAsset;
  final bool hovered;
  final Offset pointer;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final tiltX = ((pointer.dy / math.max(size.height, 1)) - .5) * (hovered ? 0.03 : 0);
    final tiltY = ((pointer.dx / math.max(size.width, 1)) - .5) * (hovered ? -0.03 : 0);

    Widget background;
    if (imageAsset != null) {
      background = Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(imageAsset!),
            fit: BoxFit.cover,
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xAA000000), Color(0x00000000)],
              ),
            ),
          ),
        ),
      );
    } else {
      background = Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F2937), Color(0xFF374151)],
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(tiltX)
            ..rotateY(tiltY),
          child: Stack(
            fit: StackFit.expand,
            children: [
              background,
              Align(
                alignment: const Alignment(.2, -.2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  transform: Matrix4.identity()
                    ..rotateZ(hovered ? 0 : -6 * math.pi / 180)
                    ..scale(hovered ? 1.03 : 1.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 16,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const _CourseCard(gold: Color(0xFFD4AF37)),
                ),
              ),
              const Align(
                alignment: Alignment(-.4, .6),
                child: _ProgressRow(gold: Color(0xFFD4AF37)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Icon helper that accepts IconData or emoji string.
Widget _iconFor(Object? icon, {required Color color, double size = 16}) {
  if (icon == null) {
    return Container(
      width: size - 6,
      height: size - 6,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .55),
        shape: BoxShape.circle,
      ),
    );
  }
  if (icon is IconData) return Icon(icon, color: color, size: size);
  if (icon is String) return Text(icon, style: TextStyle(fontSize: size, color: color));
  return Container(
    width: size - 6,
    height: size - 6,
    decoration: BoxDecoration(color: color.withValues(alpha: .55), shape: BoxShape.circle),
  );
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.gold});
  final Color gold;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      height: 130,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gold.withValues(alpha: .16), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withValues(alpha: .30)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text('📦'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'SKU Uplift',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withValues(alpha: .80),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'Campaign kit',
            style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: .65)),
          ),
            const SizedBox(height: 4),
          LinearProgressIndicator(
            value: .62,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: Colors.black.withValues(alpha: .08),
            valueColor: AlwaysStoppedAnimation(gold.withValues(alpha: .85)),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.gold});
  final Color gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: gold.withValues(alpha: .30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Promo Performance',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black.withValues(alpha: .78),
            ),
          ),
          const SizedBox(height: 12),
          ...[['Footfall', .74], ['Conv. Rate', .52], ['AOV', .66]].map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      m[0] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black.withValues(alpha: .65),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (m[1] as num).toDouble(),
                        minHeight: 6,
                        backgroundColor: Colors.black.withValues(alpha: .08),
                        valueColor: AlwaysStoppedAnimation(gold.withValues(alpha: .85)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
