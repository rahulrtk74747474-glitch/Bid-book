import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/core/theme/app_theme.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:bid_book/features/media/data/media_api.dart';
import 'package:bid_book/features/trust/application/remote_trust_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ServiceDetailScreen extends ConsumerStatefulWidget {
  const ServiceDetailScreen({super.key, required this.listingId});
  final String listingId;

  @override
  ConsumerState<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen> {
  DateTime _scheduledFor = DateTime.now().add(const Duration(days: 1));
  bool _booking = false;

  Future<void> _book(ApiService service) async {
    setState(() => _booking = true);
    try {
      final booking = await ref.read(remoteMarketplaceProvider.notifier).directBook(
            listingId: service.id,
            scheduledFor: _scheduledFor,
            area: service.area,
          );
      if (mounted) context.go('/bookings/${booking.id}');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _scheduledFor,
    );
    if (selected == null || !mounted) return;
    setState(() => _scheduledFor = DateTime(selected.year, selected.month, selected.day, 10));
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(remoteMarketplaceProvider).asData?.value;
    ApiService? service;
    for (final item in data?.services ?? const <ApiService>[]) {
      if (item.id == widget.listingId) {
        service = item;
        break;
      }
    }
    if (service == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Service')),
        body: const Center(child: Text('Service not found. Pull Home to refresh.')),
      );
    }

    final item = service;
    final isOwnProvider = data?.provider?.id == item.providerId;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final reviews = ref.watch(providerReviewSummaryProvider(item.providerId));
    final photos = ref.watch(mediaGalleryProvider('service|${item.id}'));

    return Scaffold(
      appBar: AppBar(title: const Text('Service details')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE4E7EC))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Starting at', style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
                    Text(currency.format(item.priceRupees), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.navy)),
                  ],
                ),
              ),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isOwnProvider || _booking ? null : () => _book(item),
                  icon: const Icon(Icons.book_online_outlined),
                  label: Text(isOwnProvider ? 'Your listing' : _booking ? 'Booking…' : 'Book service'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          photos.when(
            loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
            error: (_, _) => const _HeroFallback(),
            data: (items) {
              if (items.isEmpty) return const _HeroFallback();
              return SizedBox(
                height: 240,
                child: Stack(
                  children: [
                    PageView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) => Image.network(
                        items[index],
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _HeroFallback(),
                      ),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                        child: Text('${items.length} photo${items.length == 1 ? '' : 's'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.15))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(999)),
                      child: const Row(
                        children: [
                          Icon(Icons.verified, size: 15, color: AppColors.green),
                          SizedBox(width: 4),
                          Text('Trusted', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 11.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 17, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Expanded(child: Text('${item.category} • ${item.area}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600))),
                  ],
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.blueSoft,
                              child: Icon(Icons.handyman_outlined, color: AppColors.blue),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Flexible(child: Text(item.providerLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                                    const SizedBox(width: 5),
                                    const Icon(Icons.verified, size: 16, color: AppColors.green),
                                  ]),
                                  const SizedBox(height: 4),
                                  reviews.when(
                                    data: (summary) => Row(
                                      children: [
                                        const Icon(Icons.star, color: Color(0xFFF5A524), size: 17),
                                        const SizedBox(width: 4),
                                        Text(
                                          summary.count == 0
                                              ? 'New provider • No reviews yet'
                                              : '${summary.averageRating?.toStringAsFixed(1) ?? '—'} • ${summary.count} completed-job review${summary.count == 1 ? '' : 's'}',
                                          style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    loading: () => const Text('Loading provider rating…', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                                    error: (_, _) => const Text('Provider profile', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Row(
                          children: [
                            Expanded(child: _TrustStat(icon: Icons.verified_user_outlined, label: 'Profile', value: 'Checked')),
                            Expanded(child: _TrustStat(icon: Icons.shield_outlined, label: 'Booking', value: 'Protected')),
                            Expanded(child: _TrustStat(icon: Icons.rate_review_outlined, label: 'Reviews', value: 'Job-linked')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('About this service', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(item.description, style: const TextStyle(height: 1.5, color: AppColors.ink)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PRICE', style: TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 5),
                              Text(currency.format(item.priceRupees), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.navy)),
                              Text(item.pricingUnit.label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Card(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(22),
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('BOOKING DATE', style: TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 5),
                                Text(DateFormat('dd MMM').format(_scheduledFor), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.navy)),
                                const Text('Tap to change', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: AppColors.blueSoft, borderRadius: BorderRadius.circular(16)),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: AppColors.blue, size: 20),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Prefer providers to compete on price? Post a request instead and compare transparent bids before booking.',
                          style: TextStyle(color: AppColors.navy, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/requests/new'),
                    icon: const Icon(Icons.gavel_outlined),
                    label: const Text('Post a request for competitive bids'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        height: 220,
        color: const Color(0xFFE9EFF7),
        alignment: Alignment.center,
        child: const Icon(Icons.home_repair_service_outlined, size: 70, color: AppColors.blue),
      );
}

class _TrustStat extends StatelessWidget {
  const _TrustStat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: AppColors.green, size: 20),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
        ],
      );
}
