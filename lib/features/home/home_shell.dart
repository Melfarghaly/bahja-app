import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../billing/invoices_screen.dart';
import '../guardian/wards_screen.dart';
import '../notifications/inbox_screen.dart';
import '../staff/today_screen.dart';
import 'sync_indicator.dart';
import '../wall/staff_wall_screen.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.body);

  final String label;
  final IconData icon;
  final Widget body;
}

/// Bottom navigation built from what this user may do in this nursery
/// (a teacher who is also a mother sees both worlds).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final session = ref.watch(sessionControllerProvider).value;
    if (session == null) return const SizedBox.shrink();
    final can = session.can;

    final tabs = [
      if (can.guardian)
        _Tab(s.myChildren, Icons.child_care_rounded, const WardsScreen()),
      if (can.takeAttendance)
        _Tab(
          s.isArabic ? 'اليوم' : 'Today',
          Icons.today_rounded,
          const TodayScreen(),
        ),
      if (can.dailyWall && can.isStaff)
        _Tab(s.wall, Icons.photo_library_outlined, const StaffWallScreen()),
      _Tab(
        s.notifications,
        Icons.notifications_none_rounded,
        const InboxScreen(),
      ),
      if (can.guardian && can.bahgaPay)
        _Tab(s.invoices, Icons.receipt_long_outlined, const InvoicesScreen()),
    ];
    final index = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          session.nursery?.name ?? s.appName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (can.isStaff) const SyncIndicator(),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: s.account,
            onPressed: () => context.push('/account'),
          ),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: [for (final tab in tabs) tab.body],
      ),
      bottomNavigationBar: tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final tab in tabs)
                  NavigationDestination(icon: Icon(tab.icon), label: tab.label),
              ],
            ),
    );
  }
}
