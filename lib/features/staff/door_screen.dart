import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/providers.dart';
import '../../core/models/pickup.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// At the door: scan the guardian's QR (or type a pass code), see who it is
/// and which children they may take, then hand over with one tap.
class DoorScreen extends ConsumerStatefulWidget {
  const DoorScreen({super.key});

  @override
  ConsumerState<DoorScreen> createState() => _DoorScreenState();
}

class _DoorScreenState extends ConsumerState<DoorScreen> {
  final _passCode = TextEditingController();
  final _scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  PickupCheck? _check;
  String? _token;
  String? _code;
  bool _busy = false;
  final Set<int> _handedOver = {};

  @override
  void dispose() {
    _scanner.dispose();
    _passCode.dispose();
    super.dispose();
  }

  Future<void> _verify({String? token, String? code}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final check = await ref
          .read(staffRepositoryProvider)
          .verifyPickup(pickupToken: token, passCode: code);
      setState(() {
        _check = check;
        _token = token;
        _code = code;
        _handedOver.clear();
      });
      await _scanner.stop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handOver(PickupCheckChild child) async {
    final ok = await guarded(
      context,
      () => ref
          .read(staffRepositoryProvider)
          .checkOut(child.childId, pickupToken: _token, passCode: _code),
    );
    if (ok) setState(() => _handedOver.add(child.childId));
  }

  void _reset() {
    setState(() {
      _check = null;
      _token = null;
      _code = null;
      _passCode.clear();
    });
    _scanner.start();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final check = _check;

    return Scaffold(
      appBar: AppBar(title: Text(s.scanAtDoor)),
      body: check == null
          ? Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: MobileScanner(
                      controller: _scanner,
                      onDetect: (capture) {
                        final value = capture.barcodes.firstOrNull?.rawValue;
                        if (value != null && value.startsWith('BHG1.')) {
                          _verify(token: value);
                        }
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _passCode,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: s.passCodeEntry,
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(96, 52),
                        ),
                        onPressed: _busy
                            ? null
                            : () => _verify(code: _passCode.text.trim()),
                        child: Text(s.confirm),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.person_pin_rounded,
                      size: 40,
                      color: AppColors.teal,
                    ),
                    title: Text(
                      check.collectorName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(check.phone ?? ''),
                  ),
                ),
                const SizedBox(height: 12),
                for (final child in check.children)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      color: child.allowed
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFFEF2F2),
                      child: ListTile(
                        leading: Icon(
                          child.allowed ? Icons.check_circle : Icons.cancel,
                          color: child.allowed
                              ? AppColors.success
                              : AppColors.danger,
                          size: 32,
                        ),
                        title: Text(
                          child.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          child.allowed
                              ? s.allowed
                              : '${s.notAllowed}\n${child.reasonLabel ?? ''}',
                          style: TextStyle(
                            color: child.allowed
                                ? AppColors.success
                                : AppColors.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing:
                            !child.allowed ||
                                child.attendanceStatus != 'present'
                            ? null
                            : _handedOver.contains(child.childId)
                            ? const Icon(
                                Icons.done_all,
                                color: AppColors.success,
                              )
                            : FilledButton(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                ),
                                onPressed: () => _handOver(child),
                                child: Text(s.checkOut),
                              ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(s.scanAtDoor),
                ),
              ],
            ),
    );
  }
}
