import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:bid_book/features/operations/application/remote_operations_controller.dart';
import 'package:bid_book/features/production/application/payment_checkout.dart';
import 'package:bid_book/features/trust/application/remote_trust_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class BookingTrustScreen extends ConsumerWidget {
  const BookingTrustScreen({required this.bookingId, super.key});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trust = ref.watch(bookingTrustProvider(bookingId));
    final auth = ref.watch(remoteAuthControllerProvider).asData?.value;
    final marketplace = ref.watch(remoteMarketplaceProvider).asData?.value;
    final booking = marketplace?.bookings.where((item) => item.id == bookingId).firstOrNull;
    final isCustomer = booking?.customerUserId == auth?.user?.id;
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
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _section(
                context,
                title: 'Booking payment',
                children: [
                  if (data.payment == null)
                    const Text('No payment intent has been created yet.')
                  else ...[
                    _row('Amount', currency.format(data.payment!.amountRupees)),
                    if (data.payment!.platformFeePaise > 0)
                      _row('Platform fee', currency.format(data.payment!.platformFeePaise / 100)),
                    _row('Status', data.payment!.status),
                    _row('Gateway', data.payment!.gateway),
                    if (data.payment!.refundedPaise > 0)
                      _row('Refunded', currency.format(data.payment!.refundedRupees)),
                  ],
                  if (data.canPay) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _run(
                        context,
                        ref,
                        () => ref.read(remoteTrustProvider.notifier).createPayment(bookingId),
                        'Secure payment order created.',
                      ),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Create secure payment'),
                    ),
                  ],
                  if (data.payment?.gateway == 'razorpay' && data.payment?.status == 'created') ...[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () => _checkout(context, ref, data.payment!),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Pay securely'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The app never marks its own checkout callback as captured. Bid&Book waits for the signed payment-provider webhook.',
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
              const SizedBox(height: 12),
              _section(
                context,
                title: 'Secure job handoff & payout',
                children: [
                  if (data.payout == null)
                    const Text('Payout record appears after payment capture.')
                  else ...[
                    _row('Payout', currency.format(data.payout!.amountRupees)),
                    _row('Payout status', data.payout!.status),
                    if (data.payout!.holdReason != null)
                      _row('Hold reason', data.payout!.holdReason!),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (isCustomer &&
                          booking?.status.name == 'confirmed' &&
                          ['captured', 'partially_refunded'].contains(data.payment?.status))
                        FilledButton.tonalIcon(
                          onPressed: () => _generateStartCode(context, ref),
                          icon: const Icon(Icons.pin_outlined),
                          label: const Text('Generate start code'),
                        ),
                      if (data.canStart)
                        FilledButton.icon(
                          onPressed: () => _startWithCode(context, ref),
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('Start with customer code'),
                        ),
                      if (!isCustomer && booking != null)
                        OutlinedButton.icon(
                          onPressed: () => context.push('/provider/team?bookingId=$bookingId'),
                          icon: const Icon(Icons.engineering_outlined),
                          label: const Text('Assign technician'),
                        ),
                      if (data.canComplete)
                        FilledButton.icon(
                          onPressed: () => _run(
                            context,
                            ref,
                            () => ref.read(remoteTrustProvider.notifier).completeBooking(bookingId),
                            'Booking completed. Eligible payout can proceed.',
                          ),
                          icon: const Icon(Icons.task_alt),
                          label: const Text('Confirm completion'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'The provider or explicitly assigned technician must enter the short-lived customer code before work can start.',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                context,
                title: 'Reviews, warranty & disputes',
                children: [
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
                      if (isCustomer && booking?.status.name == 'completed')
                        OutlinedButton.icon(
                          onPressed: () => _warrantyDialog(context, ref),
                          icon: const Icon(Icons.workspace_premium_outlined),
                          label: const Text('Warranty claim'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => _disputeDialog(context, ref),
                        icon: const Icon(Icons.gavel_outlined),
                        label: const Text('Open dispute'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push(
                          '/media?entityType=booking&entityId=$bookingId',
                        ),
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Job photos/evidence'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Amounts come from the server-side booking snapshot. The phone cannot lower the payment, increase a payout, overwrite bid history, or bypass the customer start code.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkout(BuildContext context, WidgetRef ref, payment) async {
    final auth = ref.read(remoteAuthControllerProvider).asData?.value;
    final checkout = PaymentCheckout();
    try {
      await checkout.open(
        payment: payment,
        customerName: auth?.user?.bestName,
        customerPhone: auth?.user?.phone,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checkout submitted. Confirming payment with the server…')),
      );
      for (var attempt = 0; attempt < 6; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        ref.invalidate(bookingTrustProvider(bookingId));
        final updated = await ref.read(bookingTrustProvider(bookingId).future);
        if (['captured', 'partially_refunded'].contains(updated.payment?.status)) break;
      }
    } catch (error) {
      if (context.mounted) _showError(context, ref, error);
    } finally {
      checkout.dispose();
    }
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(bookingTrustProvider(bookingId));
    await ref.read(bookingTrustProvider(bookingId).future);
  }

  Future<void> _generateStartCode(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref.read(remoteOperationsProvider.notifier).createStartCode(bookingId);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Provider start code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                result.code,
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 6),
              ),
              const SizedBox(height: 12),
              Text(
                'Expires ${DateFormat('h:mm a').format(result.expiresAt)}. Share it only when the provider or assigned technician is ready to start.',
              ),
            ],
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done')),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) _showOpsError(context, ref, error);
    }
  }

  Future<void> _startWithCode(BuildContext context, WidgetRef ref) async {
    final code = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter customer start code'),
        content: TextField(
          controller: code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          decoration: const InputDecoration(labelText: '6-digit code'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Start job')),
        ],
      ),
    );
    if (confirmed == true && code.text.trim().length == 6 && context.mounted) {
      await _run(
        context,
        ref,
        () => ref.read(remoteTrustProvider.notifier).startBooking(
              bookingId: bookingId,
              code: code.text.trim(),
            ),
        'Start code verified. Job is in progress.',
      );
    }
    code.dispose();
  }

  Future<void> _warrantyDialog(BuildContext context, WidgetRef ref) async {
    final issue = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Open warranty claim'),
        content: TextField(
          controller: issue,
          maxLines: 5,
          maxLength: 4000,
          decoration: const InputDecoration(labelText: 'What problem returned or remains?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit')),
        ],
      ),
    );
    if (submitted == true && issue.text.trim().length >= 5 && context.mounted) {
      try {
        await ref.read(remoteOperationsProvider.notifier).createWarrantyClaim(
              bookingId: bookingId,
              issue: issue.text.trim(),
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Warranty claim opened.')),
          );
        }
      } catch (error) {
        if (context.mounted) _showOpsError(context, ref, error);
      }
    }
    issue.dispose();
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
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit')),
          ],
        ),
      ),
    );
    if (submitted == true && context.mounted) {
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
      }
    }
    comment.dispose();
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
              TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
              const SizedBox(height: 10),
              TextField(
                controller: summary,
                maxLines: 4,
                maxLength: 4000,
                decoration: const InputDecoration(labelText: 'Describe the problem'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: refund,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Requested refund ₹ (0 if none)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Open dispute')),
        ],
      ),
    );
    if (submitted == true && context.mounted) {
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
      }
    }
    category.dispose();
    summary.dispose();
    refund.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (context.mounted) _showError(context, ref, error);
    }
  }

  void _showError(BuildContext context, WidgetRef ref, Object error) {
    final message = ref.read(remoteTrustProvider.notifier).friendlyError(error);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showOpsError(BuildContext context, WidgetRef ref, Object error) {
    final message = ref.read(remoteOperationsProvider.notifier).friendlyError(error);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );

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
