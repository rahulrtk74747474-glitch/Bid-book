import 'package:bid_book/features/auth/application/auth_controller.dart';
import 'package:bid_book/features/requests/application/request_controller.dart';
import 'package:bid_book/features/requests/domain/service_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(serviceRequestsProvider);
    final currentUserId = ref.watch(authControllerProvider).user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service requests'),
        actions: [
          IconButton(
            onPressed: () => context.go('/requests/new'),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/requests/new'),
        icon: const Icon(Icons.add),
        label: const Text('Post request'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        itemCount: requests.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final request = requests[index];
          final isMine = request.createdByUserId == currentUserId;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(label: Text(request.category)),
                      const Spacer(),
                      Chip(
                        avatar: Icon(_statusIcon(request.status), size: 16),
                        label: Text(_statusLabel(request.status)),
                      ),
                    ],
                  ),
                  if (isMine)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Your request',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  Text(
                    request.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (request.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(request.description),
                  ],
                  const SizedBox(height: 10),
                  _MetaRow(
                    icon: Icons.location_on_outlined,
                    text: request.area,
                  ),
                  _MetaRow(
                    icon: Icons.schedule,
                    text: DateFormat('EEE, d MMM • h:mm a').format(request.requestedFor),
                  ),
                  if (request.groupName != null)
                    _MetaRow(
                      icon: Icons.groups_outlined,
                      text: '${request.groupName} • ${request.interestedMembers} interested',
                    ),
                  if (request.acceptedBidEventId != null)
                    _MetaRow(
                      icon: Icons.check_circle_outline,
                      text: 'Accepted bid: ${request.acceptedBidEventId}',
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.go('/requests/${request.id}/bids'),
                      icon: const Icon(Icons.history),
                      label: const Text('View complete bid history'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _statusLabel(ServiceRequestStatus status) => switch (status) {
        ServiceRequestStatus.collectingInterest => 'Collecting interest',
        ServiceRequestStatus.bidding => 'Bidding open',
        ServiceRequestStatus.awarded => 'Awarded',
        ServiceRequestStatus.booked => 'Booked',
        ServiceRequestStatus.completed => 'Completed',
      };

  static IconData _statusIcon(ServiceRequestStatus status) => switch (status) {
        ServiceRequestStatus.collectingInterest => Icons.how_to_vote_outlined,
        ServiceRequestStatus.bidding => Icons.gavel,
        ServiceRequestStatus.awarded => Icons.emoji_events_outlined,
        ServiceRequestStatus.booked => Icons.event_available_outlined,
        ServiceRequestStatus.completed => Icons.task_alt,
      };
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
