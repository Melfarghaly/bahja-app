import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/providers.dart';
import '../../core/models/pickup.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// The guardian's rotating QR: fetched again every `refresh_after` seconds
/// while the screen is open (a screenshot stops working after a minute).
class PickupCodeScreen extends ConsumerStatefulWidget {
  const PickupCodeScreen({super.key});

  @override
  ConsumerState<PickupCodeScreen> createState() => _PickupCodeScreenState();
}

class _PickupCodeScreenState extends ConsumerState<PickupCodeScreen> {
  PickupCode? _code;
  Object? _error;
  Timer? _refresh;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _refresh?.cancel();
    try {
      final code = await ref.read(guardianRepositoryProvider).pickupCode();
      if (!mounted) return;
      setState(() {
        _code = code;
        _error = null;
      });
      _refresh = Timer(Duration(seconds: code.refreshAfter), _load);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      _refresh = Timer(const Duration(seconds: 10), _load);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final code = _code;
    final secondsLeft = code == null
        ? 0
        : code.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 999);

    return Scaffold(
      appBar: AppBar(title: Text(s.pickupCode)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: code == null
              ? (_error != null
                    ? ErrorView(error: _error!, onRetry: _load)
                    : const CircularProgressIndicator())
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: QrImageView(
                          key: ValueKey(code.token),
                          data: code.token,
                          size: 260,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: AppColors.teal,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: AppColors.teal,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: secondsLeft / 60,
                      color: AppColors.coral,
                      backgroundColor: Colors.black12,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.pickupCodeHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
