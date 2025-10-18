import 'package:flutter/material.dart';
import '../sections/layout/site_scaffold.dart';
import '../sections/services/page_background.dart';
import 'branding_page.dart';
import 'marketing_page.dart';
import 'websites_page.dart';
import 'software_page.dart';
import 'automation_page.dart';
import 'training_page.dart';
import 'growth_page.dart';


/// Optimised Services hub using a single CustomScrollView (slivers) to reduce
/// layout passes and avoid jank from nested scrollables. Provides a stable
/// Scrollbar and lightweight hover animations.
class ServicesPage extends StatefulWidget {
	const ServicesPage({super.key});
	@override
	State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> with TickerProviderStateMixin {
	final ScrollController _scrollController = ScrollController();

	@override
	void dispose() {
		_scrollController.dispose();
		super.dispose();
	}

	List<_ServiceMeta> get _services => const [
				_ServiceMeta(
					title: 'Branding',
					subtitle: 'Logos, brochures & social identity assets.',
					icon: Icons.palette_rounded,
					builder: BrandingPage.new,
				),
				_ServiceMeta(
					title: 'Marketing',
					subtitle: 'Pamphlets, reels, videos, GMB & ads.',
					icon: Icons.campaign_rounded,
					builder: MarketingPage.new,
				),
				_ServiceMeta(
					title: 'Websites',
					subtitle: 'Main site, landing pages & lead capture.',
					icon: Icons.web_rounded,
					builder: WebsitesPage.new,
				),
				_ServiceMeta(
					title: 'Software',
					subtitle: 'CRM, HR, Accounts, Inventory & more.',
					icon: Icons.developer_board_rounded,
					builder: SoftwarePage.new,
				),
				_ServiceMeta(
					title: 'Automation',
					subtitle: 'WhatsApp, email, SMS & journey flows.',
					icon: Icons.auto_mode_rounded,
					builder: AutomationPage.new,
				),
				_ServiceMeta(
					title: 'Training',
					subtitle: 'CRM, lead handling & follow-up skills.',
					icon: Icons.school_rounded,
					builder: TrainingPage.new,
				),
				_ServiceMeta(
					title: 'Growth',
					subtitle: 'Sales targets & monthly performance.',
					icon: Icons.trending_up_rounded,
					builder: GrowthPage.new,
				),
			];

	@override
	Widget build(BuildContext context) {
			return SiteScaffold(
				scrollable: false,
				body: ScrollConfiguration(
					behavior: const _ServicesScrollBehavior(),
					child: Stack(
						children: [
							const PageBackground(child: SizedBox.expand()),
							Scrollbar(
								controller: _scrollController,
								thumbVisibility: true,
								interactive: true,
								radius: const Radius.circular(6),
								child: CustomScrollView(
									controller: _scrollController,
									slivers: [
												SliverToBoxAdapter(child: _Hero(onExplore: () => _scrollToGrid())),
												SliverPadding(
													padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
													sliver: SliverLayoutBuilder(
														builder: (context, constraints) {
															final w = constraints.crossAxisExtent;
															int cols = 1;
															if (w >= 1400) {
																cols = 3;
															} else if (w >= 880) {
																cols = 2;
															}
															return SliverGrid.builder(
																key: _gridKey,
																itemCount: _services.length,
																gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
																	crossAxisCount: cols,
																	mainAxisExtent: 210,
																	crossAxisSpacing: 28,
																	mainAxisSpacing: 28,
																),
																itemBuilder: (context, index) {
																	final meta = _services[index];
																	return RepaintBoundary(
																		child: _ServiceCard(
																			meta: meta,
																			onTap: () => _open(meta),
																		),
																	);
																},
															);
														},
													),
												),
												const SliverToBoxAdapter(child: SizedBox(height: 48)),
												SliverToBoxAdapter(
													child: _FooterHelp(scrollController: _scrollController),
												),
												const SliverToBoxAdapter(child: SizedBox(height: 60)),
														],
													),
												),
											],
										),
									),
								);
	}

	final GlobalKey _gridKey = GlobalKey();

	void _scrollToGrid() {
		final ctx = _gridKey.currentContext;
		if (ctx != null) {
			Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic, alignment: 0.05);
		} else {
			_scrollController.animateTo(420, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
		}
	}

	void _open(_ServiceMeta meta) {
		Navigator.of(context).push(
			PageRouteBuilder(
				transitionDuration: const Duration(milliseconds: 360),
				pageBuilder: (_, __, ___) => meta.builder(),
				transitionsBuilder: (_, anim, __, child) {
					final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
					return FadeTransition(
						opacity: curved,
						child: SlideTransition(
							position: Tween<Offset>(begin: const Offset(0, 0.015), end: Offset.zero).animate(curved),
							child: child,
						),
					);
				},
			),
		);
	}
}

