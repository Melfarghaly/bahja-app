import 'package:bahja_app/core/models/app_notification.dart';
import 'package:bahja_app/core/models/attendance_sheet.dart';
import 'package:bahja_app/core/models/billing.dart';
import 'package:bahja_app/core/models/child.dart';
import 'package:bahja_app/core/models/json.dart';
import 'package:bahja_app/core/models/moment.dart';
import 'package:bahja_app/core/models/page.dart';
import 'package:bahja_app/core/models/pickup.dart';
import 'package:bahja_app/core/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api.dart';

/// Every model parses the backend's real responses (from its Postman collection).
void main() {
  Json data(String name) => fixtureJson(name)['data'] as Json;

  test('profile with nurseries and capabilities', () {
    final owner = AppUser.fromJson(data('me_owner.json'));
    expect(owner.nurseries.single.name, 'حضانة البراعم');
    expect(owner.nurseries.single.capabilities.manageNursery, isTrue);
    expect(owner.nurseries.single.capabilities.dailyWall, isTrue);
    expect(owner.nurseries.single.capabilities.isStaff, isTrue);

    final guardian = AppUser.fromJson(data('me_guardian.json'));
    expect(guardian.nurseries.single.capabilities.guardian, isTrue);
    expect(guardian.nurseries.single.capabilities.isStaff, isFalse);
  });

  test('wards with my link, notifications and today', () {
    final wards = asList(fixtureJson('wards.json')['data'], Ward.fromJson);
    expect(wards, hasLength(2));
    expect(wards.first.myLink.isPrimary, isTrue);
    expect(wards.first.myLink.pushEnabled, isTrue);
    expect(wards.first.todayAttendance!.isPickedUp, isTrue);
    expect(wards.first.todayAttendance!.pickupMethod, 'pass_code');
  });

  test('staff child with guardians, custody flags and photo consent', () {
    final child = Child.fromJson(data('child.json'));
    expect(child.fullName, 'يوسف محمود');
    expect(child.allergies, contains('فول سوداني'));
    expect(child.photoConsentWall, isFalse);
    final father = child.guardians.firstWhere(
      (g) => g.relationship == 'father',
    );
    expect(father.isBlocked, isTrue);
    expect(father.mayCollect, isFalse);
    expect(child.guardians.where((g) => g.mayCollect), hasLength(2));
  });

  test('attendance sheet with summary and deadline', () {
    final sheet = AttendanceSheet.fromJson(
      fixtureJson('attendance_sheet.json'),
    );
    expect(sheet.pickupDeadline, '16:00');
    expect(sheet.rows.map((r) => r.status), containsAll(['absent', 'present']));
    expect(sheet.summary['present'], 1);
  });

  test('paginated attendance history', () {
    final page = PageOf.fromJson(
      fixtureJson('ward_attendance.json'),
      Attendance.fromJson,
    );
    expect(page.items.single.overrideReason, contains('خالة الطفل'));
    expect(page.hasMore, isFalse);
  });

  test('pickup code, pass and door check', () {
    final code = PickupCode.fromJson(data('pickup_code.json'));
    expect(code.token, startsWith('BHG1.'));
    expect(code.refreshAfter, 30);

    final issued = fixtureJson('pickup_pass_issued.json');
    expect(PickupPass.fromJson(issued['data'] as Json).canRevoke, isTrue);
    expect(issued['code'], matches(RegExp(r'^\d{6}$')));

    final check = PickupCheck.fromJson(data('pickup_verify.json'));
    expect(check.method, 'dynamic_qr');
    expect(check.children.every((c) => c.allowed), isTrue);
  });

  test('wall moments with signed photos and incidents', () {
    final photo = Moment.fromJson(data('moment_photo.json'));
    expect(photo.photos.single.url, contains('signature='));
    expect(photo.photos.single.aspectRatio, 1);

    final wall = PageOf.fromJson(
      fixtureJson('ward_wall.json'),
      Moment.fromJson,
    );
    final incident = wall.items.firstWhere((m) => m.requiresAck);
    expect(incident.acknowledged, isFalse);
    expect(
      wall.items.firstWhere((m) => m.type == 'meal').payload['amount'],
      'half',
    );
  });

  test('a video with its poster and duration', () {
    final moment = Moment.fromJson(data('moment_video.json'));
    final video = moment.videos.single;
    expect(moment.photos, isEmpty);
    expect(video.url, contains('signature='));
    expect(video.posterUrl, contains('/thumb?'));
    expect(video.durationLabel, '0:03');
  });

  test('invoices, payment methods and subscription', () {
    final invoice = Invoice.fromJson(data('invoice.json'));
    expect(invoice.balance.piasters, 351500);
    expect(
      invoice.items.where((i) => i.kind == 'discount').single.amount.piasters,
      -18500,
    );
    expect(invoice.payable, isTrue);

    final methods = asList(
      fixtureJson('payment_methods.json')['data'],
      PaymentMethod.fromJson,
    );
    expect(methods.map((m) => m.kind), ['redirect', 'payment_code']);

    final sub = Subscription.fromJson(fixtureJson('subscription.json'));
    expect(sub.planName, 'Pro');
    expect(sub.childrenLimit, 120);
  });

  test('notifications inbox', () {
    final page = PageOf.fromJson(
      fixtureJson('notifications.json'),
      AppNotification.fromJson,
    );
    expect(page.items.first.deepLink['screen'], 'ward');
    expect(page.items.first.read, isFalse);
  });
}
