import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/store_scope.dart';
import '../ui/maple.dart';
import '../widgets/game_widgets.dart';
import '../widgets/schedule_widgets.dart';
import '../widgets/task_widgets.dart';
import 'account_screen.dart';
import 'settings_screen.dart';

/// 오늘 할 것만 한눈에: 오늘 일정, 마감된 할 일, 남은 게임 숙제, 진행 중인 스펙업 목표.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final today = store.schedulesOn(now);
    final dueTasks = store.tasks.where((t) => t.isDueBy(now)).toList()
      ..sort((a, b) => a.due!.compareTo(b.due!));
    final allChores = [
      for (final g in store.games)
        for (final c in g.chores) (g, c, g.isChoreDone(c, now)),
    ];
    final chores = allChores.where((e) => !e.$3).toList();
    final goals = [
      for (final g in store.games)
        for (final goal in g.goals)
          if (!goal.achieved) (g, goal),
    ];

    // 오늘 진행도: 오늘 일정 + 마감 할 일(오늘 마감은 완료한 것도 포함) + 숙제 중 완료 비율
    final doneDueToday = store.tasks
        .where((t) => t.done && t.due != null && DateUtils.isSameDay(t.due, now))
        .length;
    final total = today.length + dueTasks.length + doneDueToday + allChores.length;
    final done = today.where((s) => s.done).length +
        doneDueToday +
        allChores.where((e) => e.$3).length;

    return MapleScaffold(
      title: DateFormat('M월 d일 EEEE', 'ko_KR').format(now),
      actions: [
        const SyncButton(),
        IconButton(
          tooltip: '설정 · 알림',
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        tooltip: '일정 추가',
        onPressed: () => showScheduleEditor(context),
        child: const Icon(Icons.add, size: 30),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          MaplePanel(
            accent: Maple.leaf,
            icon: '🍁',
            title: '오늘의 진행도',
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GaugeBar(
                  value: total == 0 ? 0 : done / total,
                  height: 22,
                  label: total == 0 ? '오늘은 한가해요' : 'EXP $done / $total',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Stat('📅', '일정', today.length - today.where((s) => s.done).length),
                    _Stat('📜', '할 일', dueTasks.length),
                    if (store.games.isNotEmpty) _Stat('⚔️', '퀘스트', chores.length),
                  ],
                ),
              ],
            ),
          ),
          MaplePanel(
            icon: '📅',
            title: '오늘 일정',
            trailing: MapleBadge('${today.where((s) => s.done).length}/${today.length}'),
            child: today.isEmpty
                ? const MapleEmpty('오늘 일정이 없어요')
                : Column(children: withDividers(today.map((s) => ScheduleTile(schedule: s)))),
          ),
          MaplePanel(
            icon: '📜',
            title: '오늘까지 할 일',
            trailing: MapleBadge('${dueTasks.length}'),
            child: dueTasks.isEmpty
                ? const MapleEmpty('마감된 업무·기타 할 일이 없어요')
                : Column(
                    children: withDividers(
                        dueTasks.map((t) => TaskTile(task: t, showCategory: true)))),
          ),
          if (store.games.isNotEmpty) ...[
            MaplePanel(
              icon: '⚔️',
              title: '남은 퀘스트',
              accent: const Color(0xFFE8833A),
              trailing: MapleBadge('${chores.length}'),
              child: chores.isEmpty
                  ? const MapleEmpty('오늘 퀘스트 클리어! 🎉')
                  : Column(
                      children: withDividers(chores
                          .map((e) => ChoreTile(game: e.$1, chore: e.$2, showGame: true)))),
            ),
            MaplePanel(
              icon: '⭐',
              title: '스펙업 진행 중',
              accent: const Color(0xFF9C6ADE),
              trailing: MapleBadge('${goals.length}'),
              child: goals.isEmpty
                  ? const MapleEmpty('진행 중인 스펙업 목표가 없어요')
                  : Column(
                      children: withDividers(goals
                          .map((e) => GoalTile(game: e.$1, goal: e.$2, showGame: true)))),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.label, this.count);

  final String icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Maple.creamLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Maple.brownMid, width: 1.5),
        ),
        child: Text('$icon $label $count', style: const TextStyle(fontSize: 14)),
      );
}
