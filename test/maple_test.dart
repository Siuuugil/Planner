import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_planner/data/app_store.dart';
import 'package:game_planner/maple/nexon_api.dart';
import 'package:game_planner/models/game.dart';
import 'package:game_planner/models/maple_character.dart';
import 'package:game_planner/widgets/maple_widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('넥슨 API: 키 헤더, ocid → 기본정보·전투력 파싱', () async {
    final seen = <String>[];
    final client = MockClient((req) async {
      expect(req.headers['x-nxopen-api-key'], 'KEY');
      seen.add(req.url.path);
      final body = switch (req.url.path) {
        '/maplestory/v1/id' => {'ocid': 'abc'},
        '/maplestory/v1/character/basic' => {
            'character_name': '단풍이',
            'world_name': '스카니아',
            'character_class': '아크메이지(불,독)',
            'character_level': 276,
            'character_exp_rate': '45.123',
            'character_image': 'https://open.api.nexon.com/static/x.png',
            'character_guild_name': null,
          },
        '/maplestory/v1/character/stat' => {
            'final_stat': [
              {'stat_name': 'STR', 'stat_value': '4000'},
              {'stat_name': '전투력', 'stat_value': '85321234'},
            ],
          },
        _ => throw StateError(req.url.path),
      };
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    });
    final api = NexonApi('KEY', client: client);
    final ocid = await api.ocid('단풍이');
    final basic = await api.basic(ocid);
    final stat = await api.stat(ocid);
    expect(ocid, 'abc');
    expect(NexonApi.expRate(basic), 45.123);
    expect(NexonApi.combatPower(stat), 85321234);
    expect(seen, ['/maplestory/v1/id', '/maplestory/v1/character/basic', '/maplestory/v1/character/stat']);
  });

  test('넥슨 API 오류 코드를 알기 쉬운 메시지로', () async {
    final api = NexonApi('BAD', client: MockClient((_) async => http.Response(
        '{"error":{"name":"OPENAPI00005","message":"Please input valid id"}}', 400)));
    expect(
      () => api.ocid('x'),
      throwsA(isA<NexonApiException>()
          .having((e) => e.code, 'code', 'OPENAPI00005')
          .having((e) => e.message, 'message', contains('API 키'))),
    );
  });

  test('캐릭터 갱신 시 연결된 목표 현재값 자동 반영 + 동기화 대상', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    store.games.add(Game(id: 'g', name: '메이플스토리', goals: [
      Goal(id: 'l', title: '레벨', start: 270, current: 270, target: 280, autoCharId: 'c', autoMetric: 'level'),
      Goal(id: 'p', title: '전투력', start: 1, current: 1, target: 1e8, autoCharId: 'c', autoMetric: 'combat'),
    ]));
    store.upsertCharacter(MapleCharacter(id: 'c', name: '단풍이', ocid: 'abc', level: 276, expRate: 45.67, combatPower: 85000000));
    final goals = store.games.single.goals;
    expect(goals[0].current, 276.46);
    expect(goals[1].current, 85000000);
    expect(store.pending['c']!.kind, 'maple');
  });

  test('성장 기록은 날짜당 하나, 날짜순', () {
    final c = MapleCharacter(id: 'c', name: 'a', ocid: 'o');
    c.putSnapshot(MapleSnapshot(date: '2026-11-10', level: 275, expRate: 1));
    c.putSnapshot(MapleSnapshot(date: '2026-11-08', level: 274, expRate: 1));
    c.putSnapshot(MapleSnapshot(date: '2026-11-10', level: 276, expRate: 2));
    expect(c.history.map((h) => (h.date, h.level)), [('2026-11-08', 274), ('2026-11-10', 276)]);
  });

  test('전투력 한국식 표기', () {
    expect(koreanNumber(9999), '9999');
    expect(koreanNumber(85321234), '8532만');
    expect(koreanNumber(123456789), '1억 2345만');
    expect(koreanNumber(200000000), '2억');
  });

  test('중계 서버 경로: 넥슨 경로·쿼리·키를 그대로 넘기고 오류 코드도 해석', () async {
    final calls = <(String, Map<String, String>, String)>[];
    final api = NexonApi('KEY', proxy: (path, query, key) async {
      calls.add((path, query, key));
      if (path.endsWith('/id')) return (200, '{"ocid":"abc"}');
      return (400, '{"error":{"name":"OPENAPI00004","message":"x"}}');
    });
    expect(await api.ocid('단풍이'), 'abc');
    expect(calls.single.$1, '/maplestory/v1/id');
    expect(calls.single.$2, {'character_name': '단풍이'});
    expect(calls.single.$3, 'KEY');
    expect(() => api.basic('abc'),
        throwsA(isA<NexonApiException>().having((e) => e.code, 'code', 'OPENAPI00004')));
  });
}
