import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OtpLoginScreen extends ConsumerStatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  ConsumerState<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends ConsumerState<OtpLoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(remoteAuthControllerProvider);
    final auth = authAsync.asData?.value ?? const RemoteAuthState();
    final booting = authAsync.isLoading && authAsync.asData == null;

    if (booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.handshake_outlined, size: 64),
                  const SizedBox(height: 18),
                  Text(
                    'Bid&Book',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'One account to book local services, offer work and manage neighborhood buying groups.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _phoneController,
                    enabled: !auth.busy,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile number',
                      prefixText: '+91 ',
                      prefixIcon: Icon(Icons.phone_android),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: auth.busy
                        ? null
                        : () => ref
                            .read(remoteAuthControllerProvider.notifier)
                            .requestOtp(_phoneController.text),
                    child: Text(auth.busy
                        ? 'Please wait…'
                        : auth.otpSent
                            ? 'Resend OTP'
                            : 'Send OTP'),
                  ),
                  if (auth.otpSent) ...[
                    const SizedBox(height: 24),
                    TextField(
                      controller: _otpController,
                      enabled: !auth.busy,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: const InputDecoration(
                        labelText: '6-digit OTP',
                        prefixIcon: Icon(Icons.password_outlined),
                      ),
                    ),
                    if (auth.developmentOtp != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            'Development server OTP: ${auth.developmentOtp}. This value is returned only when the backend explicitly enables development OTP exposure.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    FilledButton.icon(
                      onPressed: auth.busy
                          ? null
                          : () => ref
                              .read(remoteAuthControllerProvider.notifier)
                              .verifyOtp(_otpController.text),
                      icon: const Icon(Icons.login),
                      label: const Text('Verify & continue'),
                    ),
                  ],
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      auth.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
