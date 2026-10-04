import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/models/app_notification.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/strings.dart';
import '../../shared/paged_list.dart';
import '../../shared/widgets.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final _list = GlobalKey<PagedListState<AppNotification>>();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = s.isArabic ? 'ar' : 'en';
    final repo = ref.read(notificationsRepositoryProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'read-all',
        tooltip: s.isArabic ? 'قراءة الكل' : 'Mark all read',
        onPressed: () => guarded(context, () async {
          await repo.markAllRead();
          await _list.currentState?.reload();
        }),
        child: const Icon(Icons.done_all),
      ),
      body: PagedList<AppNotification>(
        key: _list,
        load: (page) => repo.inbox(page: page),
        empty: const EmptyView(icon: Icons.notifications_none_rounded),
        itemBuilder: (context, n, replace) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            color: n.read ? null : const Color(0xFFFFF7F4),
            child: ListTile(
              leading: Icon(
                n.urgent
                    ? Icons.priority_high_rounded
                    : Icons.notifications_rounded,
                color: n.urgent ? AppColors.danger : AppColors.teal,
              ),
              title: Text(
                n.title,
                style: TextStyle(
                  fontWeight: n.read ? FontWeight.w500 : FontWeight.w800,
                ),
              ),
              subtitle: Text('${n.body}\n${relativeTime(n.createdAt, lang)}'),
              isThreeLine: true,
              onTap: () async {
                if (!n.read) {
                  try {
                    replace(await repo.markRead(n.id));
                  } catch (_) {}
                }
                if (!context.mounted) return;
                final screen = n.deepLink['screen'];
                if (n.childId != null &&
                    (screen == 'ward' || screen == 'wall')) {
                  await context.push<void>(
                    screen == 'wall'
                        ? '/wards/${n.childId}/wall'
                        : '/wards/${n.childId}',
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
