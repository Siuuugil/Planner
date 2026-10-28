enum TaskCategory {
  work('업무'),
  etc('기타');

  const TaskCategory(this.label);
  final String label;
}

/// 업무/기타 할 일. 마감일은 선택.
class Task {
  Task({
    required this.id,
    required this.title,
    required this.category,
    this.memo = '',
    this.due,
    this.done = false,
  });

  final String id;
  String title;
  TaskCategory category;
  String memo;

  /// 마감일 (날짜만 사용)
  DateTime? due;
  bool done;

  /// 마감이 [today] 이전이거나 당일인 미완료 할 일
  bool isDueBy(DateTime today) {
    if (done || due == null) return false;
    final d = DateTime(due!.year, due!.month, due!.day);
    return !d.isAfter(DateTime(today.year, today.month, today.day));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category.name,
        'memo': memo,
        'due': due?.toIso8601String(),
        'done': done,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        category: TaskCategory.values.byName(j['category'] as String),
        memo: j['memo'] as String? ?? '',
        due: j['due'] == null ? null : DateTime.parse(j['due'] as String),
        done: j['done'] as bool? ?? false,
      );
}
