enum TrustVerificationMethod { aadhaarOffline, governmentId, business }

extension TrustVerificationMethodX on TrustVerificationMethod {
  String get wireName => switch (this) {
        TrustVerificationMethod.aadhaarOffline => 'aadhaar_offline',
        TrustVerificationMethod.governmentId => 'government_id',
        TrustVerificationMethod.business => 'business',
      };

  String get label => switch (this) {
        TrustVerificationMethod.aadhaarOffline => 'Aadhaar Offline e-KYC',
        TrustVerificationMethod.governmentId => 'Government ID',
        TrustVerificationMethod.business => 'Business verification',
      };
}

class TrustVerification {
  const TrustVerification({
    required this.id,
    required this.method,
    required this.status,
    required this.providerName,
    required this.providerReference,
    required this.createdAt,
    this.verifiedAt,
    this.failureReason,
  });

  final String id;
  final String method;
  final String status;
  final String providerName;
  final String providerReference;
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final String? failureReason;

  factory TrustVerification.fromJson(Map<String, dynamic> json) =>
      TrustVerification(
        id: json['id'].toString(),
        method: json['method'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        providerName: json['provider_name'] as String? ?? '',
        providerReference: json['provider_reference'] as String? ?? '',
        createdAt: _date(json['created_at']),
        verifiedAt: _nullableDate(json['verified_at']),
        failureReason: json['failure_reason'] as String?,
      );
}

class TrustPayment {
  const TrustPayment({
    required this.id,
    required this.bookingId,
    required this.amountPaise,
    required this.platformFeePaise,
    required this.refundedPaise,
    required this.currency,
    required this.gateway,
    required this.gatewayReference,
    required this.status,
    required this.createdAt,
    this.capturedAt,
  });

  final String id;
  final String bookingId;
  final int amountPaise;
  final int platformFeePaise;
  final int refundedPaise;
  final String currency;
  final String gateway;
  final String gatewayReference;
  final String status;
  final DateTime createdAt;
  final DateTime? capturedAt;

  double get amountRupees => amountPaise / 100;
  double get refundedRupees => refundedPaise / 100;

  factory TrustPayment.fromJson(Map<String, dynamic> json) => TrustPayment(
        id: json['id'].toString(),
        bookingId: json['booking_id'].toString(),
        amountPaise: json['amount_paise'] as int? ?? 0,
        platformFeePaise: json['platform_fee_paise'] as int? ?? 0,
        refundedPaise: json['refunded_paise'] as int? ?? 0,
        currency: json['currency'] as String? ?? 'INR',
        gateway: json['gateway'] as String? ?? '',
        gatewayReference: json['gateway_reference'] as String? ?? '',
        status: json['status'] as String? ?? 'created',
        createdAt: _date(json['created_at']),
        capturedAt: _nullableDate(json['captured_at']),
      );
}

class TrustPayout {
  const TrustPayout({
    required this.id,
    required this.paymentId,
    required this.amountPaise,
    required this.status,
    required this.createdAt,
    this.holdReason,
    this.eligibleAt,
    this.paidAt,
  });

  final String id;
  final String paymentId;
  final int amountPaise;
  final String status;
  final String? holdReason;
  final DateTime createdAt;
  final DateTime? eligibleAt;
  final DateTime? paidAt;

  double get amountRupees => amountPaise / 100;

  factory TrustPayout.fromJson(Map<String, dynamic> json) => TrustPayout(
        id: json['id'].toString(),
        paymentId: json['payment_id'].toString(),
        amountPaise: json['amount_paise'] as int? ?? 0,
        status: json['status'] as String? ?? 'pending',
        holdReason: json['hold_reason'] as String?,
        createdAt: _date(json['created_at']),
        eligibleAt: _nullableDate(json['eligible_at']),
        paidAt: _nullableDate(json['paid_at']),
      );
}

class BookingTrustState {
  const BookingTrustState({
    required this.canPay,
    required this.canStart,
    required this.canComplete,
    required this.canReview,
    required this.openDisputeCount,
    this.payment,
    this.payout,
  });

  final TrustPayment? payment;
  final TrustPayout? payout;
  final bool canPay;
  final bool canStart;
  final bool canComplete;
  final bool canReview;
  final int openDisputeCount;

  factory BookingTrustState.fromJson(Map<String, dynamic> json) =>
      BookingTrustState(
        payment: json['payment'] == null
            ? null
            : TrustPayment.fromJson(_map(json['payment'])),
        payout: json['payout'] == null
            ? null
            : TrustPayout.fromJson(_map(json['payout'])),
        canPay: json['can_pay'] as bool? ?? false,
        canStart: json['can_start'] as bool? ?? false,
        canComplete: json['can_complete'] as bool? ?? false,
        canReview: json['can_review'] as bool? ?? false,
        openDisputeCount: json['open_dispute_count'] as int? ?? 0,
      );
}

class TrustDispute {
  const TrustDispute({
    required this.id,
    required this.bookingId,
    required this.category,
    required this.summary,
    required this.requestedRefundPaise,
    required this.status,
    required this.createdAt,
    this.resolution,
    this.resolvedAt,
  });

  final String id;
  final String bookingId;
  final String category;
  final String summary;
  final int requestedRefundPaise;
  final String status;
  final String? resolution;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  factory TrustDispute.fromJson(Map<String, dynamic> json) => TrustDispute(
        id: json['id'].toString(),
        bookingId: json['booking_id'].toString(),
        category: json['category'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        requestedRefundPaise: json['requested_refund_paise'] as int? ?? 0,
        status: json['status'] as String? ?? 'open',
        resolution: json['resolution'] as String?,
        createdAt: _date(json['created_at']),
        resolvedAt: _nullableDate(json['resolved_at']),
      );
}

class TrustOverview {
  const TrustOverview({
    required this.identityVerified,
    required this.paymentsCount,
    required this.payoutsCount,
    required this.openDisputesCount,
    this.latestVerification,
  });

  final bool identityVerified;
  final TrustVerification? latestVerification;
  final int paymentsCount;
  final int payoutsCount;
  final int openDisputesCount;

  factory TrustOverview.fromJson(Map<String, dynamic> json) => TrustOverview(
        identityVerified: json['identity_verified'] as bool? ?? false,
        latestVerification: json['latest_verification'] == null
            ? null
            : TrustVerification.fromJson(_map(json['latest_verification'])),
        paymentsCount: json['payments_count'] as int? ?? 0,
        payoutsCount: json['payouts_count'] as int? ?? 0,
        openDisputesCount: json['open_disputes_count'] as int? ?? 0,
      );
}

class ProviderReviewSummary {
  const ProviderReviewSummary({required this.count, this.averageRating});
  final int count;
  final double? averageRating;

  factory ProviderReviewSummary.fromJson(Map<String, dynamic> json) =>
      ProviderReviewSummary(
        count: json['count'] as int? ?? 0,
        averageRating: (json['average_rating'] as num?)?.toDouble(),
      );
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  throw const FormatException('Expected JSON object');
}

DateTime _date(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();

DateTime? _nullableDate(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
