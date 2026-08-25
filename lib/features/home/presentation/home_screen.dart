import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(remoteAuthControllerProvider).asData?.value;
    final marketplace = ref.watch(remoteMarketplaceProvider);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bid&Book'),
        actions: [
          IconButton(
            tooltip: 'Bookings',
            onPressed: () => context.push('/bookings'),
            icon: const Icon(Icons.event_available_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(remoteMarketplaceProvider.notifier).refreshAll(),
        child: marketplace.when(
          loading: () => ListView(
            children: const [SizedBox(height: 280), Center(child: CircularProgressIndicator())],
          ),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.cloud_off_outlined, size: 52),
              const SizedBox(height: 12),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(remoteMarketplaceProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (data) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text(
                'Hi ${auth?.user?.bestName ?? 'there'}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              const Text('Book a service, post a need, or combine demand with your neighborhood.'),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.push('/requests/new'),
                    icon: const Icon(Icons.campaign_outlined),
                    label: const Text('Post request'),
                  ),
                  OutlinedButton.icon(
                    onPressed: data.provider == null
                        ? () => context.push('/provider/onboarding')
                        : () => context.push('/services/new'),
                    icon: const Icon(Icons.handyman_outlined),
                    label: Text(data.provider == null
                        ? 'Become a provider'
                        : 'Add service'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/groups'),
                    icon: const Icon(Icons.groups_2_outlined),
                    label: const Text('Neighborhood groups'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text('Available services',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            )),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => ref
                        .read(remoteMarketplaceProvider.notifier)
                        .refreshAll(),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (data.services.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No services have been published yet.'),
                  ),
                )
              else
                ...data.services.take(20).map((service) => Card(
                      child: ListTile(
                        onTap: () => context.push('/services/${service.id}'),
                        leading: const CircleAvatar(
                          child: Icon(Icons.home_repair_service_outlined),
                        ),
                        title: Text(service.title),
                        subtitle: Text(
                          '${service.category} • ${service.area}\n${service.providerLabel}',
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          currency.format(service.priceRupees),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}
