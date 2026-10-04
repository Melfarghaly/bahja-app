import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/strings.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final session = ref.watch(sessionControllerProvider).value;
    if (session == null) return const SizedBox.shrink();
    final locale = ref.watch(localeControllerProvider).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(s.account)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.teal,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                session.user.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                [
                  session.user.phone,
                  session.user.email,
                ].whereType<String>().join('\n'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                if (session.user.nurseries.length > 1)
                  ListTile(
                    leading: const Icon(Icons.swap_horiz_rounded),
                    title: Text(s.chooseNursery),
                    subtitle: Text(session.nursery?.name ?? ''),
                    onTap: () => context.push('/switch-nursery'),
                  ),
                if (session.can.manageNursery)
                  ListTile(
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: Text(s.subscription),
                    onTap: () => context.push('/subscription'),
                  ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(s.language),
                  trailing: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ar', label: Text('العربية')),
                      ButtonSegment(value: 'en', label: Text('English')),
                    ],
                    selected: {locale},
                    onSelectionChanged: (v) => ref
                        .read(localeControllerProvider.notifier)
                        .set(v.first),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: Text(
                s.signOut,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () async {
                await ref.read(sessionControllerProvider.notifier).logout();
              },
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Bahga ${Env.appVersion}',
              style: TextStyle(color: Colors.black38),
            ),
          ),
        ],
      ),
    );
  }
}
