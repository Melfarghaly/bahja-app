import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/models/billing.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';
import 'invoices_screen.dart';

final _invoiceProvider = FutureProvider.autoDispose.family<Invoice, int>(
  (ref, id) => ref.watch(billingRepositoryProvider).invoice(id),
);
final _methodsProvider = FutureProvider.autoDispose<List<PaymentMethod>>(
  (ref) => ref.watch(billingRepositoryProvider).paymentMethods(),
);

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final int invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final invoice = ref.watch(_invoiceProvider(invoiceId));
    final onlinePayments =
        ref.watch(sessionControllerProvider).value?.can.onlinePayments ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(invoice.value?.number ?? '')),
      body: AsyncView(
        value: invoice,
        onRetry: () => ref.invalidate(_invoiceProvider(invoiceId)),
        builder: (invoice) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    StatusChip(
                      label: invoice.statusLabel,
                      color: invoiceColor(invoice),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      invoice.balance.formatted,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.teal,
                      ),
                    ),
                    Text(
                      s.balance,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  for (final item in invoice.items)
                    ListTile(
                      title: Text(item.description),
                      trailing: Text(
                        item.amount.formatted,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: item.amount.piasters < 0
                              ? AppColors.success
                              : null,
                        ),
                      ),
                    ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text(s.isArabic ? 'الإجمالي' : 'Total'),
                    trailing: Text(
                      invoice.total.formatted,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  ListTile(
                    title: Text(s.isArabic ? 'المدفوع' : 'Paid'),
                    trailing: Text(invoice.paid.formatted),
                  ),
                ],
              ),
            ),
            if (invoice.payable && onlinePayments) ...[
              const SizedBox(height: 20),
              Text(
                s.payNow,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              AsyncView(
                value: ref.watch(_methodsProvider),
                builder: (methods) => Column(
                  children: [
                    for (final method in methods)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          icon: Icon(
                            method.kind == 'payment_code'
                                ? Icons.storefront_outlined
                                : Icons.credit_card,
                          ),
                          label: Text(method.label),
                          onPressed: () => _pay(context, ref, invoice, method),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pay(
    BuildContext context,
    WidgetRef ref,
    Invoice invoice,
    PaymentMethod method,
  ) => guarded(context, () async {
    final result = await ref
        .read(billingRepositoryProvider)
        .checkout(invoice.id, method.gateway);
    if (!context.mounted) return;

    if (result.checkoutUrl != null) {
      await launchUrl(
        Uri.parse(result.checkoutUrl!),
        mode: LaunchMode.externalApplication,
      );
    } else if (result.paymentCode != null) {
      final s = S.of(context);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s.fawryCode),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                result.paymentCode!,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(result.amount.formatted),
              const SizedBox(height: 12),
              Text(
                s.fawryHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: result.paymentCode!)),
              child: Text(s.isArabic ? 'نسخ' : 'Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.done),
            ),
          ],
        ),
      );
    }
    ref.invalidate(_invoiceProvider(invoice.id));
  });
}
