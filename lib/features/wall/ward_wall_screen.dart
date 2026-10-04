import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/moment.dart';
import '../../l10n/strings.dart';
import '../../shared/paged_list.dart';
import '../../shared/widgets.dart';
import 'moment_card.dart';

/// A family's view of their child's day.
class WardWallScreen extends ConsumerWidget {
  const WardWallScreen({super.key, required this.childId});

  final int childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(wallRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).dailyWall)),
      body: PagedList<Moment>(
        load: (page) => repo.wardWall(childId, page: page),
        empty: const EmptyView(icon: Icons.photo_library_outlined),
        itemBuilder: (context, moment, replace) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: MomentCard(
            moment: moment,
            onAcknowledge: () => guarded(
              context,
              () async => replace(await repo.acknowledge(childId, moment.id)),
            ),
          ),
        ),
      ),
    );
  }
}
