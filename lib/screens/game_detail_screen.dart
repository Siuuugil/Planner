import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models/game.dart';
import '../ui/maple.dart';
import '../widgets/game_widgets.dart';
import '../widgets/schedule_widgets.dart';

class GameDetailScreen extends StatelessWidget {
  const GameDetailScreen({super.key, required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final game = store.gameById(gameId);
    if (game == null) return const MapleScaffold(title: '', body: SizedBox());

    final now = DateTime.now();
    final daily = game.chores.where((c) => c.period == ChorePeriod.daily).toList();
    final weekly = game.chores.where((c) => c.period == ChorePeriod.weekly).toList();
    int doneOf(List<Chore> l) => l.where((c) => game.isChoreDone(c, now)).length;
    final upcoming = store.schedules
        .where((s) =>
            s.gameId == game.id &&
            !s.start.isBefore(DateTime(now.year, now.month, now.day)))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return MapleScaffold(
      title: game.name,
      actions: [
        IconButton(
          tooltip: '게임 수정',
          icon: const Icon(Icons.edit),
          onPressed: () => showGameEditor(context, existing: game),
        ),
        IconButton(
          tooltip: '게임 삭제',
          icon: const Icon(Icons.delete),
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
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          MaplePanel(
            icon: '⭐',
            title: '스펙업 목표',
            accent: const Color(0xFF9C6ADE),
            trailing: MapleAddButton(
              tooltip: '목표 추가',
              onPressed: () => showGoalEditor(context, game),
            ),
            child: game.goals.isEmpty
                ? const MapleEmpty('예: 아이템 레벨 1640 → 1680')
                : Column(children: withDividers(game.goals.map((g) => GoalTile(game: game, goal: g)))),
          ),
          MaplePanel(
            icon: '⚔️',
            title: '일일 퀘스트 · 매일 ${game.resetHour}시',
            accent: const Color(0xFFE8833A),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (daily.isNotEmpty) MapleBadge('${doneOf(daily)}/${daily.length}'),
              MapleAddButton(
                tooltip: '일일 숙제 추가',
                onPressed: () => showChoreEditor(context, game),
              ),
            ]),
            child: daily.isEmpty
                ? const MapleEmpty('예: 일일 던전, 몬스터 파크')
                : Column(children: withDividers(daily.map((c) => ChoreTile(game: game, chore: c)))),
          ),
          MaplePanel(
            icon: '🛡️',
            title: '주간 퀘스트 · ${weekdayNames[game.weeklyResetWeekday - 1]}요일 ${game.resetHour}시',
            accent: const Color(0xFF4F8EDC),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (weekly.isNotEmpty) MapleBadge('${doneOf(weekly)}/${weekly.length}'),
              MapleAddButton(
                tooltip: '주간 숙제 추가',
                onPressed: () => showChoreEditor(context, game, period: ChorePeriod.weekly),
              ),
            ]),
            child: weekly.isEmpty
                ? const MapleEmpty('예: 주간 보스, 길드 컨텐츠')
                : Column(children: withDividers(weekly.map((c) => ChoreTile(game: game, chore: c)))),
          ),
          MaplePanel(
            icon: '📅',
            title: '다가오는 일정',
            trailing: MapleAddButton(
              tooltip: '일정 추가',
              onPressed: () => showScheduleEditor(context, gameId: game.id),
            ),
            child: upcoming.isEmpty
                ? const MapleEmpty('예: 레이드, 이벤트 마감')
                : Column(
                    children: withDividers(
                        upcoming.map((s) => ScheduleTile(schedule: s, showDate: true)))),
          ),
        ],
      ),
    );
  }
}
