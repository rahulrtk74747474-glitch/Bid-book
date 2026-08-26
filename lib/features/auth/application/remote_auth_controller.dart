import 'dart:async';

import 'package:bid_book/core/api/api_client.dart';
import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/core/api/bidbook_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final remoteAuthControllerProvider =
    AsyncNotifierProvider<RemoteAuthController, RemoteAuthState>(RemoteAuthController.new);

class RemoteAuthState {
  const RemoteAuthState({
    this.user,
    this.pendingPhone,
    this.challengeId,
    this.developmentOtp,
    this.otpExpiresInSeconds,
    this.busy = false,
    this.errorMessage,
  });

  final ApiUser? user;
  final String? pendingPhone;
  final String? challengeId;
  final String? developmentOtp;
  final int? otpExpiresInSeconds;
  final bool busy;
  final String? errorMessage;

  bool get isAuthenticated => user != null;
  bool get otpSent => challengeId != null;

  RemoteAuthState copyWith({
    ApiUser? user,
    String? pendingPhone,
    String? challengeId,
    String? developmentOtp,
    int? otpExpiresInSeconds,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
    bool clearOtp = false,
    bool clearUser = false,
  }) =>
      RemoteAuthState(
        user: clearUser ? null : user ?? this.user,
        pendingPhone: clearOtp ? null : pendingPhone ?? this.pendingPhone,
        challengeId: clearOtp ? null : challengeId ?? this.challengeId,
        developmentOtp: clearOtp ? null : developmentOtp ?? this.developmentOtp,
        otpExpiresInSeconds: clearOtp ? null : otpExpiresInSeconds ?? this.otpExpiresInSeconds,
        busy: busy ?? this.busy,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      );
}

class RemoteAuthController extends AsyncNotifier<RemoteAuthState> {
  StreamSubscription<void>? _expiredSubscription;
  BidBookApi get _api => ref.read(bidBookApiProvider);

  @override
  Future<RemoteAuthState> build() async {
    _expiredSubscription ??= ref.read(apiClientProvider).sessionExpired.listen((_) {
      state = const AsyncData(RemoteAuthState(errorMessage: 'Your session expired. Sign in again.'));
    });
    ref.onDispose(() => _expiredSubscription?.cancel());
    try {
      if (!await _api.hasSavedSession()) return const RemoteAuthState();
      return RemoteAuthState(user: await _api.me());
    } catch (_) {
      await _api.logout();
      return const RemoteAuthState();
    }
  }

  Future<bool> requestOtp(String rawPhone) async {
    final current = state.asData?.value ?? const RemoteAuthState();
    state = AsyncData(current.copyWith(busy: true, clearError: true));
    try {
      final result = await _api.requestOtp(rawPhone.trim());
      state = AsyncData(RemoteAuthState(
        pendingPhone: rawPhone.trim(),
        challengeId: result.challengeId,
        developmentOtp: result.developmentOtp,
        otpExpiresInSeconds: result.expiresInSeconds,
      ));
      return true;
    } on ApiException catch (error) {
      state = AsyncData(current.copyWith(busy: false, errorMessage: error.message));
      return false;
    } catch (_) {
      state = AsyncData(current.copyWith(busy: false, errorMessage: 'Unable to reach Bid&Book. Try again.'));
      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    final current = state.asData?.value ?? const RemoteAuthState();
    final challengeId = current.challengeId;
    if (challengeId == null) {
      state = const AsyncData(RemoteAuthState(errorMessage: 'Request an OTP first.'));
      return false;
    }
    state = AsyncData(current.copyWith(busy: true, clearError: true));
    try {
      final result = await _api.verifyOtp(challengeId: challengeId, otp: otp.trim());
      state = AsyncData(RemoteAuthState(user: result.user));
      return true;
    } on ApiException catch (error) {
      state = AsyncData(current.copyWith(busy: false, errorMessage: error.message));
      return false;
    }
  }

  Future<bool> registerEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final current = state.asData?.value ?? const RemoteAuthState();
    state = AsyncData(current.copyWith(busy: true, clearError: true, clearOtp: true));
    try {
      final result = await _api.registerEmail(
        displayName: displayName.trim(),
        email: email.trim(),
        password: password,
      );
      state = AsyncData(RemoteAuthState(user: result.user));
      return true;
    } on ApiException catch (error) {
      state = AsyncData(current.copyWith(busy: false, errorMessage: error.message));
      return false;
    }
  }

  Future<bool> loginEmail({required String email, required String password}) async {
    final current = state.asData?.value ?? const RemoteAuthState();
    state = AsyncData(current.copyWith(busy: true, clearError: true, clearOtp: true));
    try {
      final result = await _api.loginEmail(email: email.trim(), password: password);
      state = AsyncData(RemoteAuthState(user: result.user));
      return true;
    } on ApiException catch (error) {
      state = AsyncData(current.copyWith(busy: false, errorMessage: error.message));
      return false;
    }
  }

  Future<bool> loginGoogle(String idToken) async {
    final current = state.asData?.value ?? const RemoteAuthState();
    state = AsyncData(current.copyWith(busy: true, clearError: true, clearOtp: true));
    try {
      final result = await _api.loginGoogle(idToken);
      state = AsyncData(RemoteAuthState(user: result.user));
      return true;
    } on ApiException catch (error) {
      state = AsyncData(current.copyWith(busy: false, errorMessage: error.message));
      return false;
    }
  }

  void showError(String message) {
    final current = state.asData?.value ?? const RemoteAuthState();
    state = AsyncData(current.copyWith(busy: false, errorMessage: message));
  }

  void clearError() {
    final current = state.asData?.value ?? const RemoteAuthState();
    state = AsyncData(current.copyWith(clearError: true));
  }

  Future<void> signOut() async {
    final current = state.asData?.value ?? const RemoteAuthState();
    state = AsyncData(current.copyWith(busy: true, clearError: true));
    await _api.logout();
    state = const AsyncData(RemoteAuthState());
  }
}
