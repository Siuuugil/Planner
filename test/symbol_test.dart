import 'package:flutter_test/flutter_test.dart';
import 'package:game_planner/data/app_store.dart';
import 'package:game_planner/maple/maple_service.dart';
import 'package:game_planner/models/maple_character.dart';
import 'package:game_planner/models/schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('심볼 만렙까지 남은 성장치: 아케인 n²+11, 어센틱 9n²+20n', () {
    // 아케인 1→20 전부 = 2679, 어센틱 1→11 전부 = 4565
    expect(MapleSymbol(name: '아케인심볼 : 소멸의 여로', level: 1, growth: 0, require: 12).toMax, 2679);
    expect(MapleSymbol(name: '어센틱심볼 : 세르니움', level: 1, growth: 0, require: 29).toMax, 4565);
    final s = MapleSymbol(name: '아케인심볼 : 츄츄 아일랜드', level: 19, growth: 300, require: 372);
    expect(s.toMax, 72);
    expect(s.region, '츄츄 아일랜드');
    expect(MapleSymbol(name: '아케인심볼 : 레헬른', level: 20).isMax, isTrue);
    expect(MapleSymbol(name: '그랜드 어센틱심볼 : 탈라하트', level: 3, require: 500).toMax, isNull); // 공식 모름
  });

  test('넥슨 응답 → 심볼, JSON 저장', () {
    final s = MapleSymbol.fromNexon({
      'symbol_name': '어센틱심볼 : 아르크스', 'symbol_level': 5, 'symbol_growth_count': 100,
      'symbol_require_growth_count': 325, 'symbol_icon': 'https://x/icon.png',
    });
    final back = MapleSymbol.fromJson(s.toJson());
    expect((back.level, back.growth, back.require, back.isAuthentic, back.maxLevel), (5, 100, 325, true, 11));
  });

  group('자동 관리', () {
    late AppStore store;
    late MapleService maple;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = AppStore(prefs);
      maple = MapleService(store, prefs);
    });

    test('만렙 아닌 심볼이 있으면 일일 숙제, 다 만렙이면 뺀다', () {
      final c = MapleCharacter(id: 'c1', name: '단풍이', ocid: 'o', symbols: [
        MapleSymbol(name: '아케인심볼 : 소멸의 여로', level: 20),
        MapleSymbol(name: '어센틱심볼 : 세르니움', level: 4, growth: 0, require: 224),
      ]);
      maple.syncSymbolChore(c);
      final chore = store.mapleGame().chores.single;
      expect((chore.id, chore.title, chore.charName), ('sym-c1', '심볼 일일 · 단풍이 (어센틱 1)', '단풍이'));
      expect(maple.daysToMax(c.symbols[1]), ((224 + 9 * 25 + 100 + 9 * 36 + 120 + 9 * 49 + 140 + 9 * 64 + 160 + 9 * 81 + 180 + 9 * 100 + 200) / 10).ceil());

      final done = MapleCharacter(id: 'c1', name: '단풍이', ocid: 'o', symbols: [MapleSymbol(name: '아케인심볼 : 소멸의 여로', level: 20)]);
      maple.syncSymbolChore(done);
      expect(store.mapleGame().chores, isEmpty);
    });

    test('썬데이 메이플만 그날 게임 일정으로, 나머지 이벤트는 저장 안 하고 캘린더용으로만', () {
      final now = DateTime.now();
      final sunday = DateTime(now.year, now.month, now.day + 3);
      maple.events = [
        NexonEvent(id: '1', title: '썬데이 메이플', url: 'https://maplestory.nexon.com/1', start: sunday, end: sunday.add(const Duration(hours: 23))),
        NexonEvent(id: '2', title: '메이플 출석 이벤트', url: '', end: now.add(const Duration(days: 10))),
      ];
      expect(maple.addEventSchedules(), 1);
      final s = store.schedules.single;
      expect((s.id, s.title, s.start, s.allDay, s.gameId != null), ('nx-evt-1', '☀️ 썬데이 메이플', sunday, true, true));
      expect(maple.addEventSchedules(), 0); // 한 번만
      // 나머지 이벤트는 캘린더에 끝나는 날로만
      final end = now.add(const Duration(days: 10));
      expect(maple.othersEndingOn(end).single.title, '메이플 출석 이벤트');
      expect(maple.othersEndingOn(sunday), isEmpty);
      store.deleteSchedule(s);
      expect(maple.addEventSchedules(), 0); // 지운 일정은 되살리지 않음
    });

    test('예전 버전이 넣은 다른 이벤트 일정은 지우고, 썬데이는 새 모양으로', () {
      final now = DateTime.now();
      final sunday = DateTime(now.year, now.month, now.day + 2);
      store.schedules.addAll([
        Schedule(id: 'nx-evt-9', title: '⏰ 이벤트 끝: 출석 이벤트', start: now, allDay: true),
        Schedule(id: 'nx-evt-1', title: '⏰ 이벤트 끝: 썬데이 메이플', start: now, allDay: true),
        Schedule(id: 'mine', title: '내 일정', start: now),
      ]);
      expect(maple.cleanupEventSchedules(), 1);
      maple.events = [NexonEvent(id: '1', title: '썬데이 메이플', url: '', start: sunday)];
      maple.addEventSchedules();
      expect(store.schedules.map((s) => (s.id, s.title)).toSet(), {('nx-evt-1', '☀️ 썬데이 메이플'), ('mine', '내 일정')});
      expect(store.schedules.firstWhere((s) => s.id == 'nx-evt-1').start, sunday);
    });

    test('썬데이 메이플 이름 알아보기', () {
      expect(MapleService.isSundayMaple('[썬데이 메이플] 11월 3주차'), isTrue);
      expect(MapleService.isSundayMaple('선데이메이플'), isTrue);
      expect(MapleService.isSundayMaple('메이플 출석 이벤트'), isFalse);
    });
  });
}
