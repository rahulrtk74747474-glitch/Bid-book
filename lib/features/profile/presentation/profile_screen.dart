import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(remoteAuthControllerProvider).asData?.value;
    final marketplace = ref.watch(remoteMarketplaceProvider).asData?.value;
    final user = auth?.user;
    final provider = marketplace?.provider;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.bestName ?? 'Account', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(user?.phone ?? ''),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, children: [
                    Chip(label: Text(user?.phoneVerified == true ? 'Phone verified' : 'Phone unverified')),
                    Chip(label: Text(user?.identityVerified == true ? 'Identity verified' : 'Identity not verified')),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.handyman_outlined),
            title: Text(provider == null ? 'Become a service provider' : provider.displayName),
            subtitle: Text(provider == null ? 'Independent workers and companies can offer services.' : '${provider.kind.label} • ${provider.serviceArea}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/provider/onboarding'),
          ),
          if (provider != null)
            ListTile(
              leading: const Icon(Icons.add_business_outlined),
              title: const Text('Publish a service'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/services/new'),
            ),
          ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: const Text('My bookings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/bookings'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () => ref.read(remoteAuthControllerProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}
