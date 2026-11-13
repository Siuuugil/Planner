import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_store.dart';
import '../models/ai_note.dart';
import '../models/schedule.dart';
import '../models/task.dart';
import 'claude_cli.dart';
import 'context.dart';

/// 자연어 빠른 입력 결과 한 건 (미리보기용, 아직 저장 안 함)
class QuickItem {
  QuickItem({
    required this.isTask,
    required this.title,
    this.date,
    this.time,
    this.work = true,
    this.game = false,
    this.memo = '',
  });

  final bool isTask;
  final String title;
  final DateTime? date;

  /// 'HH:mm' (없으면 종일 일정 / 마감일만 있는 할 일)
  final String? time;
  final bool work;
  final bool game;
  final String memo;

  bool selected = true;

  String describe() {
    final d = date == null ? '날짜 없음' : DateFormat('M/d (E)', 'ko_KR').format(date!);
    if (isTask) return '할 일 · ${work ? '업무' : '개인'} · ${date == null ? '마감 없음' : '$d까지'}';
    return '${game ? '게임 일정' : '일정'} · $d ${time ?? '종일'}';
  }
}

/// 오늘 날짜를 한국어로 (AI에게 상대 날짜 기준을 알려준다)
String todayLine(DateTime now) =>
    '오늘은 ${DateFormat('yyyy-MM-dd (EEEE)', 'ko_KR').format(now)}, 지금 시각 ${DateFormat('HH:mm').format(now)}.';

/// 자연어 빠른 입력 프롬프트
String quickAddPrompt(String text, DateTime now, List<String> gameNames) => '''
너는 일정 앱의 입력 도우미야. 아래 사용자의 메모를 일정(schedule)과 할 일(task)로 나눠 줘.
도구는 쓰지 말고 JSON 객체 하나만 답해.

${todayLine(now)}
사용자가 하는 게임: ${gameNames.isEmpty ? '없음' : gameNames.join(', ')}

규칙:
- 특정 시각이나 날짜에 하는 일(회의, 약속, 레이드 등)은 schedule, "~까지" 해야 하는 일은 task.
- "내일", "목요일", "다음 주 월요일" 같은 말은 오늘 기준 실제 날짜(YYYY-MM-DD)로 바꿔.
- 시각이 없으면 time은 null. task의 date는 마감일(없으면 null).
- 게임 관련(보스, 레이드, 메이플, 길드 등)이면 game: true. 게임은 항상 schedule.
- 업무면 category "work", 개인 일이면 "personal".
- 제목은 짧게, 원문의 핵심만. 부가 정보는 memo.

형식:
{"items":[{"kind":"schedule"|"task","title":"...","date":"YYYY-MM-DD"|null,"time":"HH:MM"|null,"category":"work"|"personal","game":true|false,"memo":"..."}]}

사용자 메모:
"""
$text
"""''';

List<QuickItem> parseQuickItems(Map<String, dynamic> json) => [
      for (final raw in (json['items'] as List? ?? []))
        if (raw is Map && '${raw['title'] ?? ''}'.trim().isNotEmpty)
          QuickItem(
            isTask: raw['kind'] == 'task' && raw['game'] != true,
            title: '${raw['title']}'.trim(),
            date: DateTime.tryParse('${raw['date']}'),
            time: RegExp(r'^\d{1,2}:\d{2}$').hasMatch('${raw['time']}') ? '${raw['time']}' : null,
            work: raw['category'] != 'personal',
            game: raw['game'] == true,
            memo: '${raw['memo'] ?? ''}'.trim(),
          ),
    ];

/// 오늘 계획 프롬프트
String planPrompt(String context, DateTime now, {required bool hideGames}) => '''
너는 사용자의 하루 계획을 짜 주는 비서야. 아래 오늘 상황을 보고 지금부터 잠들기 전(24시)까지의 시간표를 제안해 줘.
도구는 쓰지 말고 JSON 객체 하나만 답해.

${todayLine(now)}

규칙:
- 시각이 정해진 일정은 그 시각에 고정하고, 그 사이 빈 시간에 할 일을 배치해.
- 마감이 지났거나 오늘·내일 마감인 할 일을 먼저.
- 업무(work)는 낮에, 개인(personal)·게임(game)은 저녁 위주로. 중간에 휴식(break)도 넣어.
${hideGames ? '- 게임 관련 내용은 절대 넣지 마 (회사 모드).' : '- 게임 숙제는 초기화 시각 전에 끝나도록 배치하고, 보스는 수익이 큰 것부터.'}
- 블록은 6~12개, 제목은 짧게, note에는 이유나 팁을 한 줄로.
- summary는 오늘의 핵심을 2~3문장으로, tips는 짧은 조언 2~3개.

형식:
{"summary":"...","blocks":[{"start":"HH:MM","end":"HH:MM","title":"...","kind":"work"|"personal"|"game"|"break","note":"..."}],"tips":["..."]}

오늘 상황:
$context''';

