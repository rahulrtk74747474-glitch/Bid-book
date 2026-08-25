import 'dart:async';

import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/features/trust/domain/trust_models.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentCheckout {
  PaymentCheckout() : _razorpay = Razorpay() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);
  }

  static const _keyId = String.fromEnvironment('BIDBOOK_RAZORPAY_KEY_ID');
  final Razorpay _razorpay;
  Completer<void>? _active;

  Future<void> open({
    required TrustPayment payment,
    String? customerName,
    String? customerPhone,
  }) async {
    if (payment.gateway != 'razorpay') {
      throw const ApiException('This payment is not a Razorpay payment.');
    }
    if (_keyId.isEmpty) {
      throw const ApiException(
        'This release is missing the Razorpay public key configuration.',
      );
    }
    if (_active != null) {
      throw const ApiException('A payment window is already open.');
    }
    final completer = Completer<void>();
    _active = completer;
    try {
      _razorpay.open({
        'key': _keyId,
        'amount': payment.amountPaise,
        'currency': payment.currency,
        'name': 'Bid&Book',
        'description': 'Booking payment',
        'order_id': payment.gatewayReference,
        'prefill': {
          if (customerName?.trim().isNotEmpty == true) 'name': customerName!.trim(),
          if (customerPhone?.trim().isNotEmpty == true) 'contact': customerPhone!.trim(),
        },
        'theme': {'hide_topbar': false},
      });
      return await completer.future;
    } catch (error) {
      if (!completer.isCompleted) completer.completeError(error);
      rethrow;
    } finally {
      if (identical(_active, completer)) _active = null;
    }
  }

  void _onSuccess(PaymentSuccessResponse response) {
    final completer = _active;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _onError(PaymentFailureResponse response) {
    final completer = _active;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        ApiException(response.message ?? 'Payment was not completed.'),
      );
    }
  }

  void _onWallet(ExternalWalletResponse response) {
    // Razorpay continues the external-wallet flow; server webhooks remain the
    // source of truth for capture status.
  }

  void dispose() => _razorpay.clear();
}
