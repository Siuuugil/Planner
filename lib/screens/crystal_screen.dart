import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/app_store.dart';
import '../data/store_scope.dart';
import '../models/game.dart';
import '../ui/maple.dart';
import '../widgets/game_widgets.dart';
import '../widgets/maple_widgets.dart';

/// 이번 주 결정석 요약 (오늘·게임 탭에 넣는 작은 패널)
class CrystalSummaryPanel extends StatelessWidget {
  const CrystalSummaryPanel({super.key, this.showWhenEmpty = false});

  /// 보스 숙제가 없어도 (시작 안내용으로) 보여줄지
  final bool showWhenEmpty;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final g = store.crystalGame();
    final now = DateTime.now();
    final boss = g?.chores.where((c) => c.isBoss).toList() ?? [];
    if (boss.isEmpty && !showWhenEmpty) return const SizedBox.shrink();

    final expected = boss.fold<int>(0, (a, c) => a + g!.bossIncome(c));
    final done = boss.where((c) => g!.isChoreDone(c, now)).toList();
    final earned = done.fold<int>(0, (a, c) => a + g!.bossIncome(c));

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrystalScreen())),
      child: MaplePanel(
        icon: '💎',
        title: '이번 주 결정석',
        accent: const Color(0xFF2FA4C7),
        trailing: const Icon(Icons.chevron_right, color: Colors.white),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: boss.isEmpty
            ? const Text('보스 수확을 등록하면 주간 메소 수익을 계산해 줘요', style: TextStyle(color: Maple.brownMid))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GaugeBar(
                    value: expected == 0 ? 0 : earned / expected,
                    kind: GaugeKind.mp,
                    height: 20,
                    label: '${koreanNumber(earned)} / ${koreanNumber(expected)} 메소',
                  ),
                  const SizedBox(height: 6),
                  Text('보스 ${done.length}/${boss.length} 처치 · 남은 수익 ${koreanNumber(expected - earned)}',
                      style: const TextStyle(fontSize: 14)),
                ],
              ),
      ),
    );
  }
}

class CrystalScreen extends StatelessWidget {
  const CrystalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final g = store.crystalGame() ?? store.mapleGame();
    final now = DateTime.now();

