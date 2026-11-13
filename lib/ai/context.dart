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

/// 레벨 진행(레벨+경험치%) 하루 평균 상승량 (최근 14일 기록 기준, 기록 부족하면 null)
double? levelPerDay(List<({String date, double progress})> history) {
  if (history.length < 2) return null;
  final recent = history.length > 15 ? history.sublist(history.length - 15) : history;
  final days = DateTime.parse(recent.last.date).difference(DateTime.parse(recent.first.date)).inDays;
  if (days <= 0) return null;
  final rate = (recent.last.progress - recent.first.progress) / days;
  return rate > 0 ? rate : null;
}

/// 메이플 코치·리포트용 숫자 요약 (앱이 계산한 값만 담는다)
String mapleContext(AppStore store, DateTime now) {
  final b = StringBuffer();
  b.writeln('[캐릭터]');
  if (store.characters.isEmpty) b.writeln('- 등록된 캐릭터 없음');
  final rates = <String, double?>{};
  for (final c in store.characters) {
    final rate = levelPerDay([for (final h in c.history) (date: h.date, progress: h.levelProgress)]);
    rates[c.id] = rate;
    final cps = c.history.where((h) => h.combatPower != null).toList();
    String combatTrend = '';
    if (cps.length >= 2) {
      final days = DateTime.parse(cps.last.date).difference(DateTime.parse(cps.first.date)).inDays;
      if (days > 0) {
        combatTrend = ', 전투력 $days일간 ${koreanNumber(cps.last.combatPower! - cps.first.combatPower!)} 상승';
      }
    }
    b.writeln('- ${c.name} (${c.job}, ${c.world}): Lv.${c.level} ${c.expRate.toStringAsFixed(2)}%'
        '${c.combatPower != null ? ', 전투력 ${koreanNumber(c.combatPower!)}' : ''}'
        '${rate == null ? ', 성장 기록 부족' : ', 하루 평균 ${rate.toStringAsFixed(3)}레벨 (다음 레벨까지 약 ${((c.level + 1 - c.levelProgress) / rate).ceil()}일)'}'
        '$combatTrend, 기록 ${c.history.length}일');
  }

  for (final g in store.games) {
    final income = g.weekIncome;
    final boss = g.chores.where((c) => c.isBoss).toList();
    if (boss.isEmpty && income.isEmpty && g.goals.isEmpty) continue;
    b.writeln('\n[${g.name} 결정석]');
    final key = g.weekKey(now);
    final expected = boss.fold<int>(0, (a, c) => a + g.bossIncome(c));
    b.writeln('- 이번 주: ${koreanNumber(income[key] ?? 0)} / 예상 ${koreanNumber(expected)} 메소');
    final past = (income.entries.where((e) => e.key.compareTo(key) < 0).toList()..sort((a, c) => a.key.compareTo(c.key)));
    final last8 = past.length > 8 ? past.sublist(past.length - 8) : past;
    if (last8.isNotEmpty) {
      final avg = last8.fold<int>(0, (a, e) => a + e.value) ~/ last8.length;
      b.writeln('- 지난 주들: ${last8.map((e) => '${e.key.substring(5)} ${koreanNumber(e.value)}').join(', ')} (평균 ${koreanNumber(avg)})');
    }
    final byChar = <String, List<Chore>>{};
    for (final c in boss) {
      byChar.putIfAbsent(c.charName ?? '미지정', () => []).add(c);
    }
    for (final e in byChar.entries) {
      final weekly = e.value.where((c) => !(g.bossById(c.bossId)?.monthly ?? false)).toList();
      final done = weekly.where((c) => g.isChoreDone(c, now)).length;
      b.writeln('- ${e.key}: 매주 잡는 보스로 ${weekly.length}개 등록 (주간 결정석 판매 한도 $weeklyCrystalLimit개 중 '
          '${weekly.length}칸 사용, 빈 칸 ${(weeklyCrystalLimit - weekly.length).clamp(0, weeklyCrystalLimit)}개), '
          '이번 주 $done개 처치, 등록 보스 다 잡으면 주 ${koreanNumber(weekly.fold<int>(0, (a, c) => a + g.bossIncome(c)))}');
      for (final c in e.value) {
        final price = g.bossById(c.bossId)?.price ?? 0;
        b.writeln('  · ${c.title}${c.partySize > 1 ? ' ${c.partySize}인 파티' : ' 솔로'}: '
            '내 몫 ${koreanNumber(g.bossIncome(c))}'
            '${g.isEos(c.charName) ? ' (에오스 결정석 ${koreanNumber(g.bossIncomeRaw(c))}을 메포로 바꿔 본캐 월드로 넘긴 값, ×${g.eosRate})' : ''}'
            ' (결정석 판매가 ${koreanNumber(price)})'
            ' — 이번 주 ${g.isChoreDone(c, now) ? '처치함' : '아직'}');
      }
    }

    if (g.goals.isNotEmpty) {
      b.writeln('\n[${g.name} 목표]');
      final avgWeek = last8.isEmpty ? expected : last8.fold<int>(0, (a, e) => a + e.value) ~/ last8.length;
      for (final goal in g.goals) {
        final pct = (goal.progress * 100).toStringAsFixed(1);
        String eta = '';
        if (goal.autoMetric == 'crystal' && avgWeek > 0 && !goal.achieved) {
          eta = ', 주 평균 수익으로 약 ${((goal.target - goal.current) / avgWeek).ceil()}주 남음';
        } else if (goal.autoMetric == 'level' && rates[goal.autoCharId] != null && !goal.achieved) {
          eta = ', 지금 속도로 약 ${((goal.target - goal.current) / rates[goal.autoCharId]!).ceil()}일 남음';
        }
        final fmt = const {'combat', 'crystal'}.contains(goal.autoMetric) ? (double v) => koreanNumber(v) : (double v) => v.toStringAsFixed(2);
        b.writeln('- ${goal.title}: ${fmt(goal.current)} / ${fmt(goal.target)} ($pct%)$eta'
            '${goal.deadline != null ? ', 마감 ${DateFormat('M/d').format(goal.deadline!)}' : ''}');
      }
    }
  }
  return b.toString();
}

