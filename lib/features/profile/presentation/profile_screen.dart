import 'package:bid_book/features/auth/application/auth_controller.dart';
import 'package:bid_book/features/bookings/application/booking_controller.dart';
import 'package:bid_book/features/provider/application/provider_profile_controller.dart';
import 'package:bid_book/features/provider/domain/provider_profile.dart';
import 'package:bid_book/features/services/application/service_catalog_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final profile = ref.watch(providerProfileProvider);
    final myServices = ref
        .watch(serviceCatalogProvider)
        .where((item) => item.ownerUserId == auth.user?.id)
        .length;
    final myBookings = ref
        .watch(bookingsProvider)
        .where((item) => item.customerUserId == auth.user?.id)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 38,
                    child: Icon(Icons.person, size: 38),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile?.displayName ?? 'Your profile',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 5),
                  Text(auth.user?.phoneNumber ?? ''),
                  const SizedBox(height: 5),
                  const Text('Customer + service provider in one account'),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      const Chip(
                        avatar: Icon(Icons.phone_android, size: 16),
                        label: Text('Mobile verified'),
                      ),
                      Chip(
                        avatar: Icon(
                          profile?.identityVerified == true
                              ? Icons.verified_user
                              : Icons.verified_user_outlined,
                          size: 16,
                        ),
                        label: Text(
                          profile?.identityVerified == true
                              ? 'Identity verified'
                              : 'Identity pending',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.handyman_outlined),
            title: Text(
              profile == null ? 'Start offering services' : 'Provider profile',
            ),
            subtitle: Text(
              profile == null
                  ? 'Independent workers and companies can join'
                  : '${profile.kind.label} • ${profile.serviceArea}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/provider/onboarding'),
          ),
          if (profile != null)
            ListTile(
              leading: const Icon(Icons.add_business_outlined),
              title: const Text('Post a service'),
              subtitle: Text('$myServices active service listing(s)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/services/new'),
            ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('My bookings'),
            subtitle: Text('$myBookings booking(s)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/bookings'),
          ),
          const ListTile(
            leading: Icon(Icons.verified_user_outlined),
            title: Text('Identity verification'),
            subtitle: Text('Verification integration is the next security service'),
            trailing: Icon(Icons.chevron_right),
          ),
          const ListTile(
            leading: Icon(Icons.account_balance_outlined),
            title: Text('Payments & payouts'),
            subtitle: Text('Payment gateway integration comes after booking APIs'),
            trailing: Icon(Icons.chevron_right),
          ),
          const ListTile(
            leading: Icon(Icons.security_outlined),
            title: Text('Security & devices'),
            trailing: Icon(Icons.chevron_right),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
