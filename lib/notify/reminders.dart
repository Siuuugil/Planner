import '../data/app_store.dart';
import '../models/game.dart';

/// 알림 설정 (기기별, 동기화 안 함).
class NotifySettings {
  const NotifySettings({
    this.enabled = true,
    this.scheduleLeadMinutes = 10,
    this.taskHour = 9,
    this.choreHoursBefore = 2,
  });

  final bool enabled;

  /// 일정 시작 몇 분 전에 알릴지. 0이면 일정 알림 끔.
  final int scheduleLeadMinutes;

  /// 마감일 당일·종일 일정은 이 시각에 알림.
  final int taskHour;

  /// 숙제 초기화 몇 시간 전에 남은 숙제를 알릴지. 0이면 끔.
  final int choreHoursBefore;

  NotifySettings copyWith({
    bool? enabled,
    int? scheduleLeadMinutes,
    int? taskHour,
    int? choreHoursBefore,
  }) =>
      NotifySettings(
        enabled: enabled ?? this.enabled,
        scheduleLeadMinutes: scheduleLeadMinutes ?? this.scheduleLeadMinutes,
        taskHour: taskHour ?? this.taskHour,
        choreHoursBefore: choreHoursBefore ?? this.choreHoursBefore,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'scheduleLeadMinutes': scheduleLeadMinutes,
        'taskHour': taskHour,
        'choreHoursBefore': choreHoursBefore,
      };

  factory NotifySettings.fromJson(Map<String, dynamic> j) => NotifySettings(
        enabled: j['enabled'] as bool? ?? true,
        scheduleLeadMinutes: j['scheduleLeadMinutes'] as int? ?? 10,
        taskHour: j['taskHour'] as int? ?? 9,
        choreHoursBefore: j['choreHoursBefore'] as int? ?? 2,
      );
}

class Reminder {
  Reminder(this.key, this.when, this.title, this.body);

  /// 같은 대상이면 같은 키 → 같은 알림 id
  final String key;
  final DateTime when;
  final String title;
  final String body;

  int get id => key.hashCode & 0x7fffffff;

  @override
  String toString() => '$when $title / $body';
}

/// [now]부터 [days]일 안에 울릴 알림 목록 (시간순, 최대 [limit]개).
List<Reminder> planReminders(
  AppStore store,
  NotifySettings s,
  DateTime now, {
  int days = 7,
  int limit = 60,
}) {
  if (!s.enabled) return [];
  final end = now.add(Duration(days: days));
  final out = <Reminder>[];
  void add(Reminder r) {
    if (r.when.isAfter(now) && r.when.isBefore(end)) out.add(r);
  }

  DateTime atHour(DateTime d) => DateTime(d.year, d.month, d.day, s.taskHour);

  if (s.scheduleLeadMinutes > 0) {
    for (final e in store.schedules) {
      if (e.done) continue;
      if (e.allDay) {
        add(Reminder('s:${e.id}', atHour(e.start), '📅 오늘 일정', e.title));
      } else {
        add(Reminder(
          's:${e.id}',
          e.start.subtract(Duration(minutes: s.scheduleLeadMinutes)),
          '📅 ${s.scheduleLeadMinutes}분 뒤 일정',
          e.title,
        ));
      }
    }
  }

  for (final t in store.tasks) {
    if (t.done || t.due == null) continue;
    add(Reminder('t:${t.id}', atHour(t.due!), '📜 오늘 마감 (${t.category.label})', t.title));
  }

  if (s.choreHoursBefore > 0) {
    final before = Duration(hours: s.choreHoursBefore);
    for (final g in store.games) {
      final daily = g.chores.where((c) => c.period == ChorePeriod.daily).toList();
      final weekly = g.chores.where((c) => c.period == ChorePeriod.weekly).toList();

      if (daily.isNotEmpty) {
        final start = g.periodStart(ChorePeriod.daily, now);
        for (var k = 1; k <= days; k++) {
          final reset = DateTime(start.year, start.month, start.day + k, g.resetHour);
          // 지금 기간은 남은 개수가 확정, 이후 기간은 초기화되어 전부 남는다.
          final left = k == 1
              ? daily.where((c) => !g.isChoreDone(c, now)).length
              : daily.length;
          if (left == 0) continue;
          add(Reminder(
            'cd:${g.id}:$k',
            reset.subtract(before),
            '⚔️ ${g.name} 일일 숙제 $left개 남음',
            '${s.choreHoursBefore}시간 뒤 초기화돼요',
          ));
        }
      }

      if (weekly.isNotEmpty) {
        final start = g.periodStart(ChorePeriod.weekly, now);
        final reset = DateTime(start.year, start.month, start.day + 7, g.resetHour);
        final left = weekly.where((c) => !g.isChoreDone(c, now)).length;
        if (left > 0) {
          add(Reminder(
            'cw:${g.id}',
            reset.subtract(before),
            '🛡️ ${g.name} 주간 숙제 $left개 남음',
            '${s.choreHoursBefore}시간 뒤 주간 초기화돼요',
          ));
        }
      }
    }
  }

  out.sort((a, b) => a.when.compareTo(b.when));
  return out.take(limit).toList();
}
