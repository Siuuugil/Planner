import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/store_scope.dart';
import '../models/game.dart';
import '../models/schedule.dart';
import '../models/task.dart';
import '../ui/kit.dart';
import '../widgets/maple_widgets.dart';
import '../widgets/schedule_widgets.dart';
import '../widgets/task_widgets.dart';
import 'account_screen.dart';
import 'ai_screen.dart';
import 'settings_screen.dart';

/// 홈: 오늘 할 일(일정·마감 할 일·숙제)을 한 목록으로 + 결정석·캐릭터 위젯
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, this.onOpenMaple});

  final VoidCallback? onOpenMaple;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);

    final schedules = store.schedulesOn(now)
      ..sort((a, b) => a.allDay == b.allDay ? a.start.compareTo(b.start) : (a.allDay ? -1 : 1));
    final dueTasks = store.tasks
        .where((t) => t.due != null && !DateUtils.dateOnly(t.due!).isAfter(today))
        .where((t) => !t.done || DateUtils.isSameDay(t.due, now))
        .toList()
      ..sort((a, b) => a.due!.compareTo(b.due!));
    final choreGroups = <(Game, ChorePeriod, List<Chore>)>[
      for (final g in store.games)
        for (final p in ChorePeriod.values)
          if (g.chores.any((c) => c.period == p && !c.isBoss))
            (g, p, g.chores.where((c) => c.period == p && !c.isBoss).toList()),
    ];

    final hide = store.hideGames;
    final lifeSchedules = schedules.where((s) => s.gameId == null).toList();
    final gameSchedules = schedules.where((s) => s.gameId != null).toList();

    // 일상·업무 목록: 할 것 먼저, 끝낸 것은 아래
    final open = <Widget>[];
    final done = <Widget>[];
    for (final s in lifeSchedules) {
      (s.done ? done : open).add(_ScheduleRow(s));
    }
    for (final t in dueTasks.where((t) => t.due!.isBefore(today))) {
      open.add(_TaskRow(t));
    }
    for (final t in dueTasks.where((t) => !t.due!.isBefore(today))) {
      (t.done ? done : open).add(_TaskRow(t));
    }

    // 게임 목록 (따로)
    final gameOpen = <Widget>[];
    final gameDone = <Widget>[];
    var gameLeft = 0, gameFinished = 0;
    for (final s in gameSchedules) {
      (s.done ? gameDone : gameOpen).add(_ScheduleRow(s));
      s.done ? gameFinished++ : gameLeft++;
    }
    for (final (g, p, list) in choreGroups) {
      final left = list.where((c) => !g.isChoreDone(c, now)).length;
      gameLeft += left;
      gameFinished += list.length - left;
      (left == 0 ? gameDone : gameOpen).add(_ChoreGroupRow(g, p, list));
    }

    final openCount = lifeSchedules.where((s) => !s.done).length + dueTasks.where((t) => !t.done).length;
    final doneCount = lifeSchedules.where((s) => s.done).length + dueTasks.where((t) => t.done).length;
    final total = openCount + doneCount;
    final hasGame = gameOpen.isNotEmpty || gameDone.isNotEmpty;

    final cg = store.crystalGame();
    final boss = cg?.chores.where((c) => c.isBoss).toList() ?? [];
    final crystalExpected = boss.fold<int>(0, (a, c) => a + cg!.bossIncome(c));
    final crystalDone = boss.where((c) => cg!.isChoreDone(c, now));
    final crystalEarned = crystalDone.fold<int>(0, (a, c) => a + cg!.bossIncome(c));
    final char = store.characters.isEmpty ? null : store.characters.first;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: '추가',
        onPressed: () => _showAddMenu(context),
        child: const Icon(Icons.add, size: 28),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('M월 d일 EEEE', 'ko_KR').format(now),
                                style: const TextStyle(fontSize: 14, color: Ui.subtext, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text.rich(
                              TextSpan(children: [
                                TextSpan(text: openCount == 0 && total > 0 ? '오늘 할 일 끝! ' : '오늘 할 일 '),
                                if (openCount > 0)
                                  TextSpan(text: '$openCount개', style: const TextStyle(color: Ui.accent)),
                              ]),
                              style: Ui.title(26),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'AI 비서',
                        icon: const Icon(Icons.auto_awesome, color: Ui.accent),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AiScreen()),
                        ),
                      ),
                      IconButton(
                        tooltip: hide ? '게임 보이기' : '게임 숨기기 (회사 모드)',
                        icon: Icon(hide ? Icons.videogame_asset_off_outlined : Icons.sports_esports_outlined,
                            color: hide ? Ui.subtext : Ui.purple),
                        onPressed: () {
                          store.hideGames = !hide;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(!hide ? '게임을 숨겼어요 (홈·캘린더·탭)' : '게임을 다시 보여줘요'),
                            duration: const Duration(seconds: 2),
                          ));
                        },
                      ),
                      const SyncButton(),
                      IconButton(
                        tooltip: '설정',
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
                if (total > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: GaugeBar(
                      value: doneCount / total,
                      label: '$doneCount개 완료 · 일정 ${lifeSchedules.length} · 할 일 ${dueTasks.length}',
                    ),
                  ),
                AppSection(
                  title: '일상 · 업무',
                  child: open.isEmpty && done.isEmpty
                      ? const EmptyHint('오늘은 비어 있어요. + 로 일정이나 할 일을 추가해 보세요.')
                      : Column(children: [
                          ...open,
                          if (open.isEmpty) const EmptyHint('다 끝냈어요. 수고했어요!'),
                          ...done.map((w) => Opacity(opacity: 0.45, child: w)),
                        ]),
                ),
                if (!hide && hasGame)
                  AppSection(
                    title: '게임',
                    accent: Ui.purple,
                    trailing: CountBadge('$gameFinished/${gameLeft + gameFinished}'),
                    child: Column(children: [
                      ...gameOpen,
                      ...gameDone.map((w) => Opacity(opacity: 0.45, child: w)),
                    ]),
                  ),
                if (!hide && (boss.isNotEmpty || char != null))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (boss.isNotEmpty)
                          Expanded(
                            child: StatCard(
                              label: '이번 주 결정석',
                              value: koreanNumber(crystalEarned),
                              progress: crystalExpected == 0 ? 0 : crystalEarned / crystalExpected,
                              color: Ui.blue,
                              caption: '예상 ${koreanNumber(crystalExpected)} · 보스 ${crystalDone.length}/${boss.length}',
                              onTap: onOpenMaple,
                            ),
                          ),
                        if (boss.isNotEmpty && char != null) const SizedBox(width: 12),
                        if (char != null)
                          Expanded(
                            child: StatCard(
                              label: '${char.name} · ${char.job}',
                              value: 'Lv.${char.level}',
                              valueSuffix: '${char.expRate.toStringAsFixed(1)}%',
                              progress: char.expRate / 100,
                              caption: char.combatPower == null ? null : '전투력 ${koreanNumber(char.combatPower!)}',
                              onTap: onOpenMaple,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('일정'),
              subtitle: const Text('시간이 정해진 약속, 레이드 등'),
              onTap: () {
                Navigator.pop(sheet);
                showScheduleEditor(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('할 일'),
              subtitle: const Text('업무나 개인 할 일 (마감일 선택)'),
              onTap: () {
                Navigator.pop(sheet);
                showTaskEditor(context, TaskCategory.work);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 왼쪽 시간/상태 + 제목·설명 + 오른쪽 체크 한 줄
class _Row extends StatelessWidget {
  const _Row({
    required this.lead,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.leadColor = Ui.text,
    this.subtitleColor = Ui.subtext,
    this.strike = false,
    this.onTap,
  });

  final String lead;
  final Color leadColor;
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final Widget trailing;
  final bool strike;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(lead, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: leadColor)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        decoration: strike ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: subtitleColor)),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      );
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow(this.s);

  final Schedule s;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final game = store.gameById(s.gameId);
    return _Row(
      lead: s.allDay ? '종일' : DateFormat('HH:mm').format(s.start),
      title: s.title,
      subtitle: [if (game != null) '게임 · ${game.name}' else '일정', if (s.memo.isNotEmpty) s.memo].join(' · '),
      subtitleColor: game != null ? Ui.purple : Ui.subtext,
      strike: s.done,
      onTap: () => showScheduleEditor(context, existing: s),
      trailing: CheckCircle(
        value: s.done,
        onChanged: (v) {
          s.done = v;
          store.commit();
        },
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow(this.t);

  final Task t;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final overdue = !t.done && t.due!.isBefore(DateUtils.dateOnly(DateTime.now()));
    return _Row(
      lead: overdue ? '지남' : '오늘',
      leadColor: overdue ? Ui.red : Ui.text,
      title: t.title,
      subtitle: [
        t.category.label,
        if (overdue) '${DateFormat('M/d').format(t.due!)}까지',
        if (t.memo.isNotEmpty) t.memo,
      ].join(' · '),
      strike: t.done,
      onTap: () => showTaskEditor(context, t.category, existing: t),
      trailing: CheckCircle(
        value: t.done,
        onChanged: (v) {
          t.done = v;
          store.commit();
        },
      ),
    );
  }
}

/// 게임 숙제는 한 줄로 묶고, 누르면 하나씩 체크하는 시트
class _ChoreGroupRow extends StatelessWidget {
  const _ChoreGroupRow(this.g, this.period, this.chores);

  final Game g;
  final ChorePeriod period;
  final List<Chore> chores;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final left = chores.where((c) => !g.isChoreDone(c, now)).toList();
    final shown = left.isEmpty ? chores : left;
    return _Row(
      lead: period == ChorePeriod.daily ? '일일' : '주간',
      leadColor: Ui.purple,
      title: shown.map((c) => c.title).join(' · '),
      subtitle: '${g.name} 숙제 · '
          '${period == ChorePeriod.daily ? '매일 ${g.resetHour}시' : '${_weekday(g.weeklyResetWeekday)}요일'} 초기화',
      subtitleColor: Ui.purple,
      onTap: () => _open(context),
      trailing: SizedBox(
        width: 44,
        child: Center(
          child: Text('${chores.length - left.length}/${chores.length}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Ui.subtext)),
        ),
      ),
    );
  }

  static String _weekday(int d) => const ['월', '화', '수', '목', '금', '토', '일'][d - 1];

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _ChoreSheet(gameId: g.id, period: period),
    );
  }
}

class _ChoreSheet extends StatelessWidget {
  const _ChoreSheet({required this.gameId, required this.period});

  final String gameId;
  final ChorePeriod period;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final g = store.gameById(gameId);
    if (g == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final list = g.chores.where((c) => c.period == period && !c.isBoss).toList();
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('${g.name} ${period == ChorePeriod.daily ? '일일' : '주간'} 숙제', style: Ui.title(18)),
          ),
          for (final c in list)
            ListTile(
              title: Text(
                c.title,
                style: g.isChoreDone(c, now)
                    ? const TextStyle(decoration: TextDecoration.lineThrough, color: Ui.subtext)
                    : null,
              ),
              trailing: QuestMark(done: g.isChoreDone(c, now), onTap: () => store.toggleChore(g, c)),
              onTap: () => store.toggleChore(g, c),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
