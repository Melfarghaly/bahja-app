import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/network/api_exception.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';
import '../home/splash_screen.dart';

/// Staff sign in with a password; parents usually with an SMS code.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();

  bool _otpMode = false;
  bool _codeSent = false;
  bool _busy = false;
  int _resendIn = 0;
  Timer? _timer;
  ApiException? _error;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_login, _password, _phone, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    final sent = await ref.read(authRepositoryProvider).requestOtp(_phone.text);
    if (!mounted) return;
    showMessage(context, sent.message);
    setState(() {
      _codeSent = true;
      _resendIn = sent.resendAfter;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _resendIn <= 1) {
        t.cancel();
        if (mounted) setState(() => _resendIn = 0);
      } else {
        setState(() => _resendIn--);
      }
    });
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final session = ref.read(sessionControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: BahgaMark(size: 64)),
                    const SizedBox(height: 20),
                    Text(
                      s.welcome,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.welcomeSub,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 32),
                    if (!_otpMode) ...[
                      TextField(
                        key: const Key('login'),
                        controller: _login,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        decoration: InputDecoration(
                          labelText: s.loginField,
                          errorText: _error?.fieldError('login'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('password'),
                        controller: _password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: s.password,
                          errorText: _error?.fieldError('password'),
                        ),
                        onSubmitted: (_) => _run(
                          () => session.loginWithPassword(
                            _login.text,
                            _password.text,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        key: const Key('sign-in'),
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => session.loginWithPassword(
                                  _login.text,
                                  _password.text,
                                ),
                              ),
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(s.signIn),
                      ),
                    ] else ...[
                      TextField(
                        key: const Key('phone'),
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        enabled: !_codeSent,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: InputDecoration(
                          labelText: s.phone,
                          hintText: '01xxxxxxxxx',
                          errorText: _error?.fieldError('phone'),
                        ),
                      ),
                      if (_codeSent) ...[
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('code'),
                          controller: _code,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          decoration: InputDecoration(
                            labelText: s.code,
                            errorText: _error?.fieldError('code'),
                          ),
                        ),
                        TextButton(
                          onPressed: _resendIn > 0 || _busy ? null : _sendCode,
                          child: Text(
                            _resendIn > 0 ? s.resendIn(_resendIn) : s.resend,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : (_codeSent
                                  ? () => _run(
                                      () => session.loginWithOtp(
                                        _phone.text,
                                        _code.text,
                                      ),
                                    )
                                  : _sendCode),
                        child: Text(_codeSent ? s.verify : s.sendCode),
                      ),
                    ],
                    if (_error != null && _error!.fieldErrors.isEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() {
                        _otpMode = !_otpMode;
                        _error = null;
                      }),
                      child: Text(
                        _otpMode ? s.signInWithPassword : s.signInWithSms,
                      ),
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
}
