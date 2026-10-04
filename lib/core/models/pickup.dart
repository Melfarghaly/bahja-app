import 'json.dart';

/// The guardian's rotating QR (valid 60 s, refresh every `refreshAfter` s).
class PickupCode {
  const PickupCode({
    required this.token,
    required this.expiresAt,
    required this.refreshAfter,
  });

  factory PickupCode.fromJson(Json json) => PickupCode(
    token: json['token'] as String,
    expiresAt: parseDate(json['expires_at'])!,
    refreshAfter: asInt(json['refresh_after']) ?? 30,
  );

  final String token;
  final DateTime expiresAt;
  final int refreshAfter;
}

class PickupPass {
  const PickupPass({
    required this.id,
    required this.childId,
    required this.name,
    this.phone,
    this.note,
    required this.status,
    this.validFrom,
    this.validUntil,
    this.usedAt,
  });

  factory PickupPass.fromJson(Json json) => PickupPass(
    id: asInt(json['id'])!,
    childId: asInt(json['child_id'])!,
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String?,
    note: json['note'] as String?,
    status: json['status'] as String? ?? 'active',
    validFrom: parseDate(json['valid_from']),
    validUntil: parseDate(json['valid_until']),
    usedAt: parseDate(json['used_at']),
  );

  final int id;
  final int childId;
  final String name;
  final String? phone;
  final String? note;

  /// active / scheduled / used / expired / revoked
  final String status;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final DateTime? usedAt;

  bool get canRevoke => status == 'active' || status == 'scheduled';
}

/// Result of scanning a QR or typing a pass code at the door.
class PickupCheck {
  const PickupCheck({
    required this.collectorName,
    required this.method,
    this.collectorUserId,
    this.phone,
    required this.children,
  });

  factory PickupCheck.fromJson(Json json) {
    final collector = json['collector'] as Json;
    return PickupCheck(
      collectorName: collector['name'] as String? ?? '',
      method: collector['method'] as String? ?? '',
      collectorUserId: asInt(collector['user_id']),
      phone: collector['phone'] as String?,
      children: asList(json['children'], PickupCheckChild.fromJson),
    );
  }

  final String collectorName;
  final String method;
  final int? collectorUserId;
  final String? phone;
  final List<PickupCheckChild> children;
}

class PickupCheckChild {
  const PickupCheckChild({
    required this.childId,
    required this.name,
    this.classroom,
    required this.attendanceStatus,
    required this.allowed,
    this.reason,
    this.reasonLabel,
  });

  factory PickupCheckChild.fromJson(Json json) {
    final child = json['child'] as Json;
    return PickupCheckChild(
      childId: asInt(child['id'])!,
      name: [
        child['first_name'],
        child['last_name'],
      ].whereType<String>().join(' '),
      classroom: (child['classroom'] as Json?)?['name'] as String?,
      attendanceStatus: json['attendance_status'] as String? ?? 'absent',
      allowed: asBool(json['allowed']),
      reason: json['reason'] as String?,
      reasonLabel: json['reason_label'] as String?,
    );
  }

  final int childId;
  final String name;
  final String? classroom;
  final String attendanceStatus;
  final bool allowed;

  /// custody_blocked / not_authorized
  final String? reason;
  final String? reasonLabel;

  bool get custodyBlocked => reason == 'custody_blocked';
}
