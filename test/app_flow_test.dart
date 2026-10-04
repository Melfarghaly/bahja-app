import 'package:bahja_app/app/app.dart';
import 'package:bahja_app/app/providers.dart';
import 'package:bahja_app/core/storage/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_api.dart';

void main() {
  setUpAll(
    () => Future.wait([
      initializeDateFormatting('ar'),
      initializeDateFormatting('en'),
    ]),
  );

  testWidgets('a guardian signs in and lands on their children', (
    tester,
  ) async {
    final adapter = FakeAdapter()
      ..on(
        'POST',
        '/v1/auth/tokens',
        status: 201,
        body: fixture('auth_token.json'),
      )
      ..on('GET', '/v1/me', body: fixture('me_guardian.json'))
      ..on('GET', '/v1/me/wards', body: fixture('wards.json'))
      ..on('GET', '/v1/me/notifications', body: fixture('notifications.json'))
      ..on('GET', '/v1/me/invoices', body: fixture('invoices.json'));
    final session = MemorySessionStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(session),
          apiClientProvider.overrideWithValue(fakeClient(adapter, session)),
        ],
        child: const BahgaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('أهلاً بك في بهجة'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('login')), '01000000002');
    await tester.enterText(find.byKey(const Key('password')), 'password');
    await tester.tap(find.byKey(const Key('sign-in')));
    await tester.pumpAndSettle();

    // One nursery → straight in; the token and nursery are remembered.
    expect(session.token, startsWith('5|'));
    expect(session.tenantId, 1);
    expect(find.text('حضانة البراعم'), findsOneWidget);
    expect(find.text('ليلى محمود'), findsOneWidget);
    expect(find.text('يوسف محمود'), findsOneWidget);
    expect(
      find.text('كود الاستلام'),
      findsOneWidget,
    ); // Safe Pickup is on and she may collect
    expect(find.text('الفواتير'), findsOneWidget); // Bahga Pay tab
    expect(find.text('الحضور'), findsNothing); // not staff
  });

  testWidgets('shows the server message when sign-in fails', (tester) async {
    final adapter = FakeAdapter()
      ..on(
        'POST',
        '/v1/auth/tokens',
        status: 422,
        body: fixture('error_validation.json'),
      );
    final session = MemorySessionStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWithValue(session),
          apiClientProvider.overrideWithValue(fakeClient(adapter, session)),
        ],
        child: const BahgaApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login')), 'owner@bahga.test');
    await tester.enterText(find.byKey(const Key('password')), 'wrong');
    await tester.tap(find.byKey(const Key('sign-in')));
    await tester.pumpAndSettle();

    expect(find.text('بيانات الدخول غير صحيحة.'), findsOneWidget);
    expect(session.token, isNull);
  });

  testWidgets(
    'a teacher with a saved session checks a child in from the daily sheet',
    (tester) async {
      final adapter = FakeAdapter()
        ..on('GET', '/v1/me', body: fixture('me_owner.json'))
        ..on('GET', '/v1/attendance', body: fixture('attendance_sheet.json'))
        ..on('GET', '/v1/classrooms', body: '{"data": []}')
        ..on('GET', '/v1/moments', body: fixture('ward_wall.json'))
        ..on('GET', '/v1/me/notifications', body: fixture('notifications.json'))
        ..on(
          'POST',
          '/v1/attendance/check-in',
          body: '{"data": {"id": 9, "child_id": 5, "date": "2026-10-04", "checked_in_at": "2026-10-04T09:30:00+00:00"}}',
        );
      final session = MemorySessionStore(token: '6|teacher', tenantId: 1);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWithValue(session),
            apiClientProvider.overrideWithValue(fakeClient(adapter, session)),
          ],
          child: const BahgaApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('آدم سامي'), findsOneWidget);
      expect(find.text('الحائط'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'تسجيل حضور').first);
      await tester.pumpAndSettle();

      final checkIn = adapter.requests
          .where((r) => r.path == '/v1/attendance/check-in')
          .single;
      expect(checkIn.data, {'child_id': 5, 'method': 'manual'});
      expect(
        adapter.requests.where((r) => r.path == '/v1/attendance'),
        hasLength(2),
      ); // sheet reloaded
    },
  );
}
