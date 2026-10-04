import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/child.dart';
import '../../core/models/pickup.dart';

final wardsProvider = FutureProvider.autoDispose<List<Ward>>(
  (ref) => ref.watch(guardianRepositoryProvider).wards(),
);

final wardProvider = FutureProvider.autoDispose.family<Ward, int>(
  (ref, id) => ref.watch(guardianRepositoryProvider).ward(id),
);

final passesProvider = FutureProvider.autoDispose.family<List<PickupPass>, int>(
  (ref, childId) => ref.watch(guardianRepositoryProvider).passes(childId),
);

final photoConsentProvider = FutureProvider.autoDispose
    .family<PhotoConsent, int>(
      (ref, childId) =>
          ref.watch(guardianRepositoryProvider).photoConsent(childId),
    );
