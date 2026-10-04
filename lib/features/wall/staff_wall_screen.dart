import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/outbox.dart';
import '../../app/providers.dart';
import '../../core/models/moment.dart';
import '../../l10n/strings.dart';
import '../../shared/paged_list.dart';
import '../../shared/widgets.dart';
import 'moment_card.dart';

class StaffWallScreen extends ConsumerStatefulWidget {
  const StaffWallScreen({super.key});

  @override
  ConsumerState<StaffWallScreen> createState() => _StaffWallScreenState();
}

class _StaffWallScreenState extends ConsumerState<StaffWallScreen> {
  final _list = GlobalKey<PagedListState<Moment>>();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final repo = ref.read(wallRepositoryProvider);
    // An update reached the server: show it in the feed.
    ref.listen(
      outboxProvider.select((o) => o.delivered),
      (_, _) => _list.currentState?.reload(),
    );

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-moment',
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(s.newMoment),
        onPressed: () async {
          final posted = await context.push<bool>('/moments/new');
          if (posted == true) await _list.currentState?.reload();
        },
      ),
      body: PagedList<Moment>(
        key: _list,
        load: (page) => repo.staffWall(page: page),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        empty: const EmptyView(icon: Icons.photo_library_outlined),
        itemBuilder: (context, moment, _) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: MomentCard(
            moment: moment,
            showChildren: true,
            onDelete: () => guarded(context, () async {
              await repo.delete(moment.id);
              await _list.currentState?.reload();
            }),
          ),
        ),
      ),
    );
  }
}
