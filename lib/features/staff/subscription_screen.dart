import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

final _subscriptionProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(billingRepositoryProvider).subscription(),
);

/// Managers: the nursery's Bahga plan and usage.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ar = s.isArabic;

    return Scaffold(
      appBar: AppBar(title: Text(s.subscription)),
      body: AsyncView(
        value: ref.watch(_subscriptionProvider),
        onRetry: () => ref.invalidate(_subscriptionProvider),
        builder: (sub) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      sub.planName,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.teal,
                      ),
                    ),
                    if (sub.priceEgp != null)
                      Text(
                        ar
                            ? '${sub.priceEgp} ج.م / شهرياً'
                            : 'EGP ${sub.priceEgp} / month',
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '${ar ? 'يتجدد في' : 'Renews on'} ${formatDate(sub.periodEnd, ar ? 'ar' : 'en')}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            if (sub.childrenLimit != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ar ? 'الأطفال' : 'Children'}: ${sub.childrenUsed} / ${sub.childrenLimit}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (sub.childrenUsed ?? 0) / sub.childrenLimit!,
                        color: AppColors.coral,
                        backgroundColor: Colors.black12,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in sub.features)
                  StatusChip(label: f, color: AppColors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
