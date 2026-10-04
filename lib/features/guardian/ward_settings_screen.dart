import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';
import 'guardian_providers.dart';

/// Per child: push / SMS choices and the photo permission.
class WardSettingsScreen extends ConsumerWidget {
  const WardSettingsScreen({super.key, required this.childId});

  final int childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ward = ref.watch(wardProvider(childId));
    final dailyWall =
        ref.watch(sessionControllerProvider).value?.can.dailyWall ?? false;
    final repo = ref.read(guardianRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: AsyncView(
        value: ward,
        onRetry: () => ref.invalidate(wardProvider(childId)),
        builder: (ward) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              s.notifications,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(s.appNotifications),
                    value: ward.myLink.pushEnabled,
                    onChanged: (v) => guarded(context, () async {
                      await repo.updateNotifications(childId, push: v);
                      ref.invalidate(wardProvider(childId));
                    }),
                  ),
                  SwitchListTile(
                    title: Text(s.smsMessages),
                    value: ward.myLink.smsEnabled,
                    onChanged: (v) => guarded(context, () async {
                      await repo.updateNotifications(childId, sms: v);
                      ref.invalidate(wardProvider(childId));
                    }),
                  ),
                ],
              ),
            ),
            if (dailyWall) ...[
              const SizedBox(height: 24),
              Text(
                s.photoConsent,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _ConsentCard(childId: childId),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConsentCard extends ConsumerWidget {
  const _ConsentCard({required this.childId});

  final int childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final consent = ref.watch(photoConsentProvider(childId));

    Future<void> update({bool? wall, bool? group}) =>
        guarded(context, () async {
          await ref
              .read(guardianRepositoryProvider)
              .updatePhotoConsent(childId, wall: wall, groupPhotos: group);
          ref.invalidate(photoConsentProvider(childId));
        });

    return AsyncView(
      value: consent,
      builder: (c) => Card(
        child: Column(
          children: [
            SwitchListTile(
              title: Text(s.photoConsentWall),
              value: c.wall,
              onChanged: c.canChange ? (v) => update(wall: v) : null,
            ),
            SwitchListTile(
              title: Text(s.photoConsentGroup),
              value: c.groupPhotos,
              onChanged: c.canChange && c.wall ? (v) => update(group: v) : null,
            ),
            if (!c.canChange)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  s.primaryOnly,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
