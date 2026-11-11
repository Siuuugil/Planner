import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../maple/maple_service.dart';
import '../models/game.dart';
import '../models/maple_character.dart';
import '../ui/kit.dart';
import '../widgets/game_widgets.dart';
import '../widgets/maple_widgets.dart';
import 'character_screen.dart';
import 'crystal_screen.dart';
import 'game_detail_screen.dart';
import 'settings_screen.dart';

enum _Tab { chores, crystal, growth, goals }

/// 메이플 탭: 캐릭터 카드 + [숙제 | 결정석 | 성장 | 목표]
class MapleScreen extends StatefulWidget {
  const MapleScreen({super.key});

  @override
  State<MapleScreen> createState() => _MapleScreenState();
}

class _MapleScreenState extends State<MapleScreen> {
  _Tab _tab = _Tab.chores;
  int _charIndex = 0;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final maple = MapleScope.of(context);
    final chars = store.characters;
    if (_charIndex >= chars.length) _charIndex = 0;
    final char = chars.isEmpty ? null : chars[_charIndex];

    return AppScaffold(
      title: '메이플',
      actions: [
        if (maple != null && chars.isNotEmpty)
          IconButton(
            tooltip: '캐릭터 추가',
            icon: const Icon(Icons.person_add_alt),
            onPressed: maple.hasKey ? () => showCharacterSearch(context, maple) : () => _openSettings(context),
          ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (chars.isEmpty)
            _NoCharacter(maple: maple, openSettings: () => _openSettings(context))
          else
            _CharacterPager(
              chars: chars,
              index: _charIndex,
              onChanged: (i) => setState(() => _charIndex = i),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SegmentedButton<_Tab>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Tab.chores, label: Text('숙제')),
                ButtonSegment(value: _Tab.crystal, label: Text('결정석')),
                ButtonSegment(value: _Tab.growth, label: Text('성장')),
                ButtonSegment(value: _Tab.goals, label: Text('목표')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          ...switch (_tab) {
            _Tab.chores => _chores(context),
            _Tab.crystal => _crystal(context),
            _Tab.growth => _growth(char),
            _Tab.goals => _goals(context, char),
          },
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));

  List<Widget> _chores(BuildContext context) {
    final store = StoreScope.of(context);
    final g = store.findMapleGame();
    final now = DateTime.now();
    List<Chore> of(ChorePeriod p) => g?.chores.where((c) => c.period == p && !c.isBoss).toList() ?? [];
    final daily = of(ChorePeriod.daily);
    final weekly = of(ChorePeriod.weekly);
    String count(List<Chore> l) => '${l.where((c) => g!.isChoreDone(c, now)).length}/${l.length}';
    final others = store.games.where((x) => x != g).toList();

    return [
      AppSection(
        title: g == null ? '일일 숙제' : '일일 숙제 · 매일 ${g.resetHour}시 초기화',
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (daily.isNotEmpty) CountBadge(count(daily)),
          AddButton(tooltip: '일일 숙제 추가', onPressed: () => showChoreEditor(context, store.mapleGame())),
        ]),
        child: daily.isEmpty
            ? const EmptyHint('예: 몬스터 파크, 우르스, 아케인리버 일일 퀘스트')
            : Column(children: daily.map((c) => ChoreTile(game: g!, chore: c)).toList()),
      ),
      AppSection(
        title: g == null
            ? '주간 숙제'
            : '주간 숙제 · ${weekdayNames[g.weeklyResetWeekday - 1]}요일 ${g.resetHour}시 초기화',
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (weekly.isNotEmpty) CountBadge(count(weekly)),
          AddButton(
            tooltip: '주간 숙제 추가',
            onPressed: () => showChoreEditor(context, store.mapleGame(), period: ChorePeriod.weekly),
          ),
        ]),
        child: weekly.isEmpty
            ? const EmptyHint('예: 길드 컨텐츠, 에픽 던전 · 보스는 결정석 탭에서')
            : Column(children: weekly.map((c) => ChoreTile(game: g!, chore: c)).toList()),
      ),
      AppSection(
        title: '다른 게임',
        trailing: AddButton(tooltip: '게임 추가', onPressed: () => showGameEditor(context)),
        child: others.isEmpty
            ? const EmptyHint('메이플 말고 다른 게임 숙제도 여기서 관리할 수 있어요')
            : Column(
                children: others.map((x) {
                  final left = x.chores.where((c) => !x.isChoreDone(c, now)).length;
                  return ListTile(
                    leading: CircleAvatar(radius: 6, backgroundColor: Color(x.colorValue)),
                    title: Text(x.name),
                    subtitle: Text('남은 숙제 $left · 목표 ${x.goals.length}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GameDetailScreen(gameId: x.id)),
                    ),
                  );
                }).toList(),
              ),
      ),
      if (g != null)
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('메이플 초기화 시각·색 바꾸기'),
            onPressed: () => showGameEditor(context, existing: g),
          ),
        ),
    ];
  }

  List<Widget> _crystal(BuildContext context) {
    final store = StoreScope.of(context);
    final g = store.crystalGame() ?? store.findMapleGame();
    if (g == null) {
      return [
        AppSection(
          title: '보스 결정석',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('매주 잡는 보스를 등록하면 주간 메소 수익을 계산해 줘요.',
                    style: TextStyle(color: Ui.subtext)),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => showBossChoreEditor(context, store.mapleGame()),
                  child: const Text('보스 수확 등록하기'),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      CrystalBody(g),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('보스 수확 추가'),
          onPressed: () => showBossChoreEditor(context, g),
        ),
      ),
    ];
  }

  List<Widget> _growth(MapleCharacter? c) {
    if (c == null) {
      return const [AppSection(child: EmptyHint('캐릭터를 추가하면 레벨·전투력 변화와 장비를 볼 수 있어요'))];
    }
    return [CharacterGrowthSection(c), CharacterGearSection(c)];
  }

  List<Widget> _goals(BuildContext context, MapleCharacter? c) {
    final store = StoreScope.of(context);
    final g = store.findMapleGame();
    final manual = g?.goals.where((x) => x.autoMetric == null).toList() ?? [];
    return [
      if (c != null) CharacterGoalsSection(c),
      CrystalGoalSection(g ?? store.crystalGame() ?? store.mapleGame()),
      AppSection(
        title: '직접 기록하는 목표',
        trailing: AddButton(tooltip: '목표 추가', onPressed: () => showGoalEditor(context, store.mapleGame())),
        child: manual.isEmpty
            ? const EmptyHint('예: 스타포스 22성, 유니온 8000 — 현재값을 직접 고쳐가며 기록')
            : Column(children: manual.map((x) => GoalTile(game: g!, goal: x)).toList()),
      ),
    ];
  }
}

