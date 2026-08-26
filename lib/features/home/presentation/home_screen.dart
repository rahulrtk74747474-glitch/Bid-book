import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/core/theme/app_theme.dart';
import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:bid_book/features/media/data/media_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _categories = [
    ('AC Service', Icons.ac_unit),
    ('Plumber', Icons.plumbing),
    ('Electrician', Icons.electrical_services),
    ('Cleaning', Icons.cleaning_services),
    ('Appliance Repair', Icons.kitchen_outlined),
    ('Carpenter', Icons.carpenter),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(remoteAuthControllerProvider).asData?.value;
    final marketplace = ref.watch(remoteMarketplaceProvider);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(remoteMarketplaceProvider.notifier).refreshAll(),
        child: marketplace.when(
          loading: () => ListView(children: const [SizedBox(height: 280), Center(child: CircularProgressIndicator())]),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 120),
              const Icon(Icons.cloud_off_outlined, size: 52, color: AppColors.muted),
              const SizedBox(height: 12),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(remoteMarketplaceProvider), child: const Text('Retry')),
            ],
          ),
          data: (data) {
            final openRequests = data.requests.where((request) => request.status == ApiRequestStatus.bidding && request.createdByUserId != auth?.user?.id).take(4).toList();
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(18, MediaQuery.paddingOf(context).top + 14, 18, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.navyDeep, AppColors.navy, Color(0xFF0B4A8F)],
                    ),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Bid&Book', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 2),
                                Text('Hello, ${auth?.user?.bestName ?? 'there'}', style: const TextStyle(color: Color(0xFFD7E8FF), fontSize: 13)),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Notifications',
                            onPressed: () => context.push('/notifications'),
                            icon: const Icon(Icons.notifications_none),
                            style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.12), foregroundColor: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Find trusted help nearby', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, height: 1.15)),
                      const SizedBox(height: 8),
                      const Text('Book directly or post your work and let providers bid their best price.', style: TextStyle(color: Color(0xFFD7E8FF), height: 1.4)),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => context.push('/discover'),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: const Row(
                            children: [
                              Icon(Icons.search, color: AppColors.blue),
                              SizedBox(width: 10),
                              Expanded(child: Text('Search services, providers or jobs…', style: TextStyle(color: Color(0xFF98A2B3)))),
                              Icon(Icons.tune, color: AppColors.navy),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Wrap(
                        spacing: 9,
                        runSpacing: 8,
                        children: [
                          _HeaderTrust(icon: Icons.verified, text: 'Verified profiles'),
                          _HeaderTrust(icon: Icons.star, text: 'Ratings'),
                          _HeaderTrust(icon: Icons.gavel, text: 'Transparent bids'),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(title: 'Popular services', action: 'See all', onTap: () => context.push('/discover')),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 95,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final item = _categories[index];
                            return InkWell(
                              onTap: () => context.push('/discover'),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                width: 92,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: const Color(0xFFE5EAF2)),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(color: AppColors.blueSoft, borderRadius: BorderRadius.circular(12)),
                                      child: Icon(item.$2, color: AppColors.blue, size: 22),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(item.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFDCE5F2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(color: AppColors.orangeSoft, borderRadius: BorderRadius.circular(17)),
                              child: const Icon(Icons.gavel_outlined, color: AppColors.orange, size: 30),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Get the best price', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                  SizedBox(height: 4),
                                  Text('Post your work and let local providers bid for it.', style: TextStyle(color: AppColors.muted, height: 1.35)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: AppColors.orange, minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 13)),
                              onPressed: () => context.push('/requests/new'),
                              child: const Text('Post'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _SectionTitle(title: 'Open for bidding', action: 'See all', onTap: () => context.go('/requests')),
                      const SizedBox(height: 10),
                      if (openRequests.isEmpty)
                        const _SimpleEmpty(text: 'No open jobs are waiting for bids right now.')
                      else
                        ...openRequests.map((request) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _HomeRequestCard(request: request, hasProvider: data.provider != null),
                            )),
                      const SizedBox(height: 16),
                      _SectionTitle(title: 'Trusted services near you', action: 'Discover', onTap: () => context.push('/discover')),
                      const SizedBox(height: 10),
                      if (data.services.isEmpty)
                        const _SimpleEmpty(text: 'No providers have published services yet.')
                      else
                        SizedBox(
                          height: 260,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: data.services.take(12).length,
                            separatorBuilder: (_, _) => const SizedBox(width: 12),
                            itemBuilder: (context, index) => _ServiceCard(service: data.services[index], currency: currency),
                          ),
                        ),
                      const SizedBox(height: 24),
                      const _SectionTitle(title: 'More ways to use Bid&Book'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionTile(
                              icon: data.provider == null ? Icons.handyman_outlined : Icons.add_business_outlined,
                              title: data.provider == null ? 'Offer services' : 'Add service',
                              subtitle: data.provider == null ? 'Become a provider' : 'Publish your work',
                              color: AppColors.green,
                              onTap: () => context.push(data.provider == null ? '/provider/onboarding' : '/services/new'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionTile(
                              icon: Icons.groups_2_outlined,
                              title: 'Group buying',
                              subtitle: 'Buy together, negotiate better',
                              color: AppColors.purple,
                              onTap: () => context.push('/groups'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeRequestCard extends ConsumerWidget {
  const _HomeRequestCard({required this.request, required this.hasProvider});
  final ApiRequest request;
  final bool hasProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bids = ref.watch(remoteBidHistoryProvider(request.id)).asData?.value ?? const <ApiBid>[];
    final current = bids.where((bid) => bid.isCurrentOffer).toList();
    final lowest = current.isEmpty ? null : current.map((bid) => bid.amountPaise).reduce((a, b) => a < b ? a : b) / 100;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final photos = ref.watch(mediaGalleryProvider('request|${request.id}')).asData?.value ?? const <String>[];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/requests/${request.id}/bids'),
        child: Row(
          children: [
            SizedBox(
              width: 102,
              height: 128,
              child: photos.isNotEmpty
                  ? Image.network(photos.first, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _ImageFallback())
                  : const _ImageFallback(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text('${request.area} • ${request.category}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Text('${current.length} bid${current.length == 1 ? '' : 's'}', style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w800, fontSize: 12)),
                        const Spacer(),
                        if (lowest != null) Text('Low ${currency.format(lowest)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.navy)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.orange, minimumSize: const Size(0, 38), padding: EdgeInsets.zero),
                        onPressed: () => hasProvider ? context.push('/requests/${request.id}/bids') : context.push('/provider/onboarding'),
                        child: Text(hasProvider ? 'Bid ₹' : 'Become provider'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends ConsumerWidget {
  const _ServiceCard({required this.service, required this.currency});
  final ApiService service;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(mediaGalleryProvider('service|${service.id}')).asData?.value ?? const <String>[];
    return SizedBox(
      width: 210,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/services/${service.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 124,
                width: double.infinity,
                child: photos.isNotEmpty
                    ? Image.network(photos.first, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _ImageFallback())
                    : const _ImageFallback(),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(service.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900))),
                        const Icon(Icons.verified, size: 16, color: AppColors.green),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${service.category} • ${service.area}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                    const SizedBox(height: 9),
                    Text('From ${currency.format(service.priceRupees)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.navy)),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.star, size: 15, color: Color(0xFFF5A524)),
                        SizedBox(width: 4),
                        Text('Trusted provider', style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFEAF0F7),
        alignment: Alignment.center,
        child: const Icon(Icons.home_repair_service_outlined, size: 38, color: AppColors.blue),
      );
}

class _HeaderTrust extends StatelessWidget {
  const _HeaderTrust({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: const Color(0xFF8EE0B8)),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
          if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
        ],
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13)),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(height: 11),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
              ],
            ),
          ),
        ),
      );
}

class _SimpleEmpty extends StatelessWidget {
  const _SimpleEmpty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            const Icon(Icons.info_outline, color: AppColors.blue),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(color: AppColors.muted))),
          ]),
        ),
      );
}