/// 지난 7일 돌아보기용 숫자 (회사 모드면 게임 제외)
String weekReviewContext(AppStore store, DateTime now) {
  final b = StringBuffer();
  final from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
  bool inWeek(DateTime t) => !t.isBefore(from) && t.isBefore(now);
  final hide = store.hideGames;

  final sch = store.schedules.where((s) => inWeek(s.start) && (!hide || s.gameId == null)).toList();
  b.writeln('[지난 7일 (${DateFormat('M/d').format(from)}~${DateFormat('M/d').format(now)})]');
  b.writeln('- 일정 ${sch.length}개 중 완료 ${sch.where((s) => s.done).length}개');
  final dueTasks = store.tasks.where((t) => t.due != null && inWeek(t.due!)).toList();
  b.writeln('- 이번 주 마감 할 일 ${dueTasks.length}개 중 완료 ${dueTasks.where((t) => t.done).length}개'
      '${dueTasks.where((t) => !t.done).isEmpty ? '' : ' (못 한 것: ${dueTasks.where((t) => !t.done).map((t) => t.title).join(', ')})'}');
  final overdue = store.tasks.where((t) => !t.done && t.due != null && t.due!.isBefore(from)).toList();
  if (overdue.isNotEmpty) b.writeln('- 오래 밀린 할 일: ${overdue.map((t) => t.title).join(', ')}');
  final next = store.tasks
      .where((t) => !t.done && t.due != null && !t.due!.isBefore(now) && t.due!.isBefore(now.add(const Duration(days: 7))))
      .toList();
  if (next.isNotEmpty) b.writeln('- 다음 7일 마감: ${next.map((t) => '${t.title}(${DateFormat('M/d').format(t.due!)})').join(', ')}');

  if (!hide) {
    final marks = store.marks.values.where((m) => inWeek(m.at)).length;
    b.writeln('- 게임 숙제·보스 체크 $marks회');
    b.writeln();
    b.write(mapleContext(store, now));
  }
  return b.toString();
}
