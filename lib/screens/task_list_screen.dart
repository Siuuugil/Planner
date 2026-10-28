import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models/task.dart';
import '../ui/maple.dart';
import '../widgets/task_widgets.dart';

/// 업무 / 기타 할 일 목록.
class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key, required this.category});

  final TaskCategory category;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final all = store.tasksIn(widget.category);
    // 마감일 빠른 순, 마감일 없는 건 뒤로
    final open = all.where((t) => !t.done).toList()
      ..sort((a, b) {
        if (a.due == null || b.due == null) {
          return (a.due == null ? 1 : 0) - (b.due == null ? 1 : 0);
        }
        return a.due!.compareTo(b.due!);
      });
    final done = all.where((t) => t.done).toList();
    final isWork = widget.category == TaskCategory.work;

    return MapleScaffold(
      title: widget.category.label,
      floatingActionButton: FloatingActionButton(
        tooltip: '할 일 추가',
        onPressed: () => showTaskEditor(context, widget.category),
        child: const Icon(Icons.add, size: 30),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          MaplePanel(
            icon: isWork ? '💼' : '📝',
            title: isWork ? '진행 중인 업무' : '해야 할 일',
            accent: isWork ? const Color(0xFF4F8EDC) : Maple.orange,
            trailing: MapleBadge('${open.length}'),
            child: open.isEmpty
                ? const MapleEmpty('할 일이 없어요')
                : Column(children: withDividers(open.map((t) => TaskTile(task: t)))),
          ),
          if (done.isNotEmpty)
            MaplePanel(
              icon: '✅',
              title: '완료 ${done.length}개',
              accent: Maple.leaf,
              trailing: IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(_showDone ? Icons.expand_less : Icons.expand_more, color: Colors.white),
                onPressed: () => setState(() => _showDone = !_showDone),
              ),
              child: !_showDone
                  ? const SizedBox(height: 2)
                  : Column(
                      children: [
                        ...withDividers(done.map((t) => TaskTile(task: t))),
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
