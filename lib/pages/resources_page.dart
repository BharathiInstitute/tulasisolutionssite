import 'package:flutter/material.dart';
import '../sections/layout/site_scaffold.dart';

/// Aggregated Resources landing page linking to Blog, Guides, Templates, FAQs.
class ResourcesPage extends StatelessWidget {
	const ResourcesPage({super.key});

	@override
	Widget build(BuildContext context) {
		final cards = _resourceCards(context);
		return SiteScaffold(
			body: SingleChildScrollView(
				physics: const ClampingScrollPhysics(),
				child: Container(
					width: double.infinity,
						padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
					color: Colors.grey.shade50,
					child: Center(
						child: ConstrainedBox(
							constraints: const BoxConstraints(maxWidth: 1100),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Row(
										mainAxisSize: MainAxisSize.min,
										children: const [
											Icon(Icons.library_books, color: Colors.black87),
											SizedBox(width: 8),
											Text('Resources', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
										],
									),
									const SizedBox(height: 12),
									const Text(
										'Browse curated knowledge, tools and answers to accelerate your growth.',
										style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.4),
									),
									const SizedBox(height: 32),
									LayoutBuilder(builder: (context, c) {
										final width = c.maxWidth;
										int crossAxis = 1;
										if (width >= 1000) {
											crossAxis = 4;
										} else if (width >= 760) {
											crossAxis = 2;
										}
										return GridView.count(
											shrinkWrap: true,
											physics: const NeverScrollableScrollPhysics(),
											crossAxisCount: crossAxis,
											crossAxisSpacing: 16,
											mainAxisSpacing: 16,
											childAspectRatio: 1.1,
											children: cards,
										);
									}),
								],
							),
						),
					),
				),
			),
		);
	}

	List<Widget> _resourceCards(BuildContext context) => [
				_ResourceCard(
					icon: Icons.edit,
					title: 'Blog',
					desc: 'Insights, strategies & stories.',
					route: '/resources/blog',
				),
				_ResourceCard(
					icon: Icons.menu_book_rounded,
					title: 'Guides',
					desc: 'Practical step-by-step playbooks.',
					route: '/resources/guides',
				),
				_ResourceCard(
					icon: Icons.extension,
					title: 'Templates',
					desc: 'Ready-to-use assets & kits.',
					route: '/resources/templates',
				),
				// Case Studies removed intentionally; keep only Blog, Guides, Templates, FAQs
				_ResourceCard(
					icon: Icons.help_outline,
					title: 'FAQs',
					desc: 'Common questions answered.',
					route: '/resources/faqs',
				),
			];
}

class _ResourceCard extends StatefulWidget {
	const _ResourceCard({
		required this.icon,
		required this.title,
		required this.desc,
		required this.route,
	});
	final IconData icon;
	final String title;
	final String desc;
	final String route;
	@override
	State<_ResourceCard> createState() => _ResourceCardState();
}

class _ResourceCardState extends State<_ResourceCard> {
	bool _hovered = false;

	@override
	Widget build(BuildContext context) {
		final radius = BorderRadius.circular(20);
		return MouseRegion(
			cursor: SystemMouseCursors.click,
			child: AnimatedContainer(
				duration: const Duration(milliseconds: 160),
				curve: Curves.easeOut,
				transform: Matrix4.identity()
				  ..translate(0.0, _hovered ? -2.0 : 0.0)
				  ..scale(_hovered ? 1.01 : 1.0),
				child: Material(
					color: Colors.white,
					elevation: _hovered ? 8 : 3,
					borderRadius: radius,
					clipBehavior: Clip.antiAlias,
					child: InkWell(
						onTap: () => Navigator.of(context).pushNamed(widget.route),
						onHover: (h) => setState(() => _hovered = h),
						customBorder: RoundedRectangleBorder(borderRadius: radius),
						hoverColor: Colors.blue.withValues(alpha: 0.06),
						splashColor: Colors.blue.withValues(alpha: 0.10),
						highlightColor: Colors.blue.withValues(alpha: 0.08),
						child: Semantics(
						  button: true,
						  label: widget.title,
						  child: Padding(
							  padding: const EdgeInsets.all(20),
							  child: Column(
								  crossAxisAlignment: CrossAxisAlignment.start,
								  children: [
									  AnimatedContainer(
										  duration: const Duration(milliseconds: 160),
										  padding: const EdgeInsets.all(12),
										  decoration: BoxDecoration(
											  color: _hovered ? Colors.blue.shade100 : Colors.blue.shade50,
											  borderRadius: BorderRadius.circular(14),
										  ),
										  child: Icon(widget.icon, color: Colors.blue.shade700, size: 28),
									  ),
									  const Spacer(),
									  Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
									  const SizedBox(height: 8),
									  Text(
										  widget.desc,
										  style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.3),
									  ),
								  ],
							  ),
						  ),
						),
					),
				),
			),
		);
	}
}

