import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/core/theme/app_theme.dart';
import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:bid_book/features/media/data/media_api.dart';
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
    final rupees = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (rupees == null || rupees <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid bid price in ₹.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final bid = await ref.read(remoteMarketplaceProvider.notifier).submitBid(
            requestId: widget.requestId,
            amountPaise: (rupees * 100).round(),
            note: _note.text.trim(),
          );
      _amount.clear();
      _note.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bid.isRevision ? 'Revised bid added to permanent history.' : 'Bid submitted successfully.')),
        );
      }
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
    final photos = ref.watch(mediaGalleryProvider('request|${widget.requestId}'));
    final isOwner = request?.createdByUserId == userId;
    final canBid = marketplace?.provider != null && !isOwner && request?.status == ApiRequestStatus.bidding;
    final noProvider = marketplace?.provider == null && !isOwner && request?.status == ApiRequestStatus.bidding;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final date = DateFormat('dd MMM • h:mm a');

    return Scaffold(
      appBar: AppBar(title: Text(isOwner ? 'Compare bids' : 'Bid on request')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
        children: [
          if (request != null) ...[
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photos.asData?.value.isNotEmpty == true)
                    SizedBox(
                      height: 180,
                      child: PageView.builder(
                        itemCount: photos.asData!.value.length,
                        itemBuilder: (context, index) => Image.network(
                          photos.asData!.value[index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFEFF3F8)),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(17),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(999)),
                              child: const Text('OPEN FOR BIDDING', style: TextStyle(color: AppColors.green, fontSize: 10.5, fontWeight: FontWeight.w900)),
                            ),
                            if (request.groupId != null) ...[
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(color: const Color(0xFFF1EBFF), borderRadius: BorderRadius.circular(999)),
                                child: const Text('GROUP REQUEST', style: TextStyle(color: AppColors.purple, fontSize: 10.5, fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 11),
                        Text(request.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(request.description, style: const TextStyle(color: AppColors.muted, height: 1.42)),
                        const SizedBox(height: 13),
                        Wrap(
                          spacing: 12,
                          runSpacing: 7,
                          children: [
                            _Meta(icon: Icons.category_outlined, text: request.category),
                            _Meta(icon: Icons.location_on_outlined, text: request.area),
                            _Meta(icon: Icons.calendar_today_outlined, text: date.format(request.requestedFor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (canBid) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFFFCAA8), width: 1.3),
                boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 7))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.orangeSoft,
                        child: Icon(Icons.currency_rupee, color: AppColors.orange),
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('YOUR BID PRICE', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                            SizedBox(height: 2),
                            Text('Enter the amount you will do this job for.', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: AppColors.navy),
                    decoration: const InputDecoration(
                      labelText: 'Bid amount',
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: AppColors.navy),
                      hintText: '650',
                    ),
                  ),
                  const SizedBox(height: 11),
                  TextField(
                    controller: _note,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'What does your price include?',
                      hintText: 'Labour, materials, visit charges, warranty…',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
                    onPressed: _submitting ? null : _submit,
                    icon: const Icon(Icons.gavel),
                    label: Text(_submitting ? 'Submitting bid…' : 'Submit bid ₹'),
                  ),
                  const SizedBox(height: 9),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.history, size: 17, color: AppColors.green),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'If you bid again, the new price is added as a new event. Your older bid is never overwritten or deleted.',
                          style: TextStyle(color: AppColors.muted, fontSize: 11.8, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else if (noProvider) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  children: [
                    const Icon(Icons.handyman_outlined, color: AppColors.blue, size: 38),
                    const SizedBox(height: 9),
                    const Text('Want to bid your price?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    const Text('Create your provider profile first. The same Bid&Book account can both book work and offer services.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 13),
                    FilledButton(onPressed: () => context.push('/provider/onboarding'), child: const Text('Become a provider')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  isOwner ? 'Provider offers' : 'Transparent bid history',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
              ),
              bids.asData != null
                  ? Text('${bids.asData!.value.length} event${bids.asData!.value.length == 1 ? '' : 's'}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600))
                  : const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 9),
          bids.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (error, _) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('$error'))),
            data: (items) {
              if (items.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Icon(Icons.gavel_outlined, size: 38, color: AppColors.muted),
                        SizedBox(height: 8),
                        Text('No bids yet', style: TextStyle(fontWeight: FontWeight.w800)),
                        SizedBox(height: 3),
                        Text('The first provider bid will appear here.', style: TextStyle(color: AppColors.muted)),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: items.map((bid) {
                  final historical = !bid.isCurrentOffer;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: historical ? const Color(0xFFF2F4F7) : AppColors.blueSoft,
                              child: Icon(historical ? Icons.history : Icons.handyman_outlined, color: historical ? AppColors.muted : AppColors.blue),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(bid.providerLabel, style: const TextStyle(fontWeight: FontWeight.w800))),
                                      Text(currency.format(bid.amountRupees), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: historical ? AppColors.muted : AppColors.navy)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${bid.isRevision ? 'Revised bid' : 'Initial bid'} • ${date.format(bid.submittedAt)}',
                                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                  ),
                                  if (bid.note?.trim().isNotEmpty == true) ...[
                                    const SizedBox(height: 7),
                                    Text(bid.note!, style: const TextStyle(height: 1.35)),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(bid.isCurrentOffer ? Icons.check_circle : Icons.lock_clock_outlined, size: 16, color: bid.isCurrentOffer ? AppColors.green : AppColors.muted),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          bid.isCurrentOffer ? 'Current offer — eligible for acceptance' : 'Historical offer — permanently retained',
                                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: bid.isCurrentOffer ? AppColors.green : AppColors.muted),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isOwner && bid.isCurrentOffer && request?.status == ApiRequestStatus.bidding) ...[
                                    const SizedBox(height: 11),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _awardingBidId == null ? () => _award(bid) : null,
                                        icon: const Icon(Icons.check_circle_outline),
                                        label: Text(_awardingBidId == bid.id ? 'Accepting…' : 'Accept ${currency.format(bid.amountRupees)} bid'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
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
          Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      );
}
