import 'package:intl/intl.dart';

import '../data/app_store.dart';
import '../models/game.dart';
import '../widgets/maple_widgets.dart' show koreanNumber;

/// AI에게 보낼 오늘 상황 요약 (사람이 읽는 짧은 글).
/// 게임 숨기기(회사 모드)면 게임 정보는 넣지 않는다.
String plannerContext(AppStore store, DateTime now) {
  final b = StringBuffer();
  final hide = store.hideGames;
  final day = DateTime(now.year, now.month, now.day);
  String hm(DateTime t) => DateFormat('HH:mm').format(t);
  String md(DateTime t) => DateFormat('M/d (E)', 'ko_KR').format(t);

  final today = store.schedulesOn(now).where((s) => !hide || s.gameId == null).toList();
  b.writeln('[오늘 일정]');
  if (today.isEmpty) b.writeln('- 없음');
  for (final s in today) {
    final game = store.gameById(s.gameId);
    b.writeln('- ${s.allDay ? '종일' : hm(s.start)} ${s.title}'
        '${game != null ? ' (게임: ${game.name})' : ''}${s.done ? ' [완료]' : ''}${s.memo.isNotEmpty ? ' — ${s.memo}' : ''}');
  }

  final open = store.tasks.where((t) => !t.done).toList()
    ..sort((a, b) => (a.due ?? DateTime(2100)).compareTo(b.due ?? DateTime(2100)));
  b.writeln('\n[할 일 (마감 순, 최대 15개)]');
  if (open.isEmpty) b.writeln('- 없음');
  for (final t in open.take(15)) {
    final due = t.due == null
        ? '마감 없음'
        : t.due!.isBefore(day)
            ? '${md(t.due!)} 마감 지남'
            : '${md(t.due!)}까지';
    b.writeln('- [${t.category.label}] ${t.title} ($due)${t.memo.isNotEmpty ? ' — ${t.memo}' : ''}');
  }

  if (!hide) {
    for (final g in store.games) {
      final daily = g.chores.where((c) => c.period == ChorePeriod.daily && !c.isBoss && !g.isChoreDone(c, now));
      final weekly = g.chores.where((c) => c.period == ChorePeriod.weekly && !c.isBoss && !g.isChoreDone(c, now));
      final boss = g.chores.where((c) => c.isBoss && !g.isChoreDone(c, now)).toList();
      if (daily.isEmpty && weekly.isEmpty && boss.isEmpty) continue;
      final start = g.periodStart(ChorePeriod.weekly, now);
      final reset = DateTime(start.year, start.month, start.day + 7, g.resetHour);
      b.writeln('\n[게임: ${g.name}] 매일 ${g.resetHour}시 초기화, 주간 초기화까지 ${reset.difference(now).inHours}시간');
      if (daily.isNotEmpty) b.writeln('- 남은 일일 숙제: ${daily.map((c) => c.title).join(', ')}');
      if (weekly.isNotEmpty) b.writeln('- 남은 주간 숙제: ${weekly.map((c) => c.title).join(', ')}');
      if (boss.isNotEmpty) {
        b.writeln('- 이번 주 남은 보스 ${boss.length}개 (${koreanNumber(boss.fold<int>(0, (a, c) => a + g.bossIncome(c)))} 메소): '
            '${boss.map((c) => '${c.title}${c.charName != null ? '(${c.charName})' : ''}').join(', ')}');
      }
    }
  }
  return b.toString();
}
