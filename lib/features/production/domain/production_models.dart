class ProductionProviderProfile {
  const ProductionProviderProfile({
    required this.providerId,
    required this.yearsExperience,
    required this.languages,
    required this.skills,
    required this.serviceRadiusKm,
    required this.payoutConfigured,
    this.gstin,
    this.latitude,
    this.longitude,
    this.payoutMethodLabel,
    this.portfolioHeadline,
  });

  final String providerId;
  final int yearsExperience;
  final List<String> languages;
  final List<String> skills;
  final String? gstin;
  final int serviceRadiusKm;
  final double? latitude;
  final double? longitude;
  final bool payoutConfigured;
  final String? payoutMethodLabel;
  final String? portfolioHeadline;

  factory ProductionProviderProfile.fromJson(Map<String, dynamic> json) =>
      ProductionProviderProfile(
        providerId: '${json['provider_id']}',
        yearsExperience: (json['years_experience'] as num?)?.toInt() ?? 0,
        languages: _strings(json['languages']),
        skills: _strings(json['skills']),
        gstin: json['gstin'] as String?,
        serviceRadiusKm: (json['service_radius_km'] as num?)?.toInt() ?? 10,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        payoutConfigured: json['payout_configured'] == true,
        payoutMethodLabel: json['payout_method_label'] as String?,
        portfolioHeadline: json['portfolio_headline'] as String?,
      );
}

class NearbyService {
  const NearbyService({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.providerVerified,
    required this.title,
    required this.category,
    required this.area,
    required this.pricePaise,
    required this.pricingUnit,
    required this.reviewCount,
    required this.serviceRadiusKm,
    this.description,
    this.distanceKm,
    this.rating,
  });

  final String id;
  final String providerId;
  final String providerName;
  final bool providerVerified;
  final String title;
  final String category;
  final String? description;
  final String area;
  final int pricePaise;
  final String pricingUnit;
  final double? distanceKm;
  final double? rating;
  final int reviewCount;
  final int serviceRadiusKm;

  factory NearbyService.fromJson(Map<String, dynamic> json) => NearbyService(
        id: '${json['id']}',
        providerId: '${json['provider_id']}',
        providerName: json['provider_name'] as String? ?? 'Provider',
        providerVerified: json['provider_verified'] == true,
        title: json['title'] as String? ?? 'Service',
        category: json['category'] as String? ?? '',
        description: json['description'] as String?,
        area: json['area'] as String? ?? '',
        pricePaise: (json['price_paise'] as num?)?.toInt() ?? 0,
        pricingUnit: json['pricing_unit'] as String? ?? 'fixed',
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
        rating: (json['rating'] as num?)?.toDouble(),
        reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
        serviceRadiusKm: (json['service_radius_km'] as num?)?.toInt() ?? 10,
      );
}

class ProviderStaffMember {
  const ProviderStaffMember({
    required this.id,
    required this.providerId,
    required this.userId,
    required this.role,
    required this.active,
  });

  final String id;
  final String providerId;
  final String userId;
  final String role;
  final bool active;

  factory ProviderStaffMember.fromJson(Map<String, dynamic> json) =>
      ProviderStaffMember(
        id: '${json['id']}',
        providerId: '${json['provider_id']}',
        userId: '${json['user_id']}',
        role: json['role'] as String? ?? 'technician',
        active: json['active'] != false,
      );
}

class MediaUploadIntent {
  const MediaUploadIntent({
    required this.id,
    required this.objectKey,
    required this.uploadUrl,
    required this.status,
    this.publicUrl,
  });

  final String id;
  final String objectKey;
  final String uploadUrl;
  final String? publicUrl;
  final String status;

  factory MediaUploadIntent.fromJson(Map<String, dynamic> json) =>
      MediaUploadIntent(
        id: '${json['id']}',
        objectKey: json['object_key'] as String? ?? '',
        uploadUrl: json['upload_url'] as String? ?? '',
        publicUrl: json['public_url'] as String?,
        status: json['status'] as String? ?? 'pending',
      );
}

List<String> _strings(Object? value) => value is List
    ? value.whereType<Object>().map((item) => '$item').toList(growable: false)
    : const [];
