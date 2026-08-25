import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class BidHistoryScreen extends ConsumerStatefulWidget {
  const BidHistoryScreen({super.key, required this.requestId});
  final String requestId;

  @override
  ConsumerState<BidHistoryScreen> createState() => _BidHistoryScreenState();
}

class _BidHistoryScreenState extends ConsumerState<BidHistoryScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _submitting = false;
  String? _awardingBidId;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rupees = double.tryParse(_amount.text.trim());
    if (rupees == null || rupees <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid bid amount.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(remoteMarketplaceProvider.notifier).submitBid(
            requestId: widget.requestId,
            amountPaise: (rupees * 100).round(),
            note: _note.text.trim(),
          );
      _amount.clear();
      _note.clear();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _award(ApiBid bid) async {
    setState(() => _awardingBidId = bid.id);
    try {
      final booking = await ref.read(remoteMarketplaceProvider.notifier).awardBid(
            requestId: widget.requestId,
            bidId: bid.id,
          );
      if (mounted) context.go('/bookings/${booking.id}');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _awardingBidId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final marketplace = ref.watch(remoteMarketplaceProvider).asData?.value;
    final userId = ref.watch(remoteAuthControllerProvider).asData?.value.user?.id;
    ApiRequest? request;
    for (final item in marketplace?.requests ?? const <ApiRequest>[]) {
      if (item.id == widget.requestId) {
        request = item;
        break;
      }
    }
    final bids = ref.watch(remoteBidHistoryProvider(widget.requestId));
    final isOwner = request?.createdByUserId == userId;
    final canBid = marketplace?.provider != null && !isOwner && request?.status == ApiRequestStatus.bidding;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final date = DateFormat('dd MMM, h:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('Bid history')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (request != null) ...[
            Text(request.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${request.category} • ${request.area}'),
            const SizedBox(height: 8),
            Text(request.description),
            const SizedBox(height: 18),
          ],
          if (canBid) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Place or revise your bid', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Bid amount ₹'),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note / inclusions (optional)')),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: Text(_submitting ? 'Submitting…' : 'Submit bid'),
                    ),
                    const SizedBox(height: 8),
                    const Text('Rebidding always appends a new event. Your older prices remain permanently visible.', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text('Complete history', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          bids.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (error, _) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('$error'))),
            data: (items) {
              if (items.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No bids yet.')));
              return Column(
                children: items.map((bid) => Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Icon(bid.isRevision ? Icons.update : Icons.gavel_outlined)),
                        title: Row(
                          children: [
                            Expanded(child: Text(bid.providerLabel)),
                            Text(currency.format(bid.amountRupees), style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                        subtitle: Text(
                          '${bid.isRevision ? 'Revised bid' : 'Initial bid'} • ${date.format(bid.submittedAt)}\n${bid.note ?? 'No note'}',
                        ),
                        isThreeLine: true,
                        trailing: isOwner && bid.isCurrentOffer && request?.status == ApiRequestStatus.bidding
                            ? FilledButton(
                                onPressed: _awardingBidId == null ? () => _award(bid) : null,
                                child: Text(_awardingBidId == bid.id ? 'Accepting…' : 'Accept'),
                              )
                            : Icon(
                                bid.isCurrentOffer ? Icons.check_circle_outline : Icons.history,
                                semanticLabel: bid.isCurrentOffer ? 'Current offer' : 'Historical offer',
                              ),
                      ),
                    )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
