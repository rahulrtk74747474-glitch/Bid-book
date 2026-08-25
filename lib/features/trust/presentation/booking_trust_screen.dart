import 'package:bid_book/features/trust/application/remote_trust_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class BookingTrustScreen extends ConsumerWidget {
  const BookingTrustScreen({required this.bookingId, super.key});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trust = ref.watch(bookingTrustProvider(bookingId));
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Scaffold(
      appBar: AppBar(title: const Text('Payment & trust')),
      body: trust.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$error', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(bookingTrustProvider(bookingId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(bookingTrustProvider(bookingId));
            await ref.read(bookingTrustProvider(bookingId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking payment',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      if (data.payment == null)
                        const Text('No payment intent has been created yet.')
                      else ...[
                        _row('Amount', currency.format(data.payment!.amountRupees)),
                        _row('Status', data.payment!.status),
                        _row('Gateway', data.payment!.gateway),
                        if (data.payment!.refundedPaise > 0)
                          _row(
                            'Refunded',
                            currency.format(data.payment!.refundedRupees),
                          ),
                      ],
                      if (data.canPay) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _run(
                            context,
                            ref,
                            () => ref
                                .read(remoteTrustProvider.notifier)
                                .createPayment(bookingId),
                            'Payment intent created.',
                          ),
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('Create payment'),
                        ),
                      ],
                      if (kDebugMode &&
                          data.payment?.status == 'created' &&
                          data.payment?.gateway == 'development') ...[
                        const SizedBox(height: 10),
                        FilledButton.tonalIcon(
                          onPressed: () => _run(
                            context,
                            ref,
                            () => ref
                                .read(remoteTrustProvider.notifier)
                                .simulateCapture(bookingId, data.payment!.id),
                            'Development payment captured.',
                          ),
                          icon: const Icon(Icons.developer_mode),
                          label: const Text('Simulate payment capture'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Job & payout',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      if (data.payout == null)
                        const Text('Payout record appears after payment capture.')
                      else ...[
                        _row('Payout', currency.format(data.payout!.amountRupees)),
                        _row('Payout status', data.payout!.status),
                        if (data.payout!.holdReason != null)
                          _row('Hold reason', data.payout!.holdReason!),
                      ],
                      const SizedBox(height: 12),
                      if (data.canStart)
                        FilledButton.icon(
                          onPressed: () => _run(
                            context,
                            ref,
                            () => ref
                                .read(remoteTrustProvider.notifier)
                                .startBooking(bookingId),
                            'Job marked in progress.',
                          ),
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('Start job'),
                        ),
                      if (data.canComplete)
                        FilledButton.icon(
                          onPressed: () => _run(
                            context,
                            ref,
                            () => ref
                                .read(remoteTrustProvider.notifier)
                                .completeBooking(bookingId),
                            'Booking completed. Eligible payout can proceed.',
                          ),
                          icon: const Icon(Icons.task_alt),
                          label: const Text('Confirm completion'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reviews & disputes',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text('${data.openDisputeCount} open dispute(s) on this booking.'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (data.canReview)
                            OutlinedButton.icon(
                              onPressed: () => _reviewDialog(context, ref),
                              icon: const Icon(Icons.star_outline),
                              label: const Text('Write review'),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => _disputeDialog(context, ref),
                            icon: const Icon(Icons.gavel_outlined),
                            label: const Text('Open dispute'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Payment and payout amounts come from the server-side booking snapshot. A client cannot lower the booking payment or increase the provider payout. Open disputes hold unpaid payouts for review.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reviewDialog(BuildContext context, WidgetRef ref) async {
    var rating = 5;
    final comment = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Review booking participant'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: rating,
                decoration: const InputDecoration(labelText: 'Rating'),
                items: [5, 4, 3, 2, 1]
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value star${value == 1 ? '' : 's'}'),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => rating = value ?? 5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: comment,
                maxLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(labelText: 'Comment (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true || !context.mounted) {
      comment.dispose();
      return;
    }
    try {
      await ref.read(remoteTrustProvider.notifier).createReview(
            bookingId: bookingId,
            rating: rating,
            comment: comment.text,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted.')),
        );
      }
    } catch (error) {
      if (context.mounted) _showError(context, ref, error);
    } finally {
      comment.dispose();
    }
  }

  Future<void> _disputeDialog(BuildContext context, WidgetRef ref) async {
    final category = TextEditingController(text: 'quality');
    final summary = TextEditingController();
    final refund = TextEditingController(text: '0');
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Open dispute'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: category,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: summary,
                maxLines: 4,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Describe the problem',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: refund,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Requested refund ₹ (0 if none)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Open dispute'),
          ),
        ],
      ),
    );
    if (submitted != true || !context.mounted) {
      category.dispose();
      summary.dispose();
      refund.dispose();
      return;
    }
    final rupees = int.tryParse(refund.text.trim()) ?? 0;
    try {
      await ref.read(remoteTrustProvider.notifier).openDispute(
            bookingId: bookingId,
            category: category.text.trim(),
            summary: summary.text.trim(),
            requestedRefundPaise: rupees * 100,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispute opened. Unpaid payout is held for review.')),
        );
      }
    } catch (error) {
      if (context.mounted) _showError(context, ref, error);
    } finally {
      category.dispose();
      summary.dispose();
      refund.dispose();
    }
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String success,
  ) async {
    try {
      await action();
      if (context.mounted) {
        ref.invalidate(bookingTrustProvider(bookingId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success)),
        );
      }
    } catch (error) {
      if (context.mounted) _showError(context, ref, error);
    }
  }

  void _showError(BuildContext context, WidgetRef ref, Object error) {
    final message = ref.read(remoteTrustProvider.notifier).friendlyError(error);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}
