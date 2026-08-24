enum PricingUnit { fixed, hourly, daily, perUnit }

extension PricingUnitLabel on PricingUnit {
  String get label => switch (this) {
        PricingUnit.fixed => 'Fixed price',
        PricingUnit.hourly => 'Per hour',
        PricingUnit.daily => 'Per day',
        PricingUnit.perUnit => 'Per unit',
      };
}

class ServiceListing {
  const ServiceListing({
    required this.id,
    required this.ownerUserId,
    required this.providerId,
    required this.providerName,
    required this.title,
    required this.category,
    required this.description,
    required this.area,
    required this.pricePaise,
    required this.pricingUnit,
    required this.identityVerified,
    required this.rating,
    required this.active,
  });

  final String id;
  final String ownerUserId;
  final String providerId;
  final String providerName;
  final String title;
  final String category;
  final String description;
  final String area;
  final int pricePaise;
  final PricingUnit pricingUnit;
  final bool identityVerified;
  final double rating;
  final bool active;

  double get priceRupees => pricePaise / 100;
}
