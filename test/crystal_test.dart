import 'package:flutter_test/flutter_test.dart';
import 'package:game_planner/data/app_store.dart';
import 'package:game_planner/models/game.dart';
import 'package:game_planner/notify/reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // 목요일 0시 주간 초기화
  Game maple() => Game(
        id: 'g',
        name: '메이플스토리',
        resetHour: 0,
        weeklyResetWeekday: DateTime.thursday,
        bosses: [
          BossPrice(id: 'luc', name: '하드 루시드', price: 1000000000),
          BossPrice(id: 'will', name: '하드 윌', price: 1200000000),
        ],
        chores: [
          Chore(id: 'a', title: '하드 루시드', period: ChorePeriod.weekly, bossId: 'luc', partySize: 2, charName: '단풍이'),
          Chore(id: 'b', title: '하드 윌', period: ChorePeriod.weekly, bossId: 'will', charName: '단풍이'),
          Chore(id: 'x', title: '일반 주간 숙제', period: ChorePeriod.weekly),
        ],
      );

  test('파티 인원으로 나눈 수익, 이번 주 수익 기록', () {
    final g = maple();
    final now = DateTime(2026, 11, 11, 12); // 수요일 → 이번 주는 11/5(목) 시작
    expect(g.bossIncome(g.chores[0]), 500000000);
    expect(g.weekKey(now), '2026-11-05');

    g.chores[0].lastDone = now;
    g.recomputeCrystals(now);
    expect(g.crystalWeeks, {'2026-11-05': 500000000});

    g.chores[1].lastDone = now;
    g.recomputeCrystals(now);
    expect(g.crystalWeeks['2026-11-05'], 1700000000);
  });

  test('완료 취소하면 기록도 줄고, 지난 주 기록은 유지', () {
    final g = maple()..crystalWeeks['2026-10-29'] = 2200000000;
    final now = DateTime(2026, 11, 11, 12);
    g.chores[1].lastDone = now;
    g.recomputeCrystals(now);
    g.chores[1].lastDone = null;
    g.recomputeCrystals(now);
    expect(g.crystalWeeks, {'2026-10-29': 2200000000, '2026-11-05': 0});
  });

  test('메소 목표는 시작 주 이후 결정석 수익만 누적', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    final g = maple()
      ..crystalWeeks['2026-10-29'] = 9999999999
      ..goals.add(Goal(id: 'm', title: '무기', target: 5e9, autoMetric: 'crystal', autoSince: '2026-11-05'));
    store.games.add(g);
    // 실제 시계 기준으로 토글되므로 이번 주 키를 사용
    final key = g.weekKey(DateTime.now());
    g.goals.single.autoSince = key;
    store.toggleChore(g, g.chores[1]);
    expect(g.crystalWeeks[key], 1200000000);
    expect(g.goals.single.current, 1200000000);
    expect(store.pending['g'], isNotNull);
  });

  test('주간 초기화 알림에 남은 결정석 금액', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    store.games.add(maple());
    final r = planReminders(store, const NotifySettings(scheduleLeadMinutes: 0, choreHoursBefore: 3),
        DateTime(2026, 11, 11, 12));
    final weekly = r.singleWhere((e) => e.key == 'cw:g');
    expect(weekly.when, DateTime(2026, 11, 11, 21)); // 11/12(목) 0시 - 3시간
    expect(weekly.title, contains('주간 숙제 3개'));
    expect(weekly.body, contains('17억')); // 5억 + 12억
  });

  test('JSON 왕복', () {
    final g = maple()..crystalWeeks['2026-11-05'] = 5;
    final back = Game.fromJson(g.toJson());
    expect(back.bosses.length, 2);
    expect(back.chores[0].partySize, 2);
    expect(back.chores[0].charName, '단풍이');
    expect(back.chores[2].isBoss, isFalse);
    expect(back.crystalWeeks, {'2026-11-05': 5});
  });

  test('기본 가격표: 없는 보스 추가, 가격 갱신', () {
    final g = Game(id: 'g', name: '메이플', bosses: [BossPrice(id: 'x', name: '하드 루시드', price: 1)]);
    var n = 0;
    final changed = g.applyDefaultBossPrices(() => 'id${n++}');
    expect(changed, defaultBossPrices.length);
    expect(g.bosses.firstWhere((b) => b.name == '하드 루시드').price, 59700000);
    expect(g.bosses.firstWhere((b) => b.name == '익스트림 카링').price, 4845000000);
    expect(g.bosses.firstWhere((b) => b.name == '하드 유피테르').price, 5387000000);
    expect(g.bosses.firstWhere((b) => b.name == '익스트림 검은 마법사').monthly, isTrue);
    expect(g.applyDefaultBossPrices(() => 'z'), 0);
  });
}
