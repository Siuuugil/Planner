import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../maple/maple_service.dart';
import '../models/game.dart';
import '../ui/maple.dart';
import '../widgets/game_widgets.dart';
import '../widgets/maple_widgets.dart';
import 'character_screen.dart';
import 'crystal_screen.dart';
import 'game_detail_screen.dart';
import 'settings_screen.dart';

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
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const _CharactersPanel(),
          const CrystalSummaryPanel(showWhenEmpty: true),
          if (store.games.isEmpty)
            const MaplePanel(
              icon: '🎮',
              title: '게임',
              child: MapleEmpty('하고 있는 게임을 추가해 보세요'),
            ),
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

/// 넥슨 Open API로 불러온 내 메이플 캐릭터들.
class _CharactersPanel extends StatelessWidget {
  const _CharactersPanel();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final maple = MapleScope.of(context);
    if (maple == null) return const SizedBox.shrink();

    void openSettings() => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );

    return MaplePanel(
      icon: '🍁',
      title: '내 메이플 캐릭터',
      accent: Maple.leaf,
      trailing: MapleAddButton(
        tooltip: '닉네임으로 캐릭터 추가',
        onPressed: maple.hasKey ? () => showCharacterSearch(context, maple) : openSettings,
      ),
      child: !maple.hasKey && store.characters.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '넥슨 Open API 키를 넣으면 닉네임으로 내 캐릭터를 불러와서\n'
                    '레벨·전투력 목표와 성장 그래프를 자동으로 관리할 수 있어요.',
                    style: TextStyle(color: Maple.brownMid),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: openSettings, child: const Text('API 키 입력하러 가기')),
                ],
              ),
            )
          : store.characters.isEmpty
              ? const MapleEmpty('+ 를 눌러 닉네임으로 캐릭터를 추가하세요')
              : Column(
                  children: withDividers(store.characters.map((c) => CharacterRow(
                        character: c,
                        busy: maple.busy.contains(c.id),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CharacterScreen(characterId: c.id)),
                        ),
                      ))),
                ),
    );
  }
}
