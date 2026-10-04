import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/pickup.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';
import 'guardian_providers.dart';

/// One-time pickup passes for people without the app (a driver, a relative).
class PassesScreen extends ConsumerWidget {
  const PassesScreen({super.key, required this.childId});

  final int childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final lang = s.isArabic ? 'ar' : 'en';
    final passes = ref.watch(passesProvider(childId));

    return Scaffold(
      appBar: AppBar(title: Text(s.pickupPasses)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: Text(s.newPass),
      ),
      body: AsyncView(
        value: passes,
        onRetry: () => ref.invalidate(passesProvider(childId)),
        builder: (list) => list.isEmpty
            ? EmptyView(icon: Icons.badge_outlined, message: s.nothingHere)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final pass = list[i];
                  return Card(
                    child: ListTile(
                      title: Text(
                        pass.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${pass.phone ?? ''}\n${formatDateTime(pass.validFrom, lang)} → ${formatDateTime(pass.validUntil, lang)}',
                      ),
                      isThreeLine: true,
                      trailing: pass.canRevoke
                          ? IconButton(
                              icon: const Icon(
                                Icons.block,
                                color: AppColors.danger,
                              ),
                              tooltip: s.revoke,
                              onPressed: () => guarded(context, () async {
                                await ref
                                    .read(guardianRepositoryProvider)
                                    .revokePass(pass.id);
                                ref.invalidate(passesProvider(childId));
                              }),
                            )
                          : StatusChip(
                              label: _status(s, pass),
                              color: Colors.grey,
                            ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _status(S s, PickupPass pass) => switch (pass.status) {
    'used' => s.isArabic ? 'استُخدم' : 'Used',
    'expired' => s.isArabic ? 'منتهي' : 'Expired',
    'revoked' => s.isArabic ? 'ملغى' : 'Revoked',
    _ => pass.status,
  };

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewPassSheet(childId: childId),
    );
    if (code == null || !context.mounted) return;
    ref.invalidate(passesProvider(childId));
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          S.of(context).passCodeShown(code),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).done),
          ),
        ],
      ),
    );
  }
}

class _NewPassSheet extends ConsumerStatefulWidget {
  const _NewPassSheet({required this.childId});

  final int childId;

  @override
  ConsumerState<_NewPassSheet> createState() => _NewPassSheetState();
}

class _NewPassSheetState extends ConsumerState<_NewPassSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  double _hours = 4;
  ApiException? _error;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.newPass,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: s.passName,
              errorText: _error?.fieldError('name'),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: s.phone,
              errorText: _error?.fieldError('phone'),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: s.note),
          ),
          const SizedBox(height: 10),
          Text('${s.passValidHours}: ${_hours.round()}'),
          Slider(
            value: _hours,
            min: 1,
            max: 24,
            divisions: 23,
            onChanged: (v) => setState(() => _hours = v),
          ),
          if (_error != null && _error!.fieldErrors.isEmpty)
            Text(
              _error!.message,
              style: const TextStyle(color: AppColors.danger),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      final (_, code) = await ref
                          .read(guardianRepositoryProvider)
                          .issuePass(
                            widget.childId,
                            name: _name.text,
                            phone: _phone.text,
                            note: _note.text,
                            validUntil: DateTime.now().add(
                              Duration(hours: _hours.round()),
                            ),
                          );
                      if (context.mounted) Navigator.pop(context, code);
                    } on ApiException catch (e) {
                      setState(() => _error = e);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: Text(s.newPass),
          ),
        ],
      ),
    );
  }
}
