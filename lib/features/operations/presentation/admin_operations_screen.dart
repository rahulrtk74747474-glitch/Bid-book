import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/features/operations/data/operations_api.dart';
import 'package:bid_book/features/operations/domain/operations_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AdminOperationsScreen extends ConsumerStatefulWidget {
  const AdminOperationsScreen({super.key});

  @override
  ConsumerState<AdminOperationsScreen> createState() =>
      _AdminOperationsScreenState();
}

class _AdminOperationsScreenState
    extends ConsumerState<AdminOperationsScreen> {
  bool _loading = true;
  Object? _error;
  AdminOverviewModel? _overview;
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _verifications = const [];
  List<Map<String, dynamic>> _disputes = const [];
  List<Map<String, dynamic>> _payouts = const [];
  List<Map<String, dynamic>> _risks = const [];
  List<Map<String, dynamic>> _reports = const [];
  List<Map<String, dynamic>> _support = const [];
  List<Map<String, dynamic>> _warranty = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = ref.read(operationsApiProvider);
    try {
      final overview = await api.adminOverview();
      final results = await Future.wait<Object>([
        api.adminUsers(),
        api.adminVerifications(),
        api.adminDisputes(),
        api.adminPayouts(),
        api.adminRisks(),
        api.adminReports(),
        api.adminSupportCases(),
        api.adminWarrantyClaims(),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _users = results[0] as List<Map<String, dynamic>>;
        _verifications = results[1] as List<Map<String, dynamic>>;
        _disputes = results[2] as List<Map<String, dynamic>>;
        _payouts = results[3] as List<Map<String, dynamic>>;
        _risks = results[4] as List<Map<String, dynamic>>;
        _reports = results[5] as List<Map<String, dynamic>>;
        _support = results[6] as List<Map<String, dynamic>>;
        _warranty = results[7] as List<Map<String, dynamic>>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin operations'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      if (_overview != null) ...[
                        Text('Marketplace health', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _metric('Users', '${_overview!.users}'),
                            _metric('Providers', '${_overview!.providers}'),
                            _metric('Services', '${_overview!.activeServices}'),
                            _metric('Bookings', '${_overview!.bookings}'),
                            _metric('Completed', '${_overview!.completedBookings}'),
                            _metric('GMV', currency.format(_overview!.capturedGmvPaise / 100)),
                            _metric('Open disputes', '${_overview!.openDisputes}'),
                            _metric('Reports', '${_overview!.openReports}'),
                            _metric('Support', '${_overview!.openSupportCases}'),
                            _metric('Risk signals', '${_overview!.openRiskSignals}'),
                            _metric('Verifications', '${_overview!.pendingVerifications}'),
                            _metric('Payout queue', '${_overview!.pendingPayouts}'),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      _section(
                        'Verification queue',
                        _verifications.where((item) => item['status'] == 'pending').map((item) => ListTile(
                              leading: const Icon(Icons.verified_user_outlined),
                              title: Text('${item['method'] ?? 'verification'}'),
                              subtitle: Text('User ${_short(item['user_id'])}'),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: 'Approve',
                                    onPressed: () => _verification(item, 'verified'),
                                    icon: const Icon(Icons.check_circle_outline),
                                  ),
                                  IconButton(
                                    tooltip: 'Reject',
                                    onPressed: () => _verification(item, 'rejected'),
                                    icon: const Icon(Icons.cancel_outlined),
                                  ),
                                ],
                              ),
                            )),
                      ),
                      _section(
                        'Payout queue',
                        _payouts.where((item) => ['eligible', 'held', 'pending'].contains(item['status'])).map((item) => ListTile(
                              leading: const Icon(Icons.account_balance_wallet_outlined),
                              title: Text(currency.format(((item['amount_paise'] as num?)?.toDouble() ?? 0) / 100)),
                              subtitle: Text('Status: ${item['status']}'),
                              trailing: item['status'] == 'eligible'
                                  ? FilledButton.tonal(onPressed: () => _payout(item, 'paid'), child: const Text('Pay'))
                                  : item['status'] == 'held'
                                      ? const Chip(label: Text('Held'))
                                      : IconButton(onPressed: () => _payout(item, 'held'), icon: const Icon(Icons.pause_circle_outline)),
                            )),
                      ),
                      _section(
                        'Disputes',
                        _disputes.where((item) => ['open', 'under_review'].contains(item['status'])).map((item) => ListTile(
                              leading: const Icon(Icons.gavel_outlined),
                              title: Text('${item['category'] ?? 'Dispute'}'),
                              subtitle: Text('${item['summary'] ?? ''}'),
                              trailing: FilledButton.tonal(
                                onPressed: () => _resolveDispute(item),
                                child: const Text('Resolve'),
                              ),
                            )),
                      ),
                      _section(
                        'Safety reports',
                        _reports.where((item) => ['open', 'reviewing'].contains(item['status'])).map((item) => ListTile(
                              leading: const Icon(Icons.flag_outlined),
                              title: Text('${item['category'] ?? 'Report'}'),
                              subtitle: Text('${item['summary'] ?? ''}'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) => _report(item, value),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'resolved', child: Text('Resolve')),
                                  PopupMenuItem(value: 'dismissed', child: Text('Dismiss')),
                                ],
                              ),
                            )),
                      ),
                      _section(
                        'Support queue',
                        _support.where((item) => ['open', 'in_progress'].contains(item['status'])).map((item) => ListTile(
                              leading: const Icon(Icons.support_agent),
                              title: Text('${item['subject'] ?? 'Support case'}'),
                              subtitle: Text('${item['category'] ?? ''} • ${item['priority'] ?? ''}'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) => _supportCase(item, value),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'in_progress', child: Text('Assign / progress')),
                                  PopupMenuItem(value: 'resolved', child: Text('Resolve')),
                                ],
                              ),
                            )),
                      ),
                      _section(
                        'Risk signals',
                        _risks.where((item) => item['status'] == 'open').map((item) => ListTile(
                              leading: const Icon(Icons.shield_outlined),
                              title: Text('${item['kind'] ?? 'Risk signal'} • score ${item['score'] ?? 0}'),
                              subtitle: Text('${item['detail'] ?? ''}'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) => _risk(item, value),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'reviewed', child: Text('Reviewed')),
                                  PopupMenuItem(value: 'dismissed', child: Text('Dismiss')),
                                ],
                              ),
                            )),
                      ),
                      _section(
                        'Warranty claims',
                        _warranty.where((item) => ['open', 'under_review'].contains(item['status'])).map((item) => ListTile(
                              leading: const Icon(Icons.workspace_premium_outlined),
                              title: Text('${item['issue'] ?? 'Warranty claim'}'),
                              subtitle: Text('Booking ${_short(item['booking_id'])}'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) => _warrantyDecision(item, value),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'resolved', child: Text('Resolve')),
                                  PopupMenuItem(value: 'rejected', child: Text('Reject')),
                                ],
                              ),
                            )),
                      _section(
                        'Users',
                        _users.take(40).map((item) {
                          final suspended = item['suspended_at'] != null;
                          return ListTile(
                            leading: Icon(suspended ? Icons.person_off_outlined : Icons.person_outline),
                            title: Text('${item['display_name'] ?? item['phone'] ?? 'User'}'),
                            subtitle: Text('${item['phone'] ?? ''}${item['identity_verified'] == true ? ' • Verified' : ''}'),
                            trailing: item['is_admin'] == true
                                ? const Chip(label: Text('Admin'))
                                : TextButton(
                                    onPressed: () => suspended ? _restore(item) : _suspend(item),
                                    child: Text(suspended ? 'Restore' : 'Suspend'),
                                  ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _errorView() {
    final message = _error is ApiException ? (_error as ApiException).message : '$_error';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.admin_panel_settings_outlined, size: 56),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value) => SizedBox(
        width: 155,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(label),
            ]),
          ),
        ),
      );

  Widget _section(String title, Iterable<Widget> children) {
    final items = children.toList(growable: false);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (items.isEmpty) const Text('Nothing waiting in this queue.') else Card(child: Column(children: items)),
        ],
      ),
    );
  }

  Future<void> _verification(Map<String, dynamic> item, String status) async {
    await _action(() => ref.read(operationsApiProvider).decideVerification('${item['id']}', status));
  }

  Future<void> _payout(Map<String, dynamic> item, String status) async {
    await _action(() => ref.read(operationsApiProvider).processPayout('${item['id']}', status));
  }

  Future<void> _resolveDispute(Map<String, dynamic> item) async {
    final controller = TextEditingController(text: 'Reviewed by Bid&Book operations.');
    final refund = TextEditingController(text: '0');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resolve dispute'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(labelText: 'Resolution')),
          const SizedBox(height: 10),
          TextField(controller: refund, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Refund ₹')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Resolve')),
        ],
      ),
    );
    if (confirmed == true) {
      final paise = (int.tryParse(refund.text.trim()) ?? 0) * 100;
      await _action(() => ref.read(operationsApiProvider).resolveDispute(id: '${item['id']}', resolution: controller.text.trim(), refundPaise: paise));
    }
    controller.dispose();
    refund.dispose();
  }

  Future<void> _report(Map<String, dynamic> item, String status) async {
    await _action(() => ref.read(operationsApiProvider).decideReport('${item['id']}', status, 'Reviewed by Bid&Book operations.'));
  }

  Future<void> _supportCase(Map<String, dynamic> item, String status) async {
    await _action(() => ref.read(operationsApiProvider).decideSupportCase('${item['id']}', status));
  }

  Future<void> _risk(Map<String, dynamic> item, String status) async {
    await _action(() => ref.read(operationsApiProvider).decideRisk('${item['id']}', status));
  }

  Future<void> _warrantyDecision(Map<String, dynamic> item, String status) async {
    await _action(() => ref.read(operationsApiProvider).decideWarranty('${item['id']}', status, 'Reviewed by Bid&Book operations.'));
  }

  Future<void> _suspend(Map<String, dynamic> item) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Suspend account'),
        content: TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Suspend')),
        ],
      ),
    );
    if (confirmed == true && reason.text.trim().length >= 3) {
      await _action(() => ref.read(operationsApiProvider).suspendUser('${item['id']}', reason.text.trim()));
    }
    reason.dispose();
  }

  Future<void> _restore(Map<String, dynamic> item) async {
    await _action(() => ref.read(operationsApiProvider).restoreUser('${item['id']}'));
  }

  Future<void> _action(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : '$error';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _short(Object? value) {
    final text = value?.toString() ?? '';
    return text.length <= 8 ? text : text.substring(0, 8).toUpperCase();
  }
}
