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
    required this.title,
    required this.category,
    required this.area,
    required this.requestedFor,
    required this.status,
    required this.createdByName,
    this.groupName,
    this.interestedMembers = 0,
  });

  final String id;
  final String title;
  final String category;
  final String area;
  final DateTime requestedFor;
  final ServiceRequestStatus status;
  final String createdByName;
  final String? groupName;
  final int interestedMembers;
}
