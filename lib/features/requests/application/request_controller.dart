import 'package:bid_book/features/requests/domain/service_request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final serviceRequestsProvider =
    NotifierProvider<ServiceRequestController, List<ServiceRequest>>(
  ServiceRequestController.new,
);

class ServiceRequestController extends Notifier<List<ServiceRequest>> {
  static const _uuid = Uuid();

  @override
  List<ServiceRequest> build() => List.unmodifiable(_seed);

  ServiceRequest createRequest({
    required String createdByUserId,
    required String createdByName,
    required String title,
    required String category,
    required String description,
    required String area,
    required DateTime requestedFor,
  }) {
    if (title.trim().length < 3) {
      throw ArgumentError.value(title, 'title', 'Title is too short');
    }
    if (area.trim().length < 2) {
      throw ArgumentError.value(area, 'area', 'Area is required');
    }

    final request = ServiceRequest(
      id: _uuid.v4(),
      createdByUserId: createdByUserId,
      createdByName: createdByName.trim().isEmpty ? 'Customer' : createdByName.trim(),
      title: title.trim(),
      category: category.trim(),
      description: description.trim(),
      area: area.trim(),
      requestedFor: requestedFor,
      status: ServiceRequestStatus.bidding,
    );

    state = List.unmodifiable([request, ...state]);
    return request;
  }

  void markBooked({
    required String requestId,
    required String bidEventId,
    required String bookingId,
  }) {
    final index = state.indexWhere((request) => request.id == requestId);
    if (index == -1) {
      throw StateError('Service request not found.');
    }
    final request = state[index];
    if (request.status != ServiceRequestStatus.bidding) {
      throw StateError('Only an open bidding request can be booked.');
    }

    final updated = request.copyWith(
      status: ServiceRequestStatus.booked,
      acceptedBidEventId: bidEventId,
      bookingId: bookingId,
    );
    final next = [...state];
    next[index] = updated;
    state = List.unmodifiable(next);
  }

  static final _seed = [
    ServiceRequest(
      id: 'req-ac-001',
      createdByUserId: 'user-demo',
      createdByName: 'Group Admin',
      title: 'Bulk AC servicing for residents',
      category: 'AC Service',
      description: 'General AC servicing for participating Green Residency homes.',
      area: 'Sector 15, Sonipat',
      requestedFor: DateTime(2026, 9, 10, 9),
      status: ServiceRequestStatus.bidding,
      groupName: 'Green Residency',
      interestedMembers: 47,
    ),
    ServiceRequest(
      id: 'req-plumber-002',
      createdByUserId: 'user-amit',
      createdByName: 'Amit',
      title: 'Kitchen sink leakage repair',
      category: 'Plumber',
      description: 'Leak below the kitchen sink. Need inspection and repair.',
      area: 'Model Town, Sonipat',
      requestedFor: DateTime(2026, 8, 26, 11),
      status: ServiceRequestStatus.bidding,
    ),
  ];
}
