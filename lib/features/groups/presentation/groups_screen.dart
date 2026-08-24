import 'package:flutter/material.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neighborhood groups'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.group_add_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Create group'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(child: Icon(Icons.apartment)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Green Residency',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text('Sector 15, Sonipat • 127 members'),
                          ],
                        ),
                      ),
                      Chip(label: Text('Admin')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Active proposal',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'AC servicing on 10 September',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(value: 0.72),
                  const SizedBox(height: 8),
                  const Text('72% responded • 47 interested'),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: null, child: Text('Reject'))),
                      SizedBox(width: 10),
                      Expanded(child: FilledButton(onPressed: null, child: Text('Interested'))),
                    ],
                  ),
                  const Divider(height: 32),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.gavel_outlined),
                    title: Text('Next step: publish for provider bidding'),
                    subtitle: Text(
                      'When the group requirement is approved, independent workers and companies can bid and every bid remains in history.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
