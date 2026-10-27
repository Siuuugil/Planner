enum ChorePeriod { daily, weekly }

/// 일일/주간 숙제. 게임의 초기화 시각이 지나면 자동으로 미완료 상태가 된다.
class Chore {
  Chore({
    required this.id,
    required this.title,
    required this.period,
    this.lastDone,
  });

  final String id;
  String title;
  ChorePeriod period;
  DateTime? lastDone;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'period': period.name,
        'lastDone': lastDone?.toIso8601String(),
      };

  factory Chore.fromJson(Map<String, dynamic> j) => Chore(
        id: j['id'] as String,
        title: j['title'] as String,
        period: ChorePeriod.values.byName(j['period'] as String),
        lastDone: j['lastDone'] == null
            ? null
            : DateTime.parse(j['lastDone'] as String),
      );
}

/// 스펙업 목표. 예: "아이템 레벨 1640 → 1680", current=1640, target=1680.
class Goal {
  Goal({
    required this.id,
    required this.title,
    this.start = 0,
    this.current = 0,
    required this.target,
    this.unit = '',
    this.deadline,
  });

  final String id;
  String title;
  double start;
  double current;
  double target;
  String unit;
  DateTime? deadline;

  double get progress {
    final span = target - start;
    if (span == 0) return current >= target ? 1 : 0;
    return ((current - start) / span).clamp(0, 1).toDouble();
  }

  bool get achieved => progress >= 1;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start': start,
        'current': current,
        'target': target,
        'unit': unit,
        'deadline': deadline?.toIso8601String(),
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String,
        title: j['title'] as String,
        start: (j['start'] as num? ?? 0).toDouble(),
        current: (j['current'] as num? ?? 0).toDouble(),
        target: (j['target'] as num).toDouble(),
        unit: j['unit'] as String? ?? '',
        deadline: j['deadline'] == null
            ? null
            : DateTime.parse(j['deadline'] as String),
      );
}

class Game {
  Game({
    required this.id,
    required this.name,
    this.colorValue = 0xFF5C6BC0,
    this.resetHour = 6,
    this.weeklyResetWeekday = DateTime.wednesday,
    List<Goal>? goals,
    List<Chore>? chores,
  })  : goals = goals ?? [],
        chores = chores ?? [];

  final String id;
  String name;
  int colorValue;

  /// 일일 초기화 시각 (0~23). 국내 게임은 대부분 오전 6시.
  int resetHour;

  /// 주간 초기화 요일 (DateTime.monday ~ DateTime.sunday).
  int weeklyResetWeekday;
  final List<Goal> goals;
  final List<Chore> chores;

  /// [now] 기준으로 [period]가 시작된 시각.
  DateTime periodStart(ChorePeriod period, DateTime now) {
    var base = DateTime(now.year, now.month, now.day, resetHour);
    if (now.isBefore(base)) {
      base = DateTime(base.year, base.month, base.day - 1, resetHour);
    }
    if (period == ChorePeriod.weekly) {
      final back = (base.weekday - weeklyResetWeekday + 7) % 7;
      base = DateTime(base.year, base.month, base.day - back, resetHour);
    }
    return base;
  }

  bool isChoreDone(Chore c, DateTime now) =>
      c.lastDone != null && !c.lastDone!.isBefore(periodStart(c.period, now));

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'resetHour': resetHour,
        'weeklyResetWeekday': weeklyResetWeekday,
        'goals': goals.map((g) => g.toJson()).toList(),
        'chores': chores.map((c) => c.toJson()).toList(),
      };

  factory Game.fromJson(Map<String, dynamic> j) => Game(
        id: j['id'] as String,
        name: j['name'] as String,
        colorValue: j['colorValue'] as int? ?? 0xFF5C6BC0,
        resetHour: j['resetHour'] as int? ?? 6,
        weeklyResetWeekday:
            j['weeklyResetWeekday'] as int? ?? DateTime.wednesday,
        goals: (j['goals'] as List? ?? [])
            .map((e) => Goal.fromJson(e as Map<String, dynamic>))
            .toList(),
        chores: (j['chores'] as List? ?? [])
            .map((e) => Chore.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
