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

/// 메이플 코치 프롬프트
String coachPrompt(String question, String stats, DateTime now) => '''
너는 메이플스토리 성장 코치야. 아래 [숫자]는 앱이 계산한 정확한 값이야. 질문에 이 숫자를 근거로 답해.
숫자를 새로 지어내지 말고, 계산이 필요하면 아래 값으로만 해. 모르는 건 모른다고 말해.
도구는 쓰지 말고 JSON 객체 하나만 답해.

${todayLine(now)}

형식: {"answer":"3~6문장 한국어 답","points":["바로 해볼 것 1","바로 해볼 것 2"]}

[숫자]
$stats

질문: $question''';

/// 주간 리포트 프롬프트
String reportPrompt(String review, DateTime now, {required bool hideGames}) => '''
너는 사용자의 한 주를 돌아봐 주는 비서야. 아래 지난 7일 기록으로 짧은 주간 리포트를 써 줘.
숫자는 아래 값만 쓰고 지어내지 마. 다그치지 말고 담백하게.${hideGames ? ' 게임 이야기는 하지 마.' : ''}
도구는 쓰지 말고 JSON 객체 하나만 답해.

${todayLine(now)}

형식: {"summary":"한 주 요약 3~4문장","highlights":["잘한 점이나 눈에 띄는 숫자 2~4개"],"nextWeek":["다음 주에 할 것 2~4개"]}

[기록]
$review''';

AiNote parseCoach(Map<String, dynamic> json, String question, DateTime now) => AiNote(
      id: 'coach:${now.microsecondsSinceEpoch}',
      type: 'coach',
      title: question,
      body: '${json['answer'] ?? ''}'.trim(),
      createdAt: now,
      bullets: [for (final p in (json['points'] as List? ?? [])) '$p'.trim()],
    );

AiNote parseReport(Map<String, dynamic> json, DateTime now) {
  final date = DateFormat('yyyy-MM-dd').format(now);
  return AiNote(
    id: 'report:$date',
    type: 'report',
    title: '${DateFormat('M월 d일', 'ko_KR').format(now)} 주간 리포트',
    body: [
      '${json['summary'] ?? ''}'.trim(),
      if ((json['highlights'] as List? ?? []).isNotEmpty)
        '\n잘한 점\n${(json['highlights'] as List).map((h) => '· $h').join('\n')}',
    ].join('\n'),
    createdAt: now,
    date: date,
    bullets: [for (final p in (json['nextWeek'] as List? ?? [])) '$p'.trim()],
  );
}

/// 대화 프롬프트. 바꾸는 일은 actions로 제안만 하고, 사용자가 확인해야 적용된다.
String chatPrompt(String message, String context, List<AiNote> history, DateTime now, {required bool hideGames}) => '''
너는 사용자의 일정·할 일${hideGames ? '' : '·메이플스토리 숙제'}를 같이 관리하는 비서야. 짧고 친근하게 한국어로 답해.
아래 [상황]과 [숫자]는 앱이 준 정확한 값이니 이것만 근거로 하고, 모르는 건 지어내지 마.${hideGames ? ' 게임 이야기는 하지 마 (회사 모드).' : ''}
일정·할 일을 추가하거나 완료 처리해 달라는 요청이면 직접 했다고 하지 말고 actions로 제안해 (사용자가 확인 버튼을 눌러야 적용돼).
도구는 쓰지 말고 JSON 객체 하나만 답해.

${todayLine(now)}

actions 종류:
- {"type":"add_schedule","title":"...","date":"YYYY-MM-DD","time":"HH:MM"|null,"game":true|false,"memo":"..."}
- {"type":"add_task","title":"...","due":"YYYY-MM-DD"|null,"category":"work"|"personal","memo":"..."}
- {"type":"complete_task","title":"[상황]에 있는 할 일 제목 그대로"}
- {"type":"check_chore","chore":"[상황]에 있는 숙제·보스 이름 그대로"}

형식: {"reply":"답","actions":[...]}  (제안할 게 없으면 actions는 [])

[상황]
$context
${history.isEmpty ? '' : '[최근 대화]\n${history.map((h) => '사용자: ${h.title}\n비서: ${h.body}').join('\n')}\n'}
사용자: $message''';

