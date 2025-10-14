import 'package:flutter/material.dart';

class WhatsappChatSection extends StatelessWidget {
  const WhatsappChatSection({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade100,
            Colors.green.shade50,
          ],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, c) {
              final isNarrow = c.maxWidth < 800;
              final content = <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: isNarrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                    children: [
                      Text('Chat With Us on WhatsApp',
                          textAlign: isNarrow ? TextAlign.center : TextAlign.left,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.green.shade900,
                              )),
                      const SizedBox(height: 8),
                      Text('Quickest way to connect with our team.',
                          textAlign: isNarrow ? TextAlign.center : TextAlign.left,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.green.shade800)),
                      const SizedBox(height: 16),
                      Align(
                        alignment: isNarrow ? Alignment.center : Alignment.centerLeft,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          onPressed: () {},
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Click to Chat →'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24, height: 24),
                Expanded(
                  child: _MockChatCard(color: scheme.primary),
                ),
              ];
              return isNarrow
                  ? Column(children: [content[0], const SizedBox(height: 20), content[2]])
                  : Row(children: content);
            },
          ),
        ),
      ),
    );
  }
}

class _MockChatCard extends StatelessWidget {
  const _MockChatCard({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.green.shade200.withValues(alpha: 0.5), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _Bubble(me: false, text: 'Hi! How can we help today?'),
          SizedBox(height: 8),
          _Bubble(me: true, text: 'Looking to grow my business online.'),
          SizedBox(height: 8),
          _Bubble(me: false, text: 'Great! Let’s schedule a quick call.'),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.me, required this.text});
  final bool me;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: me ? Colors.green.shade600 : Colors.green.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(me ? 14 : 4),
            bottomRight: Radius.circular(me ? 4 : 14),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            text,
            style: TextStyle(color: me ? Colors.white : Colors.green.shade900),
          ),
        ),
      ),
    );
  }
}

