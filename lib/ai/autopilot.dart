import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_store.dart';
import '../models/ai_note.dart';
import 'ai_service.dart';
import 'claude_cli.dart';

/// AI 자동 실행 (PC 앱, 트레이에 켜져 있을 때):
/// - 아침 브리핑: 정한 시각이 지나면 오늘 계획을 만들고 요약을 PC 마을 알림 허브(`event`)로 → 휴대폰 푸시·디스코드 DM
/// - 월요일 주간 리포트: 같은 시각에 지난주 리포트
/// 여러 PC가 켜져 있으면 한 대만: 그날 표시(`ai` 행 id `auto:<날짜>`)를 먼저 잡은 PC가 한다.
class Autopilot extends ChangeNotifier {
  Autopilot(this.store, this.ai, this._prefs, {DateTime Function()? clock, this.claimWait = const Duration(seconds: 3)})
      : _clock = clock ?? DateTime.now;

  final AppStore store;
  final AiService ai;
  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  final Duration claimWait;
  Timer? _timer;
  bool _busy = false;

  /// 마지막 결과 한 줄 (설정 화면에 보여 줌)
  String? lastResult;

  static Future<Autopilot> open(AppStore store, AiService ai) async =>
      Autopilot(store, ai, await SharedPreferences.getInstance());

  bool get briefing => _prefs.getBool('auto_briefing') ?? false;
  set briefing(bool v) => _set('auto_briefing', v);

  /// 브리핑 시각 (분 단위, 기본 8:30)
  int get minuteOfDay => _prefs.getInt('auto_briefing_min') ?? 8 * 60 + 30;
  set minuteOfDay(int v) {
    _prefs.setInt('auto_briefing_min', v);
    notifyListeners();
  }

  bool get weekdaysOnly => _prefs.getBool('auto_weekdays') ?? true;
  set weekdaysOnly(bool v) => _set('auto_weekdays', v);

  bool get mondayReport => _prefs.getBool('auto_monday_report') ?? true;
  set mondayReport(bool v) => _set('auto_monday_report', v);

  /// PC 마을로 휴대폰·디스코드 알림 보내기
  bool get sendEvent => _prefs.getBool('auto_send_event') ?? true;
  set sendEvent(bool v) => _set('auto_send_event', v);

  void _set(String k, bool v) {
    _prefs.setBool(k, v);
    notifyListeners();
  }

  String get timeLabel => '${minuteOfDay ~/ 60}:${(minuteOfDay % 60).toString().padLeft(2, '0')}';

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => tick());
    Timer(const Duration(seconds: 20), tick); // 켜자마자 한 번 (늦게 켠 날도)
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _dayId(DateTime d) => 'auto:${DateFormat('yyyy-MM-dd').format(d)}';

  /// 지금 할 차례인지 (정한 시각 ~ 오후 6시, 오늘 아직 안 했음)
  bool due(DateTime now) {
    if (!briefing || !ai.supported) return false;
    if (weekdaysOnly && now.weekday > DateTime.friday) return false;
    final m = now.hour * 60 + now.minute;
    if (m < minuteOfDay || now.hour >= 18) return false;
    return !store.notes.any((n) => n.id == _dayId(now));
  }

  Future<void> tick() async {
    final now = _clock();
    if (_busy || !due(now) || ai.running != null) return;
    _busy = true;
    try {
      // 오늘 표시를 잡고, 동기화 한 바퀴 뒤에도 내 것인지 확인 (다른 PC가 잡았으면 물러남)
      final id = _dayId(now);
      final me = ai.deviceId;
      store.saveNote(AiNote(id: id, type: 'auto', title: '자동 실행', body: '', createdAt: now, by: me, claimedAt: now));
      await Future<void>.delayed(claimWait);
      final mine = store.notes.where((n) => n.id == id).firstOrNull;
      if (mine == null || mine.by != me) return;
      await run(now);
    } finally {
      _busy = false;
    }
  }

  /// 브리핑(+월요일 리포트) 실행. 설정 화면의 '지금 해 보기'도 이걸 부른다
  Future<String> run(DateTime now) async {
    final lines = <String>[];
    try {
      final plan = await ai.planToday();
      final brief = briefingText(plan, store, now);
      if (sendEvent) store.addEvent('☀️ 오늘 브리핑', brief, url: '/');
      lines.add('브리핑 보냄');
      if (mondayReport && now.weekday == DateTime.monday) {
        final r = await ai.weeklyReport();
        if (sendEvent) {
          store.addEvent('📊 주간 리포트', [r.body, ...r.bullets.take(3).map((b) => '· $b')].join('\n'), url: '/');
        }
        lines.add('주간 리포트 보냄');
      }
    } on ClaudeCliException catch (e) {
      lines.add('실패: ${e.message}');
      if (sendEvent) store.addEvent('⚠️ 아침 브리핑 실패', 'PC의 Claude가 답하지 못했어요: ${e.message}');
    }
    lastResult = '${DateFormat('M/d HH:mm').format(now)} ${lines.join(' · ')}';
    final done = store.notes.where((n) => n.id == _dayId(now)).firstOrNull;
    if (done != null) {
      store.saveNote(AiNote(
          id: done.id, type: 'auto', title: '자동 실행', body: lastResult!, createdAt: done.createdAt,
          by: done.by, claimedAt: done.claimedAt));
    }
    notifyListeners();
    return lastResult!;
  }
}

/// 휴대폰 알림에 들어갈 브리핑 글 (짧게): 계획 한 줄 + 첫 일정 + 마감 + 시간표 앞부분
String briefingText(AiNote plan, AppStore store, DateTime now) {
  final today = store.schedulesOn(now).where((s) => !s.done && (!store.hideGames || s.gameId == null)).toList();
  final due = store.tasks.where((t) => t.isDueBy(now)).toList();
  final b = StringBuffer();
  if (plan.body.isNotEmpty) b.writeln(plan.body.split('\n').first);
  if (today.isNotEmpty) {
    final f = today.first;
    b.writeln('📅 일정 ${today.length}개 · 첫 일정 ${f.allDay ? '종일' : DateFormat('HH:mm').format(f.start)} ${f.title}');
  }
  if (due.isNotEmpty) b.writeln('📜 오늘까지 ${due.length}개: ${due.take(3).map((t) => t.title).join(', ')}');
  for (final blk in plan.blocks.take(4)) {
    b.writeln('${blk.start} ${blk.title}');
  }
  return b.toString().trim();
}

class AutopilotScope extends InheritedNotifier<Autopilot> {
  const AutopilotScope({super.key, required Autopilot autopilot, required super.child}) : super(notifier: autopilot);

  static Autopilot? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AutopilotScope>()?.notifier;
}
