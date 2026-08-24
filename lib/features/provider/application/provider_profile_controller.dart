import 'package:bid_book/features/provider/domain/provider_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final providerProfileProvider =
    NotifierProvider<ProviderProfileController, ProviderProfile?>(
  ProviderProfileController.new,
);

class ProviderProfileController extends Notifier<ProviderProfile?> {
  static const _uuid = Uuid();

  @override
  ProviderProfile? build() => null;

  ProviderProfile saveProfile({
    required String userId,
    required String displayName,
    required ProviderKind kind,
    required String serviceArea,
  }) {
    final cleanName = displayName.trim();
    final cleanArea = serviceArea.trim();
    if (cleanName.length < 2) {
      throw ArgumentError.value(displayName, 'displayName', 'Name is too short');
    }
    if (cleanArea.length < 2) {
      throw ArgumentError.value(serviceArea, 'serviceArea', 'Area is required');
    }

    final profile = ProviderProfile(
      id: state?.id ?? _uuid.v4(),
      userId: userId,
      displayName: cleanName,
      kind: kind,
      serviceArea: cleanArea,
      identityVerified: state?.identityVerified ?? false,
      rating: state?.rating ?? 0,
      completedJobs: state?.completedJobs ?? 0,
    );
    state = profile;
    return profile;
  }
}
