class ApiUser {
  const ApiUser({
    required this.id,
    required this.phone,
    required this.phoneVerified,
    required this.identityVerified,
    this.displayName,
  });

  final String id;
  final String phone;
  final String? displayName;
  final bool phoneVerified;
  final bool identityVerified;

  String get bestName =>
      displayName?.trim().isNotEmpty == true ? displayName!.trim() : phone;

  factory ApiUser.fromJson(Map<String, dynamic> json) => ApiUser(
        id: json['id'].toString(),
        phone: json['phone'] as String? ?? '',
        displayName: json['display_name'] as String?,
        phoneVerified: json['phone_verified'] as bool? ?? false,
        identityVerified: json['identity_verified'] as bool? ?? false,
      );
}

class OtpChallengeResult {
  const OtpChallengeResult({
    required this.challengeId,
    required this.expiresInSeconds,
    this.developmentOtp,
  });

  final String challengeId;
  final int expiresInSeconds;
  final String? developmentOtp;

  factory OtpChallengeResult.fromJson(Map<String, dynamic> json) =>
      OtpChallengeResult(
        challengeId: json['challenge_id'].toString(),
        expiresInSeconds: json['expires_in_seconds'] as int? ?? 300,
        developmentOtp: json['development_otp'] as String?,
      );
}

class AuthResult {
  const AuthResult({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final ApiUser user;
  final String accessToken;
  final String refreshToken;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        user: ApiUser.fromJson(_map(json['user'])),
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
      );
}

enum ApiProviderKind { individual, company }

extension ApiProviderKindX on ApiProviderKind {
  String get wireName => name;
  String get label => this == ApiProviderKind.individual
      ? 'Independent worker'
      : 'Company';
}

class ApiProvider {
  const ApiProvider({
    required this.id,
    required this.userId,
    required this.kind,
    required this.displayName,
    required this.serviceArea,
    required this.active,
    this.bio,
  });

  final String id;
  final String userId;
  final ApiProviderKind kind;
  final String displayName;
  final String serviceArea;
  final String? bio;
  final bool active;

  factory ApiProvider.fromJson(Map<String, dynamic> json) => ApiProvider(
        id: json['id'].toString(),
        userId: json['user_id'].toString(),
        kind: ApiProviderKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => ApiProviderKind.individual,
        ),
        displayName: json['display_name'] as String? ?? 'Provider',
        serviceArea: json['service_area'] as String? ?? '',
        bio: json['bio'] as String?,
        active: json['active'] as bool? ?? true,
      );
}

enum ApiPricingUnit { fixed, hourly, daily, perUnit, quote }

extension ApiPricingUnitX on ApiPricingUnit {
  String get wireName => this == ApiPricingUnit.perUnit ? 'per_unit' : name;
  String get label => switch (this) {
        ApiPricingUnit.fixed => 'Fixed price',
        ApiPricingUnit.hourly => 'Per hour',
        ApiPricingUnit.daily => 'Per day',
        ApiPricingUnit.perUnit => 'Per unit',
        ApiPricingUnit.quote => 'Quote required',
      };

  static ApiPricingUnit fromWire(Object? value) {
    if (value == 'per_unit') return ApiPricingUnit.perUnit;
    return ApiPricingUnit.values.firstWhere(
      (item) => item.name == value,
      orElse: () => ApiPricingUnit.fixed,
    );
  }
}

class ApiService {
  const ApiService({
    required this.id,
    required this.providerId,
    required this.title,
    required this.category,
    required this.description,
    required this.area,
    required this.pricePaise,
    required this.pricingUnit,
    required this.active,
    required this.createdAt,
  });

  final String id;
  final String providerId;
  final String title;
  final String category;
  final String description;
  final String area;
  final int pricePaise;
  final ApiPricingUnit pricingUnit;
  final bool active;
  final DateTime createdAt;

  double get priceRupees => pricePaise / 100;
  String get providerLabel => 'Provider ${_shortId(providerId)}';

  factory ApiService.fromJson(Map<String, dynamic> json) => ApiService(
        id: json['id'].toString(),
        providerId: json['provider_id'].toString(),
        title: json['title'] as String? ?? '',
        category: json['category'] as String? ?? '',
        description: json['description'] as String? ?? '',
        area: json['area'] as String? ?? '',
        pricePaise: json['price_paise'] as int? ?? 0,
        pricingUnit: ApiPricingUnitX.fromWire(json['pricing_unit']),
        active: json['active'] as bool? ?? true,
        createdAt: _date(json['created_at']),
      );
}

enum ApiRequestStatus { bidding, booked, completed, cancelled }

class ApiRequest {
  const ApiRequest({
    required this.id,
    required this.createdByUserId,
    required this.title,
    required this.category,
    required this.description,
    required this.area,
    required this.requestedFor,
    required this.status,
    required this.createdAt,
    this.groupId,
    this.acceptedBidEventId,
    this.bookingId,
  });

  final String id;
  final String createdByUserId;
  final String? groupId;
  final String title;
  final String category;
  final String description;
  final String area;
  final DateTime requestedFor;
  final ApiRequestStatus status;
  final String? acceptedBidEventId;
  final String? bookingId;
  final DateTime createdAt;

  factory ApiRequest.fromJson(Map<String, dynamic> json) => ApiRequest(
        id: json['id'].toString(),
        createdByUserId: json['created_by_user_id'].toString(),
        groupId: json['group_id']?.toString(),
        title: json['title'] as String? ?? '',
        category: json['category'] as String? ?? '',
        description: json['description'] as String? ?? '',
        area: json['area'] as String? ?? '',
        requestedFor: _date(json['requested_for']),
        status: ApiRequestStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => ApiRequestStatus.bidding,
        ),
        acceptedBidEventId: json['accepted_bid_event_id']?.toString(),
        bookingId: json['booking_id']?.toString(),
        createdAt: _date(json['created_at']),
      );
}