const _actionTypes = {'add_schedule', 'add_task', 'complete_task', 'check_chore'};

AiNote parseChat(Map<String, dynamic> json, String message, DateTime now) => AiNote(
      id: 'chat:${now.microsecondsSinceEpoch}',
      type: 'chat',
      title: message,
      body: '${json['reply'] ?? ''}'.trim(),
      createdAt: now,
      actions: [
        for (final a in (json['actions'] as List? ?? []))
          if (a is Map && _actionTypes.contains(a['type'])) a.cast<String, dynamic>(),
      ],
    );

/// 제안 작업을 사람이 읽는 한 줄로
String describeAction(Map<String, dynamic> a) => switch (a['type']) {
      'add_schedule' => '${a['game'] == true ? '게임 일정' : '일정'} 추가: ${a['title']} · ${a['date']} ${a['time'] ?? '종일'}',
      'add_task' => '할 일 추가: ${a['title']}${a['due'] == null ? '' : ' · ${a['due']}까지'}',
      'complete_task' => '할 일 완료: ${a['title']}',
      'check_chore' => '숙제 체크: ${a['chore']}',
      _ => '${a['type']}',
    };

/// AI 기능 (PC에서 Claude CLI 사용). 실행 경로는 기기별 설정.
class AiService extends ChangeNotifier {
  AiService(this.store, this._prefs, {this.askOverride, bool? supportedOverride}) : _supported = supportedOverride {
    // 이 PC가 폰·웹의 대화 요청에 답한다 (PC 앱이 켜져 있을 때)
    if (supported) store.addListener(_scheduleRemote);
  }

  /// 테스트용: CLI 대신 답을 만든다
  final Future<Map<String, dynamic>> Function(String prompt)? askOverride;
  final bool? _supported;

  static const _pathKey = 'claude_cli_path';
  static const _serveKey = 'serve_remote_chat';
  final AppStore store;
  final SharedPreferences _prefs;

  /// 지금 AI가 일하는 중인 작업 이름 (없으면 null)
  String? running;

  static Future<AiService> open(AppStore store) async =>
      AiService(store, await SharedPreferences.getInstance());

  bool get supported => _supported ?? (askOverride != null || ClaudeCli.supported);

  String get executable => _prefs.getString(_pathKey) ?? 'claude';

  set executable(String v) {
    _prefs.setString(_pathKey, v.trim().isEmpty ? 'claude' : v.trim());
    notifyListeners();
  }

  Future<String> checkCli() => ClaudeCli.version(executable: executable);

  /// 폰·웹에서 보낸 대화에 이 PC가 답할지 (기본 켜짐)
  bool get serveRemote => _prefs.getBool(_serveKey) ?? true;

  set serveRemote(bool v) {
    _prefs.setBool(_serveKey, v);
    notifyListeners();
    if (v) _scheduleRemote();
  }

  bool _remoteQueued = false;

  void _scheduleRemote() {
    if (_remoteQueued || !serveRemote) return;
    _remoteQueued = true;
    Future.microtask(() async {
      _remoteQueued = false;
      await _answerRemote();
    });
  }