class _Hero extends StatelessWidget {
	const _Hero({required this.onExplore});
	final VoidCallback onExplore;
	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.fromLTRB(32, 40, 32, 28),
			child: Center(
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 1100),
					child: Container(
						padding: const EdgeInsets.fromLTRB(36, 40, 36, 42),
						decoration: BoxDecoration(
							borderRadius: BorderRadius.circular(30),
							gradient: const LinearGradient(
								colors: [Color(0xFF0B63FF), Color(0xFF22D3EE)],
								begin: Alignment.topLeft,
								end: Alignment.bottomRight,
							),
							boxShadow: const [
								BoxShadow(color: Color(0x33000000), blurRadius: 36, offset: Offset(0, 18)),
							],
						),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.center,
							children: [
								Text(
									'Services Overview',
									textAlign: TextAlign.center,
									style: Theme.of(context).textTheme.displaySmall?.copyWith(
												color: Colors.white,
												fontWeight: FontWeight.w800,
												letterSpacing: 0.2,
											),
								),
								const SizedBox(height: 16),
								const Text(
									'Move from setup to scalable growth across branding, marketing, web, software, automation, training and performance review.',
									textAlign: TextAlign.center,
									style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.45, fontWeight: FontWeight.w500),
								),
								const SizedBox(height: 30),
								Wrap(
									spacing: 14,
									runSpacing: 12,
									alignment: WrapAlignment.center,
									children: [
										FilledButton(
											onPressed: onExplore,
											style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12)),
											child: const Text('Explore Categories'),
										),
										OutlinedButton(
											onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactPagePlaceholder())),
											style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
											child: const Text('Get Advice'),
										),
									],
								),
								const SizedBox(height: 4),
								Text('Smooth scrolling • Lightweight cards • Fast navigation', style: TextStyle(color: Colors.white.withValues(alpha: .65), fontSize: 12)),
							],
						),
					),
				),
			),
		);
	}
}

class _ServiceMeta {
	const _ServiceMeta({required this.title, required this.subtitle, required this.icon, required this.builder});
	final String title;
	final String subtitle;
	final IconData icon;
	final Widget Function() builder;
}

class _ServiceCard extends StatefulWidget {
	const _ServiceCard({required this.meta, required this.onTap});
	final _ServiceMeta meta;
	final VoidCallback onTap;
	@override
	State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> with SingleTickerProviderStateMixin {
	bool _hover = false;
	late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
	late final Animation<double> _scale = Tween(begin: 1.0, end: 1.022).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

	void _setHover(bool h) {
		if (_hover == h) return;
		setState(() => _hover = h);
		if (h) {
			_controller.forward();
		} else {
			_controller.reverse();
		}
	}

	@override
	void dispose() {
		_controller.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final meta = widget.meta;
		final cs = Theme.of(context).colorScheme;
		final bg = Color.lerp(cs.surface, cs.primary.withValues(alpha: .08), _hover ? 0.8 : 0.3)!;
		return MouseRegion(
			onEnter: (_) => _setHover(true),
			onExit: (_) => _setHover(false),
			cursor: SystemMouseCursors.click,
			child: GestureDetector(
				onTap: widget.onTap,
				child: ScaleTransition(
					scale: _scale,
					child: AnimatedContainer(
						duration: const Duration(milliseconds: 280),
						curve: Curves.easeOutCubic,
						padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
						decoration: BoxDecoration(
							color: bg,
							borderRadius: BorderRadius.circular(22),
							border: Border.all(
								color: (_hover ? cs.primary : cs.outlineVariant).withValues(alpha: _hover ? .55 : .35),
								width: 1.1,
							),
							boxShadow: _hover
									? [
											BoxShadow(
												color: cs.primary.withValues(alpha: .25),
												blurRadius: 30,
												offset: const Offset(0, 16),
											)
										]
									: const [],
						),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Icon(meta.icon, size: 40, color: cs.primary),
								const SizedBox(height: 16),
								Text(meta.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.5)),
								const SizedBox(height: 6),
								Expanded(
									child: Text(
										meta.subtitle,
										style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: .72), height: 1.28),
									),
								),
								const SizedBox(height: 10),
								Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										Text('View details', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
										const SizedBox(width: 4),
										Icon(Icons.arrow_outward_rounded, size: 18, color: cs.primary),
									],
								)
							],
						),
					),
				),
			),
		);
	}
}

class _FooterHelp extends StatelessWidget {
	const _FooterHelp({required this.scrollController});
	final ScrollController scrollController;
	@override
	Widget build(BuildContext context) {
		final cs = Theme.of(context).colorScheme;
		return Padding(
			padding: const EdgeInsets.symmetric(horizontal: 24),
			child: Center(
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 880),
					child: Column(
						children: [
							Text('Need help choosing?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
							const SizedBox(height: 12),
							Text(
								'We can assemble a blended package across branding, marketing, web and automation aligned to your current growth stage.',
								textAlign: TextAlign.center,
								style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: .70), height: 1.4),
							),
							const SizedBox(height: 26),
							Wrap(
								spacing: 14,
								runSpacing: 12,
								alignment: WrapAlignment.center,
								children: [
									FilledButton(
										onPressed: () {},
										child: const Padding(
											padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
											child: Text('Book a Consultation'),
										),
									),
									OutlinedButton(
										onPressed: () => scrollController.animateTo(0, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic),
										child: const Text('Back to Top'),
									),
								],
							)
						],
					),
				),
			),
		);
	}
}

class _ServicesScrollBehavior extends MaterialScrollBehavior {
	const _ServicesScrollBehavior();
	@override
	ScrollPhysics getScrollPhysics(BuildContext context) {
		// Desktop clamping; mobile bouncing for platform-consistent feel.
		final platform = getPlatform(context);
		if (platform == TargetPlatform.windows || platform == TargetPlatform.linux || platform == TargetPlatform.macOS) {
			return const ClampingScrollPhysics();
		}
		return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
	}
}

// Placeholder contact page for CTA (replace with real ContactPage if exists already imported elsewhere)
class ContactPagePlaceholder extends StatelessWidget {
	const ContactPagePlaceholder({super.key});
	@override
	Widget build(BuildContext context) => Scaffold(
				appBar: AppBar(title: const Text('Contact')),
				body: const Center(child: Text('Implement real contact page or route here.')),
			);
}

