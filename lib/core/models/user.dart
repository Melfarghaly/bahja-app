import 'json.dart';

/// What the signed-in user may do in one nursery (from `GET /v1/me`).
class Capabilities {
  const Capabilities({
    this.manageNursery = false,
    this.takeAttendance = false,
    this.viewChildren = false,
    this.manageChildren = false,
    this.guardian = false,
    this.bahgaPay = false,
    this.onlinePayments = false,
    this.safePickup = false,
    this.dailyWall = false,
  });

  factory Capabilities.fromJson(Json json) => Capabilities(
    manageNursery: asBool(json['manage_nursery']),
    takeAttendance: asBool(json['take_attendance']),
    viewChildren: asBool(json['view_children']),
    manageChildren: asBool(json['manage_children']),
    guardian: asBool(json['guardian']),
    bahgaPay: asBool(json['bahga_pay']),
    onlinePayments: asBool(json['online_payments']),
    safePickup: asBool(json['safe_pickup']),
    dailyWall: asBool(json['daily_wall']),
  );

  final bool manageNursery;
  final bool takeAttendance;
  final bool viewChildren;
  final bool manageChildren;
  final bool guardian;
  final bool bahgaPay;
  final bool onlinePayments;
  final bool safePickup;
  final bool dailyWall;

  bool get isStaff => takeAttendance || viewChildren || manageNursery;
}

class Nursery {
  const Nursery({
    required this.id,
    required this.name,
    this.phone,
    this.logoUrl,
    this.roles = const [],
    this.capabilities = const Capabilities(),
  });

  factory Nursery.fromJson(Json json) => Nursery(
    id: asInt(json['id'])!,
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String?,
    logoUrl: json['logo_url'] as String?,
    roles: (json['roles'] as List<dynamic>? ?? const []).cast<String>(),
    capabilities: Capabilities.fromJson(
      json['capabilities'] as Json? ?? const {},
    ),
  );

  final int id;
  final String name;
  final String? phone;
  final String? logoUrl;
  final List<String> roles;
  final Capabilities capabilities;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.locale = 'ar',
    this.nurseries = const [],
  });

  factory AppUser.fromJson(Json json) => AppUser(
    id: asInt(json['id'])!,
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    locale: json['locale'] as String? ?? 'ar',
    nurseries: asList(json['nurseries'], Nursery.fromJson),
  );

  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String locale;
  final List<Nursery> nurseries;
}
