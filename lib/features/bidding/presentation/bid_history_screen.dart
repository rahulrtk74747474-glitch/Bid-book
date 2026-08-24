import 'package:bid_book/features/bidding/application/bid_history_controller.dart';
import 'package:bid_book/features/bidding/domain/bid_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class BidHistoryScreen extends ConsumerWidget {
  const BidHistoryScreen({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref
        .watch(bidHistoryProvider)
        .where((event) => event.requestId == requestId)
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Bid history')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
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
                      'Transparent bidding: every submitted price and every revision remains visible. Older bids are never replaced.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (events.isEmpty)
            const Center(child: Text('No bids yet.'))
          else
            ...events.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BidCard(event: event),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBidSheet(context, ref),
        icon: const Icon(Icons.gavel),
        label: const Text('Place / revise bid'),
      ),
    );
  }

  Future<void> _showBidSheet(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: '315');
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
              'Place revised bid',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Submitting a new price will add another history entry. Your old price will stay visible.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Price per unit',
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
          providerId: 'provider-coolcare',
          providerName: 'CoolCare Services',
          amountPaise: amount,
          rating: 4.8,
          completedJobs: 1240,
          identityVerified: true,
          note: 'Revised price submitted from the mobile app.',
        );
  }
}

class _BidCard extends StatelessWidget {
  const _BidCard({required this.event});

  final BidEvent event;

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
                CircleAvatar(
                  child: Text(event.providerName.substring(0, 1)),
                ),
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
          ],
        ),
      ),
    );
  }
}
