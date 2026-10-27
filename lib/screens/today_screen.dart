import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/store_scope.dart';
import '../widgets/game_widgets.dart';
import '../widgets/schedule_widgets.dart';

/// 오늘 할 것만 한눈에: 오늘 일정, 남은 게임 숙제, 진행 중인 스펙업 목표.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final today = store.schedulesOn(now);
    final chores = [
      for (final g in store.games)
        for (final c in g.chores)
          if (!g.isChoreDone(c, now)) (g, c),
    ];
    final goals = [
      for (final g in store.games)
        for (final goal in g.goals)
          if (!goal.achieved) (g, goal),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('M월 d일 EEEE', 'ko_KR').format(now)),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '일정 추가',
        onPressed: () => showScheduleEditor(context),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          _Header('오늘 일정', '${today.where((s) => s.done).length}/${today.length}'),
          if (today.isEmpty) const _Empty('오늘 일정이 없어요'),
          for (final s in today) ScheduleTile(schedule: s),
          _Header('남은 숙제', '${chores.length}개'),
          if (store.games.isEmpty)
            const _Empty('게임 탭에서 게임과 숙제를 추가해 보세요')
          else if (chores.isEmpty)
            const _Empty('숙제 끝! 🎉'),
          for (final (g, c) in chores) ChoreTile(game: g, chore: c, showGame: true),
          _Header('진행 중인 목표', '${goals.length}개'),
          if (goals.isEmpty) const _Empty('진행 중인 스펙업 목표가 없어요'),
          for (final (g, goal) in goals) GoalTile(game: g, goal: goal, showGame: true),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.trailing);

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const Spacer(),
          Text(trailing, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(text, style: TextStyle(color: Theme.of(context).hintColor)),
      );
}
