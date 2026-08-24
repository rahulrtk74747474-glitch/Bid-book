import 'package:bid_book/features/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('development OTP flow validates phone and creates a session', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);
    expect(controller.requestOtp('9876543210'), isTrue);
    expect(container.read(authControllerProvider).pendingPhoneNumber, '+919876543210');

    expect(controller.verifyOtp('000000'), isFalse);
    expect(container.read(authControllerProvider).isAuthenticated, isFalse);

    expect(controller.verifyOtp(AuthController.developmentOtp), isTrue);
    final state = container.read(authControllerProvider);
    expect(state.isAuthenticated, isTrue);
    expect(state.user?.id, 'user-demo');
  });

  test('invalid phone number is rejected', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = container
        .read(authControllerProvider.notifier)
        .requestOtp('123');
    expect(result, isFalse);
    expect(container.read(authControllerProvider).otpSent, isFalse);
  });
}
