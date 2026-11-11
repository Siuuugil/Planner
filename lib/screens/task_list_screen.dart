import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/store_scope.dart';
import '../models/task.dart';
import '../ui/kit.dart';
import '../widgets/task_widgets.dart';

/// 할 일: 업무·개인을 한 곳에서, 필터 칩 + 빠른 추가
class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  /// null = 전체
  TaskCategory? _filter;
  bool _showDone = false;
  final _quick = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _quick.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _quickAdd() {
    final title = _quick.text.trim();
    if (title.isEmpty) return;
    StoreScope.read(context).upsertTask(Task(
      id: newId(),
      title: title,
      category: _filter ?? TaskCategory.work,
    ));
    _quick.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final all = _filter == null ? store.tasks : store.tasksIn(_filter!);
    // 마감일 빠른 순, 마감일 없는 건 뒤로
    final open = all.where((t) => !t.done).toList()
      ..sort((a, b) {
        if (a.due == null || b.due == null) {
          return (a.due == null ? 1 : 0) - (b.due == null ? 1 : 0);
        }
        return a.due!.compareTo(b.due!);
      });
    final done = all.where((t) => t.done).toList();

    return AppScaffold(
      title: '할 일',
      floatingActionButton: FloatingActionButton(
        tooltip: '할 일 추가 (마감일·메모)',
        onPressed: () => showTaskEditor(context, _filter ?? TaskCategory.work),
        child: const Icon(Icons.add, size: 28),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Wrap(
              spacing: 8,
              children: [
                for (final (label, value) in [
                  ('전체', null),
                  ('업무', TaskCategory.work),
                  ('개인', TaskCategory.etc),
                ])
                  _FilterPill(
                    label: label,
                    selected: _filter == value,
                    onTap: () => setState(() => _filter = value),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _quick,
              focusNode: _focus,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _quickAdd(),
              decoration: InputDecoration(
                hintText: '${(_filter ?? TaskCategory.work).label} 할 일 빠르게 추가',
                fillColor: Ui.card,
                prefixIcon: const Icon(Icons.add, color: Ui.subtext),
                suffixIcon: IconButton(
                  tooltip: '추가',
                  icon: const Icon(Icons.arrow_upward_rounded),
                  onPressed: _quickAdd,
                ),
              ),
            ),
          ),
          AppSection(
            title: '진행 중',
            trailing: CountBadge('${open.length}'),
            child: open.isEmpty
                ? const EmptyHint('할 일이 없어요')
                : Column(children: open.map((t) => TaskTile(task: t, showCategory: _filter == null)).toList()),
          ),
          if (done.isNotEmpty)
            AppSection(
              title: '완료 ${done.length}개',
              trailing: IconButton(
                tooltip: _showDone ? '접기' : '펼치기',
                icon: Icon(_showDone ? Icons.expand_less : Icons.expand_more, color: Ui.subtext),
                onPressed: () => setState(() => _showDone = !_showDone),
              ),
              child: !_showDone
                  ? const SizedBox(height: 4)
                  : Column(
                      children: [
                        ...done.map((t) => TaskTile(task: t, showCategory: _filter == null)),
                        TextButton(
                          onPressed: () {
                            for (final t in done) {
                              store.tasks.remove(t);
                            }
                            store.commit();
                          },
                          child: const Text('완료한 항목 모두 삭제'),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? Ui.text : Ui.card,
          shape: StadiumBorder(side: BorderSide(color: selected ? Ui.text : Ui.line)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40, minWidth: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Ui.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