  /// 대기 중인 요청(15분 이내) 하나에 답한다. 끝나면 다음 것을 다시 확인.
  Future<void> _answerRemote() async {
    if (running != null) return;
    final cutoff = DateTime.now().subtract(const Duration(minutes: 15));
    final todo = store.notes
        .where((n) => n.type == 'chat' && n.status == 'pending' && n.createdAt.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (todo.isEmpty) return;
    final req = todo.first;
    store.saveNote(AiNote(id: req.id, type: 'chat', title: req.title, body: '', createdAt: req.createdAt, status: 'working'));
    try {
      final json = await _ask('폰·웹 대화', _chatPromptFor(req.title, excludeId: req.id));
      final ans = parseChat(json, req.title, req.createdAt);
      store.saveNote(AiNote(
          id: req.id, type: 'chat', title: req.title, body: ans.body, createdAt: req.createdAt, actions: ans.actions));
    } on ClaudeCliException catch (e) {
      store.saveNote(AiNote(
          id: req.id, type: 'chat', title: req.title, body: 'PC에서 답하지 못했어요: ${e.message}', createdAt: req.createdAt, status: 'error'));
    }
    _scheduleRemote();
  }

  /// 폰·웹: PC에게 대화 요청을 보낸다 (PC 앱이 켜져 있으면 답이 동기화돼서 온다)
  void requestChat(String message) {
    final now = DateTime.now();
    store.saveNote(AiNote(id: 'chat:${now.microsecondsSinceEpoch}', type: 'chat', title: message, body: '', createdAt: now, status: 'pending'));
  }

  Future<Map<String, dynamic>> _ask(String what, String prompt) async {
    if (running != null) throw ClaudeCliException('AI가 "$running" 작업 중이에요. 끝나면 다시 해 주세요.');
    running = what;
    notifyListeners();
    try {
      return await (askOverride?.call(prompt) ?? ClaudeCli.ask(prompt, executable: executable));
    } finally {
      running = null;
      notifyListeners();
      // 다른 작업 때문에 미뤄둔 폰·웹 요청이 있으면 이어서 답한다
      if (supported) _scheduleRemote();
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

  /// 메이플 코치에게 질문 (답은 저장·동기화)
  Future<AiNote> coach(String question) async {
    final now = DateTime.now();
    final json = await _ask('메이플 코치', coachPrompt(question, mapleContext(store, now), now));
    final note = parseCoach(json, question, now);
    store.saveNote(note);
    return note;
  }

  /// 지난 7일 주간 리포트
  Future<AiNote> weeklyReport() async {
    final now = DateTime.now();
    final json = await _ask('주간 리포트', reportPrompt(weekReviewContext(store, now), now, hideGames: store.hideGames));
    final note = parseReport(json, now);
    store.saveNote(note);
    return note;
  }

  /// 대화 한 번 (최근 6번의 대화를 함께 보낸다)
  Future<AiNote> chat(String message) async {
    final now = DateTime.now();
    final json = await _ask('대화', _chatPromptFor(message));
    final note = parseChat(json, message, now);
    store.saveNote(note);
    return note;
  }

  String _chatPromptFor(String message, {String? excludeId}) {
    final now = DateTime.now();
    final history = store.notes
        .where((n) => n.type == 'chat' && n.id != excludeId && n.status == null && n.body.isNotEmpty)
        .take(6)
        .toList()
        .reversed
        .toList();
    final context = store.hideGames
        ? plannerContext(store, now)
        : '${plannerContext(store, now)}\n[숫자]\n${mapleContext(store, now)}';
    return chatPrompt(message, context, history, now, hideGames: store.hideGames);
  }

  /// 제안 작업 적용. 결과를 한 줄로 돌려준다 (못 찾으면 그 이유).
  String applyAction(Map<String, dynamic> a) {
    switch (a['type']) {
      case 'add_schedule':
        applyQuickItems([
          QuickItem(
            isTask: false,
            title: '${a['title']}',
            date: DateTime.tryParse('${a['date']}'),
            time: RegExp(r'^\d{1,2}:\d{2}$').hasMatch('${a['time']}') ? '${a['time']}' : null,
            game: a['game'] == true,
            memo: '${a['memo'] ?? ''}',
          ),
        ]);
        return '추가했어요';
      case 'add_task':
        applyQuickItems([
          QuickItem(
            isTask: true,
            title: '${a['title']}',
            date: DateTime.tryParse('${a['due']}'),
            work: a['category'] != 'personal',
            memo: '${a['memo'] ?? ''}',
          ),
        ]);
        return '추가했어요';
      case 'complete_task':
        final t = store.tasks.where((t) => !t.done && t.title == '${a['title']}').firstOrNull;
        if (t == null) return '"${a['title']}" 할 일을 찾지 못했어요';
        t.done = true;
        store.commit();
        return '완료로 표시했어요';
      case 'check_chore':
        final now = DateTime.now();
        for (final g in store.games) {
          for (final c in g.chores) {
            if (c.title == '${a['chore']}' && !g.isChoreDone(c, now)) {
              store.toggleChore(g, c);
              return '체크했어요';
            }
          }
        }
        return '"${a['chore']}" 숙제를 찾지 못했거나 이미 했어요';
    }
    return '할 수 없는 작업이에요';
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
