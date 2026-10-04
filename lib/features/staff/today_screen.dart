import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/outbox.dart';
import '../../app/providers.dart';
import '../../core/models/attendance_sheet.dart';
import '../../core/models/child.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/wall_repository.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';
import 'nap_store.dart';

final _classroomFilterProvider = NotifierProvider<_ClassroomFilter, int?>(
  _ClassroomFilter.new,
);

class _ClassroomFilter extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? id) => state = id;
}

final sheetProvider = FutureProvider.autoDispose<AttendanceSheet>(
  (ref) => ref
      .watch(staffRepositoryProvider)
      .sheet(classroomId: ref.watch(_classroomFilterProvider)),
);
final _classroomsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(staffRepositoryProvider).classrooms(),
);

enum TodayMode { attendance, meal, nap, diaper, mood }

/// The teacher's day on one screen. Attendance, then quick logging for the
/// whole class with a "brush": pick a value, apply it to everyone, tap the
/// few exceptions, save — about five taps for twenty children. Everything is
/// acknowledged instantly and sent in the background (outbox).
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  TodayMode _mode = TodayMode.attendance;
  String _search = '';

  // Attendance multi-select.
  final Set<int> _selected = {};

  // Quick log: the brush and who got which value.
  String _meal = 'lunch';
  String _brush = 'all';
  final Map<int, String> _assigned = {};

  // Naps: who is asleep since when.
  final _naps = NapStore();
  Map<int, DateTime> _asleep = {};
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _loadNaps();
    _clock = Timer.periodic(
      const Duration(minutes: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _loadNaps() async {
    final tenantId = ref.read(sessionStoreProvider).tenantId;
    if (tenantId == null) return;
    final naps = await _naps.load(tenantId);
    if (mounted) setState(() => _asleep = naps);
  }

  Map<String, String> _choices(S s) => switch (_mode) {
    TodayMode.meal =>
      s.isArabic
          ? {
              'all': 'أكل كله',
              'most': 'معظمه',
              'half': 'نصفه',
              'little': 'قليلاً',
              'none': 'لم يأكل',
            }
          : {
              'all': 'All',
              'most': 'Most',
              'half': 'Half',
              'little': 'A little',
              'none': 'None',
            },
    TodayMode.diaper =>
      s.isArabic
          ? {'wet': 'مبلل', 'dirty': 'متسخ', 'dry': 'جاف'}
          : {'wet': 'Wet', 'dirty': 'Dirty', 'dry': 'Dry'},
    TodayMode.mood =>
      s.isArabic
          ? {
              'happy': '😊 سعيد',
              'calm': '😌 هادئ',
              'tired': '🥱 متعب',
              'sad': '😢 حزين',
              'upset': '😠 منزعج',
            }
          : {
              'happy': '😊 Happy',
              'calm': '😌 Calm',
              'tired': '🥱 Tired',
              'sad': '😢 Sad',
              'upset': '😠 Upset',
            },
    _ => const {},
  };

  void _setMode(TodayMode mode) => setState(() {
    _mode = mode;
    _assigned.clear();
    _selected.clear();
    _brush = switch (mode) {
      TodayMode.diaper => 'wet',
      TodayMode.mood => 'happy',
      _ => 'all',
    };
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final sheet = ref.watch(sheetProvider);
    final outbox = ref.watch(outboxProvider);
    // Something reached the server: show the confirmed state.
    ref.listen(
      outboxProvider.select((o) => o.delivered),
      (_, _) => ref.invalidate(sheetProvider),
    );
    final safePickup =
        ref.watch(sessionControllerProvider).value?.can.safePickup ?? false;

    return Scaffold(
      floatingActionButton:
          _mode == TodayMode.attendance && _selected.isEmpty && safePickup
          ? FloatingActionButton.extended(
              heroTag: 'door',
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(s.scanAtDoor),
              onPressed: () async {
                await context.push('/door');
                ref.invalidate(sheetProvider);
              },
            )
          : null,
      bottomNavigationBar: _actionBar(s, sheet.value),
      body: RefreshIndicator(
        onRefresh: () async {
          unawaited(ref.read(outboxProvider.notifier).flush());
          return ref.refresh(sheetProvider.future);
        },
        child: AsyncView(
          value: sheet,
          onRetry: () => ref.invalidate(sheetProvider),
          builder: (sheet) {
            final rows = sheet.rows
                .where((r) => _search.isEmpty || r.fullName.contains(_search))
                .toList();
            final present = rows.where((r) => _isPresent(r, outbox)).toList();

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverList.list(
                    children: [
                      _ModeBar(mode: _mode, onChanged: _setMode),
                      const SizedBox(height: 10),
                      _Toolbar(
                        onSearch: (q) => setState(() => _search = q.trim()),
                      ),
                      const SizedBox(height: 10),
                      if (_mode == TodayMode.attendance)
                        _Summary(
                          sheet: sheet,
                          pending: outbox.pendingCheckIns.length,
                        ),
                      if (_mode == TodayMode.meal ||
                          _mode == TodayMode.diaper ||
                          _mode == TodayMode.mood)
                        _brushBar(s, present),
                      if (_mode == TodayMode.nap) _napBar(s, present),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                if (_mode == TodayMode.attendance)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverList.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, i) =>
                          _attendanceRow(s, rows[i], outbox),
                    ),
                  )
                else if (present.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyView(
                      icon: Icons.how_to_reg_outlined,
                      message: s.isArabic
                          ? 'سجّلي حضور الأطفال أولاً'
                          : 'Check children in first',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 128,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.92,
                          ),
                      itemCount: present.length,
                      itemBuilder: (context, i) => _tile(s, present[i]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _isPresent(SheetRow row, OutboxState outbox) =>
      row.status == 'present' ||
      (row.status == 'absent' && outbox.pendingCheckIns.contains(row.childId));

  // ---------------------------------------------------------------- attendance

  Widget _attendanceRow(S s, SheetRow row, OutboxState outbox) {
    final lang = s.isArabic ? 'ar' : 'en';
    final pending =
        row.status == 'absent' && outbox.pendingCheckIns.contains(row.childId);
    final selected = _selected.contains(row.childId);
    final selecting = _selected.isNotEmpty;

    final (label, color) = switch (row.status) {
      _ when pending => (
        s.isArabic ? 'حاضر · جارٍ الإرسال' : 'Present · sending',
        AppColors.success,
      ),
      'present' => (
        row.latePickup
            ? s.latePickup
            : s.arrivedAt(formatTime(row.attendance?.checkedInAt, lang)),
        row.latePickup ? AppColors.danger : AppColors.success,
      ),
      'picked_up' => (
        s.leftAt(
          formatTime(row.attendance?.checkedOutAt, lang),
          row.attendance?.pickedUpByName,
        ),
        AppColors.teal,
      ),
      _ => (s.absent, Colors.grey),
    };

    void toggle() => setState(
      () =>
          selected ? _selected.remove(row.childId) : _selected.add(row.childId),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: selected ? const Color(0xFFFFF1EC) : null,
        child: ListTile(
          onLongPress: row.status == 'absent' && !pending ? toggle : null,
          onTap: selecting && row.status == 'absent' && !pending
              ? toggle
              : null,
          leading: selecting && row.status == 'absent' && !pending
              ? Checkbox(value: selected, onChanged: (_) => toggle())
              : ChildAvatar(name: row.firstName),
          title: Text(
            row.fullName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusChip(label: label, color: color),
            ),
          ),
          trailing: selecting
              ? null
              : switch (row.status) {
                  'absent' when !pending => FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: AppColors.teal,
                    ),
                    onPressed: () => _checkIn([row]),
                    child: Text(s.checkIn),
                  ),
                  'present' => OutlinedButton(
                    onPressed: () => _checkOut(row),
                    child: Text(s.checkOut),
                  ),
                  _ when pending => const Icon(
                    Icons.cloud_upload_outlined,
                    color: AppColors.success,
                  ),
                  _ => null,
                },
        ),
      ),
    );
  }

  Future<void> _checkIn(List<SheetRow> rows) async {
    unawaited(HapticFeedback.lightImpact());
    await ref
        .read(outboxProvider.notifier)
        .checkIn(rows.map((r) => (id: r.childId, name: r.fullName)));
    setState(_selected.clear);
  }

  /// Handing a child over is a safety decision: always online, always verified.
  Future<void> _checkOut(SheetRow row) async {
    final s = S.of(context);
    final repo = ref.read(staffRepositoryProvider);
    Child child;
    try {
      child = await repo.child(row.childId);
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (!mounted) return;

    final collector = await showModalBottomSheet<Guardian>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              s.whoIsCollecting,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final g in child.guardians)
              ListTile(
                leading: Icon(
                  g.isBlocked
                      ? Icons.block
                      : (g.canPickup ? Icons.verified_user : Icons.person_off),
                  color: g.isBlocked
                      ? AppColors.danger
                      : (g.canPickup ? AppColors.success : Colors.grey),
                ),
                title: Text(
                  g.name,
                  style: TextStyle(
                    color: g.isBlocked ? AppColors.danger : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  g.isBlocked ? s.notAllowed : (g.relationship ?? ''),
                ),
                enabled: g.mayCollect,
                onTap: () => Navigator.pop(context, g),
              ),
          ],
        ),
      ),
    );
    if (collector == null || !mounted) return;

    final ok = await guarded(
      context,
      () => repo.checkOut(row.childId, collectorId: collector.id),
    );
    if (ok) {
      unawaited(HapticFeedback.mediumImpact());
      ref.invalidate(sheetProvider);
    }
  }

  // ---------------------------------------------------------------- quick log

  Widget _brushBar(S s, List<SheetRow> present) {
    final choices = _choices(s);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_mode == TodayMode.meal) ...[
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: 'breakfast',
                    label: Text(s.isArabic ? 'الإفطار' : 'Breakfast'),
                  ),
                  ButtonSegment(
                    value: 'lunch',
                    label: Text(s.isArabic ? 'الغداء' : 'Lunch'),
                  ),
                  ButtonSegment(
                    value: 'snack',
                    label: Text(s.isArabic ? 'السناك' : 'Snack'),
                  ),
                ],
                selected: {_meal},
                onSelectionChanged: (v) => setState(() => _meal = v.first),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              s.isArabic
                  ? 'اختاري القيمة ثم المسي الأطفال'
                  : 'Pick a value, then tap children',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in choices.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _brush == e.key,
                    selectedColor: AppColors.coral.withValues(alpha: 0.2),
                    onSelected: (_) => setState(() => _brush = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.select_all_rounded),
                  label: Text(
                    s.isArabic
                        ? 'للكل: ${choices[_brush]}'
                        : 'All: ${choices[_brush]}',
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(
                      () => _assigned.addEntries(
                        present.map((r) => MapEntry(r.childId, _brush)),
                      ),
                    );
                  },
                ),
                const Spacer(),
                if (_assigned.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(_assigned.clear),
                    child: Text(s.isArabic ? 'مسح' : 'Clear'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _napBar(S s, List<SheetRow> present) {
    final sleeping = present
        .where((r) => _asleep.containsKey(r.childId))
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.bedtime_outlined, color: AppColors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.isArabic
                    ? 'نائم الآن: $sleeping — المسي الطفل عند النوم ثم عند الاستيقاظ'
                    : 'Asleep: $sleeping — tap at sleep, tap again at wake-up',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () => _startNaps(
                present.where((r) => !_asleep.containsKey(r.childId)),
              ),
              child: Text(s.isArabic ? 'نوم الكل' : 'All asleep'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(S s, SheetRow row) {
    final choices = _choices(s);
    final value = _assigned[row.childId];
    final asleepSince = _asleep[row.childId];
    final lang = s.isArabic ? 'ar' : 'en';

    final (Color bg, Color fg, String? caption) = switch (_mode) {
      TodayMode.nap when asleepSince != null => (
        AppColors.teal,
        Colors.white,
        '${formatTime(asleepSince, lang)} · ${DateTime.now().difference(asleepSince).inMinutes}${s.isArabic ? 'د' : 'm'}',
      ),
      TodayMode.nap => (Colors.white, Colors.black87, null),
      _ when value != null => (AppColors.coral, Colors.white, choices[value]),
      _ => (Colors.white, Colors.black87, null),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          HapticFeedback.selectionClick();
          if (_mode == TodayMode.nap) {
            asleepSince == null ? _startNaps([row]) : _wakeUp(row, asleepSince);
          } else {
            setState(
              () => value == _brush
                  ? _assigned.remove(row.childId)
                  : _assigned[row.childId] = _brush,
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_mode == TodayMode.nap && asleepSince != null)
                const Icon(Icons.bedtime, color: Colors.white, size: 32)
              else if (_mode != TodayMode.nap && value != null)
                const Icon(Icons.check_circle, color: Colors.white, size: 32)
              else
                ChildAvatar(name: row.firstName, radius: 22),
              const SizedBox(height: 6),
              Text(
                row.firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, color: fg),
              ),
              if (caption != null)
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: fg),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startNaps(Iterable<SheetRow> rows) async {
    final tenantId = ref.read(sessionStoreProvider).tenantId;
    if (tenantId == null) return;
    final now = DateTime.now();
    setState(
      () => _asleep = {..._asleep, for (final r in rows) r.childId: now},
    );
    await _naps.save(tenantId, _asleep);
  }

  /// Waking up posts the nap (from → to) for that child, in the background.
  Future<void> _wakeUp(SheetRow row, DateTime since) async {
    final tenantId = ref.read(sessionStoreProvider).tenantId;
    if (tenantId == null) return;
    final napLabel = S.of(context).isArabic ? 'نوم' : 'Nap';
    String hhmm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final now = DateTime.now();

    setState(() => _asleep = Map.of(_asleep)..remove(row.childId));
    await _naps.save(tenantId, _asleep);
    await ref
        .read(outboxProvider.notifier)
        .addMoment(
          NewMoment(
            type: 'nap',
            childIds: [row.childId],
            payload: {
              'from': hhmm(since),
              'to': hhmm(
                now.isAfter(since)
                    ? now
                    : since.add(const Duration(minutes: 1)),
              ),
            },
          ),
          label: '$napLabel · ${row.firstName}',
        );
  }

  /// One update per value: "lunch — all" for 17 children, "lunch — half" for 3.
  Future<void> _saveAssigned() async {
    final s = S.of(context);
    final groups = <String, List<int>>{};
    _assigned.forEach(
      (child, value) => groups.putIfAbsent(value, () => []).add(child),
    );
    final choices = _choices(s);
    final outbox = ref.read(outboxProvider.notifier);

    for (final MapEntry(key: value, value: children) in groups.entries) {
      final (type, payload) = switch (_mode) {
        TodayMode.meal => ('meal', {'meal': _meal, 'amount': value}),
        TodayMode.diaper => ('diaper', {'kind': value}),
        _ => ('mood', {'mood': value}),
      };
      await outbox.addMoment(
        NewMoment(type: type, childIds: children, payload: payload),
        label:
            '${choices[value]} · ${children.length} ${s.isArabic ? 'طفل' : 'children'}',
      );
    }

    final count = _assigned.length;
    setState(_assigned.clear);
    unawaited(HapticFeedback.mediumImpact());
    if (mounted) {
      showMessage(
        context,
        s.isArabic
            ? 'تم تسجيل $count طفل — يُرسل تلقائياً'
            : '$count logged — sending in the background',
      );
    }
  }

  Widget? _actionBar(S s, AttendanceSheet? sheet) {
    final (String label, VoidCallback onPressed)? action = switch (_mode) {
      TodayMode.attendance when _selected.isNotEmpty => (
        s.isArabic
            ? 'تسجيل حضور (${_selected.length})'
            : 'Check in (${_selected.length})',
        () => _checkIn(
          sheet!.rows.where((r) => _selected.contains(r.childId)).toList(),
        ),
      ),
      TodayMode.meal ||
      TodayMode.diaper ||
      TodayMode.mood when _assigned.isNotEmpty => (
        s.isArabic
            ? 'حفظ لـ ${_assigned.length} طفل'
            : 'Save for ${_assigned.length}',
        _saveAssigned,
      ),
      _ => null,
    };
    if (action == null) return null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            if (_mode == TodayMode.attendance)
              IconButton(
                onPressed: () => setState(_selected.clear),
                icon: const Icon(Icons.close),
              ),
            Expanded(
              child: FilledButton(onPressed: action.$2, child: Text(action.$1)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeBar extends StatelessWidget {
  const _ModeBar({required this.mode, required this.onChanged});

  final TodayMode mode;
  final ValueChanged<TodayMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final ar = S.of(context).isArabic;
    final modes = {
      TodayMode.attendance: (
        Icons.how_to_reg_outlined,
        ar ? 'الحضور' : 'Attendance',
      ),
      TodayMode.meal: (Icons.restaurant_rounded, ar ? 'وجبة' : 'Meal'),
      TodayMode.nap: (Icons.bedtime_outlined, ar ? 'نوم' : 'Nap'),
      TodayMode.diaper: (
        Icons.baby_changing_station_outlined,
        ar ? 'حفاض' : 'Diaper',
      ),
      TodayMode.mood: (Icons.mood_rounded, ar ? 'مزاج' : 'Mood'),
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final e in modes.entries)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: ChoiceChip(
                avatar: Icon(e.value.$1, size: 18),
                label: Text(e.value.$2),
                selected: mode == e.key,
                onSelected: (_) => onChanged(e.key),
              ),
            ),
        ],
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = S.of(context).isArabic;
    final classrooms =
        ref.watch(_classroomsProvider).value ?? const <ClassroomRef>[];
    final selected = ref.watch(_classroomFilterProvider);

    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: onSearch,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: ar ? 'ابحثي باسم الطفل' : 'Search a child',
            ),
          ),
        ),
        if (classrooms.length > 1) ...[
          const SizedBox(width: 8),
          DropdownButton<int?>(
            value: selected,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(ar ? 'كل الفصول' : 'All classes'),
              ),
              for (final c in classrooms)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (id) =>
                ref.read(_classroomFilterProvider.notifier).set(id),
          ),
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.sheet, required this.pending});

  final AttendanceSheet sheet;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final ar = S.of(context).isArabic;
    Widget cell(String label, int value, Color color) => Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            cell(
              ar ? 'حاضر' : 'Present',
              (sheet.summary['present'] ?? 0) + pending,
              AppColors.success,
            ),
            cell(
              ar ? 'انصرف' : 'Left',
              sheet.summary['picked_up'] ?? 0,
              AppColors.teal,
            ),
            cell(
              ar ? 'غائب' : 'Absent',
              ((sheet.summary['absent'] ?? 0) - pending).clamp(0, 9999),
              Colors.grey,
            ),
            if ((sheet.summary['late_pickup'] ?? 0) > 0)
              cell(
                ar ? 'متأخر' : 'Late',
                sheet.summary['late_pickup']!,
                AppColors.danger,
              ),
          ],
        ),
      ),
    );
  }
}
