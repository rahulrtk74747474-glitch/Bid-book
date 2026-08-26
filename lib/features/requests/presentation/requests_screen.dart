import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/core/theme/app_theme.dart';
import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:bid_book/features/media/data/media_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketplace = ref.watch(remoteMarketplaceProvider);
    final userId = ref.watch(remoteAuthControllerProvider).asData?.value.user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Requests'),
            Text('Compare work. Compete on price.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.muted)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/requests/new'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Post request'),
      ),
      body: marketplace.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Error(error: error, onRetry: () => ref.invalidate(remoteMarketplaceProvider)),
        data: (data) {
          return RefreshIndicator(
            onRefresh: () => ref.read(remoteMarketplaceProvider.notifier).refreshAll(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.navyDeep, AppColors.navy]),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Open bidding marketplace', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                            SizedBox(height: 5),
                            Text('Providers enter their own price. Customers can compare every bid and rebid.', style: TextStyle(color: Color(0xFFD7E8FF), height: 1.35)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(17)),
                        child: const Icon(Icons.gavel_outlined, color: Colors.white, size: 30),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (data.requests.isEmpty)
                  const _Empty()
                else
                  ...data.requests.map((request) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RequestCard(
                          request: request,
                          mine: request.createdByUserId == userId,
                          hasProvider: data.provider != null,
                        ),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request, required this.mine, required this.hasProvider});
  final ApiRequest request;
  final bool mine;
  final bool hasProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bids = ref.watch(remoteBidHistoryProvider(request.id));
    final photos = ref.watch(mediaGalleryProvider('request|${request.id}'));
    final currentBids = bids.asData?.value.where((bid) => bid.isCurrentOffer).toList() ?? const <ApiBid>[];
    final lowest = currentBids.isEmpty
        ? null
        : currentBids.map((item) => item.amountPaise).reduce((a, b) => a < b ? a : b) / 100;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final date = DateFormat('dd MMM • h:mm a');
    final open = request.status == ApiRequestStatus.bidding;
    final photo = photos.asData?.value.isNotEmpty == true ? photos.asData!.value.first : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/requests/${request.id}/bids'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photo != null)
              Image.network(
                photo,
                width: double.infinity,
                height: 148,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Tag(
                        text: open ? 'OPEN FOR BIDDING' : request.status.name.toUpperCase(),
                        color: open ? AppColors.green : AppColors.muted,
                        background: open ? AppColors.greenSoft : const Color(0xFFF2F4F7),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 7),
                        const _Tag(text: 'YOUR REQUEST', color: AppColors.blue, background: AppColors.blueSoft),
                      ],
                    ],
                  ),
                  const SizedBox(height: 11),
                  Text(request.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(request.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, height: 1.35)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 7,
                    children: [
                      _Meta(icon: Icons.category_outlined, text: request.category),
                      _Meta(icon: Icons.location_on_outlined, text: request.area),
                      _Meta(icon: Icons.calendar_today_outlined, text: date.format(request.requestedFor)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Active bids', style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
                              const SizedBox(height: 2),
                              Text('${currentBids.length}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 34, color: const Color(0xFFE4E7EC)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Lowest current bid', style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
                              const SizedBox(height: 2),
                              Text(lowest == null ? 'No bids yet' : currency.format(lowest), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.navy)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),
                  if (open && !mine)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
                        onPressed: hasProvider
                            ? () => context.push('/requests/${request.id}/bids')
                            : () => context.push('/provider/onboarding'),
                        icon: Icon(hasProvider ? Icons.currency_rupee : Icons.handyman_outlined),
                        label: Text(hasProvider ? 'Bid ₹ — Enter your price' : 'Become a provider to bid'),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/requests/${request.id}/bids'),
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text(mine ? 'View & compare bids' : 'View bid history'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color, required this.background});
  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.3)),
      );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.muted),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
        ],
      );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              const Icon(Icons.request_quote_outlined, size: 48, color: AppColors.blue),
              const SizedBox(height: 12),
              const Text('No requests yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Post work and let providers compete with transparent prices.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => context.push('/requests/new'), child: const Text('Post your first request')),
            ],
          ),
        ),
      );
}

class _Error extends StatelessWidget {
  const _Error({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 44, color: AppColors.muted),
              const SizedBox(height: 10),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
