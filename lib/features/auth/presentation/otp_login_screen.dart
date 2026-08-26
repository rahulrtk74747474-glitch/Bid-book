import 'package:bid_book/core/theme/app_theme.dart';
import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

class OtpLoginScreen extends ConsumerStatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  ConsumerState<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends ConsumerState<OtpLoginScreen> {
  static const _googleServerClientId = String.fromEnvironment('BIDBOOK_GOOGLE_SERVER_CLIENT_ID');

  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  int _mode = 0;
  bool _createAccount = false;
  bool _obscure = true;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _google() async {
    try {
      if (_googleServerClientId.trim().isEmpty) {
        ref.read(remoteAuthControllerProvider.notifier).showError(
              'Google sign-in needs the production Google OAuth client ID. Phone and email login are ready now.',
            );
        return;
      }
      final account = await GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: _googleServerClientId,
      ).signIn();
      if (account == null) return;
      final auth = await account.authentication;
      final token = auth.idToken;
      if (token == null || token.isEmpty) {
        ref.read(remoteAuthControllerProvider.notifier).showError('Google did not return an ID token.');
        return;
      }
      await ref.read(remoteAuthControllerProvider.notifier).loginGoogle(token);
    } catch (_) {
      ref.read(remoteAuthControllerProvider.notifier).showError(
            'Google sign-in is not configured for this test build yet. Use phone or email.',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(remoteAuthControllerProvider);
    final auth = authAsync.asData?.value ?? const RemoteAuthState();
    if (authAsync.isLoading && authAsync.asData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 36),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.navyDeep, AppColors.navy, Color(0xFF0C4A8E)],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(34),
                    bottomRight: Radius.circular(34),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(Icons.handshake_outlined, size: 38, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text('Bid&Book', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 7),
                    const Text(
                      'Trusted providers. Transparent bidding. Secure bookings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFD7E8FF), fontSize: 15, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    const Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 9,
                      runSpacing: 8,
                      children: [
                        _TrustPill(icon: Icons.verified_user_outlined, text: 'Verified'),
                        _TrustPill(icon: Icons.gavel_outlined, text: 'Fair bidding'),
                        _TrustPill(icon: Icons.shield_outlined, text: 'Safer jobs'),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: auth.busy ? null : _google,
                        icon: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF4285F4))),
                        label: const Text('Continue with Google'),
                      ),
                      const SizedBox(height: 18),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('OR', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 0, icon: Icon(Icons.phone_android), label: Text('Phone')),
                          ButtonSegment(value: 1, icon: Icon(Icons.email_outlined), label: Text('Email')),
                        ],
                        selected: {_mode},
                        onSelectionChanged: auth.busy
                            ? null
                            : (value) {
                                ref.read(remoteAuthControllerProvider.notifier).clearError();
                                setState(() => _mode = value.first);
                              },
                      ),
                      const SizedBox(height: 20),
                      if (_mode == 0) _phoneForm(auth) else _emailForm(auth),
                      if (auth.errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F0),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFFD1D1)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFB42318), size: 20),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(auth.errorMessage!, style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      const Text(
                        'By continuing, you agree to Bid&Book’s Terms and Privacy Policy. Never share banking passwords or OTPs with providers.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.45),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneForm(RemoteAuthState auth) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Continue with mobile', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text('We’ll send a secure one-time code.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          TextField(
            controller: _phone,
            enabled: !auth.busy,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              prefixText: '+91 ',
              prefixIcon: Icon(Icons.phone_android),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: auth.busy ? null : () => ref.read(remoteAuthControllerProvider.notifier).requestOtp(_phone.text),
            icon: const Icon(Icons.sms_outlined),
            label: Text(auth.busy ? 'Please wait…' : auth.otpSent ? 'Resend OTP' : 'Send OTP'),
          ),
          if (auth.otpSent) ...[
            const SizedBox(height: 18),
            TextField(
              controller: _otp,
              enabled: !auth.busy,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: const InputDecoration(labelText: '6-digit OTP', prefixIcon: Icon(Icons.password_outlined)),
            ),
            if (auth.developmentOtp != null) ...[
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(14)),
                child: Text(
                  'Test OTP: ${auth.developmentOtp}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              onPressed: auth.busy ? null : () => ref.read(remoteAuthControllerProvider.notifier).verifyOtp(_otp.text),
              icon: const Icon(Icons.login),
              label: const Text('Verify & continue'),
            ),
          ],
        ],
      );

  Widget _emailForm(RemoteAuthState auth) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _createAccount ? 'Create your account' : 'Welcome back',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: auth.busy
                    ? null
                    : () {
                        ref.read(remoteAuthControllerProvider.notifier).clearError();
                        setState(() => _createAccount = !_createAccount);
                      },
                child: Text(_createAccount ? 'Log in' : 'Create account'),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _createAccount ? 'One account lets you book services and offer work.' : 'Sign in using your Bid&Book email.',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          if (_createAccount) ...[
            TextField(
              controller: _name,
              enabled: !auth.busy,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _email,
            enabled: !auth.busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            enabled: !auth.busy,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: _createAccount ? 'Password (8+ characters)' : 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: auth.busy
                ? null
                : () {
                    if (_createAccount) {
                      ref.read(remoteAuthControllerProvider.notifier).registerEmail(
                            displayName: _name.text,
                            email: _email.text,
                            password: _password.text,
                          );
                    } else {
                      ref.read(remoteAuthControllerProvider.notifier).loginEmail(
                            email: _email.text,
                            password: _password.text,
                          );
                    }
                  },
            icon: Icon(_createAccount ? Icons.person_add_alt_1 : Icons.login),
            label: Text(auth.busy ? 'Please wait…' : _createAccount ? 'Create Bid&Book account' : 'Log in with email'),
          ),
        ],
      );
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF8EE0B8)),
            const SizedBox(width: 5),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
