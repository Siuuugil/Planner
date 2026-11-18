import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_store.dart';
import '../data/store_scope.dart';
import '../models/repeat.dart';
import '../models/schedule.dart';
import '../ui/kit.dart';

class ScheduleTile extends StatelessWidget {
  const ScheduleTile({super.key, required this.schedule, this.showDate = false});

  final Schedule schedule;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final game = store.gameById(schedule.gameId);
    final time = schedule.allDay
        ? '종일'
        : DateFormat('HH:mm').format(schedule.start);
    final date = showDate
        ? '${DateFormat('M/d (E)', 'ko_KR').format(schedule.start)} '
        : '';

    return ListTile(
      leading: CheckCircle(
        value: schedule.done,
        onChanged: (v) => store.setScheduleDone(schedule, v),
      ),
      title: Text(
        schedule.title,
        style: schedule.done
            ? TextStyle(decoration: TextDecoration.lineThrough, color: Ui.subtext)
            : null,
      ),
      subtitle: Text(
        [
          '$date$time',
          if (schedule.memo.isNotEmpty) schedule.memo,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: game == null ? null : GameTag(game.name),
      onTap: () => showScheduleEditor(context, existing: schedule),
    );
  }
}

/// 일정 추가/수정 다이얼로그.
Future<void> showScheduleEditor(
  BuildContext context, {
  Schedule? existing,
  DateTime? day,
  String? gameId,
}) {
  return showDialog(
    context: context,
    builder: (_) => _ScheduleEditor(
      existing: existing,
      day: day ?? DateTime.now(),
      gameId: gameId,
    ),
  );
}

class _ScheduleEditor extends StatefulWidget {
  const _ScheduleEditor({this.existing, required this.day, this.gameId});

  final Schedule? existing;
  final DateTime day;
  final String? gameId;

  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _memo = TextEditingController(text: widget.existing?.memo);
  late DateTime _date;
  late TimeOfDay _time;
  late bool _allDay;
  String? _gameId;
  Repeat? _repeat;
  DateTime? _until;

  /// 수정할 때는 회차가 아니라 원래 일정(반복 전체)을 고친다
  Schedule? get _root => widget.existing?.root;

  @override
  void initState() {
    super.initState();
    final e = widget.existing?.root;
    _repeat = e?.repeat;
    _until = e?.repeat?.until;
    final now = DateTime.now();
    _date = e?.start ?? widget.day;
    _time = e != null
        ? TimeOfDay.fromDateTime(e.start)
        : TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
    _allDay = e?.allDay ?? false;
    _gameId = e?.gameId ?? widget.gameId;
  }

