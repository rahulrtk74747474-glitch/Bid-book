enum ProviderKind { individual, company }

extension ProviderKindLabel on ProviderKind {
  String get label => switch (this) {
        ProviderKind.individual => 'Independent worker',
        ProviderKind.company => 'Company',
      };
}

class ProviderProfile {
  const ProviderProfile({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.kind,
    required this.serviceArea,
    required this.identityVerified,
    required this.rating,
    required this.completedJobs,
  });

  final String id;
  final String userId;
  final String displayName;
  final ProviderKind kind;
  final String serviceArea;
  final bool identityVerified;
  final double rating;
  final int completedJobs;
}
