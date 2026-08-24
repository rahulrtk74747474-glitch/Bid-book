import 'package:bid_book/features/auth/application/auth_controller.dart';
import 'package:bid_book/features/bidding/application/bid_history_controller.dart';
import 'package:bid_book/features/bidding/domain/bid_event.dart';
import 'package:bid_book/features/marketplace/application/marketplace_actions.dart';
import 'package:bid_book/features/provider/application/provider_profile_controller.dart';
import 'package:bid_book/features/requests/application/request_controller.dart';
import 'package:bid_book/features/requests/domain/service_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class BidHistoryScreen extends ConsumerWidget {
  const BidHistoryScreen({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final profile = ref.watch(providerProfileProvider);
    final requests = ref.watch(serviceRequestsProvider);
    ServiceRequest? request;
    for (final item in requests) {
      if (item.id == requestId) {
        request = item;
        break;
      }
    }
    if (request == null) {
      return const Scaffold(body: Center(child: Text('Request not found.')));
    }

    final events = ref
        .watch(bidHistoryProvider)
        .where((event) => event.requestId == requestId)
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    final latestBidIds = <String>{};
    final seenProviders = <String>{};
    for (final event in events) {
      if (seenProviders.add(event.providerId)) latestBidIds.add(event.id);
    }

    final isOwner = user?.id == request.createdByUserId;
    final biddingOpen = request.status == ServiceRequestStatus.bidding;
    final canBid =
        user != null && profile != null && !isOwner && biddingOpen;

    return Scaffold(
      appBar: AppBar(title: const Text('Bid history')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          Text(
            request.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text('${request.area} • ${DateFormat('d MMM, h:mm a').format(request.requestedFor)}'),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.visibility_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Every submitted price and every revision remains visible. Only each provider’s latest offer can be accepted; older offers stay as history.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (request.status == ServiceRequestStatus.booked) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Booking confirmed'),
                subtitle: Text('Accepted bid event: ${request.acceptedBidEventId}'),
                onTap: request.bookingId == null
                    ? null
                    : () => context.go('/bookings/${request.bookingId}'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (events.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No bids yet. Providers can bid while this request is open.'),
            ))
          else
            ...events.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BidCard(
                  event: event,
                  isCurrentOffer: latestBidIds.contains(event.id),
                  isAccepted: request!.acceptedBidEventId == event.id,
                  canAccept: isOwner &&
                      biddingOpen &&
                      latestBidIds.contains(event.id),
                  onAccept: () => _acceptBid(context, ref, event),
                ),
              ),
            ),
          if (!isOwner && profile == null && biddingOpen) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.go('/provider/onboarding'),
              icon: const Icon(Icons.handyman_outlined),
              label: const Text('Set up provider profile to bid'),
            ),
          ],
        ],
      ),
      floatingActionButton: canBid
          ? FloatingActionButton.extended(
              onPressed: () => _showBidSheet(context, ref),
              icon: const Icon(Icons.gavel),
              label: const Text('Place / revise bid'),
            )
          : null,
    );
  }

  Future<void> _showBidSheet(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(providerProfileProvider);
    if (profile == null) return;
    final controller = TextEditingController();
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Place or revise bid',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'A new price creates another permanent history entry. Your previous price remains visible.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Bid amount',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                final rupees = int.tryParse(controller.text.trim());
                if (rupees != null && rupees > 0) {
                  Navigator.pop(context, rupees * 100);
                }
              },
              child: const Text('Submit bid'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (amount == null) return;

    ref.read(bidHistoryProvider.notifier).submitBid(
          requestId: requestId,
          providerId: profile.id,
          providerName: profile.displayName,
          amountPaise: amount,
          rating: profile.rating,
          completedJobs: profile.completedJobs,
          identityVerified: profile.identityVerified,
          note: 'Submitted from the Bid&Book mobile app.',
        );
  }

  void _acceptBid(BuildContext context, WidgetRef ref, BidEvent event) {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    try {
      final booking = ref.read(marketplaceActionsProvider.notifier).acceptBid(
            requestId: requestId,
            bidEventId: event.id,
            customerUserId: user.id,
          );
      context.go('/bookings/${booking.id}');
    } on StateError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }
}

class _BidCard extends StatelessWidget {
  const _BidCard({
    required this.event,
    required this.isCurrentOffer,
    required this.isAccepted,
    required this.canAccept,
    required this.onAccept,
  });

  final BidEvent event;
  final bool isCurrentOffer;
  final bool isAccepted;
  final bool canAccept;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final isRevision = event.type == BidEventType.revisedBid;
    final submittedLocal = event.submittedAt.toLocal();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(event.providerName.substring(0, 1))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              event.providerName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (event.identityVerified) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.verified, size: 17),
                          ],
                        ],
                      ),
                      Text('★ ${event.rating} • ${event.completedJobs} jobs'),
                    ],
                  ),
                ),
                Text(
                  '₹${NumberFormat.decimalPattern('en_IN').format(event.amountRupees.round())}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(label: Text(isRevision ? 'Revised bid' : 'Initial bid')),
                Chip(label: Text(isCurrentOffer ? 'Current offer' : 'Historical')),
                if (isAccepted)
                  const Chip(
                    avatar: Icon(Icons.check, size: 16),
                    label: Text('Accepted'),
                  ),
                Text(DateFormat('d MMM • h:mm a').format(submittedLocal)),
              ],
            ),
            if (event.note != null) ...[
              const SizedBox(height: 8),
              Text(event.note!),
            ],
            if (event.previousBidEventId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Previous bid retained in history',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
            if (canAccept) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Accept this current offer'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
