import 'package:flutter/material.dart';

import '../../core/models/child.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

/// "At nursery since 08:05" / "Picked up 15:30 with Mona" / "Not in today".
class TodayStatus extends StatelessWidget {
  const TodayStatus({super.key, required this.attendance});

  final Attendance? attendance;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = s.isArabic ? 'ar' : 'en';
    final a = attendance;

    if (a == null || a.checkedInAt == null) {
      return StatusChip(label: s.absent, color: Colors.grey);
    }
    if (a.isPickedUp) {
      return StatusChip(
        label: s.leftAt(formatTime(a.checkedOutAt, lang), a.pickedUpByName),
        color: AppColors.teal,
      );
    }
    return StatusChip(
      label: '${s.present} · ${s.arrivedAt(formatTime(a.checkedInAt, lang))}',
      color: AppColors.success,
    );
  }
}
