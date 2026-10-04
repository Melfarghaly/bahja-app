import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';
import 'guardian_providers.dart';
import 'today_status.dart';

class WardDetailScreen extends ConsumerWidget {
  const WardDetailScreen({super.key, required this.childId});

  final int childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ward = ref.watch(wardProvider(childId));
    final can = ref.watch(sessionControllerProvider).value?.can;

    return Scaffold(
      appBar: AppBar(title: Text(ward.value?.firstName ?? '')),
      body: AsyncView(
        value: ward,
        onRetry: () => ref.invalidate(wardProvider(childId)),
        builder: (ward) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ChildAvatar(name: ward.firstName, radius: 40),
                    const SizedBox(height: 12),
                    Text(
                      ward.fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (ward.classroom != null)
                      Text(
                        ward.classroom!.name,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    const SizedBox(height: 12),
                    TodayStatus(attendance: ward.todayAttendance),
                    if (ward.todayAttendance?.overrideReason != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        ward.todayAttendance!.overrideReason!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.warning),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if ((can?.dailyWall ?? false) && ward.myLink.canViewWall)
              _Action(
                icon: Icons.photo_library_outlined,
                label: s.dailyWall,
                onTap: () => context.push('/wards/$childId/wall'),
              ),
            _Action(
              icon: Icons.event_available_outlined,
              label: s.attendanceHistory,
              onTap: () => context.push('/wards/$childId/attendance'),
            ),
            if ((can?.safePickup ?? false) && ward.myLink.canPickup)
              _Action(
                icon: Icons.badge_outlined,
                label: s.pickupPasses,
                onTap: () => context.push('/wards/$childId/passes'),
              ),
            _Action(
              icon: Icons.tune_rounded,
              label: s.settings,
              onTap: () => context.push('/wards/$childId/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.teal),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    ),
  );
}
