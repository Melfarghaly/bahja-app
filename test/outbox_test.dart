import 'package:bahja_app/app/outbox.dart';
import 'package:bahja_app/app/providers.dart';
import 'package:bahja_app/core/outbox/outbox_item.dart';
import 'package:bahja_app/core/outbox/outbox_store.dart';
import 'package:bahja_app/core/storage/session_store.dart';
import 'package:bahja_app/data/wall_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAdapter api;
  late MemoryOutboxStore store;
  late ProviderContainer container;

  ProviderContainer start() {
    final session = MemorySessionStore(token: '6|teacher', tenantId: 1);
    return ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(session),
        apiClientProvider.overrideWithValue(fakeClient(api, session)),
        outboxStoreProvider.overrideWithValue(store),
      ],
    );
  }

  setUp(() {
    api = FakeAdapter();
    store = MemoryOutboxStore();
    container = start();
  });

  tearDown(() => container.dispose());

  OutboxController outbox() => container.read(outboxProvider.notifier);
  OutboxState state() => container.read(outboxProvider);

  /// Lets the background send finish (it runs on real futures).
  Future<void> settle() async {
    var idle = 0;
    for (var i = 0; i < 300 && idle < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      idle = state().syncing ? 0 : idle + 1;
    }
  }

  test(
    'sends a morning of check-ins in a single request, then forgets them',
    () async {
      api.on('POST', '/v1/attendance/check-in/bulk', body: '{"data": []}');

      await outbox().checkIn([
        (id: 1, name: 'يوسف'),
        (id: 2, name: 'ليلى'),
        (id: 3, name: 'آدم'),
      ]);
      await settle();

      final bulk = api.requests
          .where((r) => r.path == '/v1/attendance/check-in/bulk')
          .toList();
      expect(bulk, hasLength(1));
      expect(
        ((bulk.single.data as Map)['children'] as List).map(
          (c) => (c as Map)['child_id'],
        ),
        [1, 2, 3],
      );
      expect(state().items, isEmpty);
      expect(state().delivered, 1);
      expect(store.items, isEmpty);
    },
  );

  test('keeps everything through a network failure and retries with the same client_ref', () async {
    await outbox().addMoment(
      const NewMoment(
        type: 'meal',
        childIds: [1, 2],
        payload: {'meal': 'lunch', 'amount': 'all'},
      ),
      label: 'أكل كله · 2',
    );
    await settle();

    // No route → connection error: still queued, saved on the device, attempt counted.
    expect(state().items.single.attempts, 1);
    expect(store.items, hasLength(1));
    final firstRef = (api.requests.single.data as Map)['client_ref'];

    api.on(
      'POST',
      '/v1/moments',
      status: 201,
      body: fixture('moment_photo.json'),
    );
    await outbox().flush();
    await settle();

    expect(state().items, isEmpty);
    expect((api.requests.last.data as Map)['client_ref'], firstRef);
    expect(firstRef, matches(RegExp(r'^[0-9a-f-]{36}$')));
  });

  test(
    'a refusal waits for the teacher: retry or discard, nothing silently lost',
    () async {
      api.on(
        'POST',
        '/v1/moments',
        status: 422,
        body: fixture('error_validation.json'),
      );

      await outbox().addMoment(
        const NewMoment(type: 'note', childIds: [1], body: 'x'),
        label: 'ملاحظة',
      );
      await settle();

      final failed = state().items.single;
      expect(failed.failed, isTrue);
      expect(failed.error, 'البيانات المرسلة غير صحيحة.');

      api.on(
        'POST',
        '/v1/moments',
        status: 201,
        body: fixture('moment_photo.json'),
      );
      await outbox().retry(failed.id);
      await settle();
      expect(state().items, isEmpty);

      api.on(
        'POST',
        '/v1/moments',
        status: 422,
        body: fixture('error_validation.json'),
      );
      await outbox().addMoment(
        const NewMoment(type: 'note', childIds: [1], body: 'y'),
        label: 'ملاحظة',
      );
      await settle();
      await outbox().discard(state().items.single.id);
      expect(state().items, isEmpty);
      expect(store.items, isEmpty);
    },
  );

  test('resumes what was queued before the app was closed', () async {
    store.items = [
      OutboxItem(
        id: '1d2c3b4a-0000-4000-8000-000000000001',
        kind: OutboxKind.moment,
        tenantId: 1,
        label: 'مزاج',
        createdAt: DateTime.now(),
        data: const {
          'type': 'mood',
          'child_ids': [4],
          'payload': {'mood': 'happy'},
        },
      ),
    ];
    api.on(
      'POST',
      '/v1/moments',
      status: 201,
      body: fixture('moment_photo.json'),
    );

    container.dispose();
    container = start();
    container.read(outboxProvider);
    await Future<void>.delayed(Duration.zero);
    await settle();

    final sent = api.requests.single.data as Map;
    expect(sent['client_ref'], '1d2c3b4a-0000-4000-8000-000000000001');
    expect(sent['payload'], {'mood': 'happy'});
    expect(state().items, isEmpty);
  });
}
