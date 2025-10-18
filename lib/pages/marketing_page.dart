import 'package:flutter/material.dart';
import '../sections/layout/site_scaffold.dart';
import '../sections/services/page_background.dart';
import '../sections/services/marketing/pamphlet_hero_section.dart';
import '../sections/services/marketing/hoardings_hero_section.dart';
import '../sections/services/marketing/reels_hero_section.dart';
import '../sections/services/marketing/promotional_videos_hero_section.dart';
import '../sections/services/marketing/gmb_hero_section.dart';
import '../sections/services/marketing/channel_growth_hero_section.dart';
import '../sections/services/marketing/whatsapp_marketing_hero_section.dart';
import '../sections/services/marketing/google_ads_hero_section.dart';
// Navigation between services now handled by global header; no per-page imports needed

class MarketingPage extends StatefulWidget {
  const MarketingPage({super.key});

  @override
  State<MarketingPage> createState() => _MarketingPageState();
}

class _MarketingPageState extends State<MarketingPage> {
  final _pamphletKey = GlobalKey();
  final _hoardingsKey = GlobalKey();
  final _reelsKey = GlobalKey();
  final _videosKey = GlobalKey();
  final _gmbKey = GlobalKey();
  final _channelsKey = GlobalKey();
  final _whatsappKey = GlobalKey();
  final _adsKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(arg));
    }
  }

  void _scrollTo(String id) {
    final l = id.toLowerCase();
    GlobalKey? key;
    if (l.contains('pamphlet')) {
      key = _pamphletKey;
    } else if (l.contains('hoard')) {
      key = _hoardingsKey;
    } else if (l.contains('reel')) {
      key = _reelsKey;
    } else if (l.contains('promo') || l.contains('video')) {
      key = _videosKey;
    } else if (l.contains('gmb') || l.contains('google my business')) {
      key = _gmbKey;
    } else if (l.contains('fb') || l.contains('insta') || l.contains('youtube') || l.contains('x') || l.contains('linkedin')) {
      key = _channelsKey;
    } else if (l.contains('whatsapp')) {
      key = _whatsappKey;
    } else if (l.contains('ads')) {
      key = _adsKey;
    }
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic, alignment: 0.05);
    }
  }
  // Removed per-page services nav; site-wide header handles navigation

  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      body: PageBackground(
        child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(key: _pamphletKey, child: const PamphletHeroSection()),
                  const SizedBox(height: 24),
                  Container(key: _hoardingsKey, child: const HoardingsHeroSection()),
                  const SizedBox(height: 24),
                  Container(key: _reelsKey, child: const ReelsHeroSection()),
                  const SizedBox(height: 24),
                  Container(key: _videosKey, child: const PromotionalVideosHeroSection()),
                  const SizedBox(height: 24),
                  Container(key: _gmbKey, child: const GmbHeroSection()),
                  const SizedBox(height: 24),
                  Container(key: _channelsKey, child: const ChannelGrowthHeroSection()),
                  const SizedBox(height: 24),
                  Container(key: _whatsappKey, child: const WhatsAppMarketingHeroSection()),
                  const SizedBox(height: 32),
                  Container(key: _adsKey, child: const GoogleAdsHeroSection()),
                ],
              ),
        ),
      ),
    );
  }
}

