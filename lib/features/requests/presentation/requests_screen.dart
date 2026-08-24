import 'package:bid_book/features/requests/domain/service_request.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  static final _requests = [
    ServiceRequest(
      id: 'req-ac-001',
      title: 'Bulk AC servicing for residents',
      category: 'AC Service',
      area: 'Sector 15, Sonipat',
      requestedFor: DateTime(2026, 9, 10, 9),
      status: ServiceRequestStatus.bidding,
      createdByName: 'Group Admin',
      groupName: 'Green Residency',
      interestedMembers: 47,
    ),
    ServiceRequest(
      id: 'req-plumber-002',
      title: 'Kitchen sink leakage repair',
      category: 'Plumber',
      area: 'Model Town, Sonipat',
      requestedFor: DateTime(2026, 8, 26, 11),
      status: ServiceRequestStatus.bidding,
      createdByName: 'Amit',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service requests'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Post request'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        itemCount: _requests.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final request = _requests[index];
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
                      const Chip(
                        avatar: Icon(Icons.gavel, size: 16),
                        label: Text('Bidding open'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    request.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  _MetaRow(
                    icon: Icons.location_on_outlined,
                    text: request.area,
                  ),
                  _MetaRow(
                    icon: Icons.schedule,
                    text: DateFormat('EEE, d MMM • h:mm a')
                        .format(request.requestedFor),
                  ),
                  if (request.groupName != null)
                    _MetaRow(
                      icon: Icons.groups_outlined,
                      text:
                          '${request.groupName} • ${request.interestedMembers} interested',
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () =>
                          context.go('/requests/${request.id}/bids'),
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
