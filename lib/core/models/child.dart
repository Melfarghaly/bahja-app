import 'json.dart';

class ClassroomRef {
  const ClassroomRef({
    required this.id,
    required this.name,
    this.capacity,
    this.childrenCount,
  });

  factory ClassroomRef.fromJson(Json json) => ClassroomRef(
    id: asInt(json['id'])!,
    name: json['name'] as String? ?? '',
    capacity: asInt(json['capacity']),
    childrenCount: asInt(json['children_count']),
  );

  final int id;
  final String name;
  final int? capacity;
  final int? childrenCount;
}

/// One day of attendance for a child.
class Attendance {
  const Attendance({
    required this.id,
    required this.childId,
    required this.date,
    this.checkedInAt,
    this.checkInMethod,
    this.checkedOutAt,
    this.pickedUpBy,
    this.pickedUpByName,
    this.pickupVerified,
    this.pickupMethod,
    this.overrideReason,
  });

  factory Attendance.fromJson(Json json) => Attendance(
    id: asInt(json['id'])!,
    childId: asInt(json['child_id'])!,
    date: json['date'] as String? ?? '',
    checkedInAt: parseDate(json['checked_in_at']),
    checkInMethod: json['check_in_method'] as String?,
    checkedOutAt: parseDate(json['checked_out_at']),
    pickedUpBy: asInt(json['picked_up_by']),
    pickedUpByName: json['picked_up_by_name'] as String?,
    pickupVerified: json['pickup_verified'] as bool?,
    pickupMethod: json['pickup_method'] as String?,
    overrideReason: json['override_reason'] as String?,
  );

  final int id;
  final int childId;
  final String date;
  final DateTime? checkedInAt;
  final String? checkInMethod;
  final DateTime? checkedOutAt;
  final int? pickedUpBy;
  final String? pickedUpByName;
  final bool? pickupVerified;
  final String? pickupMethod;
  final String? overrideReason;

  bool get isPresent => checkedInAt != null && checkedOutAt == null;
  bool get isPickedUp => checkedOutAt != null;
}

/// A guardian linked to a child, as staff see it.
class Guardian {
  const Guardian({
    required this.id,
    required this.name,
    this.phone,
    this.relationship,
    this.role,
    this.canViewWall = false,
    this.canPickup = false,
    this.isPayer = false,
    this.custodyFlag = 'none',
  });

  factory Guardian.fromJson(Json json) => Guardian(
    id: asInt(json['id'])!,
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String?,
    relationship: json['relationship'] as String?,
    role: json['role'] as String?,
    canViewWall: asBool(json['can_view_wall']),
    canPickup: asBool(json['can_pickup']),
    isPayer: asBool(json['is_payer']),
    custodyFlag: json['custody_flag'] as String? ?? 'none',
  );

  final int id;
  final String name;
  final String? phone;
  final String? relationship;
  final String? role;
  final bool canViewWall;
  final bool canPickup;
  final bool isPayer;
  final String custodyFlag;

  bool get isBlocked => custodyFlag == 'blocked';
  bool get mayCollect => canPickup && !isBlocked;
}

/// A child as staff see it (`/v1/children`).
class Child {
  const Child({
    required this.id,
    required this.firstName,
    this.lastName,
    this.birthDate,
    this.gender,
    this.status,
    this.classroom,
    this.guardians = const [],
    this.medicalNotes,
    this.photoConsentWall,
    this.photoConsentGroup,
    this.todayAttendance,
  });

  factory Child.fromJson(Json json) {
    final consent = json['photo_consent'] as Json?;
    return Child(
      id: asInt(json['id'])!,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String?,
      birthDate: json['birth_date'] as String?,
      gender: json['gender'] as String?,
      status: json['status'] as String?,
      classroom: json['classroom'] is Json
          ? ClassroomRef.fromJson(json['classroom'] as Json)
          : null,
      guardians: asList(json['guardians'], Guardian.fromJson),
      medicalNotes: json['medical_notes'] is Json
          ? json['medical_notes'] as Json
          : null,
      photoConsentWall: consent == null ? null : asBool(consent['wall']),
      photoConsentGroup: consent == null
          ? null
          : asBool(consent['group_photos']),
      todayAttendance: json['today_attendance'] is Json
          ? Attendance.fromJson(json['today_attendance'] as Json)
          : null,
    );
  }

  final int id;
  final String firstName;
  final String? lastName;
  final String? birthDate;
  final String? gender;
  final String? status;
  final ClassroomRef? classroom;
  final List<Guardian> guardians;
  final Json? medicalNotes;
  final bool? photoConsentWall;
  final bool? photoConsentGroup;
  final Attendance? todayAttendance;

  String get fullName => [
    firstName,
    lastName,
  ].whereType<String>().where((s) => s.isNotEmpty).join(' ');

  List<String> get allergies =>
      (medicalNotes?['allergies'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
}

/// This guardian's own link to a child (never other guardians').
class MyLink {
  const MyLink({
    this.relationship,
    this.role,
    this.canViewWall = false,
    this.canPickup = false,
    this.isPayer = false,
    this.pushEnabled = true,
    this.smsEnabled = true,
  });

  factory MyLink.fromJson(Json json) {
    final notifications = json['notifications'] as Json? ?? const {};
    return MyLink(
      relationship: json['relationship'] as String?,
      role: json['role'] as String?,
      canViewWall: asBool(json['can_view_wall']),
      canPickup: asBool(json['can_pickup']),
      isPayer: asBool(json['is_payer']),
      pushEnabled: notifications['push'] != false,
      smsEnabled: notifications['sms'] != false,
    );
  }

  final String? relationship;
  final String? role;
  final bool canViewWall;
  final bool canPickup;
  final bool isPayer;
  final bool pushEnabled;
  final bool smsEnabled;

  bool get isPrimary => role == 'primary';
}

/// A child as their guardian sees it (`/v1/me/wards`).
class Ward {
  const Ward({
    required this.id,
    required this.firstName,
    this.lastName,
    this.birthDate,
    this.gender,
    this.classroom,
    this.medicalNotes,
    this.myLink = const MyLink(),
    this.todayAttendance,
  });

  factory Ward.fromJson(Json json) => Ward(
    id: asInt(json['id'])!,
    firstName: json['first_name'] as String? ?? '',
    lastName: json['last_name'] as String?,
    birthDate: json['birth_date'] as String?,
    gender: json['gender'] as String?,
    classroom: json['classroom'] is Json
        ? ClassroomRef.fromJson(json['classroom'] as Json)
        : null,
    medicalNotes: json['medical_notes'] is Json
        ? json['medical_notes'] as Json
        : null,
    myLink: MyLink.fromJson(json['my_link'] as Json? ?? const {}),
    todayAttendance: json['today_attendance'] is Json
        ? Attendance.fromJson(json['today_attendance'] as Json)
        : null,
  );

  final int id;
  final String firstName;
  final String? lastName;
  final String? birthDate;
  final String? gender;
  final ClassroomRef? classroom;
  final Json? medicalNotes;
  final MyLink myLink;
  final Attendance? todayAttendance;

  String get fullName => [
    firstName,
    lastName,
  ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
}

class PhotoConsent {
  const PhotoConsent({
    required this.wall,
    required this.groupPhotos,
    required this.canChange,
  });

  factory PhotoConsent.fromJson(Json json) => PhotoConsent(
    wall: asBool(json['wall']),
    groupPhotos: asBool(json['group_photos']),
    canChange: asBool(json['can_change']),
  );

  final bool wall;
  final bool groupPhotos;
  final bool canChange;
}
