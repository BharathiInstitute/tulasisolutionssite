import 'package:flutter/material.dart';

class ContactIntroSection extends StatelessWidget {
  const ContactIntroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 800;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 48 : 72),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: isMobile ? _MobileLayout() : _DesktopLayout(),
        ),
      ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: const [
        _IntroTextBlock(textAlign: TextAlign.center),
        SizedBox(height: 24),
        _IllustrationPlaceholder(height: 180),
      ],
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: const [
        Expanded(flex: 6, child: _IntroTextBlock(textAlign: TextAlign.left)),
        SizedBox(width: 40),
        Expanded(flex: 5, child: _IllustrationPlaceholder(height: 260)),
      ],
    );
  }
}

class _IntroTextBlock extends StatelessWidget {
  const _IntroTextBlock({required this.textAlign});
  final TextAlign textAlign;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: textAlign == TextAlign.left ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🤝', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Icon(Icons.wifi_tethering, size: 22, color: scheme.primary),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          "Let's Talk Growth",
          textAlign: textAlign,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0D1B2A),
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'Reach out through WhatsApp, phone, or our quick form. We respond fast.',
          textAlign: textAlign,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF284B63),
                height: 1.35,
              ),
        ),
      ],
    );
  }
}

class _IllustrationPlaceholder extends StatelessWidget {
  const _IllustrationPlaceholder({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Circular highlight
          Align(
            alignment: Alignment.center,
            child: Container(
              width: height * 0.9,
              height: height * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Three people using devices (emoji-based minimal placeholder)
          Align(
            alignment: Alignment.centerLeft,
            child: _PersonBubble(emoji: '📱', label: 'Chat'),
          ),
          Align(
            alignment: Alignment.center,
            child: _PersonBubble(emoji: '💻', label: 'Type'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _PersonBubble(emoji: '📲', label: 'Message'),
          ),
        ],
      ),
    );
  }
}

class _PersonBubble extends StatelessWidget {
  const _PersonBubble({required this.emoji, required this.label});
  final String emoji;
  final String label;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: scheme.primary.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
