import 'package:flutter_riverpod/flutter_riverpod.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class SessionUser {
  const SessionUser({
    required this.id,
    required this.phoneNumber,
  });

  final String id;
  final String phoneNumber;
}

class AuthState {
  const AuthState({
    this.pendingPhoneNumber,
    this.user,
    this.errorMessage,
  });

  final String? pendingPhoneNumber;
  final SessionUser? user;
  final String? errorMessage;

  bool get otpSent => pendingPhoneNumber != null;
  bool get isAuthenticated => user != null;
}

class AuthController extends Notifier<AuthState> {
  static const developmentOtp = '123456';

  @override
  AuthState build() => const AuthState();

  bool requestOtp(String rawPhoneNumber) {
    final digits = rawPhoneNumber.replaceAll(RegExp(r'\D'), '');
    final localNumber = digits.length > 10
        ? digits.substring(digits.length - 10)
        : digits;

    if (localNumber.length != 10) {
      state = const AuthState(
        errorMessage: 'Enter a valid 10-digit mobile number.',
      );
      return false;
    }

    state = AuthState(pendingPhoneNumber: '+91$localNumber');
    return true;
  }

  bool verifyOtp(String otp) {
    final phoneNumber = state.pendingPhoneNumber;
    if (phoneNumber == null) {
      state = const AuthState(errorMessage: 'Request an OTP first.');
      return false;
    }

    if (otp.trim() != developmentOtp) {
      state = AuthState(
        pendingPhoneNumber: phoneNumber,
        errorMessage: 'Incorrect OTP. Try again.',
      );
      return false;
    }

    state = AuthState(
      user: SessionUser(
        id: 'user-demo',
        phoneNumber: phoneNumber,
      ),
    );
    return true;
  }

  void signOut() {
    state = const AuthState();
  }
}
