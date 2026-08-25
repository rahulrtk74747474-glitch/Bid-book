import 'package:bid_book/core/api/api_exception.dart';
import 'package:bid_book/features/operations/presentation/admin_operations_screen.dart';
import 'package:bid_book/features/production/data/production_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminMfaGateScreen extends ConsumerStatefulWidget {
  const AdminMfaGateScreen({super.key});

  @override
  ConsumerState<AdminMfaGateScreen> createState() => _AdminMfaGateScreenState();
}

class _AdminMfaGateScreenState extends ConsumerState<AdminMfaGateScreen> {
  final _code = TextEditingController();
  bool _verified = false;
  bool _busy = false;
  String? _error;

  Future<void> _verify() async {
    if (_busy || _code.text.trim().length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(productionApiProvider).adminStepUp(_code.text.trim());
      if (mounted) setState(() => _verified = true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is ApiException ? error.message : error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_verified) return const AdminOperationsScreen();
    return Scaffold(
      appBar: AppBar(title: const Text('Admin verification')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.admin_panel_settings_outlined, size: 52),
                    const SizedBox(height: 14),
                    Text(
                      'Operations step-up',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter the six-digit code from the administrator authenticator. This is separate from phone OTP and expires quickly.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _code,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      onSubmitted: (_) => _verify(),
                      decoration: const InputDecoration(labelText: 'Authenticator code'),
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _verify,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_open_outlined),
                      label: const Text('Verify & open operations'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }
}
