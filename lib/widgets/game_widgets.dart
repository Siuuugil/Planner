import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_store.dart';
import '../data/store_scope.dart';
import '../models/game.dart';

const gameColors = [
  0xFF5C6BC0,
  0xFFE53935,
  0xFFFB8C00,
  0xFFFDD835,
  0xFF43A047,
  0xFF00ACC1,
  0xFF8E24AA,
  0xFF6D4C41,
];

const weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

String _num(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

class ChoreTile extends StatelessWidget {
  const ChoreTile({super.key, required this.game, required this.chore, this.showGame = false});

  final Game game;
  final Chore chore;
  final bool showGame;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final done = game.isChoreDone(chore, DateTime.now());
    return CheckboxListTile(
      value: done,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (_) => store.toggleChore(game, chore),
      title: Text(
        chore.title,
        style: done ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
      ),
      subtitle: Text([
        if (showGame) game.name,
        chore.period == ChorePeriod.daily ? '일일' : '주간',
      ].join(' · ')),
      secondary: showGame
          ? null
          : IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showChoreEditor(context, game, existing: chore),
            ),
    );
  }
}

class GoalTile extends StatelessWidget {
  const GoalTile({super.key, required this.game, required this.goal, this.showGame = false});

  final Game game;
  final Goal goal;
  final bool showGame;

  @override
  Widget build(BuildContext context) {
    final pct = (goal.progress * 100).round();
    final deadline = goal.deadline == null
        ? null
        : 'D${_dday(goal.deadline!)} (${DateFormat('M/d').format(goal.deadline!)})';
    return ListTile(
      title: Text(showGame ? '[${game.name}] ${goal.title}' : goal.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: goal.progress,
            color: Color(game.colorValue),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 4),
          Text([
            '${_num(goal.current)} / ${_num(goal.target)}${goal.unit} ($pct%)',
            ?deadline,
          ].join(' · ')),
        ],
      ),
      trailing: goal.achieved ? const Icon(Icons.emoji_events, color: Colors.amber) : null,
      onTap: () => showGoalEditor(context, game, existing: goal),
    );
  }
}

String _dday(DateTime d) {
  final today = DateTime.now();
  final diff = DateTime(d.year, d.month, d.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  if (diff == 0) return '-Day';
  return diff > 0 ? '-$diff' : '+${-diff}';
}

// ---------------------------------------------------------------- 게임 편집

Future<void> showGameEditor(BuildContext context, {Game? existing}) =>
    showDialog(context: context, builder: (_) => _GameEditor(existing: existing));

class _GameEditor extends StatefulWidget {
  const _GameEditor({this.existing});

  final Game? existing;

  @override
  State<_GameEditor> createState() => _GameEditorState();
}

class _GameEditorState extends State<_GameEditor> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late int _color = widget.existing?.colorValue ?? gameColors.first;
  late int _resetHour = widget.existing?.resetHour ?? 6;
  late int _weekday = widget.existing?.weeklyResetWeekday ?? DateTime.wednesday;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final e = widget.existing;
    final store = StoreScope.read(context);
    if (e != null) {
      e
        ..name = name
        ..colorValue = _color
        ..resetHour = _resetHour
        ..weeklyResetWeekday = _weekday;
      store.commit();
    } else {
      store.upsertGame(Game(
        id: newId(),
        name: name,
        colorValue: _color,
        resetHour: _resetHour,
        weeklyResetWeekday: _weekday,
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '게임 추가' : '게임 수정'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.existing == null,
              decoration: const InputDecoration(labelText: '게임 이름'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final c in gameColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(c),
                      child: c == _color
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _resetHour,
                    decoration: const InputDecoration(labelText: '일일 초기화'),
                    items: [
                      for (var h = 0; h < 24; h++)
                        DropdownMenuItem(value: h, child: Text('$h시')),
                    ],
                    onChanged: (v) => setState(() => _resetHour = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _weekday,
                    decoration: const InputDecoration(labelText: '주간 초기화'),
                    items: [
                      for (var d = 1; d <= 7; d++)
                        DropdownMenuItem(value: d, child: Text('${weekdayNames[d - 1]}요일')),
                    ],
                    onChanged: (v) => setState(() => _weekday = v!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: _save, child: const Text('저장')),
      ],
    );
  }
}

// ---------------------------------------------------------------- 숙제 편집

Future<void> showChoreEditor(
  BuildContext context,
  Game game, {
  Chore? existing,
  ChorePeriod period = ChorePeriod.daily,
}) =>
    showDialog(
      context: context,
      builder: (_) => _ChoreEditor(game: game, existing: existing, period: period),
    );

class _ChoreEditor extends StatefulWidget {
  const _ChoreEditor({required this.game, this.existing, required this.period});

  final Game game;
  final Chore? existing;
  final ChorePeriod period;

  @override
  State<_ChoreEditor> createState() => _ChoreEditorState();
}

class _ChoreEditorState extends State<_ChoreEditor> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late ChorePeriod _period = widget.existing?.period ?? widget.period;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final e = widget.existing;
    if (e != null) {
      e
        ..title = title
        ..period = _period;
    } else {
      widget.game.chores.add(Chore(id: newId(), title: title, period: _period));
    }
    StoreScope.read(context).commit();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '숙제 추가' : '숙제 수정'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: widget.existing == null,
              decoration: const InputDecoration(labelText: '할 일 (예: 카오스 던전, 주간 보스)'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            SegmentedButton<ChorePeriod>(
              segments: const [
                ButtonSegment(value: ChorePeriod.daily, label: Text('일일')),
                ButtonSegment(value: ChorePeriod.weekly, label: Text('주간')),
              ],
              selected: {_period},
              onSelectionChanged: (s) => setState(() => _period = s.first),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () {
              widget.game.chores.remove(widget.existing);
              StoreScope.read(context).commit();
              Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: _save, child: const Text('저장')),
      ],
    );
  }
}

