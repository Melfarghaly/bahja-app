import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';
import 'guardian_providers.dart';
import 'today_status.dart';

/// The siblings view: every child of mine in this nursery, with today's status.
class WardsScreen extends ConsumerWidget {
  const WardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final wards = ref.watch(wardsProvider);
    final can = ref.watch(sessionControllerProvider).value?.can;
    final mayPickUp = wards.value?.any((w) => w.myLink.canPickup) ?? false;

    return Scaffold(
      floatingActionButton: (can?.safePickup ?? false) && mayPickUp
          ? FloatingActionButton.extended(
              heroTag: 'pickup-code',
              onPressed: () => context.push('/pickup-code'),
              icon: const Icon(Icons.qr_code_2_rounded),
              label: Text(s.pickupCode),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(wardsProvider.future),
        child: AsyncView(
          value: wards,
          onRetry: () => ref.invalidate(wardsProvider),
          builder: (list) => list.isEmpty
              ? ListView(
                  children: [
                    EmptyView(
                      message: s.nothingHere,
                      icon: Icons.child_care_rounded,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final ward = list[i];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => context.push('/wards/${ward.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              ChildAvatar(name: ward.firstName, radius: 28),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ward.fullName,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (ward.classroom != null)
                                      Text(
                                        ward.classroom!.name,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    TodayStatus(
                                      attendance: ward.todayAttendance,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
