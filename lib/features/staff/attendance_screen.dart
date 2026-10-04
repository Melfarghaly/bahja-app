import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/models/attendance_sheet.dart';
import '../../core/models/child.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

final _classroomFilterProvider = NotifierProvider<_ClassroomFilter, int?>(
  _ClassroomFilter.new,
);

class _ClassroomFilter extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? id) => state = id;
}

final sheetProvider = FutureProvider.autoDispose<AttendanceSheet>(
  (ref) => ref
      .watch(staffRepositoryProvider)
      .sheet(classroomId: ref.watch(_classroomFilterProvider)),
);
final _classroomsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(staffRepositoryProvider).classrooms(),
);

/// The teacher's main screen: today's children, one tap to check in or out.
class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final sheet = ref.watch(sheetProvider);
    final safePickup =
        ref.watch(sessionControllerProvider).value?.can.safePickup ?? false;

    return Scaffold(
      floatingActionButton: safePickup
          ? FloatingActionButton.extended(
              heroTag: 'door',
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(s.scanAtDoor),
              onPressed: () async {
                await context.push('/door');
                ref.invalidate(sheetProvider);
              },
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(sheetProvider.future),
        child: AsyncView(
          value: sheet,
          onRetry: () => ref.invalidate(sheetProvider),
          builder: (sheet) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _ClassroomPicker(),
              const SizedBox(height: 12),
              _Summary(sheet: sheet),
              const SizedBox(height: 12),
              for (final row in sheet.rows) _Row(row: row),
              if (sheet.rows.isEmpty)
                const EmptyView(icon: Icons.child_care_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassroomPicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = S.of(context).isArabic;
    final classrooms =
        ref.watch(_classroomsProvider).value ?? const <ClassroomRef>[];
    if (classrooms.length < 2) return const SizedBox.shrink();
    final selected = ref.watch(_classroomFilterProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text(ar ? 'الكل' : 'All'),
            selected: selected == null,
            onSelected: (_) =>
                ref.read(_classroomFilterProvider.notifier).set(null),
          ),
          for (final c in classrooms)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6),
              child: ChoiceChip(
                label: Text(c.name),
                selected: selected == c.id,
                onSelected: (_) =>
                    ref.read(_classroomFilterProvider.notifier).set(c.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.sheet});

  final AttendanceSheet sheet;

  @override
  Widget build(BuildContext context) {
    final ar = S.of(context).isArabic;
    Widget cell(String label, int value, Color color) => Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            cell(
              ar ? 'حاضر' : 'Present',
              sheet.summary['present'] ?? 0,
              AppColors.success,
            ),
            cell(
              ar ? 'انصرف' : 'Left',
              sheet.summary['picked_up'] ?? 0,
              AppColors.teal,
            ),
            cell(
              ar ? 'غائب' : 'Absent',
              sheet.summary['absent'] ?? 0,
              Colors.grey,
            ),
            if ((sheet.summary['late_pickup'] ?? 0) > 0)
              cell(
                ar ? 'متأخر' : 'Late',
                sheet.summary['late_pickup']!,
                AppColors.danger,
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.row});

  final SheetRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final lang = s.isArabic ? 'ar' : 'en';
    final repo = ref.read(staffRepositoryProvider);

    final (label, color) = switch (row.status) {
      'present' => (
        row.latePickup
            ? s.latePickup
            : s.arrivedAt(formatTime(row.attendance?.checkedInAt, lang)),
        row.latePickup ? AppColors.danger : AppColors.success,
      ),
      'picked_up' => (
        s.leftAt(
          formatTime(row.attendance?.checkedOutAt, lang),
          row.attendance?.pickedUpByName,
        ),
        AppColors.teal,
      ),
      _ => (s.absent, Colors.grey),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: ChildAvatar(name: row.firstName),
          title: Text(
            row.fullName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusChip(label: label, color: color),
            ),
          ),
          trailing: switch (row.status) {
            'absent' => FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                backgroundColor: AppColors.teal,
              ),
              onPressed: () => guarded(context, () async {
                await repo.checkIn(row.childId);
                ref.invalidate(sheetProvider);
              }),
              child: Text(s.checkIn),
            ),
            'present' => OutlinedButton(
              onPressed: () => _checkOut(context, ref),
              child: Text(s.checkOut),
            ),
            _ => null,
          },
        ),
      ),
    );
  }

  /// Choose a guardian who may collect; blocked ones are shown in red and disabled.
  Future<void> _checkOut(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    final repo = ref.read(staffRepositoryProvider);
    final child = await repo.child(row.childId).catchError((Object e) {
      if (context.mounted) showError(context, e);
      throw e;
    });
    if (!context.mounted) return;

    final collector = await showModalBottomSheet<Guardian>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              s.whoIsCollecting,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final g in child.guardians)
              ListTile(
                leading: Icon(
                  g.isBlocked
                      ? Icons.block
                      : (g.canPickup ? Icons.verified_user : Icons.person_off),
                  color: g.isBlocked
                      ? AppColors.danger
                      : (g.canPickup ? AppColors.success : Colors.grey),
                ),
                title: Text(
                  g.name,
                  style: TextStyle(
                    color: g.isBlocked ? AppColors.danger : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  g.isBlocked ? s.notAllowed : (g.relationship ?? ''),
                ),
                enabled: g.mayCollect,
                onTap: () => Navigator.pop(context, g),
              ),
          ],
        ),
      ),
    );
    if (collector == null || !context.mounted) return;

    final ok = await guarded(
      context,
      () => repo.checkOut(row.childId, collectorId: collector.id),
    );
    if (ok) ref.invalidate(sheetProvider);
  }
}
