import 'package:bid_book/features/trust/application/remote_trust_controller.dart';
import 'package:bid_book/features/trust/domain/trust_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class TrustCenterScreen extends ConsumerWidget {
  const TrustCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trust = ref.watch(remoteTrustProvider);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trust & payments'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(remoteTrustProvider.notifier).refreshAll(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
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
                  onPressed: () => ref.invalidate(remoteTrustProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final verification = data.overview.latestVerification;
          return RefreshIndicator(
            onRefresh: () => ref.read(remoteTrustProvider.notifier).refreshAll(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              data.overview.identityVerified
                                  ? Icons.verified_user
                                  : Icons.verified_user_outlined,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                data.overview.identityVerified
                                    ? 'Identity verified'
                                    : 'Identity verification',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Bid&Book stores verification status and an opaque provider reference. It does not store your Aadhaar number, Aadhaar OTP, biometrics, or raw Aadhaar document in this flow.',
                        ),
                        if (verification != null) ...[
                          const SizedBox(height: 12),
                          Text('Latest: ${verification.method} • ${verification.status}'),
                        ],
                        const SizedBox(height: 14),
                        if (!data.overview.identityVerified &&
                            verification?.status != 'pending')
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: TrustVerificationMethod.values
                                .map(
                                  (method) => OutlinedButton(
                                    onPressed: () => _startVerification(
                                      context,
                                      ref,
                                      method,
                                    ),
                                    child: Text(method.label),
                                  ),
                                )
                                .toList(),
                          ),
                        if (kDebugMode && verification?.status == 'pending') ...[
                          const SizedBox(height: 10),
                          FilledButton.tonal(
                            onPressed: () async {
                              try {
                                await ref
                                    .read(remoteTrustProvider.notifier)
                                    .simulateVerify(verification!.id);
                              } catch (error) {
                                if (context.mounted) {
                                  _showError(context, ref, error);
                                }
                              }
                            },
                            child: const Text('Simulate verification (debug)'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _sectionTitle(context, 'Payments'),
                Text('${data.overview.paymentsCount} payment record(s)'),
                const SizedBox(height: 8),
                if (data.payments.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No booking payments yet.'),
                    ),
                  )
                else
                  ...data.payments.take(10).map(
                        (payment) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.payments_outlined),
                            title: Text(currency.format(payment.amountRupees)),
                            subtitle: Text(
                              '${payment.status} • ${payment.gateway}\nBooking ${_short(payment.bookingId)}',
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 18),
                _sectionTitle(context, 'Provider payouts'),
                Text('${data.overview.payoutsCount} payout record(s)'),
                const SizedBox(height: 8),
                if (data.payouts.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No provider payouts yet.'),
                    ),
                  )
                else
                  ...data.payouts.take(10).map(
                        (payout) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.account_balance_outlined),
                            title: Text(currency.format(payout.amountRupees)),
                            subtitle: Text(
                              payout.holdReason == null
                                  ? payout.status
                                  : '${payout.status}\n${payout.holdReason}',
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 18),
                _sectionTitle(context, 'Disputes'),
                Text('${data.overview.openDisputesCount} open dispute(s)'),
                const SizedBox(height: 8),
                if (data.disputes.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No disputes on your account.'),
                    ),
                  )
                else
                  ...data.disputes.take(10).map(
                        (dispute) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.gavel_outlined),
                            title: Text(dispute.category),
                            subtitle: Text(
                              '${dispute.status} • Booking ${_short(dispute.bookingId)}\n${dispute.summary}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _startVerification(
    BuildContext context,
    WidgetRef ref,
    TrustVerificationMethod method,
  ) async {
    try {
      await ref.read(remoteTrustProvider.notifier).startVerification(method);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${method.label} verification started.')),
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

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      );

  String _short(String value) =>
      value.length <= 8 ? value : value.substring(0, 8).toUpperCase();
}
