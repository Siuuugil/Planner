import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models/game.dart';
import '../widgets/game_widgets.dart';
import '../widgets/schedule_widgets.dart';

class GameDetailScreen extends StatelessWidget {
  const GameDetailScreen({super.key, required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final game = store.gameById(gameId);
    if (game == null) return const Scaffold();

    final daily = game.chores.where((c) => c.period == ChorePeriod.daily);
    final weekly = game.chores.where((c) => c.period == ChorePeriod.weekly);
    final today = DateTime.now();
    final upcoming = store.schedules
        .where((s) =>
            s.gameId == game.id &&
            !s.start.isBefore(DateTime(today.year, today.month, today.day)))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return Scaffold(
      appBar: AppBar(
        title: Text(game.name),
        actions: [
          IconButton(
            tooltip: '게임 수정',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showGameEditor(context, existing: game),
          ),
          IconButton(
            tooltip: '게임 삭제',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text('${game.name} 삭제'),
                  content: const Text('숙제와 목표가 모두 삭제돼요. 연결된 일정은 일반 일정으로 남아요.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('삭제')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                Navigator.pop(context);
                store.deleteGame(game);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _Section(
            title: '스펙업 목표',
            onAdd: () => showGoalEditor(context, game),
          ),
          for (final g in game.goals) GoalTile(game: game, goal: g),
          _Section(
            title: '일일 숙제 (매일 ${game.resetHour}시 초기화)',
            onAdd: () => showChoreEditor(context, game),
          ),
          for (final c in daily) ChoreTile(game: game, chore: c),
          _Section(
            title: '주간 숙제 (${weekdayNames[game.weeklyResetWeekday - 1]}요일 ${game.resetHour}시 초기화)',
            onAdd: () => showChoreEditor(context, game, period: ChorePeriod.weekly),
          ),
          for (final c in weekly) ChoreTile(game: game, chore: c),
          _Section(
            title: '다가오는 일정',
            onAdd: () => showScheduleEditor(context, gameId: game.id),
          ),
          for (final s in upcoming) ScheduleTile(schedule: s, showDate: true),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 4, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(icon: const Icon(Icons.add), onPressed: onAdd),
          ],
        ),
      );
}