    return MapleScaffold(
      title: '💎 결정석 수익',
      floatingActionButton: FloatingActionButton(
        tooltip: '보스 수확 추가',
        onPressed: () => showBossChoreEditor(context, g),
        child: const Icon(Icons.add, size: 30),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          _WeekPanel(g, now),
          ..._routinePanels(context, g),
          _HistoryPanel(g, now),
          _GoalPanel(g, now),
          _PricePanel(g),
        ],
      ),
    );
  }

  List<Widget> _routinePanels(BuildContext context, Game g) {
    final boss = g.chores.where((c) => c.isBoss).toList();
    if (boss.isEmpty) {
      return [
        MaplePanel(
          icon: '⚔️',
          title: '주간 보스 수확',
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '+ 를 눌러 매주 잡는 보스를 등록하세요.\n가격은 $bossPriceTableDate 기준 가격표가 자동으로 들어가요.',
                  style: const TextStyle(color: Maple.brownMid),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    final byChar = <String, List<Chore>>{};
    for (final c in boss) {
      byChar.putIfAbsent(c.charName ?? '캐릭터 미지정', () => []).add(c);
    }
    final now = DateTime.now();
    return [
      for (final e in byChar.entries)
        MaplePanel(
          icon: '⚔️',
          title: e.key,
          accent: const Color(0xFFE8833A),
          trailing: MapleBadge(
            '${e.value.where((c) => g.isChoreDone(c, now)).length}/${e.value.length}'
            '${e.value.length > weeklyCrystalLimit ? ' ⚠️' : ''}',
          ),
          child: Column(
            children: [
              if (e.value.length > weeklyCrystalLimit)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Text(
                    '캐릭터당 주간 결정석 판매는 $weeklyCrystalLimit개까지예요. '
                    '비싼 보스 위주로 $weeklyCrystalLimit개만 남기세요.',
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                  ),
                ),
              ...withDividers((e.value..sort((a, b) => g.bossIncome(b).compareTo(g.bossIncome(a))))
                  .map((c) => ChoreTile(game: g, chore: c))),
            ],
          ),
        ),
    ];
  }
}

class _WeekPanel extends StatelessWidget {
  const _WeekPanel(this.g, this.now);

  final Game g;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final boss = g.chores.where((c) => c.isBoss).toList();
    final expected = boss.fold<int>(0, (a, c) => a + g.bossIncome(c));
    final earned = boss.where((c) => g.isChoreDone(c, now)).fold<int>(0, (a, c) => a + g.bossIncome(c));
    final start = g.periodStart(ChorePeriod.weekly, now);
    final reset = DateTime(start.year, start.month, start.day + 7, g.resetHour);
    final left = reset.difference(now);

    return MaplePanel(
      icon: '💎',
      title: '이번 주',
      accent: const Color(0xFF2FA4C7),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(koreanNumber(earned), style: const TextStyle(fontSize: 30, color: Color(0xFF1E62D0))),
          Text('예상 ${koreanNumber(expected)} 메소', style: const TextStyle(color: Maple.brownMid)),
          const SizedBox(height: 8),
          GaugeBar(
            value: expected == 0 ? 0 : earned / expected,
            kind: GaugeKind.mp,
            height: 20,
            label: expected == 0 ? '등록된 보스 없음' : '${(earned / expected * 100).toStringAsFixed(1)}%',
          ),
          const SizedBox(height: 6),
          Text(
            '${weekdayNames[g.weeklyResetWeekday - 1]}요일 ${g.resetHour}시 초기화까지 '
            '${left.inDays}일 ${left.inHours % 24}시간',
            style: const TextStyle(fontSize: 13, color: Maple.brownMid),
          ),
        ],
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel(this.g, this.now);

  final Game g;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    // 최근 12주 (빈 주는 0)
    final start = g.periodStart(ChorePeriod.weekly, now);
    final weeks = [
      for (var k = 11; k >= 0; k--) DateTime(start.year, start.month, start.day - 7 * k),
    ];
    String key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
    final values = [for (final w in weeks) g.crystalWeeks[key(w)] ?? 0];
    final recorded = g.crystalWeeks.values.where((v) => v > 0).toList();
    final avg = recorded.isEmpty ? 0 : recorded.reduce((a, b) => a + b) ~/ recorded.length;
    final total = g.crystalWeeks.values.fold<int>(0, (a, b) => a + b);
    final month = g.crystalWeeks.entries
        .where((e) => e.key.startsWith(DateFormat('yyyy-MM').format(now)))
        .fold<int>(0, (a, e) => a + e.value);
    final maxV = values.fold<int>(1, math.max);

    return MaplePanel(
      icon: '📊',
      title: '주간 수익 기록',
      accent: const Color(0xFF4F8EDC),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < weeks.length; i++)
                  Expanded(
                    child: Tooltip(
                      message: '${DateFormat('M/d').format(weeks[i])} 주 · ${koreanNumber(values[i])}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: 4 + 100 * values[i] / maxV,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: i == weeks.length - 1
                                    ? Maple.exp
                                    : const [Color(0xFF9BE3F5), Color(0xFF2FA4C7)],
                              ),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              border: Border.all(color: Maple.brown, width: 1.2),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            i % 3 == 2 || i == weeks.length - 1 ? DateFormat('M/d').format(weeks[i]) : '',
                            style: const TextStyle(fontSize: 10, color: Maple.brownMid),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip('주 평균', koreanNumber(avg)),
              _chip('이번 달', koreanNumber(month)),
              _chip('누적', koreanNumber(total)),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _chip(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Maple.creamLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Maple.brownSoft, width: 1.5),
        ),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$k ', style: const TextStyle(color: Maple.brownMid, fontSize: 13)),
          TextSpan(text: v, style: const TextStyle(fontSize: 15)),
        ])),
      );
}

/// 메소 목표: 결정석 누적 수익으로 자동 진행, 현재 속도로 몇 주 남았는지.
class _GoalPanel extends StatelessWidget {
  const _GoalPanel(this.g, this.now);

  final Game g;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final goals = g.goals.where((x) => x.autoMetric == 'crystal').toList();
    final boss = g.chores.where((c) => c.isBoss);
    final weekly = boss.fold<int>(0, (a, c) => a + g.bossIncome(c));