// ---------------------------------------------------------------- 목표 편집

Future<void> showGoalEditor(BuildContext context, Game game, {Goal? existing}) =>
    showDialog(
      context: context,
      builder: (_) => _GoalEditor(game: game, existing: existing),
    );

class _GoalEditor extends StatefulWidget {
  const _GoalEditor({required this.game, this.existing});

  final Game game;
  final Goal? existing;

  @override
  State<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<_GoalEditor> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _start = TextEditingController(text: _fmt(widget.existing?.start));
  late final _current = TextEditingController(text: _fmt(widget.existing?.current));
  late final _target = TextEditingController(text: _fmt(widget.existing?.target));
  late final _unit = TextEditingController(text: widget.existing?.unit);
  late DateTime? _deadline = widget.existing?.deadline;

  static String _fmt(double? v) => v == null ? '' : _num(v);

  @override
  void dispose() {
    for (final c in [_title, _start, _current, _target, _unit]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    final target = double.tryParse(_target.text.trim());
    if (title.isEmpty || target == null) return;
    final current = double.tryParse(_current.text.trim()) ?? 0;
    final start = double.tryParse(_start.text.trim()) ?? current;
    final e = widget.existing;
    if (e != null) {
      e
        ..title = title
        ..start = start
        ..current = current
        ..target = target
        ..unit = _unit.text.trim()
        ..deadline = _deadline;
    } else {
      widget.game.goals.add(Goal(
        id: newId(),
        title: title,
        start: start,
        current: current,
        target: target,
        unit: _unit.text.trim(),
        deadline: _deadline,
      ));
    }
    StoreScope.read(context).commit();
    Navigator.pop(context);
  }

  Widget _numField(TextEditingController c, String label) => Expanded(
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '스펙업 목표 추가' : '목표 수정 / 진행 업데이트'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                autofocus: widget.existing == null,
                decoration: const InputDecoration(labelText: '목표 (예: 아이템 레벨, 캐릭터 레벨)'),
              ),
              Row(
                children: [
                  _numField(_start, '시작값'),
                  const SizedBox(width: 8),
                  _numField(_current, '현재값'),
                  const SizedBox(width: 8),
                  _numField(_target, '목표값'),
                ],
              ),
              TextField(
                controller: _unit,
                decoration: const InputDecoration(labelText: '단위 (선택, 예: Lv, %)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.flag_outlined),
                      label: Text(_deadline == null
                          ? '마감일 없음'
                          : DateFormat('yyyy.M.d (E)', 'ko_KR').format(_deadline!)),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _deadline ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => _deadline = d);
                      },
                    ),
                  ),
                  if (_deadline != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _deadline = null),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () {
              widget.game.goals.remove(widget.existing);
              StoreScope.read(context).commit();
              Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: _save, child: const Text('저장')),
      ],
    );
  }
}
