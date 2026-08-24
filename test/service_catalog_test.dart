import 'package:bid_book/features/provider/domain/provider_profile.dart';
import 'package:bid_book/features/services/application/service_catalog_controller.dart';
import 'package:bid_book/features/services/domain/service_listing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provider can append a priced service listing', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const provider = ProviderProfile(
      id: 'provider-test',
      userId: 'user-test',
      displayName: 'Test Worker',
      kind: ProviderKind.individual,
      serviceArea: 'Sonipat',
      identityVerified: false,
      rating: 0,
      completedJobs: 0,
    );

    final before = container.read(serviceCatalogProvider).length;
    final listing = container.read(serviceCatalogProvider.notifier).addListing(
          provider: provider,
          title: 'Plumbing visit',
          category: 'Plumber',
          description: 'Inspection and minor repairs.',
          area: 'Sonipat',
          pricePaise: 35000,
          pricingUnit: PricingUnit.fixed,
        );

    expect(listing.ownerUserId, 'user-test');
    expect(listing.pricePaise, 35000);
    expect(container.read(serviceCatalogProvider).length, before + 1);
  });
}
