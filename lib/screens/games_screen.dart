import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models/game.dart';
import '../ui/maple.dart';
import '../widgets/game_widgets.dart';
import 'game_detail_screen.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();

    return MapleScaffold(
      title: '게임 스펙업',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showGameEditor(context),
        icon: const Icon(Icons.add),
        label: Text('게임 추가', style: Maple.titleText(16)),
        shape: const StadiumBorder(side: BorderSide(color: Maple.brown, width: 3)),
      ),
      body: store.games.isEmpty
          ? ListView(
              children: const [
                MaplePanel(
                  icon: '🎮',
                  title: '캐릭터 선택',
                  child: MapleEmpty('하고 있는 게임을 추가해 보세요'),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                for (final g in store.games) _GameCard(game: g, now: now),
              ],
            ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.now});

  final Game game;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final g = game;
    final daily = g.chores.where((c) => c.period == ChorePeriod.daily).toList();
    final weekly = g.chores.where((c) => c.period == ChorePeriod.weekly).toList();
    int doneOf(List<Chore> l) => l.where((c) => g.isChoreDone(c, now)).length;
    final achieved = g.goals.where((x) => x.achieved).length;
    final avg = g.goals.isEmpty
        ? 0.0
        : g.goals.map((x) => x.progress).reduce((a, b) => a + b) / g.goals.length;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GameDetailScreen(gameId: g.id)),
      ),
      child: MaplePanel(
        icon: '🎮',
        title: g.name,
        accent: Color(g.colorValue),
        trailing: const Icon(Icons.chevron_right, color: Colors.white),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row('일일', daily.isEmpty
                ? null
                : GaugeBar(
                    value: doneOf(daily) / daily.length,
                    kind: GaugeKind.hp,
                    label: '${doneOf(daily)} / ${daily.length}',
                  )),
            const SizedBox(height: 6),
            _row('주간', weekly.isEmpty
                ? null
                : GaugeBar(
                    value: doneOf(weekly) / weekly.length,
                    kind: GaugeKind.mp,
                    label: '${doneOf(weekly)} / ${weekly.length}',
                  )),
            const SizedBox(height: 6),
            _row('목표', g.goals.isEmpty
                ? null
                : GaugeBar(
                    value: avg,
                    label: '평균 ${(avg * 100).toStringAsFixed(1)}% · 달성 $achieved/${g.goals.length}',
                  )),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, Widget? gauge) => Row(
        children: [
          SizedBox(width: 40, child: Text(label, style: const TextStyle(fontSize: 14))),
          Expanded(
            child: gauge ??
                const Text('없음', style: TextStyle(color: Maple.brownMid, fontSize: 13)),
          ),
        ],
      );
}
