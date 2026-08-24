import 'package:bid_book/features/auth/application/auth_controller.dart';
import 'package:bid_book/features/services/application/service_catalog_controller.dart';
import 'package:bid_book/features/services/domain/service_listing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _services = [
    ('AC Service', Icons.ac_unit),
    ('Electrician', Icons.electrical_services),
    ('Plumber', Icons.plumbing),
    ('Cleaning', Icons.cleaning_services),
    ('Carpenter', Icons.carpenter),
    ('Labour', Icons.engineering),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(authControllerProvider).user?.id;
    final listings = ref
        .watch(serviceCatalogProvider)
        .where((item) => item.active && item.ownerUserId != currentUserId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bid&Book'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'Book trusted local work.\nOr let providers bid for it.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
          ),
          const SizedBox(height: 18),
          TextField(
            readOnly: true,
            decoration: const InputDecoration(
              hintText: 'What service do you need?',
              prefixIcon: Icon(Icons.search),
              suffixIcon: Icon(Icons.tune),
            ),
            onTap: () => context.go('/requests'),
          ),
          const SizedBox(height: 24),
          Text('Popular services', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _services.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: .98,
            ),
            itemBuilder: (context, index) {
              final item = _services[index];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => context.go('/requests'),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.$2, size: 30),
                        const SizedBox(height: 10),
                        Text(item.$1, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Services near you',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/requests'),
                child: const Text('Requests'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...listings.take(4).map(
                (listing) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                listing.title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (listing.identityVerified)
                              const Icon(Icons.verified, size: 18),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text('${listing.providerName} • ${listing.area}'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '₹${NumberFormat.decimalPattern('en_IN').format(listing.priceRupees.round())} • ${listing.pricingUnit.label}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            FilledButton(
                              onPressed: () => context.go('/services/${listing.id}'),
                              child: const Text('Book'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.campaign_outlined,
            title: 'Post a request',
            subtitle: 'Describe the job and compare transparent bids.',
            onTap: () => context.go('/requests/new'),
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.groups_outlined,
            title: 'Neighborhood group buying',
            subtitle: 'Combine demand, vote, then invite providers to bid.',
            onTap: () => context.go('/groups'),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(radius: 27, child: Icon(icon)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward),
            ],
          ),
        ),
      ),
    );
  }
}
