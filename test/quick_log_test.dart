import 'dart:convert';

import 'package:bahja_app/app/app.dart';
import 'package:bahja_app/app/outbox.dart';
import 'package:bahja_app/app/providers.dart';
import 'package:bahja_app/core/outbox/outbox_store.dart';
import 'package:bahja_app/core/storage/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// Three children present today.
String _sheet() => jsonEncode({
  'date': '2026-10-04',
  'pickup_deadline': null,
  'summary': {
    'total': 3,
    'present': 3,
    'picked_up': 0,
    'absent': 0,
    'late_pickup': 0,
  },
  'data': [
    for (final (id, name) in [(1, 'آدم'), (2, 'ليلى'), (3, 'يوسف')])
      {
        'child': {
          'id': id,
          'first_name': name,
          'last_name': 'محمود',
          'classroom': {'id': 1, 'name': 'عباد الشمس'},
        },
        'status': 'present',
        'late_pickup': false,
        'attendance': {
          'id': id,
          'child_id': id,
          'date': '2026-10-04',
          'checked_in_at': '2026-10-04T06:00:00+00:00',
        },
      },
  ],
});

void main() {
  setUpAll(
    () => Future.wait([
      initializeDateFormatting('ar'),
      initializeDateFormatting('en'),
    ]),
  );

  testWidgets(
    'lunch for a whole class in five taps: everyone "all", one "half", save',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      // A phone screen (412 × 915).
      tester.view.physicalSize = const Size(1236, 2745);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final api = FakeAdapter()
        ..on('GET', '/v1/me', body: fixture('me_owner.json'))
        ..on('GET', '/v1/attendance', body: _sheet())
        ..on('GET', '/v1/classrooms', body: '{"data": []}')
        ..on(
          'GET',
          '/v1/moments',
          body: '{"data": [], "meta": {"current_page": 1, "last_page": 1}}',
        )
        ..on('GET', '/v1/me/notifications', body: fixture('notifications.json'))
        ..on(
          'POST',
          '/v1/moments',
          status: 201,
          body: fixture('moment_photo.json'),
        );
      final session = MemorySessionStore(token: '6|teacher', tenantId: 1);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWithValue(session),
            apiClientProvider.overrideWithValue(fakeClient(api, session)),
            outboxStoreProvider.overrideWithValue(MemoryOutboxStore()),
          ],
          child: const BahgaApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(ChoiceChip, 'وجبة'),
      ); // 1. lunch mode
      await tester.pumpAndSettle();
      await tester.tap(find.text('للكل: أكل كله')); // 2. everyone ate all
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(ChoiceChip, 'نصفه'),
      ); // 3. brush: half
      await tester.pumpAndSettle();
      await tester.tap(find.text('ليلى')); // 4. Layla ate half
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ لـ 3 طفل')); // 5. save
      await tester.pumpAndSettle();
      // The outbox sends in the background, one update after the other.
      await tester.runAsync(() async {
        for (
          var i = 0;
          i < 100 && api.requests.where((r) => r.method == 'POST').length < 2;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();

      final posted = api.requests
          .where((r) => r.method == 'POST' && r.path == '/v1/moments')
          .map((r) => r.data as Map)
          .toList();
      expect(posted, hasLength(2)); // one update per value
      final byAmount = {
        for (final p in posted) (p['payload'] as Map)['amount']: p['child_ids'],
      };
      expect(byAmount['all'], [1, 3]);
      expect(byAmount['half'], [2]);
      expect(
        posted.every((p) => (p['payload'] as Map)['meal'] == 'lunch'),
        isTrue,
      );
      expect(posted.map((p) => p['client_ref']).toSet(), hasLength(2));
      expect(
        find.text('حفظ لـ 3 طفل'),
        findsNothing,
      ); // cleared, ready for the next round
    },
  );
}
