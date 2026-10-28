import 'package:flutter_test/flutter_test.dart';
import 'package:game_planner/data/app_store.dart';
import 'package:game_planner/models/game.dart';
import 'package:game_planner/models/schedule.dart';
import 'package:game_planner/models/task.dart';
import 'package:game_planner/notify/reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // 2026-10-28(수) 12:00
  final now = DateTime(2026, 10, 28, 12);
  late AppStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AppStore(await SharedPreferences.getInstance());
  });

  test('일정은 N분 전, 종일 일정·마감은 설정 시각에', () {
    store.schedules.addAll([
      Schedule(id: 'a', title: '레이드', start: DateTime(2026, 10, 28, 20)),
      Schedule(id: 'b', title: '생일', start: DateTime(2026, 10, 29), allDay: true),
      Schedule(id: 'old', title: '지난 일정', start: DateTime(2026, 10, 28, 9)),
      Schedule(id: 'done', title: '완료', start: DateTime(2026, 10, 28, 21), done: true),
    ]);
    store.tasks.add(Task(id: 't', title: '보고서', category: TaskCategory.work, due: DateTime(2026, 10, 30)));

    final r = planReminders(store, const NotifySettings(scheduleLeadMinutes: 15, taskHour: 8, choreHoursBefore: 0), now);
    expect(r.map((e) => (e.key, e.when)), [
      ('s:a', DateTime(2026, 10, 28, 19, 45)),
      ('s:b', DateTime(2026, 10, 29, 8)),
      ('t:t', DateTime(2026, 10, 30, 8)),
    ]);
  });

  test('일일 숙제: 오늘 다 했으면 오늘 알림은 없고 내일부터', () {
    final g = Game(id: 'g', name: '메이플', resetHour: 0, chores: [
      Chore(id: 'c', title: '몬파', period: ChorePeriod.daily, lastDone: DateTime(2026, 10, 28, 10)),
    ]);
    store.games.add(g);
    final r = planReminders(store, const NotifySettings(scheduleLeadMinutes: 0, choreHoursBefore: 2), now, days: 3);
    expect(r.map((e) => e.when), [
      DateTime(2026, 10, 29, 22), // 10/30 0시 초기화 2시간 전
      DateTime(2026, 10, 30, 22),
    ]);
  });

  test('주간 숙제: 남아 있으면 주간 초기화 전에 알림', () {
    store.games.add(Game(id: 'g', name: '로아', resetHour: 6, weeklyResetWeekday: DateTime.wednesday, chores: [
      Chore(id: 'w', title: '군단장', period: ChorePeriod.weekly),
    ]));
    final r = planReminders(store, const NotifySettings(scheduleLeadMinutes: 0, choreHoursBefore: 3), now);
    // 이번 주기는 10/28(수) 6시 시작 → 다음 초기화 11/4(수) 6시, 3시간 전
    expect(r.single.when, DateTime(2026, 11, 4, 3));
    expect(r.single.title, contains('주간 숙제 1개'));
  });

  test('알림을 끄면 아무것도 없음', () {
    store.schedules.add(Schedule(id: 'a', title: 'x', start: DateTime(2026, 10, 28, 20)));
    expect(planReminders(store, const NotifySettings(enabled: false), now), isEmpty);
  });
}
