import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// For people who belong to more than one nursery (or to switch later).
class NurseryPickerScreen extends ConsumerWidget {
  const NurseryPickerScreen({super.key, this.switching = false});

  final bool switching;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final session = ref.watch(sessionControllerProvider).value;
    final nurseries = session?.user.nurseries ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(s.chooseNursery),
        actions: [
          if (!switching)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: s.signOut,
              onPressed: () =>
                  ref.read(sessionControllerProvider.notifier).logout(),
            ),
        ],
      ),
      body: nurseries.isEmpty
          ? EmptyView(message: s.noNurseries, icon: Icons.home_work_outlined)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: nurseries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final nursery = nurseries[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: ChildAvatar(name: nursery.name),
                    title: Text(
                      nursery.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      nursery.roles.map(_roleLabel(s)).join(' · '),
                    ),
                    trailing: session?.nursery?.id == nursery.id
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.chevron_right),
                    onTap: () async {
                      await ref
                          .read(sessionControllerProvider.notifier)
                          .selectNursery(nursery);
                      if (switching && context.mounted) context.go('/');
                    },
                  ),
                );
              },
            ),
    );
  }

  String Function(String) _roleLabel(S s) =>
      (role) => switch (role) {
        'owner' => s.isArabic ? 'المالك' : 'Owner',
        'admin' => s.isArabic ? 'مدير' : 'Manager',
        'teacher' => s.isArabic ? 'معلمة' : 'Teacher',
        'guardian' => s.isArabic ? 'وليّ أمر' : 'Guardian',
        _ => role,
      };
}
