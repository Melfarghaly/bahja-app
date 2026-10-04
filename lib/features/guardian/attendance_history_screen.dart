import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/child.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/strings.dart';
import '../../shared/paged_list.dart';

class AttendanceHistoryScreen extends ConsumerWidget {
  const AttendanceHistoryScreen({super.key, required this.childId});

  final int childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final lang = s.isArabic ? 'ar' : 'en';

    return Scaffold(
      appBar: AppBar(title: Text(s.attendanceHistory)),
      body: PagedList<Attendance>(
        load: (page) => ref
            .read(guardianRepositoryProvider)
            .attendance(childId, page: page),
        itemBuilder: (context, a, _) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: ListTile(
              leading: Icon(
                a.isPickedUp ? Icons.home_rounded : Icons.school_rounded,
                color: a.isPickedUp ? AppColors.teal : AppColors.success,
              ),
              title: Text(
                formatDate(DateTime.tryParse(a.date), lang),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                [
                  s.arrivedAt(formatTime(a.checkedInAt, lang)),
                  if (a.isPickedUp)
                    s.leftAt(
                      formatTime(a.checkedOutAt, lang),
                      a.pickedUpByName,
                    ),
                ].join('\n'),
              ),
              trailing: a.pickupVerified == false && a.isPickedUp
                  ? const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
