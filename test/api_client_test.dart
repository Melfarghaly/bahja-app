import 'package:bahja_app/core/network/api_exception.dart';
import 'package:bahja_app/core/storage/session_store.dart';
import 'package:bahja_app/data/auth_repository.dart';
import 'package:bahja_app/data/wall_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api.dart';

void main() {
  late FakeAdapter adapter;
  late MemorySessionStore session;

  setUp(() {
    adapter = FakeAdapter();
    session = MemorySessionStore(token: '7|secret', tenantId: 1)..locale = 'en';
  });

  test('sends the token, the nursery and the language', () async {
    adapter.on('GET', '/v1/me/wards', body: fixture('wards.json'));
    await fakeClient(adapter, session).get('/v1/me/wards');

    final headers = adapter.requests.single.headers;
    expect(headers['Authorization'], 'Bearer 7|secret');
    expect(headers['X-Tenant-Id'], '1');
    expect(headers['Accept-Language'], 'en');
  });

  test('leaves out the nursery on tenant-free endpoints', () async {
    adapter.on('GET', '/v1/me', body: fixture('me_owner.json'));
    final user = await AuthRepository(fakeClient(adapter, session)).me();

    expect(user.name, 'سامية المديرة');
    expect(adapter.requests.single.headers.containsKey('X-Tenant-Id'), isFalse);
  });

  test(
    'turns the unified error format into an ApiException with field errors',
    () async {
      adapter.on(
        'POST',
        '/v1/auth/tokens',
        status: 422,
        body: fixture('error_validation.json'),
      );

      final error = await AuthRepository(fakeClient(adapter, session))
          .login('x', 'y')
          .then<ApiException?>(
            (_) => null,
            onError: (Object e) => e as ApiException,
          );

      expect(error!.isValidation, isTrue);
      expect(error.code, 'validation_failed');
      expect(error.fieldError('login'), 'بيانات الدخول غير صحيحة.');
    },
  );

  test('reports an expired session once, and maps plan limits', () async {
    var expired = 0;
    adapter.on(
      'GET',
      '/v1/me/wards',
      status: 401,
      body: fixture('error_unauth.json'),
    );
    adapter.on(
      'POST',
      '/v1/children',
      status: 402,
      body: fixture('error_plan.json'),
    );
    final client = fakeClient(adapter, session)
      ..onUnauthenticated = () => expired++;

    await expectLater(
      client.get('/v1/me/wards'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.isUnauthenticated,
          'unauthenticated',
          isTrue,
        ),
      ),
    );
    await expectLater(
      client.post('/v1/children'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'plan_limit_reached'),
      ),
    );
    expect(expired, 1);
  });

  test('explains a network failure in Arabic', () async {
    final error = await fakeClient(adapter, session)
        .get('/v1/nowhere')
        .then<ApiException?>(
          (_) => null,
          onError: (Object e) => e as ApiException,
        );

    expect(error!.code, 'network_error');
    expect(error.message, contains('تعذّر الاتصال'));
  });

  test('posts a class-wide update as JSON with exceptions', () async {
    adapter.on(
      'POST',
      '/v1/moments',
      status: 201,
      body: fixture('moment_photo.json'),
    );

    await WallRepository(fakeClient(adapter, session)).post(
      const NewMoment(
        type: 'meal',
        classroomId: 3,
        exceptChildIds: [7],
        payload: {'meal': 'lunch', 'amount': 'half'},
      ),
    );

    expect(adapter.requests.single.data, {
      'type': 'meal',
      'payload': {'meal': 'lunch', 'amount': 'half'},
      'classroom_id': 3,
      'except_child_ids': [7],
    });
  });
}
