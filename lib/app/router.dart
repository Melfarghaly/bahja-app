import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/nursery_picker_screen.dart';
import '../features/billing/invoice_detail_screen.dart';
import '../features/guardian/attendance_history_screen.dart';
import '../features/guardian/passes_screen.dart';
import '../features/guardian/pickup_code_screen.dart';
import '../features/guardian/ward_detail_screen.dart';
import '../features/guardian/ward_settings_screen.dart';
import '../features/home/home_shell.dart';
import '../features/home/splash_screen.dart';
import '../features/staff/door_screen.dart';
import '../features/staff/subscription_screen.dart';
import '../features/wall/post_moment_screen.dart';
import '../features/wall/ward_wall_screen.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever the session changes (sign in / out / nursery).
  final refresh = ValueNotifier(0);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final at = state.matchedLocation;

      if (session.isLoading && !session.hasValue) {
        return at == '/splash' ? null : '/splash';
      }
      final current = session.value;
      if (current == null) return at == '/login' ? null : '/login';
      if (current.nursery == null) {
        return at == '/nurseries' ? null : '/nurseries';
      }
      if (at == '/login' || at == '/splash' || at == '/nurseries') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/nurseries',
        builder: (_, _) => const NurseryPickerScreen(),
      ),
      GoRoute(
        path: '/switch-nursery',
        builder: (_, _) => const NurseryPickerScreen(switching: true),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const HomeShell(),
        routes: [
          GoRoute(
            path: 'wards/:id',
            builder: (_, s) =>
                WardDetailScreen(childId: int.parse(s.pathParameters['id']!)),
            routes: [
              GoRoute(
                path: 'wall',
                builder: (_, s) =>
                    WardWallScreen(childId: int.parse(s.pathParameters['id']!)),
              ),
              GoRoute(
                path: 'attendance',
                builder: (_, s) => AttendanceHistoryScreen(
                  childId: int.parse(s.pathParameters['id']!),
                ),
              ),
              GoRoute(
                path: 'passes',
                builder: (_, s) =>
                    PassesScreen(childId: int.parse(s.pathParameters['id']!)),
              ),
              GoRoute(
                path: 'settings',
                builder: (_, s) => WardSettingsScreen(
                  childId: int.parse(s.pathParameters['id']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'pickup-code',
            builder: (_, _) => const PickupCodeScreen(),
          ),
          GoRoute(
            path: 'invoices/:id',
            builder: (_, s) => InvoiceDetailScreen(
              invoiceId: int.parse(s.pathParameters['id']!),
            ),
          ),
          GoRoute(path: 'door', builder: (_, _) => const DoorScreen()),
          GoRoute(
            path: 'moments/new',
            builder: (_, _) => const PostMomentScreen(),
          ),
          GoRoute(
            path: 'subscription',
            builder: (_, _) => const SubscriptionScreen(),
          ),
          GoRoute(path: 'account', builder: (_, _) => const AccountScreen()),
        ],
      ),
    ],
  );
});
