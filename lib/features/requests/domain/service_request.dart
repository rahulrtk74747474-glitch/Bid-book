enum ServiceRequestStatus {
  collectingInterest,
  bidding,
  awarded,
  booked,
  completed,
}

class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.createdByUserId,
    required this.createdByName,
    required this.title,
    required this.category,
    required this.description,
    required this.area,
    required this.requestedFor,
    required this.status,
    this.groupName,
    this.interestedMembers = 0,
    this.acceptedBidEventId,
    this.bookingId,
  });

  final String id;
  final String createdByUserId;
  final String createdByName;
  final String title;
  final String category;
  final String description;
  final String area;
  final DateTime requestedFor;
  final ServiceRequestStatus status;
  final String? groupName;
  final int interestedMembers;
  final String? acceptedBidEventId;
  final String? bookingId;

  ServiceRequest copyWith({
    ServiceRequestStatus? status,
    String? acceptedBidEventId,
    String? bookingId,
  }) {
    return ServiceRequest(
      id: id,
      createdByUserId: createdByUserId,
      createdByName: createdByName,
      title: title,
      category: category,
      description: description,
      area: area,
      requestedFor: requestedFor,
      status: status ?? this.status,
      groupName: groupName,
      interestedMembers: interestedMembers,
      acceptedBidEventId: acceptedBidEventId ?? this.acceptedBidEventId,
      bookingId: bookingId ?? this.bookingId,
    );
  }
}
