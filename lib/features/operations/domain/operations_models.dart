class OpsSupportCase {
  const OpsSupportCase({
    required this.id,
    required this.subject,
    required this.category,
    required this.description,
    required this.priority,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String subject;
  final String category;
  final String description;
  final String priority;
  final String status;
  final DateTime createdAt;

  factory OpsSupportCase.fromJson(Map<String, dynamic> json) => OpsSupportCase(
        id: json['id'].toString(),
        subject: json['subject'] as String? ?? '',
        category: json['category'] as String? ?? '',
        description: json['description'] as String? ?? '',
        priority: json['priority'] as String? ?? 'normal',
        status: json['status'] as String? ?? 'open',
        createdAt: _date(json['created_at']),
      );
}

class OpsReport {
  const OpsReport({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.category,
    required this.summary,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String category;
  final String summary;
  final String status;
  final DateTime createdAt;

  factory OpsReport.fromJson(Map<String, dynamic> json) => OpsReport(
        id: json['id'].toString(),
        entityType: json['entity_type'] as String? ?? '',
        entityId: json['entity_id'].toString(),
        category: json['category'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        status: json['status'] as String? ?? 'open',
        createdAt: _date(json['created_at']),
      );
}

class OpsAvailability {
  const OpsAvailability({
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
    required this.active,
    this.id,
  });

  final String? id;
  final int weekday;
  final int startMinute;
  final int endMinute;
  final bool active;

  factory OpsAvailability.fromJson(Map<String, dynamic> json) => OpsAvailability(
        id: json['id']?.toString(),
        weekday: json['weekday'] as int? ?? 0,
        startMinute: json['start_minute'] as int? ?? 540,
        endMinute: json['end_minute'] as int? ?? 1020,
        active: json['active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'start_minute': startMinute,
        'end_minute': endMinute,
        'active': active,
      };
}

class DiscoveryService {
  const DiscoveryService({
    required this.id,
    required this.providerId,
    required this.providerUserId,
    required this.providerName,
    required this.providerVerified,
    required this.providerReviewCount,
    required this.title,
    required this.category,
    required this.description,
    required this.area,
    required this.pricePaise,
    required this.pricingUnit,
    this.providerRating,
  });

  final String id;
  final String providerId;
  final String providerUserId;
  final String providerName;
  final bool providerVerified;
  final double? providerRating;
  final int providerReviewCount;
  final String title;
  final String category;
  final String description;
  final String area;
  final int pricePaise;
  final String pricingUnit;

  double get priceRupees => pricePaise / 100;

  factory DiscoveryService.fromJson(Map<String, dynamic> json) => DiscoveryService(
        id: json['id'].toString(),
        providerId: json['provider_id'].toString(),
        providerUserId: json['provider_user_id'].toString(),
        providerName: json['provider_name'] as String? ?? 'Provider',
        providerVerified: json['provider_verified'] as bool? ?? false,
        providerRating: (json['provider_rating'] as num?)?.toDouble(),
        providerReviewCount: json['provider_review_count'] as int? ?? 0,
        title: json['title'] as String? ?? '',
        category: json['category'] as String? ?? '',
        description: json['description'] as String? ?? '',
        area: json['area'] as String? ?? '',
        pricePaise: json['price_paise'] as int? ?? 0,
        pricingUnit: json['pricing_unit'] as String? ?? 'fixed',
      );
}

class AdminOverviewModel {
  const AdminOverviewModel({
    required this.users,
    required this.providers,
    required this.activeServices,
    required this.bookings,
    required this.completedBookings,
    required this.capturedGmvPaise,
    required this.platformFeesPaise,
    required this.openDisputes,
    required this.openReports,
    required this.openSupportCases,
    required this.openRiskSignals,
    required this.pendingVerifications,
    required this.pendingPayouts,
  });

  final int users;
  final int providers;
  final int activeServices;
  final int bookings;
  final int completedBookings;
  final int capturedGmvPaise;
  final int platformFeesPaise;
  final int openDisputes;
  final int openReports;
  final int openSupportCases;
  final int openRiskSignals;
  final int pendingVerifications;
  final int pendingPayouts;

  factory AdminOverviewModel.fromJson(Map<String, dynamic> json) => AdminOverviewModel(
        users: json['users'] as int? ?? 0,
        providers: json['providers'] as int? ?? 0,
        activeServices: json['active_services'] as int? ?? 0,
        bookings: json['bookings'] as int? ?? 0,
        completedBookings: json['completed_bookings'] as int? ?? 0,
        capturedGmvPaise: json['captured_gmv_paise'] as int? ?? 0,
        platformFeesPaise: json['platform_fees_paise'] as int? ?? 0,
        openDisputes: json['open_disputes'] as int? ?? 0,
        openReports: json['open_reports'] as int? ?? 0,
        openSupportCases: json['open_support_cases'] as int? ?? 0,
        openRiskSignals: json['open_risk_signals'] as int? ?? 0,
        pendingVerifications: json['pending_verifications'] as int? ?? 0,
        pendingPayouts: json['pending_payouts'] as int? ?? 0,
      );
}

class StartCodeResult {
  const StartCodeResult({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;

  factory StartCodeResult.fromJson(Map<String, dynamic> json) => StartCodeResult(
        code: json['code'] as String? ?? '',
        expiresAt: _date(json['expires_at']),
      );
}

DateTime _date(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();
