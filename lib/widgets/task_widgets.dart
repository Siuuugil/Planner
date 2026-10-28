import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_store.dart';
import '../data/store_scope.dart';
import '../models/task.dart';
import '../ui/maple.dart';

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
      if (task.memo.isNotEmpty) task.memo,
    ].join(' · ');

    return ListTile(
      leading: SlotCheck(
        value: task.done,
        onChanged: (v) {
          task.done = v;
          store.commit();
        },
      ),
      title: Text(
        task.title,
        style: task.done
            ? const TextStyle(decoration: TextDecoration.lineThrough, color: Maple.brownMid)
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

  @override
  void dispose() {
    _title.dispose();
    _memo.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final e = widget.existing;
    StoreScope.read(context).upsertTask(Task(
      id: e?.id ?? newId(),
      title: title,
      category: _category,
      memo: _memo.text.trim(),
      due: _due,
      done: e?.done ?? false,
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
