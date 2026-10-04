import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/models/billing.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

final invoicesProvider = FutureProvider.autoDispose<List<Invoice>>(
  (ref) => ref.watch(billingRepositoryProvider).invoices(),
);

Color invoiceColor(Invoice invoice) => switch (invoice.status) {
  'paid' => AppColors.success,
  'void' => Colors.grey,
  _ => invoice.isOverdue ? AppColors.danger : AppColors.warning,
};

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final invoices = ref.watch(invoicesProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(invoicesProvider.future),
      child: AsyncView(
        value: invoices,
        onRetry: () => ref.invalidate(invoicesProvider),
        builder: (list) => list.isEmpty
            ? ListView(
                children: const [EmptyView(icon: Icons.receipt_long_outlined)],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final invoice = list[i];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      title: Text(
                        invoice.period,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${invoice.number}\n${s.balance}: ${invoice.balance.formatted}',
                      ),
                      isThreeLine: true,
                      trailing: StatusChip(
                        label: invoice.statusLabel,
                        color: invoiceColor(invoice),
                      ),
                      onTap: () => context.push('/invoices/${invoice.id}'),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
