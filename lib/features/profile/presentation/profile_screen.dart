import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:bid_book/features/operations/application/remote_operations_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(remoteAuthControllerProvider).asData?.value;
    final marketplace = ref.watch(remoteMarketplaceProvider).asData?.value;
    final operations = ref.watch(remoteOperationsProvider).asData?.value;
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
                  Text(
                    user?.bestName ?? 'Account',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(user?.phone ?? ''),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          user?.phoneVerified == true
                              ? 'Phone verified'
                              : 'Phone unverified',
                        ),
                      ),
                      Chip(
                        label: Text(
                          user?.identityVerified == true
                              ? 'Identity verified'
                              : 'Identity not verified',
                        ),
                      ),
                      if (operations?.isAdmin == true)
                        const Chip(label: Text('Administrator')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Find services'),
            subtitle: const Text('Search by area, verification, rating and availability'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/discover'),
          ),
          ListTile(
            leading: const Icon(Icons.near_me_outlined),
            title: const Text('Nearby services'),
            subtitle: const Text('Foreground location search using provider service radius'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/nearby'),
          ),
          ListTile(
            leading: const Icon(Icons.handyman_outlined),
            title: Text(
              provider == null ? 'Become a service provider' : provider.displayName,
            ),
            subtitle: Text(
              provider == null
                  ? 'Independent workers and companies can offer services.'
                  : '${provider.kind.label} • ${provider.serviceArea}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/provider/onboarding'),
          ),
          if (provider != null) ...[
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Business & professional profile'),
              subtitle: const Text('Skills, languages, experience, GSTIN, service radius and location'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/provider/business'),
            ),
            ListTile(
              leading: const Icon(Icons.add_business_outlined),
              title: const Text('Publish a service'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/services/new'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Provider availability'),
              subtitle: const Text('Set the days you normally accept work'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/provider/availability'),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Company team'),
              subtitle: const Text('Managers, dispatchers, technicians and accountants'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/provider/team'),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: const Text('My bookings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/bookings'),
          ),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Trust & payments'),
            subtitle: const Text(
              'Identity verification, payments, payouts and disputes',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/trust'),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Support & safety'),
            subtitle: const Text('Support cases, reports and account controls'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/support-safety'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy, data & notifications'),
            subtitle: const Text('Push setup, data export and device privacy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/privacy-data'),
          ),
          if (operations?.isAdmin == true)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Admin operations'),
              subtitle: const Text('MFA-protected trust, safety, payout and support queues'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin'),
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
