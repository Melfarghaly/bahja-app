import 'child.dart';
import 'json.dart';

/// One row of the teacher's daily sheet.
class SheetRow {
  const SheetRow({
    required this.childId,
    required this.firstName,
    this.lastName,
    this.classroom,
    required this.status,
    this.latePickup = false,
    this.attendance,
  });

  factory SheetRow.fromJson(Json json) {
    final child = json['child'] as Json;
    return SheetRow(
      childId: asInt(child['id'])!,
      firstName: child['first_name'] as String? ?? '',
      lastName: child['last_name'] as String?,
      classroom: child['classroom'] is Json
          ? ClassroomRef.fromJson(child['classroom'] as Json)
          : null,
      status: json['status'] as String? ?? 'absent',
      latePickup: asBool(json['late_pickup']),
      attendance: json['attendance'] is Json
          ? Attendance.fromJson(json['attendance'] as Json)
          : null,
    );
  }

  final int childId;
  final String firstName;
  final String? lastName;
  final ClassroomRef? classroom;

  /// absent / present / picked_up
  final String status;
  final bool latePickup;
  final Attendance? attendance;

  String get fullName => [
    firstName,
    lastName,
  ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
}

class AttendanceSheet {
  const AttendanceSheet({
    required this.date,
    required this.rows,
    this.pickupDeadline,
    this.summary = const {},
  });

  factory AttendanceSheet.fromJson(Json json) => AttendanceSheet(
    date: json['date'] as String? ?? '',
    rows: asList(json['data'], SheetRow.fromJson),
    pickupDeadline: json['pickup_deadline'] as String?,
    summary: (json['summary'] as Json? ?? const {}).map(
      (k, v) => MapEntry(k, asInt(v) ?? 0),
    ),
  );

  final String date;
  final List<SheetRow> rows;
  final String? pickupDeadline;
  final Map<String, int> summary;
}