/// 캐릭터 없을 때 시작 안내
class _NoCharacter extends StatelessWidget {
  const _NoCharacter({required this.maple, required this.openSettings});

  final MapleService? maple;
  final VoidCallback openSettings;

  @override
  Widget build(BuildContext context) {
    final hasKey = maple?.hasKey ?? false;
    return AppSection(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('내 캐릭터 불러오기', style: Ui.title(18)),
          const SizedBox(height: 6),
          Text(
            hasKey
                ? '닉네임으로 검색하면 레벨·전투력이 자동으로 기록되고 목표에 반영돼요.'
                : '넥슨 Open API 키를 넣으면 닉네임으로 캐릭터를 불러올 수 있어요.',
            style: const TextStyle(color: Ui.subtext, height: 1.45),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: maple == null
                ? null
                : hasKey
                    ? () => showCharacterSearch(context, maple!)
                    : openSettings,
            child: Text(hasKey ? '닉네임으로 검색' : 'API 키 입력하기'),
          ),
        ],
      ),
    );
  }
}

/// 캐릭터 카드 (여러 개면 좌우로 넘김)
class _CharacterPager extends StatelessWidget {
  const _CharacterPager({required this.chars, required this.index, required this.onChanged});

  final List<MapleCharacter> chars;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 132,
          child: PageView.builder(
            controller: PageController(initialPage: index, viewportFraction: chars.length > 1 ? 0.92 : 1),
            itemCount: chars.length,
            onPageChanged: onChanged,
            itemBuilder: (_, i) => _CharacterCard(chars[i]),
          ),
        ),
        if (chars.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < chars.length; i++)
                  Container(
                    width: i == index ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == index ? Ui.text : Ui.ring,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard(this.c);

  final MapleCharacter c;

  @override
  Widget build(BuildContext context) {
    final maple = MapleScope.of(context);
    final busy = maple?.busy.contains(c.id) ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Ui.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CharacterScreen(characterId: c.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(color: Ui.field, borderRadius: BorderRadius.circular(14)),
                  child: NexonImage(c.image, size: 96),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ui.title(19)),
                      Text('${c.job} · ${c.world}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: Ui.subtext)),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: 'Lv.${c.level} '),
                          TextSpan(
                            text: '${c.expRate.toStringAsFixed(2)}%',
                            style: const TextStyle(color: Ui.accent, fontSize: 13),
                          ),
                        ]),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      GaugeBar(value: c.expRate / 100, height: 6),
                      if (c.combatPower != null) ...[
                        const SizedBox(height: 4),
                        Text('전투력 ${koreanNumber(c.combatPower!)}',
                            style: const TextStyle(fontSize: 12.5, color: Ui.subtext)),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '갱신',
                  onPressed: busy || maple == null ? null : () => runNexon(context, () => maple.refresh(c)),
                  icon: busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, color: Ui.subtext),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
