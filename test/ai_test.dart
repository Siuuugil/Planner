import 'package:flutter_test/flutter_test.dart';
import 'package:game_planner/ai/ai_service.dart';
import 'package:game_planner/ai/claude_cli.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  group('CLI 출력 해석', () {
    test('structured_output 우선', () {
      expect(parseCliOutput('{"type":"result","is_error":false,"result":"x","structured_output":{"a":1}}'), {'a': 1});
    });
    test('result 글 속 JSON (코드블록 포함)', () {
      expect(parseCliOutput('{"is_error":false,"result":"여기요\\n```json\\n{\\"items\\":[]}\\n```"}'), {'items': []});
    });
    test('오류는 예외로', () {
      expect(() => parseCliOutput('{"is_error":true,"result":"Not logged in"}'),
          throwsA(isA<ClaudeCliException>().having((e) => e.message, 'message', contains('Not logged in'))));
      expect(() => parseCliOutput('command not found'), throwsA(isA<ClaudeCliException>()));
    });
  });

  test('빠른 입력 결과 해석: 게임은 항상 일정, 잘못된 시각은 무시', () {
    final items = parseQuickItems({
      'items': [
        {'kind': 'schedule', 'title': '팀회의', 'date': '2026-11-14', 'time': '15:00', 'category': 'work', 'game': false, 'memo': ''},
        {'kind': 'task', 'title': '보고서', 'date': '2026-11-19', 'time': null, 'category': 'work', 'game': false},
        {'kind': 'task', 'title': '하드 윌', 'date': '2026-11-15', 'time': '21:00', 'category': 'personal', 'game': true},
        {'kind': 'schedule', 'title': '헬스', 'date': '2026-11-14', 'time': '저녁', 'category': 'personal'},
        {'kind': 'task', 'title': '   '},
      ],
    });
    expect(items.map((i) => (i.title, i.isTask, i.time, i.game)), [
      ('팀회의', false, '15:00', false),
      ('보고서', true, null, false),
      ('하드 윌', false, '21:00', true),
      ('헬스', false, null, false),
    ]);
    expect(items[1].describe(), contains('11/19'));
  });

  test('빠른 입력 프롬프트에 오늘 날짜·게임 목록이 들어감', () {
    final p = quickAddPrompt('내일 회의', DateTime(2026, 11, 13, 9), ['메이플스토리']);
    expect(p, contains('2026-11-13'));
    expect(p, contains('메이플스토리'));
    expect(p, contains('내일 회의'));
  });
}
