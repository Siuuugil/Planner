import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_store.dart';
import '../data/store_scope.dart';
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
        onChanged: (v) {
          schedule.done = v;
          store.commit();
        },
      ),
      title: Text(
        schedule.title,
        style: schedule.done
            ? const TextStyle(decoration: TextDecoration.lineThrough, color: Ui.subtext)
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

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
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
    final e = widget.existing;
    store.upsertSchedule(Schedule(
      id: e?.id ?? newId(),
      title: title,
      start: start,
      allDay: _allDay,
      memo: _memo.text.trim(),
      done: e?.done ?? false,
      gameId: _gameId == '' ? store.mapleGame().id : _gameId,
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
            onPressed: () {
              StoreScope.read(context).deleteSchedule(widget.existing!);
              Navigator.pop(context);
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
          color: const Color(0xFFF3EEFF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('게임 · $name',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Ui.purple)),
      );
}
