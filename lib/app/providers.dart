import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/user.dart';
import '../core/network/api_client.dart';
import '../core/storage/session_store.dart';
import '../data/auth_repository.dart';
import '../data/billing_repository.dart';
import '../data/guardian_repository.dart';
import '../data/notifications_repository.dart';
import '../data/staff_repository.dart';
import '../data/wall_repository.dart';

/// Overridden in tests with a [MemorySessionStore].
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(session: ref.watch(sessionStoreProvider));
  // An expired / revoked token signs the user out everywhere.
  client.onUnauthenticated = () =>
      ref.read(sessionControllerProvider.notifier).expire();
  return client;
});

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);
final guardianRepositoryProvider = Provider(
  (ref) => GuardianRepository(ref.watch(apiClientProvider)),
);
final wallRepositoryProvider = Provider(
  (ref) => WallRepository(ref.watch(apiClientProvider)),
);
final staffRepositoryProvider = Provider(
  (ref) => StaffRepository(ref.watch(apiClientProvider)),
);
final billingRepositoryProvider = Provider(
  (ref) => BillingRepository(ref.watch(apiClientProvider)),
);
final notificationsRepositoryProvider = Provider(
  (ref) => NotificationsRepository(ref.watch(apiClientProvider)),
);

/// Who is signed in, and in which nursery they are working.
class Session {
  const Session({required this.user, this.nursery});

  final AppUser user;
  final Nursery? nursery;

  Capabilities get can => nursery?.capabilities ?? const Capabilities();

  Session copyWith({AppUser? user, Nursery? nursery}) =>
      Session(user: user ?? this.user, nursery: nursery ?? this.nursery);
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, Session?>(SessionController.new);

class SessionController extends AsyncNotifier<Session?> {
  SessionStore get _store => ref.read(sessionStoreProvider);
  AuthRepository get _auth => ref.read(authRepositoryProvider);

  @override
  Future<Session?> build() async {
    await _store.readLocale();
    final token = await _store.readToken();
    if (token == null) return null;

    try {
      return await _load(await _store.readTenantId());
    } catch (_) {
      // Offline or token rejected: back to sign-in (the token stays if it was only offline).
      return null;
    }
  }

  Future<void> loginWithPassword(String login, String password) =>
      _signIn(() => _auth.login(login, password));

  Future<void> loginWithOtp(String phone, String code) =>
      _signIn(() => _auth.verifyOtp(phone, code));

  Future<void> _signIn(Future<String> Function() obtainToken) async {
    final token = await obtainToken();
    await _store.writeToken(token);
    state = AsyncData(await _load(_store.tenantId));
  }

  Future<void> selectNursery(Nursery nursery) async {
    await _store.writeTenantId(nursery.id);
    final current = state.value;
    if (current != null) {
      state = AsyncData(Session(user: current.user, nursery: nursery));
    }
  }

  /// Reload profile and capabilities (e.g. after a pull-to-refresh).
  Future<void> refresh() async {
    if (state.value == null) return;
    state = AsyncData(await _load(_store.tenantId));
  }

  Future<void> logout() async {
    try {
      await _auth.logout();
    } catch (_) {
      // Signing out locally matters more than telling the server.
    }
    await expire();
  }

  /// The token is no longer valid: forget it and go back to sign-in.
  Future<void> expire() async {
    await _store.writeToken(null);
    await _store.writeTenantId(null);
    state = const AsyncData(null);
  }

  Future<Session> _load(int? preferredTenantId) async {
    final user = await _auth.me();
    final nurseries = user.nurseries;
    final Nursery? nursery =
        nurseries.where((n) => n.id == preferredTenantId).firstOrNull ??
        (nurseries.length == 1 ? nurseries.first : null);

    await _store.writeTenantId(nursery?.id);
    return Session(user: user, nursery: nursery);
  }
}

/// App language (ar / en), sent as Accept-Language on every request.
final localeControllerProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => Locale(ref.read(sessionStoreProvider).locale);

  Future<void> set(String code) async {
    await ref.read(sessionStoreProvider).writeLocale(code);
    state = Locale(code);
  }
}
