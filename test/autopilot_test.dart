import 'package:flutter_test/flutter_test.dart';
import 'package:game_planner/ai/ai_service.dart';
import 'package:game_planner/ai/autopilot.dart';
import 'package:game_planner/data/app_store.dart';
import 'package:game_planner/models/schedule.dart';
import 'package:game_planner/models/task.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  late DateTime now;
  late AppStore store;
  late SharedPreferences prefs;
  final asked = <String>[];

  Map<String, dynamic> answer(String prompt) => prompt.contains('주간 리포트') || prompt.contains('한 주를 돌아봐')
      ? {'summary': '지난주 잘했어요', 'highlights': ['보고서 끝'], 'nextWeek': ['발표 준비']}
      : {
          'summary': '보고서 먼저 끝내요',
          'blocks': [
            {'start': '09:00', 'end': '11:00', 'title': '보고서', 'kind': 'work'},
            {'start': '14:00', 'end': '15:00', 'title': '회의', 'kind': 'work'},
          ],
          'tips': [],
        };

  Autopilot pilot(String device) {
    final ai = AiService(store, prefs, deviceIdOverride: device, claimWait: Duration.zero, askOverride: (p) async {
      asked.add(device);
      return answer(p);
    });
    return Autopilot(store, ai, prefs, clock: () => now, claimWait: const Duration(milliseconds: 20))..briefing = true;
  }

  setUp(() async {
    asked.clear();
    now = DateTime(2026, 11, 16, 9, 0); // 월요일 9시
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = AppStore(prefs, clock: () => now);
    store.schedules.add(Schedule(id: 's', title: '주간회의', start: DateTime(2026, 11, 16, 14)));
    store.tasks.add(Task(id: 't', title: '분기 보고서', category: TaskCategory.work, due: DateTime(2026, 11, 16)));
  });

  test('정한 시각 전·주말·저녁에는 안 하고, 하루 한 번만', () async {
    final p = pilot('A');
    now = DateTime(2026, 11, 16, 8, 0);
    expect(p.due(now), isFalse); // 8:30 전
    now = DateTime(2026, 11, 21, 10, 0);
    expect(p.due(now), isFalse); // 토요일 (평일만)
    now = DateTime(2026, 11, 16, 19, 0);
    expect(p.due(now), isFalse); // 저녁
    now = DateTime(2026, 11, 16, 9, 0);
    expect(p.due(now), isTrue);
    await p.tick();
    expect(p.due(now), isFalse); // 오늘 했음
  });

  test('브리핑 + 월요일 리포트를 PC 마을 event 행으로 보낸다', () async {
    await pilot('A').tick();
    final events = store.pending.values.where((r) => r.kind == 'event').toList();
    expect(events.map((e) => e.data!['title']), ['☀️ 오늘 브리핑', '📊 주간 리포트']);
    final body = events.first.data!['body'] as String;
    expect(body, allOf(contains('보고서 먼저 끝내요'), contains('14:00 주간회의'), contains('분기 보고서'), contains('09:00 보고서')));
    expect(events.first.data!['source'], 'planner');
    // event 행은 앱 상태가 아니라서 다음 commit 때 삭제로 올라가지 않는다
    store.commit();
    expect(store.pending.values.where((r) => r.kind == 'event' && r.deleted), isEmpty);
  });

  test('PC 두 대가 켜져 있어도 하루 한 번만', () async {
    final a = pilot('A'), b = pilot('B');
    await Future.wait([a.tick(), b.tick()]);
    expect(asked.toSet().length, 1); // 한 대만 Claude 에게 물음
    expect(store.pending.values.where((r) => r.kind == 'event' && r.data!['title'] == '☀️ 오늘 브리핑').length, 1);
  });

  test('휴대폰으로 보내기를 끄면 event 없이 앱에만', () async {
    final p = pilot('A')..sendEvent = false;
    await p.tick();
    expect(store.pending.values.where((r) => r.kind == 'event'), isEmpty);
    expect(store.notes.any((n) => n.type == 'plan'), isTrue);
  });
}