AiNote parsePlan(Map<String, dynamic> json, DateTime now) {
  final date = DateFormat('yyyy-MM-dd').format(now);
  final hm = RegExp(r'^\d{1,2}:\d{2}$');
  return AiNote(
    id: 'plan:$date',
    type: 'plan',
    title: '${DateFormat('M월 d일 (E)', 'ko_KR').format(now)} 계획',
    body: '${json['summary'] ?? ''}'.trim(),
    createdAt: now,
    date: date,
    blocks: [
      for (final raw in (json['blocks'] as List? ?? []))
        if (raw is Map && hm.hasMatch('${raw['start']}') && '${raw['title'] ?? ''}'.trim().isNotEmpty)
          PlanBlock.fromJson(raw.cast<String, dynamic>()),
    ]..sort((a, b) => a.start.padLeft(5, '0').compareTo(b.start.padLeft(5, '0'))),
    bullets: [for (final t in (json['tips'] as List? ?? [])) '$t'.trim()],
  );
}

/// AI 기능 (PC에서 Claude CLI 사용). 실행 경로는 기기별 설정.
class AiService extends ChangeNotifier {
  AiService(this.store, this._prefs);

  static const _pathKey = 'claude_cli_path';
  final AppStore store;
  final SharedPreferences _prefs;

  /// 지금 AI가 일하는 중인 작업 이름 (없으면 null)
  String? running;

  static Future<AiService> open(AppStore store) async =>
      AiService(store, await SharedPreferences.getInstance());

  bool get supported => ClaudeCli.supported;

  String get executable => _prefs.getString(_pathKey) ?? 'claude';

  set executable(String v) {
    _prefs.setString(_pathKey, v.trim().isEmpty ? 'claude' : v.trim());
    notifyListeners();
  }

  Future<String> checkCli() => ClaudeCli.version(executable: executable);

  Future<Map<String, dynamic>> _ask(String what, String prompt) async {
    if (running != null) throw ClaudeCliException('AI가 "$running" 작업 중이에요. 끝나면 다시 해 주세요.');
    running = what;
    notifyListeners();
    try {
      return await ClaudeCli.ask(prompt, executable: executable);
    } finally {
      running = null;
      notifyListeners();
    }
  }

  Future<List<QuickItem>> quickAdd(String text) async {
    final json = await _ask('빠른 입력', quickAddPrompt(text, DateTime.now(), store.games.map((g) => g.name).toList()));
    return parseQuickItems(json);
  }

  /// 오늘 계획을 만들어 저장 (오늘 계획이 있으면 바꾼다)
  Future<AiNote> planToday() async {
    final now = DateTime.now();
    final json = await _ask('오늘 계획', planPrompt(plannerContext(store, now), now, hideGames: store.hideGames));
    final note = parsePlan(json, now);
    store.saveNote(note);
    return note;
  }

  /// 미리보기에서 고른 항목을 실제로 저장
  int applyQuickItems(List<QuickItem> items) {
    var n = 0;
    for (final it in items.where((i) => i.selected)) {
      if (it.isTask) {
        store.tasks.add(Task(
          id: newId(),
          title: it.title,
          category: it.work ? TaskCategory.work : TaskCategory.etc,
          due: it.date,
          memo: it.memo,
        ));
      } else {
        final d = it.date ?? DateTime.now();
        final hm = it.time?.split(':');
        store.schedules.add(Schedule(
          id: newId(),
          title: it.title,
          start: DateTime(d.year, d.month, d.day, hm == null ? 0 : int.parse(hm[0]), hm == null ? 0 : int.parse(hm[1])),
          allDay: hm == null,
          memo: it.memo,
          gameId: it.game ? store.mapleGame().id : null,
        ));
      }
      n++;
    }
    if (n > 0) store.commit();
    return n;
  }
}

class AiScope extends InheritedNotifier<AiService> {
  const AiScope({super.key, required AiService ai, required super.child}) : super(notifier: ai);

  static AiService? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AiScope>()?.notifier;
}