class ApiBid {
  const ApiBid({
    required this.id,
    required this.requestId,
    required this.providerId,
    required this.amountPaise,
    required this.submittedAt,
    required this.isCurrentOffer,
    this.note,
    this.previousBidEventId,
  });

  final String id;
  final String requestId;
  final String providerId;
  final int amountPaise;
  final String? note;
  final String? previousBidEventId;
  final DateTime submittedAt;
  final bool isCurrentOffer;

  double get amountRupees => amountPaise / 100;
  bool get isRevision => previousBidEventId != null;
  String get providerLabel => 'Provider ${_shortId(providerId)}';

  factory ApiBid.fromJson(Map<String, dynamic> json) => ApiBid(
        id: json['id'].toString(),
        requestId: json['request_id'].toString(),
        providerId: json['provider_id'].toString(),
        amountPaise: json['amount_paise'] as int? ?? 0,
        note: json['note'] as String?,
        previousBidEventId: json['previous_bid_event_id']?.toString(),
        submittedAt: _date(json['submitted_at']),
        isCurrentOffer: json['is_current_offer'] as bool? ?? false,
      );
}

enum ApiBookingStatus { confirmed, inProgress, completed, cancelled }

class ApiBooking {
  const ApiBooking({
    required this.id,
    required this.customerUserId,
    required this.providerId,
    required this.agreedAmountPaise,
    required this.scheduledFor,
    required this.area,
    required this.status,
    required this.createdAt,
    this.serviceListingId,
    this.requestId,
    this.acceptedBidEventId,
  });

  final String id;
  final String customerUserId;
  final String providerId;
  final String? serviceListingId;
  final String? requestId;
  final String? acceptedBidEventId;
  final int agreedAmountPaise;
  final DateTime scheduledFor;
  final String area;
  final ApiBookingStatus status;
  final DateTime createdAt;

  double get agreedAmountRupees => agreedAmountPaise / 100;

  factory ApiBooking.fromJson(Map<String, dynamic> json) => ApiBooking(
        id: json['id'].toString(),
        customerUserId: json['customer_user_id'].toString(),
        providerId: json['provider_id'].toString(),
        serviceListingId: json['service_listing_id']?.toString(),
        requestId: json['request_id']?.toString(),
        acceptedBidEventId: json['accepted_bid_event_id']?.toString(),
        agreedAmountPaise: json['agreed_amount_paise'] as int? ?? 0,
        scheduledFor: _date(json['scheduled_for']),
        area: json['area'] as String? ?? '',
        status: switch (json['status']) {
          'in_progress' => ApiBookingStatus.inProgress,
          'completed' => ApiBookingStatus.completed,
          'cancelled' => ApiBookingStatus.cancelled,
          _ => ApiBookingStatus.confirmed,
        },
        createdAt: _date(json['created_at']),
      );
}

class ApiGroup {
  const ApiGroup({
    required this.id,
    required this.name,
    required this.area,
    required this.ownerUserId,
    required this.inviteCode,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String area;
  final String ownerUserId;
  final String inviteCode;
  final DateTime createdAt;

  factory ApiGroup.fromJson(Map<String, dynamic> json) => ApiGroup(
        id: json['id'].toString(),
        name: json['name'] as String? ?? '',
        area: json['area'] as String? ?? '',
        ownerUserId: json['owner_user_id'].toString(),
        inviteCode: json['invite_code'] as String? ?? '',
        createdAt: _date(json['created_at']),
      );
}

enum ApiProposalStatus { voting, published, closed }
enum ApiVoteChoice { accept, reject, maybe }

class ApiProposal {
  const ApiProposal({
    required this.id,
    required this.groupId,
    required this.createdByUserId,
    required this.title,
    required this.category,
    required this.description,
    required this.preferredFor,
    required this.status,
    required this.createdAt,
    this.publishedRequestId,
  });

  final String id;
  final String groupId;
  final String createdByUserId;
  final String title;
  final String category;
  final String description;
  final DateTime preferredFor;
  final ApiProposalStatus status;
  final String? publishedRequestId;
  final DateTime createdAt;

  factory ApiProposal.fromJson(Map<String, dynamic> json) => ApiProposal(
        id: json['id'].toString(),
        groupId: json['group_id'].toString(),
        createdByUserId: json['created_by_user_id'].toString(),
        title: json['title'] as String? ?? '',
        category: json['category'] as String? ?? '',
        description: json['description'] as String? ?? '',
        preferredFor: _date(json['preferred_for']),
        status: ApiProposalStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => ApiProposalStatus.voting,
        ),
        publishedRequestId: json['published_request_id']?.toString(),
        createdAt: _date(json['created_at']),
      );
}

class ApiProposalSummary {
  const ApiProposalSummary({
    required this.acceptCount,
    required this.rejectCount,
    required this.maybeCount,
    required this.acceptedQuantity,
  });

  final int acceptCount;
  final int rejectCount;
  final int maybeCount;
  final int acceptedQuantity;

  factory ApiProposalSummary.fromJson(Map<String, dynamic> json) =>
      ApiProposalSummary(
        acceptCount: json['accept_count'] as int? ?? 0,
        rejectCount: json['reject_count'] as int? ?? 0,
        maybeCount: json['maybe_count'] as int? ?? 0,
        acceptedQuantity: json['accepted_quantity'] as int? ?? 0,
      );
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  throw const FormatException('Expected a JSON object');
}

DateTime _date(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();

String _shortId(String value) =>
    value.length <= 8 ? value : value.substring(0, 8).toUpperCase();
