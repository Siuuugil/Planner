import 'package:flutter_test/flutter_test.dart';
import 'package:game_planner/data/app_store.dart';
import 'package:game_planner/models/game.dart';
import 'package:game_planner/models/maple_character.dart';
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
    expect(g.weekIncome, {'2026-11-05': 500000000});

    g.chores[1].lastDone = now;
    g.recomputeCrystals(now);
    expect(g.weekIncome['2026-11-05'], 1700000000);
  });

  test('완료 취소하면 기록도 줄고, 지난 주 기록은 유지', () {
    final g = maple()..crystalWeeks['2026-10-29'] = 2200000000;
    final now = DateTime(2026, 11, 11, 12);
    g.chores[1].lastDone = now;
    g.recomputeCrystals(now);
    g.chores[1].lastDone = null;
    g.recomputeCrystals(now);
    expect(g.weekIncome, {'2026-10-29': 2200000000, '2026-11-05': 0});
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
    expect(g.weekIncome[key], 1200000000);
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

  group('보스 선택', () {
    var n = 0;
    String id() => 'id${n++}';
    Game fresh() => Game(id: 'g', name: '메이플', resetHour: 0, weeklyResetWeekday: DateTime.thursday)
      ..applyDefaultBossPrices(id);

    Set<String> names(Game g, String c) => {
          for (final e in g.bossPlanOf(c).entries) '${e.value.$1} ${e.key}',
        };

    test('검밑솔: 남은 검밑솔 보스 전부 가장 높은 난이도 (스우는 하드)', () {
      final g = fresh()..applyBossPreset('단풍이', BossPreset.geommilsol, id);
      expect(names(g, '단풍이'), {
        '하드 진 힐라', '하드 듄켈', '하드 윌', '카오스 가디언 엔젤 슬라임', '카오스 더스크', '하드 루시드',
        '하드 스우', '하드 데미안',
      });
    });

    test('하세이칼: 검밑솔 8 + 하드 세렌·이지 칼로스·이지 대적자 + 하드 검마', () {
      final g = fresh()..applyBossPreset('단풍이', BossPreset.haseikal, id);
      final s = names(g, '단풍이');
      expect(s.length, 12);
      expect(s, containsAll(['하드 선택받은 세렌', '이지 감시자 칼로스', '이지 최초의 대적자', '하드 검은 마법사', '하드 스우']));
    });

    test('노적노칼: 파풀·스우 빼고 칼로스·대적자 노멀 + 이지 카링·벨로나', () {
      final g = fresh()..applyBossPreset('단풍이', BossPreset.nojeoknokal, id);
      final s = names(g, '단풍이');
      expect(s, containsAll(['노멀 감시자 칼로스', '노멀 최초의 대적자', '이지 카링', '이지 벨로나', '하드 검은 마법사']));
      expect(s.any((x) => x.endsWith('파풀라투스') || x.endsWith('스우')), isFalse);
      expect(s.length, 13); // 주간 12 + 월간 1
    });

    test('난이도 바꾸면 완료 상태 유지, 같은 칩 다시 누르면 해제, 캐릭터별로 따로', () {
      final g = fresh();
      g.setBoss('A', '루시드', '노멀', 1, id);
      final chore = g.bossPlanOf('A')['루시드']!.$3..lastDone = DateTime.now();
      g.setBoss('A', '루시드', '하드', 2, id);
      final after = g.bossPlanOf('A')['루시드']!;
      expect(after.$1, '하드');
      expect(after.$2, 2);
      expect(identical(after.$3, chore), isTrue);
      expect(g.bossIncome(after.$3), 59700000 ~/ 2);

      g.setBoss('B', '루시드', '이지', 1, id);
      expect(g.bossPlanOf('A').length, 1);
      expect(g.bossPlanOf('B').length, 1);

      g.setBoss('A', '루시드', null, 1, id);
      expect(g.bossPlanOf('A'), isEmpty);
      g.clearBosses('B');
      expect(g.chores, isEmpty);
    });
  });

  test('id는 반복문에서 연달아 만들어도 겹치지 않음', () {
    final ids = {for (var i = 0; i < 5000; i++) newId()};
    expect(ids.length, 5000);
  });

  test('겹친 가격표 id 정리 (첫 항목 유지)', () {
    final g = Game(id: 'g', name: '메이플', bosses: [
      BossPrice(id: 'x', name: '하드 루시드', price: 1),
      BossPrice(id: 'x', name: '하드 윌', price: 2),
    ], chores: [
      Chore(id: 'c', title: '하드 루시드', period: ChorePeriod.weekly, bossId: 'x'),
    ]);
    var n = 0;
    expect(g.fixDuplicateIds(() => 'new${n++}'), isTrue);
    expect(g.bosses.map((b) => b.id), ['x', 'new0']);
    expect(g.bossById('x')!.name, '하드 루시드');
    expect(g.fixDuplicateIds(() => 'z'), isFalse);
  });

  group('에오스 (메포 환산)', () {
    test('에오스 캐릭터 수익은 ×0.55, 원금도 따로', () {
      final g = maple()..charWorlds['단풍이'] = 'eos';
      final wil = g.chores[1]; // 하드 윌 12억 솔로
      expect(g.bossIncomeRaw(wil), 1200000000);
      expect(g.bossIncome(wil), 660000000);
      g.eosRate = 0.6;
      expect(g.bossIncome(wil), 720000000);
      final back = Game.fromJson(g.toJson());
      expect((back.isEos('단풍이'), back.eosRate), (true, 0.6));
      expect(Game.fromJson(maple().toJson()).eosRate, defaultEosRate);
    });

    test('넥슨 캐릭터 월드가 에오스면 자동 지정, 직접 끈 건 유지, 체크 수익은 환산값', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(await SharedPreferences.getInstance());
      final g = maple();
      store.games.add(g);
      store.characters.add(MapleCharacter(id: 'c', name: '단풍이', ocid: 'o', world: '에오스'));
      store.commit();
      expect(g.isEos('단풍이'), isTrue);

      store.toggleChore(g, g.chores[1]);
      expect(g.weekIncome[g.weekKey(DateTime.now())], 660000000);
      expect(store.marks.values.single.income, 660000000);

      g.charWorlds['단풍이'] = 'main';
      store.commit();
      expect(g.isEos('단풍이'), isFalse);
    });
  });

  group('보스 목록 정리', () {
    test('결정석 4천만 이하는 빼고, 노멀 루시드·윌·듄켈·더스크·진힐라는 남김, 하드는 하드 스우부터', () {
      const keep = {'노멀 루시드', '노멀 윌', '노멀 듄켈', '노멀 더스크', '노멀 진 힐라'};
      for (final b in bossCatalog) {
        for (final d in b.difficulties) {
          final name = '$d ${b.name}';
          final price = defaultBossPrices.firstWhere((e) => e.$1 == name).$2;
          expect(price > 40000000 || keep.contains(name), isTrue, reason: name);
        }
      }
      for (final k in keep) {
        expect(isListedBoss(k), isTrue, reason: k);
      }
      for (final gone in ['노멀 스우', '노멀 데미안', '이지 루시드', '이지 윌', '하드 매그너스', '카오스 벨룸', '노멀 가디언 엔젤 슬라임']) {
        expect(isListedBoss(gone), isFalse, reason: gone);
      }
      // 하드는 하드 스우(4,890만)가 가장 싸다
      final hard = [for (final b in bossCatalog) if (b.difficulties.contains('하드') && !b.grandis && !b.monthly) b.name];
      expect(hard.first, '스우');
      expect(bossIconOf('벨룸'), 'vellum'); // 예전에 골라 둔 보스 아이콘은 유지
    });
  });

  group('월간 보스 분리', () {
    // 목요일 0시 주간 초기화, 하드 검마(월간) + 하드 루시드(주간)
    Game game() => Game(
          id: 'g',
          name: '메이플스토리',
          resetHour: 0,
          weeklyResetWeekday: DateTime.thursday,
          bosses: [
            BossPrice(id: 'luc', name: '하드 루시드', price: 60000000),
            BossPrice(id: 'bm', name: '하드 검은 마법사', price: 465000000), // 예전 데이터처럼 monthly 표시 없음
          ],
          chores: [
            Chore(id: 'l', title: '하드 루시드', period: ChorePeriod.weekly, bossId: 'luc', charName: 'A'),
            Chore(id: 'm', title: '하드 검은 마법사', period: ChorePeriod.weekly, bossId: 'bm', charName: 'A'),
          ],
        );

    test('주간 수익에는 안 들어가고 월간으로 따로, 주가 바뀌어도 그 달엔 완료 유지', () async {
      SharedPreferences.setMockInitialValues({});
      var now = DateTime(2026, 11, 3, 12); // 화요일
      final store = AppStore(await SharedPreferences.getInstance(), clock: () => now);
      final g = game();
      store.games.add(g);
      store.commit();
      expect(g.isMonthly(g.chores[1]), isTrue);
      expect(g.isMonthly(g.chores[0]), isFalse);

      store.toggleChore(g, g.chores[0]);
      store.toggleChore(g, g.chores[1]);
      expect(g.weekIncome[g.weekKey(now)], 60000000);
      expect(g.crystalMonthly['M2026-11'], 465000000);

      now = DateTime(2026, 11, 12, 12); // 다음 주 (11/5 목 초기화 지남)
      store.commit();
      expect(g.isChoreDone(g.chores[0], now), isFalse); // 주간 보스는 초기화
      expect(g.isChoreDone(g.chores[1], now), isTrue); // 월간은 이번 달 계속 완료

      now = DateTime(2026, 12, 2, 12); // 다음 달
      store.commit();
      expect(g.isChoreDone(g.chores[1], now), isFalse);
      expect(g.crystalMonthly['M2026-11'], 465000000); // 지난 달 기록은 남음
    });

    test('예전에 주간으로 기록된 검마 완료는 그 달 월간으로 옮겨 센다', () async {
      final g = game();
      SharedPreferences.setMockInitialValues({});
      final now = DateTime(2026, 11, 20, 12);
      final store = AppStore(await SharedPreferences.getInstance(), clock: () => now);
      store.games.add(g);
      store.marks['done:m:2026-11-12'] = DoneMark(
          id: 'done:m:2026-11-12', gameId: 'g', choreId: 'm', at: DateTime(2026, 11, 13, 21), week: '2026-11-12', income: 465000000);
      store.commit();
      expect(g.weekIncome['2026-11-12'], isNull);
      expect(g.crystalMonthly['M2026-11'], 465000000);
      expect(g.isChoreDone(g.chores[1], now), isTrue);
    });

    test('주간 숙제 알림의 남은 결정석에서 월간 보스는 빠진다', () async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime(2026, 11, 3, 12);
      final store = AppStore(await SharedPreferences.getInstance(), clock: () => now);
      store.games.add(game());
      store.commit();
      final r = planReminders(store, const NotifySettings(enabled: true, choreHoursBefore: 3), now)
          .firstWhere((r) => r.key == 'cw:g');
      expect(r.title, contains('1개'));
      expect(r.body, contains('6000만'));
    });
  });
}
