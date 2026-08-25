import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
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
    final date = DateFormat('dd MMM, h:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('Requests')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/requests/new'),
        icon: const Icon(Icons.add),
        label: const Text('Post request'),
      ),
      body: marketplace.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Error(error: error, onRetry: () => ref.invalidate(remoteMarketplaceProvider)),
        data: (data) {
          if (data.requests.isEmpty) return const Center(child: Text('No service requests yet.'));
          return RefreshIndicator(
            onRefresh: () => ref.read(remoteMarketplaceProvider.notifier).refreshAll(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: data.requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final request = data.requests[index];
                final mine = request.createdByUserId == userId;
                return Card(
                  child: ListTile(
                    onTap: () => context.push('/requests/${request.id}/bids'),
                    leading: CircleAvatar(
                      child: Icon(request.groupId == null ? Icons.person_outline : Icons.groups_2_outlined),
                    ),
                    title: Text(request.title),
                    subtitle: Text('${request.category} • ${request.area}\n${date.format(request.requestedFor)}${mine ? ' • Your request' : ''}'),
                    isThreeLine: true,
                    trailing: _Status(status: request.status),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.status});
  final ApiRequestStatus status;
  @override
  Widget build(BuildContext context) => Chip(label: Text(status.name), visualDensity: VisualDensity.compact);
}

class _Error extends StatelessWidget {
  const _Error({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      );
}