  @override
  void dispose() {
    _title.dispose();
    _memo.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final store = StoreScope.read(context);
    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _allDay ? 0 : _time.hour,
      _allDay ? 0 : _time.minute,
    );
    final e = _root;
    final repeat = _repeat == null ? null : Repeat(_repeat!.freq, interval: _repeat!.interval, until: _until);
    store.upsertSchedule(Schedule(
      id: e?.id ?? newId(),
      title: title,
      start: start,
      allDay: _allDay,
      memo: _memo.text.trim(),
      done: e?.done ?? false,
      gameId: _gameId == '' ? store.mapleGame().id : _gameId,
      repeat: repeat,
      doneDates: repeat == null ? null : e?.doneDates,
      skipDates: repeat == null ? null : e?.skipDates,
      extra: e?.extra,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AlertDialog(
      title: Text(widget.existing == null ? '일정 추가' : '일정 수정'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                autofocus: widget.existing == null,
                decoration: const InputDecoration(labelText: '제목'),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(DateFormat('yyyy.M.d (E)', 'ko_KR').format(_date)),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => _date = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text(_allDay ? '종일' : _time.format(context)),
                    onPressed: _allDay
                        ? null
                        : () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: _time,
                            );
                            if (t != null) setState(() => _time = t);
                          },
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('종일'),
                value: _allDay,
                onChanged: (v) => setState(() => _allDay = v),
              ),
              RepeatPicker(
                repeat: _repeat,
                until: _until,
                start: _date,
                onChanged: (r, u) => setState(() {
                  _repeat = r;
                  _until = u;
                }),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 4),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('일상·업무'), icon: Icon(Icons.work_outline, size: 18)),
                  ButtonSegment(value: true, label: Text('게임'), icon: Icon(Icons.sports_esports_outlined, size: 18)),
                ],
                selected: {_gameId != null},
                onSelectionChanged: (sel) => setState(() {
                  if (sel.first) {
                    _gameId = (store.findMapleGame() ?? (store.games.isEmpty ? null : store.games.first))?.id ?? '';
                  } else {
                    _gameId = null;
                  }
                }),
              ),
              if (_gameId != null && store.games.length > 1) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: store.gameById(_gameId) == null ? store.games.first.id : _gameId,
                  decoration: const InputDecoration(labelText: '어떤 게임'),
                  items: [
                    for (final g in store.games) DropdownMenuItem(value: g.id, child: Text(g.name)),
                  ],
                  onChanged: (v) => setState(() => _gameId = v),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _memo,
                decoration: const InputDecoration(labelText: '메모'),
                maxLines: 3,
                minLines: 1,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () async {
              final store = StoreScope.read(context);
              final occ = widget.existing!;
              if (occ.root.isRepeat) {
                final which = await showDialog<String>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('반복 일정 삭제'),
                    content: Text('${DateFormat('M/d (E)', 'ko_KR').format(occ.start)} 하루만 뺄까요, 반복 전체를 지울까요?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d), child: const Text('취소')),
                      TextButton(onPressed: () => Navigator.pop(d, 'all'), child: const Text('전체 삭제')),
                      FilledButton(onPressed: () => Navigator.pop(d, 'one'), child: const Text('이날만 빼기')),
                    ],
                  ),
                );
                if (which == null) return;
                if (which == 'one') {
                  occ.root.skipDates.add(dayKey(occ.start));
                  store.commit();
                } else {
                  store.deleteSchedule(occ.root);
                }
              } else {
                store.deleteSchedule(occ);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _save, child: const Text('저장')),
      ],
    );
  }
}

/// 게임 일정·숙제임을 분명히 보여주는 보라색 태그
class GameTag extends StatelessWidget {
  const GameTag(this.name, {super.key});

  final String name;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Ui.purple.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('게임 · $name',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Ui.purple)),
      );
}

/// 반복 고르기 (일정·할 일 공통): 반복 종류 + 끝나는 날(선택)
class RepeatPicker extends StatelessWidget {
  const RepeatPicker({super.key, required this.repeat, required this.until, required this.start, required this.onChanged});

  final Repeat? repeat;
  final DateTime? until;
  final DateTime start;
  final void Function(Repeat? repeat, DateTime? until) onChanged;

  @override
  Widget build(BuildContext context) {
    final idx = Repeat.choices.indexWhere((c) => c.$2 == null ? repeat == null : c.$2!.sameRule(repeat));
    return Row(
      children: [
        Icon(Icons.repeat, size: 20, color: Ui.subtext),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<int>(
            isExpanded: true,
            value: idx < 0 ? 0 : idx,
            underline: const SizedBox(),
            borderRadius: BorderRadius.circular(10),
            items: [
              for (var i = 0; i < Repeat.choices.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(Repeat.choices[i].$2 == null ? Repeat.choices[i].$1 : Repeat.choices[i].$2!.label(start)),
                ),
            ],
            onChanged: (i) => onChanged(Repeat.choices[i!].$2, Repeat.choices[i].$2 == null ? null : until),
          ),
        ),
        if (repeat != null)
          TextButton(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: until ?? start.add(const Duration(days: 90)),
                firstDate: start,
                lastDate: DateTime(2100),
                helpText: '반복 끝나는 날',
              );
              onChanged(repeat, d);
            },
            child: Text(until == null ? '계속' : '${DateFormat('M/d').format(until!)}까지'),
          ),
      ],
    );
  }
}
