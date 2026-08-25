import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/core/api/bidbook_api.dart';
import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final remoteGroupControllerProvider = AsyncNotifierProvider<RemoteGroupController, RemoteGroupState>(RemoteGroupController.new);

class ProposalKey {
  const ProposalKey(this.groupId, this.proposalId);
  final String groupId;
  final String proposalId;
  @override
  bool operator ==(Object other) => other is ProposalKey && other.groupId == groupId && other.proposalId == proposalId;
  @override
  int get hashCode => Object.hash(groupId, proposalId);
}

final proposalSummaryProvider = FutureProvider.family<ApiProposalSummary, ProposalKey>((ref, key) async {
  ref.watch(remoteGroupControllerProvider);
  return ref.read(bidBookApiProvider).proposalSummary(groupId: key.groupId, proposalId: key.proposalId);
});

class RemoteGroupState {
  const RemoteGroupState({this.groups = const [], this.proposalsByGroup = const {}});
  final List<ApiGroup> groups;
  final Map<String, List<ApiProposal>> proposalsByGroup;
  RemoteGroupState copyWith({List<ApiGroup>? groups, Map<String, List<ApiProposal>>? proposalsByGroup}) => RemoteGroupState(
        groups: groups ?? this.groups,
        proposalsByGroup: proposalsByGroup ?? this.proposalsByGroup,
      );
}

class RemoteGroupController extends AsyncNotifier<RemoteGroupState> {
  BidBookApi get _api => ref.read(bidBookApiProvider);

  @override
  Future<RemoteGroupState> build() async {
    final auth = ref.watch(remoteAuthControllerProvider).asData?.value;
    if (auth?.isAuthenticated != true) return const RemoteGroupState();
    return RemoteGroupState(groups: await _api.groups());
  }

  Future<void> refreshGroups() async {
    final current = state.asData?.value ?? const RemoteGroupState();
    state = AsyncData(current.copyWith(groups: await _api.groups()));
  }

  Future<ApiGroup> createGroup({required String name, required String area}) async {
    final group = await _api.createGroup(name: name, area: area);
    final current = state.asData?.value ?? const RemoteGroupState();
    state = AsyncData(current.copyWith(groups: [group, ...current.groups]));
    return group;
  }

  Future<void> joinGroup(String inviteCode) async {
    await _api.joinGroup(inviteCode.trim());
    await refreshGroups();
  }

  Future<List<ApiProposal>> loadProposals(String groupId) async {
    final proposals = await _api.proposals(groupId);
    final current = state.asData?.value ?? const RemoteGroupState();
    final map = Map<String, List<ApiProposal>>.from(current.proposalsByGroup)..[groupId] = proposals;
    state = AsyncData(current.copyWith(proposalsByGroup: map));
    return proposals;
  }

  Future<ApiProposal> createProposal({required String groupId, required String title, required String category, required String description, required DateTime preferredFor}) async {
    final proposal = await _api.createProposal(groupId: groupId, title: title, category: category, description: description, preferredFor: preferredFor);
    await loadProposals(groupId);
    return proposal;
  }

  Future<void> vote({required String groupId, required String proposalId, required ApiVoteChoice choice, required int quantity}) async {
    await _api.vote(groupId: groupId, proposalId: proposalId, choice: choice, quantity: quantity);
    ref.invalidate(proposalSummaryProvider(ProposalKey(groupId, proposalId)));
  }

  Future<ApiRequest> publish({required String groupId, required String proposalId}) async {
    final request = await _api.publishProposal(groupId: groupId, proposalId: proposalId);
    await loadProposals(groupId);
    ref.invalidate(remoteMarketplaceProvider);
    ref.invalidate(proposalSummaryProvider(ProposalKey(groupId, proposalId)));
    return request;
  }
}
