import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_store.dart';
import '../data/store_scope.dart';
import '../models/repeat.dart';
import '../models/task.dart';
import '../ui/kit.dart';
import 'schedule_widgets.dart' show RepeatPicker;

String dueLabel(DateTime due) {
  final now = DateTime.now();
  final diff = DateTime(due.year, due.month, due.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  final date = DateFormat('M/d (E)', 'ko_KR').format(due);
  if (diff == 0) return '오늘까지';
  if (diff == 1) return '내일까지 · $date';
  if (diff < 0) return '${-diff}일 지남 · $date';
  return 'D-$diff · $date';
}

class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, this.showCategory = false});

  final Task task;
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final overdue = task.isDueBy(DateTime.now()) &&
        task.due!.isBefore(DateUtils.dateOnly(DateTime.now()));
    final subtitle = [
      if (showCategory) task.category.label,
      if (task.due != null) dueLabel(task.due!),
      if (task.repeat != null) '🔁 ${task.repeat!.label(task.due ?? DateTime.now())}',
      if (task.steps.isNotEmpty) '단계 ${task.stepsDone}/${task.steps.length}',
      if (task.memo.isNotEmpty) task.memo,
    ].join(' · ');

    return ListTile(
      leading: CheckCircle(
        value: task.done,
        onChanged: (v) => store.setTaskDone(task, v),
      ),
      title: Text(
        task.title,
        style: task.done
            ? TextStyle(decoration: TextDecoration.lineThrough, color: Ui.subtext)
            : null,
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: overdue
                  ? TextStyle(color: Theme.of(context).colorScheme.error)
                  : null,
            ),
      onTap: () => showTaskEditor(context, task.category, existing: task),
    );
  }
}

Future<void> showTaskEditor(
  BuildContext context,
  TaskCategory category, {
  Task? existing,
}) =>
    showDialog(
      context: context,
      builder: (_) => _TaskEditor(category: category, existing: existing),
    );

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({required this.category, this.existing});

  final TaskCategory category;
  final Task? existing;

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _memo = TextEditingController(text: widget.existing?.memo);
  late TaskCategory _category = widget.existing?.category ?? widget.category;
  late DateTime? _due = widget.existing?.due;
  late Repeat? _repeat = widget.existing?.repeat;
  late DateTime? _until = widget.existing?.repeat?.until;
  late final List<TaskStep> _steps = [
    for (final s in widget.existing?.steps ?? <TaskStep>[]) TaskStep(s.title, done: s.done),
  ];
  final _newStep = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _memo.dispose();
    _newStep.dispose();
    super.dispose();
  }

  void _addStep() {
    final t = _newStep.text.trim();
    if (t.isEmpty) return;
    setState(() => _steps.add(TaskStep(t)));
    _newStep.clear();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final e = widget.existing;
    // 반복은 마감일이 있어야 다음 회차를 정할 수 있다 (없으면 오늘을 마감으로)
    final due = _repeat != null ? (_due ?? DateUtils.dateOnly(DateTime.now())) : _due;
    StoreScope.read(context).upsertTask(Task(
      id: e?.id ?? newId(),
      title: title,
      category: _category,
      memo: _memo.text.trim(),
      due: due,
      done: e?.done ?? false,
      repeat: _repeat == null ? null : Repeat(_repeat!.freq, interval: _repeat!.interval, until: _until),
      steps: _steps,
      extra: e?.extra,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '할 일 추가' : '할 일 수정'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                autofocus: widget.existing == null,
                decoration: const InputDecoration(labelText: '할 일'),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              SegmentedButton<TaskCategory>(
                segments: [
                  for (final c in TaskCategory.values)
                    ButtonSegment(value: c, label: Text(c.label)),
                ],
                selected: {_category},
                onSelectionChanged: (s) => setState(() => _category = s.first),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(_due == null
                          ? '마감일 없음'
                          : DateFormat('yyyy.M.d (E)', 'ko_KR').format(_due!)),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _due ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => _due = d);
                      },
                    ),
                  ),
                  if (_due != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _due = null),
                    ),
                ],
              ),
              RepeatPicker(
                repeat: _repeat,
                until: _until,
                start: _due ?? DateTime.now(),
                onChanged: (r, u) => setState(() {
                  _repeat = r;
                  _until = u;
                }),
              ),
              if (_repeat != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('끝내면 마감일이 다음 회차로 넘어가요', style: TextStyle(fontSize: 12.5, color: Ui.subtext)),
                ),
              TextField(
                controller: _memo,
                decoration: const InputDecoration(labelText: '메모'),
                maxLines: 3,
                minLines: 1,
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _steps.isEmpty ? '단계 (선택)' : '단계 ${_steps.where((s) => s.done).length}/${_steps.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ReorderableListView(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                physics: const NeverScrollableScrollPhysics(),
                onReorderItem: (a, b) => setState(() => _steps.insert(b, _steps.removeAt(a))),
                children: [
                  for (var i = 0; i < _steps.length; i++)
                    Row(
                      key: ObjectKey(_steps[i]),
                      children: [
                        Checkbox(
                          value: _steps[i].done,
                          onChanged: (v) => setState(() => _steps[i].done = v ?? false),
                        ),
                        Expanded(
                          child: Text(_steps[i].title,
                              style: _steps[i].done
                                  ? TextStyle(decoration: TextDecoration.lineThrough, color: Ui.subtext)
                                  : null),
                        ),
                        IconButton(
                          tooltip: '단계 빼기',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _steps.removeAt(i)),
                        ),
                        ReorderableDragStartListener(index: i, child: Icon(Icons.drag_handle, size: 20, color: Ui.subtext)),
                      ],
                    ),
                ],
              ),
              TextField(
                controller: _newStep,
                decoration: InputDecoration(
                  hintText: '단계 추가 (예: 자료 모으기)',
                  suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: _addStep),
                ),
                onSubmitted: (_) => _addStep(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () {
              StoreScope.read(context).deleteTask(widget.existing!);
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