    return MaplePanel(
      icon: '🎯',
      title: '메소 목표',
      accent: const Color(0xFF9C6ADE),
      trailing: MapleAddButton(tooltip: '메소 목표 추가', onPressed: () => _add(context)),
      child: goals.isEmpty
          ? const MapleEmpty('예: 아케인 무기 사기 위해 50억 모으기 → 결정석 수익으로 자동 진행')
          : Column(
              children: withDividers(goals.map((goal) {
                final left = goal.target - goal.current;
                final eta = left <= 0
                    ? '🏆 달성!'
                    : weekly <= 0
                        ? '보스를 등록하면 예상 기간이 나와요'
                        : '지금 속도면 약 ${(left / weekly).ceil()}주 뒤 달성 '
                            '(${DateFormat('M/d').format(now.add(Duration(days: 7 * (left / weekly).ceil())))})';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GoalTile(game: g, goal: goal),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Text(eta, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                );
              })),
            ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final store = StoreScope.read(context);
    final title = TextEditingController();
    final amount = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('🎯 메소 목표'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(labelText: '목표 (예: 아케인 무기 구매)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '모을 금액 (억 메소)', suffixText: '억'),
              ),
              const SizedBox(height: 6),
              const Text('이번 주부터 들어오는 결정석 수익이 자동으로 쌓여요',
                  style: TextStyle(color: Maple.brownMid, fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('만들기')),
        ],
      ),
    );
    final eok = double.tryParse(amount.text.trim());
    final name = title.text.trim();
    title.dispose();
    amount.dispose();
    if (ok != true || eok == null || eok <= 0 || name.isEmpty) return;
    g.goals.add(Goal(
      id: newId(),
      title: name,
      start: 0,
      current: 0,
      target: eok * 100000000,
      autoMetric: 'crystal',
      autoSince: g.weekKey(now),
    ));
    g.recomputeCrystals(now);
    store.commit();
  }
}

class _PricePanel extends StatefulWidget {
  const _PricePanel(this.g);

  final Game g;

  @override
  State<_PricePanel> createState() => _PricePanelState();
}

class _PricePanelState extends State<_PricePanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final store = StoreScope.of(context);
    final priced = g.bosses.where((b) => b.price > 0).length;
    final list = [...g.bosses]..sort((a, b) => b.price.compareTo(a.price));

    return MaplePanel(
      icon: '🏷️',
      title: '결정석 가격표',
      accent: const Color(0xFF6D4C41),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        MapleBadge('$priced/${g.bosses.length}'),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(_open ? Icons.expand_less : Icons.expand_more, color: Colors.white),
          onPressed: () => setState(() => _open = !_open),
        ),
      ]),
      child: !_open && g.bosses.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(10),
              child: Text('가격이 바뀌면 여기서 수정하세요 (펼치기 ▼)',
                  style: const TextStyle(color: Maple.brownMid, fontSize: 13)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 8, 14, 4),
                  child: Text(
                    '기본값은 $bossPriceTableDate 기준이에요. 패치로 바뀌면 보스를 눌러 고치세요.',
                    style: TextStyle(color: Maple.brownMid, fontSize: 13),
                  ),
                ),
                ...withDividers(list.map((b) => ListTile(
                      dense: true,
                      title: Text(b.monthly ? '${b.name} (월간)' : b.name),
                      trailing: Text(
                        b.price == 0 ? '가격 입력' : koreanNumber(b.price),
                        style: TextStyle(
                          fontSize: 15,
                          color: b.price == 0 ? Theme.of(context).colorScheme.error : Maple.brown,
                        ),
                      ),
                      onTap: () => _edit(context, store, b),
                    ))),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (d) => AlertDialog(
                              title: const Text('기본 가격표 적용'),
                              content: const Text(
                                  '$bossPriceTableDate 기준 가격으로 맞춰요.\n'
                                  '없는 보스는 추가되고, 같은 이름의 보스는 가격이 바뀌어요.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
                                FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('적용')),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          final n = g.applyDefaultBossPrices(newId);
                          g.recomputeCrystals(DateTime.now());
                          store.commit();
                          setState(() => _open = true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(n == 0 ? '이미 최신 가격이에요' : '$n개 보스 가격을 반영했어요')));
                          }
                        },
                        child: const Text('기본 가격표 적용 ($bossPriceTableDate)'),
                      ),
                      OutlinedButton(
                        onPressed: () => _edit(context, store, null),
                        child: const Text('보스 직접 추가'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _edit(BuildContext context, AppStore store, BossPrice? b) async {
    final g = widget.g;
    final name = TextEditingController(text: b?.name);
    final price = TextEditingController(text: b == null || b.price == 0 ? '' : '${b.price}');
    final result = await showDialog<String>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) {
          final v = int.tryParse(price.text) ?? 0;
          return AlertDialog(
            title: Text(b == null ? '보스 추가' : b.name),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (b == null)
                    TextField(
                      controller: name,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: '보스 이름 (예: 하드 루시드)'),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: price,
                    autofocus: b != null,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: '결정석 1개 판매가 (메소)'),
                    onChanged: (_) => setD(() {}),
                  ),
                  const SizedBox(height: 6),
                  Text(v == 0 ? '' : '= ${koreanNumber(v)} 메소', style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
            actions: [
              if (b != null)
                TextButton(onPressed: () => Navigator.pop(d, 'delete'), child: const Text('삭제')),
              TextButton(onPressed: () => Navigator.pop(d), child: const Text('취소')),
              FilledButton(onPressed: () => Navigator.pop(d, 'save'), child: const Text('저장')),
            ],
          );
        },
      ),
    );
    final p = int.tryParse(price.text) ?? 0;
    final n = name.text.trim();
    name.dispose();
    price.dispose();
    if (result == 'delete' && b != null) {
      if (g.chores.any((c) => c.bossId == b.id)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('이 보스를 쓰는 수확 일정이 있어요. 먼저 그걸 삭제해 주세요.')));
        }
        return;
      }
      g.bosses.remove(b);
    } else if (result == 'save') {
      if (b != null) {
        b.price = p;
      } else if (n.isNotEmpty) {
        g.bosses.add(BossPrice(id: newId(), name: n, price: p));
      }
    } else {
      return;
    }
    g.recomputeCrystals(DateTime.now());
    store.commit();
  }
}

