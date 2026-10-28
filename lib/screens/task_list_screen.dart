import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models/task.dart';
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
    final hint = Theme.of(context).hintColor;

    return Scaffold(
      appBar: AppBar(title: Text(widget.category.label)),
      floatingActionButton: FloatingActionButton(
        tooltip: '할 일 추가',
        onPressed: () => showTaskEditor(context, widget.category),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          if (open.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('할 일이 없어요', style: TextStyle(color: hint)),
              ),
            ),
          for (final t in open) TaskTile(task: t),
          if (done.isNotEmpty) ...[
            const Divider(),
            ListTile(
              title: Text('완료 ${done.length}개'),
              trailing: Icon(_showDone ? Icons.expand_less : Icons.expand_more),
              onTap: () => setState(() => _showDone = !_showDone),
            ),
            if (_showDone) ...[
              for (final t in done) TaskTile(task: t),
              Center(
                child: TextButton(
                  onPressed: () {
                    for (final t in done) {
                      store.tasks.remove(t);
                    }
                    store.commit();
                  },
                  child: const Text('완료한 항목 모두 삭제'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
