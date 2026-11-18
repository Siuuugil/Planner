import 'package:flutter_test/flutter_test.dart';
import 'package:game_planner/data/app_store.dart';
import 'package:game_planner/models/repeat.dart';
import 'package:game_planner/models/schedule.dart';
import 'package:game_planner/models/task.dart';
import 'package:game_planner/notify/reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('반복 규칙', () {
    final mon = DateTime(2026, 11, 16, 10); // 월요일

    test('매일·평일·매주·격주·매월', () {
      expect(const Repeat(RepeatFreq.daily).occursOn(mon, DateTime(2026, 11, 20)), isTrue);
      expect(const Repeat(RepeatFreq.daily).occursOn(mon, DateTime(2026, 11, 15)), isFalse); // 시작 전
      expect(const Repeat(RepeatFreq.weekdays).occursOn(mon, DateTime(2026, 11, 21)), isFalse); // 토
      expect(const Repeat(RepeatFreq.weekdays).occursOn(mon, DateTime(2026, 11, 20)), isTrue); // 금
      expect(const Repeat(RepeatFreq.weekly).occursOn(mon, DateTime(2026, 11, 23)), isTrue);
      expect(const Repeat(RepeatFreq.weekly).occursOn(mon, DateTime(2026, 11, 24)), isFalse);
      const biweekly = Repeat(RepeatFreq.weekly, interval: 2);
      expect(biweekly.occursOn(mon, DateTime(2026, 11, 23)), isFalse);
      expect(biweekly.occursOn(mon, DateTime(2026, 11, 30)), isTrue);
      expect(const Repeat(RepeatFreq.monthly).occursOn(mon, DateTime(2026, 12, 16)), isTrue);
    });

    test('31일 매월은 짧은 달엔 말일, 끝나는 날 이후는 없음', () {
      final jan31 = DateTime(2027, 1, 31);
      expect(const Repeat(RepeatFreq.monthly).occursOn(jan31, DateTime(2027, 2, 28)), isTrue);
      final until = Repeat(RepeatFreq.daily, until: DateTime(2026, 11, 18));
      expect(until.occursOn(mon, DateTime(2026, 11, 18)), isTrue);
      expect(until.occursOn(mon, DateTime(2026, 11, 19)), isFalse);
      expect(until.nextAfter(mon, DateTime(2026, 11, 18)), isNull);
    });

    test('JSON으로 오가고 이름표가 읽기 쉽다', () {
      final r = Repeat(RepeatFreq.weekly, interval: 2, until: DateTime(2026, 12, 31));
      final back = Repeat.fromJson(r.toJson())!;
      expect((back.freq, back.interval, back.until), (RepeatFreq.weekly, 2, DateTime(2026, 12, 31)));
      expect(r.label(mon), '격주 월요일 · 12/31까지');
      expect(Repeat.fromJson({'freq': 'yearly'}), isNull); // 모르는 값은 반복 아님
    });
  });

  group('반복 일정', () {
    late AppStore store;
    final now = DateTime(2026, 11, 16, 8);
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = AppStore(await SharedPreferences.getInstance(), clock: () => now);
      store.schedules.add(Schedule(
          id: 'mt', title: '주간회의', start: DateTime(2026, 11, 16, 10), repeat: const Repeat(RepeatFreq.weekly)));
    });

    test('날짜마다 펼쳐지고, 완료는 그 날짜만', () {
      final today = store.schedulesOn(DateTime(2026, 11, 16)).single;
      final next = store.schedulesOn(DateTime(2026, 11, 23)).single;
      expect(next.start, DateTime(2026, 11, 23, 10));
      store.setScheduleDone(today, true);
      expect(store.schedulesOn(DateTime(2026, 11, 16)).single.done, isTrue);
      expect(store.schedulesOn(DateTime(2026, 11, 23)).single.done, isFalse);
      expect(store.schedules.single.doneDates, {'2026-11-16'});
    });

    test('이날만 빼기, 알림은 회차마다', () {
      store.schedules.single.skipDates.add('2026-11-23');
      expect(store.schedulesOn(DateTime(2026, 11, 23)), isEmpty);
      final r = planReminders(store, const NotifySettings(), now, days: 15)
          .where((r) => r.body == '주간회의')
          .map((r) => r.when)
          .toList();
      expect(r, [DateTime(2026, 11, 16, 9, 50), DateTime(2026, 11, 30, 9, 50)]);
    });

    test('반복·완료 날짜는 JSON으로 오간다', () {
      final s = store.schedules.single..doneDates.add('2026-11-16');
      final back = Schedule.fromJson(s.toJson());
      expect(back.repeat!.freq, RepeatFreq.weekly);
      expect(back.doneDates, {'2026-11-16'});
      expect(back.occursOn(DateTime(2026, 11, 30)), isTrue);
    });
  });

  group('반복 할 일 · 단계', () {
    test('끝내면 마감이 다음 회차로, 단계는 다시 처음부터', () {
      final t = Task(
          id: 't', title: '주간보고', category: TaskCategory.work, due: DateTime(2026, 11, 20), // 금
          repeat: const Repeat(RepeatFreq.weekly), steps: [TaskStep('초안', done: true), TaskStep('제출')]);
      t.complete(true, today: DateTime(2026, 11, 20));
      expect((t.done, t.due), (false, DateTime(2026, 11, 27)));
      expect(t.stepsDone, 0);
      // 한참 밀렸다가 끝내면 오늘 다음 회차로
      t.complete(true, today: DateTime(2026, 12, 9));
      expect(t.due, DateTime(2026, 12, 11));
    });

    test('반복 아닌 할 일은 그냥 완료, 반복이 끝나면 완료', () {
      final plain = Task(id: 'p', title: '보고서', category: TaskCategory.work)..complete(true);
      expect(plain.done, isTrue);
      final last = Task(
          id: 'l', title: '마지막', category: TaskCategory.work, due: DateTime(2026, 11, 20),
          repeat: Repeat(RepeatFreq.weekly, until: DateTime(2026, 11, 25)));
      last.complete(true, today: DateTime(2026, 11, 20));
      expect(last.done, isTrue);
    });

    test('단계·반복은 JSON으로 오가고, 모르는 필드는 지워지지 않는다', () {
      final t = Task.fromJson({
        'id': 't', 'title': '분기 보고서', 'category': 'work', 'memo': '', 'due': null, 'done': false,
        'steps': [{'title': '자료', 'done': true}, {'title': '초안', 'done': false}],
        'priority': 'high', // 다른 앱이 넣은 필드
      });
      expect(t.stepsDone, 1);
      t.title = '분기 보고서 v2';
      final j = t.toJson();
      expect(j['priority'], 'high');
      expect((j['steps'] as List).length, 2);
      final s = Schedule.fromJson({'id': 's', 'title': 'x', 'start': '2026-11-16T10:00:00.000', 'color': 'red'});
      expect(s.toJson()['color'], 'red');
    });
  });
}
