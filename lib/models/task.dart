import 'repeat.dart';

enum TaskCategory {
  work('업무'),
  etc('개인');

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
    this.repeat,
    List<TaskStep>? steps,
    Map<String, dynamic>? extra,
  })  : steps = steps ?? [],
        extra = extra ?? {};

  final String id;
  String title;
  TaskCategory category;
  String memo;

  /// 마감일 (날짜만 사용)
  DateTime? due;
  bool done;

  /// 반복 할 일: 끝내면 사라지지 않고 마감이 다음 회차로 넘어간다 (마감이 있어야 함)
  Repeat? repeat;

  /// 이 버전이 모르는 필드 — 그대로 다시 저장해서 지워지지 않게
  final Map<String, dynamic> extra;

  static const _known = {'id', 'title', 'category', 'memo', 'due', 'done', 'repeat', 'steps'};

  /// 하위 단계 (체크리스트)
  final List<TaskStep> steps;

  int get stepsDone => steps.where((s) => s.done).length;

  /// 완료 처리. 반복이면 마감을 다음 회차로 옮기고 단계는 다시 처음부터. 반복이 끝났으면 진짜 완료
  void complete(bool v, {DateTime? today}) {
    if (!v || repeat == null || due == null) {
      done = v;
      return;
    }
    final base = today != null && today.isAfter(due!) ? today : due!;
    final next = repeat!.nextAfter(due!, base);
    if (next == null) {
      done = true;
      return;
    }
    due = next;
    done = false;
    for (final s in steps) {
      s.done = false;
    }
  }

  /// 마감이 [today] 이전이거나 당일인 미완료 할 일
  bool isDueBy(DateTime today) {
    if (done || due == null) return false;
    final d = DateTime(due!.year, due!.month, due!.day);
    return !d.isAfter(DateTime(today.year, today.month, today.day));
  }

  Map<String, dynamic> toJson() => {
        ...extra,
        'id': id,
        'title': title,
        'category': category.name,
        'memo': memo,
        'due': due?.toIso8601String(),
        'done': done,
        if (repeat != null) 'repeat': repeat!.toJson(),
        if (steps.isNotEmpty) 'steps': steps.map((s) => s.toJson()).toList(),
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        category: TaskCategory.values.byName(j['category'] as String),
        memo: j['memo'] as String? ?? '',
        due: j['due'] == null ? null : DateTime.parse(j['due'] as String),
        done: j['done'] as bool? ?? false,
        repeat: Repeat.fromJson(j['repeat']),
        steps: [for (final s in (j['steps'] as List? ?? [])) if (s is Map) TaskStep.fromJson(s.cast<String, dynamic>())],
        extra: {for (final e in j.entries) if (!_known.contains(e.key)) e.key: e.value},
      );
}

/// 할 일의 하위 단계 하나
class TaskStep {
  TaskStep(this.title, {this.done = false});

  String title;
  bool done;

  Map<String, dynamic> toJson() => {'title': title, 'done': done};

  factory TaskStep.fromJson(Map<String, dynamic> j) => TaskStep('${j['title'] ?? ''}', done: j['done'] == true);
}
