import 'package:flutter/material.dart';
import 'retail_playbook_card.dart';

class RetailPlaybookLanding extends StatelessWidget {
  const RetailPlaybookLanding({super.key, this.onPrimary, this.onSecondary});
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: RetailPlaybookCard(
            title: 'Retail Growth Playbook',
            subtitle: 'We streamline billing, inventory, and promotions for shops of all sizes.',
            bullets: const [
              BulletItem(text: 'Persona packs (walk-in shoppers, repeat buyers)', icon: Icons.person_outline),
              BulletItem(text: 'Website sections that sell (POS + offers)', icon: Icons.point_of_sale_outlined),
              BulletItem(text: 'Promotions & loyalty SOPs', icon: Icons.campaign_outlined),
              BulletItem(text: 'Retail KPIs (footfall, conversion, basket size)', icon: Icons.show_chart),
            ],
            onPrimaryTap: onPrimary ?? () {},
            onSecondaryTap: onSecondary ?? () {},
          ),
        ),
      ),
    );
  }
}