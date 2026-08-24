import 'package:bid_book/features/provider/domain/provider_profile.dart';
import 'package:bid_book/features/services/domain/service_listing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final serviceCatalogProvider =
    NotifierProvider<ServiceCatalogController, List<ServiceListing>>(
  ServiceCatalogController.new,
);

class ServiceCatalogController extends Notifier<List<ServiceListing>> {
  static const _uuid = Uuid();

  @override
  List<ServiceListing> build() => List.unmodifiable(_seed);

  ServiceListing addListing({
    required ProviderProfile provider,
    required String title,
    required String category,
    required String description,
    required String area,
    required int pricePaise,
    required PricingUnit pricingUnit,
  }) {
    if (pricePaise <= 0) {
      throw ArgumentError.value(pricePaise, 'pricePaise', 'Must be positive');
    }

    final cleanTitle = title.trim();
    if (cleanTitle.length < 3) {
      throw ArgumentError.value(title, 'title', 'Title is too short');
    }

    final listing = ServiceListing(
      id: _uuid.v4(),
      ownerUserId: provider.userId,
      providerId: provider.id,
      providerName: provider.displayName,
      title: cleanTitle,
      category: category.trim(),
      description: description.trim(),
      area: area.trim(),
      pricePaise: pricePaise,
      pricingUnit: pricingUnit,
      identityVerified: provider.identityVerified,
      rating: provider.rating,
      active: true,
    );

    state = List.unmodifiable([...state, listing]);
    return listing;
  }

  static const _seed = [
    ServiceListing(
      id: 'listing-ac-001',
      ownerUserId: 'user-coolcare',
      providerId: 'provider-coolcare',
      providerName: 'CoolCare Services',
      title: 'AC general service',
      category: 'AC Service',
      description: 'Indoor unit, filters and outdoor-unit basic cleaning.',
      area: 'Sonipat',
      pricePaise: 49900,
      pricingUnit: PricingUnit.perUnit,
      identityVerified: true,
      rating: 4.8,
      active: true,
    ),
    ServiceListing(
      id: 'listing-electric-001',
      ownerUserId: 'user-powerfix',
      providerId: 'provider-powerfix',
      providerName: 'PowerFix Electrician',
      title: 'Electrician visit',
      category: 'Electrician',
      description: 'Home electrical inspection and minor repair visit.',
      area: 'Sonipat',
      pricePaise: 29900,
      pricingUnit: PricingUnit.fixed,
      identityVerified: true,
      rating: 4.7,
      active: true,
    ),
  ];
}