/// 보스 수확 추가/수정: 보스·파티 인원·캐릭터
Future<void> showBossChoreEditor(BuildContext context, Game g, {Chore? existing}) {
  if (g.bosses.isEmpty) {
    g.applyDefaultBossPrices(newId);
    StoreScope.read(context).commit();
  }
  return showDialog(context: context, builder: (_) => _BossChoreEditor(g, existing));
}

class _BossChoreEditor extends StatefulWidget {
  const _BossChoreEditor(this.g, this.existing);

  final Game g;
  final Chore? existing;

  @override
  State<_BossChoreEditor> createState() => _BossChoreEditorState();
}

class _BossChoreEditorState extends State<_BossChoreEditor> {
  late String? _bossId = widget.existing?.bossId;
  late int _party = widget.existing?.partySize ?? 1;
  late final _char = TextEditingController(text: widget.existing?.charName);

  @override
  void dispose() {
    _char.dispose();
    super.dispose();
  }

  void _save() {
    final b = widget.g.bossById(_bossId);
    if (b == null) return;
    final store = StoreScope.read(context);
    final char = _char.text.trim().isEmpty ? null : _char.text.trim();
    final e = widget.existing;
    if (e != null) {
      e
        ..bossId = b.id
        ..title = b.name
        ..partySize = _party
        ..charName = char;
    } else {
      widget.g.chores.add(Chore(
        id: newId(),
        title: b.name,
        period: ChorePeriod.weekly,
        bossId: b.id,
        partySize: _party,
        charName: char,
      ));
    }
    widget.g.recomputeCrystals(DateTime.now());
    store.commit();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final g = widget.g;
    final bosses = [...g.bosses]..sort((a, b) => b.price.compareTo(a.price));
    final b = g.bossById(_bossId);
    final names = {for (final c in store.characters) c.name, for (final c in g.chores) ?c.charName}.toList();

    return AlertDialog(
      title: Text(widget.existing == null ? '⚔️ 보스 수확 추가' : '⚔️ 보스 수확 수정'),
      content: SizedBox(
        width: 400,
        child: bosses.isEmpty
            ? const Text('보스 가격표가 비어 있어요.')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _bossId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '보스'),
                      items: [
                        for (final x in bosses)
                          DropdownMenuItem(
                            value: x.id,
                            child: Text('${x.name}  ${x.price == 0 ? '(가격 미입력)' : koreanNumber(x.price)}'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _bossId = v),
                    ),
                    const SizedBox(height: 12),
                    const Text('파티 인원 (판매가를 나눠 가져요)'),
                    const SizedBox(height: 6),
                    SegmentedButton<int>(
                      segments: [for (var n = 1; n <= 6; n++) ButtonSegment(value: n, label: Text('$n'))],
                      selected: {_party},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => setState(() => _party = s.first),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _char,
                      decoration: const InputDecoration(labelText: '캐릭터 (선택)'),
                    ),
                    if (names.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          children: [
                            for (final n in names)
                              ActionChip(label: Text(n), onPressed: () => setState(() => _char.text = n)),
                          ],
                        ),
                      ),
                    if (b != null && b.price > 0) ...[
                      const SizedBox(height: 12),
                      Text('1회 수익: ${koreanNumber(b.price ~/ _party)} 메소', style: const TextStyle(fontSize: 17)),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () {
              g.chores.remove(widget.existing);
              g.recomputeCrystals(DateTime.now());
              store.commit();
              Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: _save, child: const Text('저장')),
      ],
    );
  }
}
