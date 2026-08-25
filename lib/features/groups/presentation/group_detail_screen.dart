import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:bid_book/features/groups/application/remote_group_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(remoteGroupControllerProvider.notifier).loadProposals(widget.groupId));
  }

  Future<void> _createProposal() async {
    final title = TextEditingController();
    final description = TextEditingController();
    String category = 'AC Service';
    DateTime preferred = DateTime.now().add(const Duration(days: 3));
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Raise group request'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Request title')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                items: const ['AC Service', 'Electrician', 'Plumber', 'Cleaning', 'Pest Control', 'Other']
                    .map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                onChanged: (value) => setLocalState(() => category = value ?? category),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 10),
              TextField(controller: description, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Preferred date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(preferred)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate: preferred,
                  );
                  if (picked != null) setLocalState(() => preferred = DateTime(picked.year, picked.month, picked.day, 9));
                },
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start voting')),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    setState(() => _loading = true);
    try {
      await ref.read(remoteGroupControllerProvider.notifier).createProposal(
            groupId: widget.groupId,
            title: title.text.trim(),
            category: category,
            description: description.text.trim(),
            preferredFor: preferred,
          );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _vote(ApiProposal proposal, ApiVoteChoice choice) async {
    var quantity = choice == ApiVoteChoice.accept ? 1 : 0;
    if (choice == ApiVoteChoice.accept) {
      final controller = TextEditingController(text: '1');
      final result = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('How many units / jobs?'),
          content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(controller.text) ?? 1), child: const Text('Vote')),
          ],
        ),
      );
      if (result == null) return;
      quantity = result.clamp(1, 100).toInt();
    }
    try {
      await ref.read(remoteGroupControllerProvider.notifier).vote(
            groupId: widget.groupId,
            proposalId: proposal.id,
            choice: choice,
            quantity: quantity,
          );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _publish(ApiProposal proposal) async {
    setState(() => _loading = true);
    try {
      final request = await ref.read(remoteGroupControllerProvider.notifier).publish(
            groupId: widget.groupId,
            proposalId: proposal.id,
          );
      if (mounted) context.push('/requests/${request.id}/bids');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(remoteGroupControllerProvider).asData?.value;
    final userId = ref.watch(remoteAuthControllerProvider).asData?.value.user?.id;
    ApiGroup? group;
    for (final item in state?.groups ?? const <ApiGroup>[]) {
      if (item.id == widget.groupId) {
        group = item;
        break;
      }
    }
    final proposals = state?.proposalsByGroup[widget.groupId] ?? const <ApiProposal>[];
    final isOwner = group?.ownerUserId == userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(group?.name ?? 'Group'),
        actions: [
          if (isOwner) IconButton(onPressed: _loading ? null : _createProposal, icon: const Icon(Icons.add_comment_outlined), tooltip: 'Raise request'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(remoteGroupControllerProvider.notifier).loadProposals(widget.groupId),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (group != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(group.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(group.area),
                    const SizedBox(height: 8),
                    SelectableText('Invite code: ${group.inviteCode}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text('Proposals', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              if (isOwner) FilledButton.icon(onPressed: _loading ? null : _createProposal, icon: const Icon(Icons.add), label: const Text('Raise')),
            ]),
            const SizedBox(height: 8),
            if (proposals.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No proposals yet. Group admins can raise a service request for members to vote on.')))
            else
              ...proposals.map((proposal) => _ProposalCard(
                    proposal: proposal,
                    groupId: widget.groupId,
                    canPublish: isOwner,
                    onVote: (choice) => _vote(proposal, choice),
                    onPublish: () => _publish(proposal),
                  )),
          ],
        ),
      ),
    );
  }
}

class _ProposalCard extends ConsumerWidget {
  const _ProposalCard({required this.proposal, required this.groupId, required this.canPublish, required this.onVote, required this.onPublish});
  final ApiProposal proposal;
  final String groupId;
  final bool canPublish;
  final ValueChanged<ApiVoteChoice> onVote;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(proposalSummaryProvider(ProposalKey(groupId, proposal.id)));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(proposal.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            Chip(label: Text(proposal.status.name)),
          ]),
          Text('${proposal.category} • ${DateFormat('dd MMM yyyy').format(proposal.preferredFor)}'),
          const SizedBox(height: 8),
          Text(proposal.description),
          const SizedBox(height: 12),
          summary.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const Text('Vote summary unavailable'),
            data: (value) => Text('Accept ${value.acceptCount} • Reject ${value.rejectCount} • Maybe ${value.maybeCount} • Quantity ${value.acceptedQuantity}'),
          ),
          if (proposal.status == ApiProposalStatus.voting) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(onPressed: () => onVote(ApiVoteChoice.accept), child: const Text('Accept')),
              OutlinedButton(onPressed: () => onVote(ApiVoteChoice.reject), child: const Text('Reject')),
              OutlinedButton(onPressed: () => onVote(ApiVoteChoice.maybe), child: const Text('Maybe')),
              if (canPublish) FilledButton(onPressed: onPublish, child: const Text('Publish for bidding')),
            ]),
          ],
          if (proposal.publishedRequestId != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.push('/requests/${proposal.publishedRequestId}/bids'),
              icon: const Icon(Icons.gavel_outlined),
              label: const Text('Open bidding request'),
            ),
          ],
        ]),
      ),
    );
  }
}
