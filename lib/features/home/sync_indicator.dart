import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/outbox.dart';
import '../../core/outbox/outbox_item.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/strings.dart';

/// A small cloud in the app bar: nothing when all is sent, a count while
/// sending, red when something needs the teacher's attention.
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outbox = ref.watch(outboxProvider);
    if (outbox.items.isEmpty) return const SizedBox.shrink();

    final failed = outbox.failed.length;
    return IconButton(
      tooltip: S.of(context).isArabic ? 'قيد الإرسال' : 'Sending',
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => const _OutboxSheet(),
      ),
      icon: Badge(
        backgroundColor: failed > 0 ? AppColors.danger : AppColors.coral,
        label: Text('${outbox.items.length}'),
        child: Icon(
          failed > 0 ? Icons.cloud_off_rounded : Icons.cloud_upload_outlined,
          color: failed > 0 ? AppColors.danger : AppColors.teal,
        ),
      ),
    );
  }
}

class _OutboxSheet extends ConsumerWidget {
  const _OutboxSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ar = s.isArabic;
    final outbox = ref.watch(outboxProvider);
    final controller = ref.read(outboxProvider.notifier);

    if (outbox.items.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_done_rounded, color: AppColors.success),
              const SizedBox(width: 8),
              Text(ar ? 'تم إرسال كل شيء' : 'Everything is sent'),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ar
                      ? 'يُحفظ كل شيء على الهاتف ويُرسل تلقائياً عند توفر الإنترنت'
                      : 'Saved on the phone, sent automatically when online',
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              TextButton(
                onPressed: controller.flush,
                child: Text(ar ? 'أرسل الآن' : 'Send now'),
              ),
            ],
          ),
          for (final item in outbox.items)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  item.kind == OutboxKind.checkIn
                      ? Icons.how_to_reg_outlined
                      : (item.hasMedia
                            ? Icons.perm_media_outlined
                            : Icons.edit_note_rounded),
                  color: item.failed ? AppColors.danger : AppColors.teal,
                ),
                title: Text(
                  item.kind == OutboxKind.checkIn
                      ? '${ar ? 'حضور' : 'Check-in'} · ${item.label}'
                      : item.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: item.failed
                    ? Text(
                        item.error!,
                        style: const TextStyle(color: AppColors.danger),
                      )
                    : outbox.uploadingId == item.id && outbox.progress != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: LinearProgressIndicator(
                          value: outbox.progress,
                          color: AppColors.coral,
                        ),
                      )
                    : Text(
                        '${ar ? 'في الانتظار' : 'Waiting'} · ${formatTime(item.createdAt, ar ? 'ar' : 'en')}',
                      ),
                trailing: item.failed
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: s.retry,
                            onPressed: () => controller.retry(item.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: ar ? 'حذف' : 'Discard',
                            onPressed: () => controller.discard(item.id),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
