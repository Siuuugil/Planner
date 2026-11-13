import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/app_store.dart';
import '../data/store_scope.dart';
import '../models/game.dart';
import '../ui/kit.dart';
import '../widgets/game_widgets.dart';
import '../widgets/maple_widgets.dart';
import 'boss_picker_screen.dart';

class CrystalScreen extends StatelessWidget {
  const CrystalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final g = store.crystalGame() ?? store.mapleGame();
    final now = DateTime.now();

    return AppScaffold(
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
        AppSection(
          title: '주간 보스 수확',
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '아래 "보스 선택"에서 캐릭터별로 잡는 보스를 고르세요.\n검밑솔·하세이칼·노적노칼 버튼으로 한 번에 채울 수 있어요.',
                  style: const TextStyle(color: Ui.subtext),
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
        AppSection(
          title: e.key,
          accent: const Color(0xFFE8833A),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            CountBadge('${e.value.where((c) => g.isChoreDone(c, now)).length}/${e.value.length}'),
            TextButton(
              onPressed: () => showBossChoreEditor(context, g, existing: e.value.first),
              child: const Text('보스 선택'),
            ),
          ]),
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

    final rate = expected == 0 ? 0.0 : earned / expected;
    const muted = Color(0xFFA9ADB8);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF23262F), Color(0xFF14161C)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('이번 주 결정석 수익',
                    style: TextStyle(fontSize: 13, color: muted, fontWeight: FontWeight.w600)),
              ),
              Text(
                '초기화까지 ${left.inDays}일 ${left.inHours % 24}시간',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(koreanNumber(earned),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: Colors.white)),
          Text('예상 ${koreanNumber(expected)} 메소 · ${(rate * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFFE8B86A))),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate.clamp(0, 1),
              minHeight: 8,
              color: const Color(0xFFE8B86A),
              backgroundColor: const Color(0xFF3A3E4A),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '보스 ${boss.where((c) => g.isChoreDone(c, now)).length}/${boss.length} 처치 · '
            '${weekdayNames[g.weeklyResetWeekday - 1]}요일 ${g.resetHour}시 초기화',
            style: const TextStyle(fontSize: 12.5, color: muted),
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

    return AppSection(
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
                                    ? const [Color(0xFFF0C987), Color(0xFFE0A84E)]
                                    : const [Color(0xFF4B5060), Color(0xFF2A2D36)],
                              ),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            i % 3 == 2 || i == weeks.length - 1 ? DateFormat('M/d').format(weeks[i]) : '',
                            style: const TextStyle(fontSize: 10, color: Ui.subtext),
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
          color: Ui.field,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Ui.line, width: 1.5),
        ),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$k ', style: const TextStyle(color: Ui.subtext, fontSize: 13)),
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

    return AppSection(
      title: '메소 목표',
      accent: const Color(0xFF9C6ADE),
      trailing: AddButton(tooltip: '메소 목표 추가', onPressed: () => _add(context)),
      child: goals.isEmpty
          ? const EmptyHint('예: 아케인 무기 사기 위해 50억 모으기 → 결정석 수익으로 자동 진행')
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
                  style: TextStyle(color: Ui.subtext, fontSize: 13)),
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

    return AppSection(
      title: '결정석 가격표',
      accent: const Color(0xFF6D4C41),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        CountBadge('$priced/${g.bosses.length}'),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(_open ? Icons.expand_less : Icons.expand_more, color: Ui.subtext),
          onPressed: () => setState(() => _open = !_open),
        ),
      ]),
      child: !_open && g.bosses.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(10),
              child: Text('가격이 바뀌면 여기서 수정하세요 (펼치기 ▼)',
                  style: const TextStyle(color: Ui.subtext, fontSize: 13)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 8, 14, 4),
                  child: Text(
                    '기본값은 $bossPriceTableDate 기준이에요. 패치로 바뀌면 보스를 눌러 고치세요.',
                    style: TextStyle(color: Ui.subtext, fontSize: 13),
                  ),
                ),
                ...withDividers(list.map((b) => ListTile(
                      dense: true,
                      title: Text(b.monthly ? '${b.name} (월간)' : b.name),
                      trailing: Text(
                        b.price == 0 ? '가격 입력' : koreanNumber(b.price),
                        style: TextStyle(
                          fontSize: 15,
                          color: b.price == 0 ? Theme.of(context).colorScheme.error : Ui.text,
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

/// 보스 수확 추가/수정 → 보스 선택 화면 (해당 캐릭터)
Future<void> showBossChoreEditor(BuildContext context, Game g, {Chore? existing}) {
  final store = StoreScope.read(context);
  if (!store.games.contains(g)) store.games.add(g);
  if (g.bosses.isEmpty) g.applyDefaultBossPrices(newId);
  store.commit();
  return Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => BossPickerScreen(gameId: g.id, charName: existing?.charName)),
  );
}

/// 메이플 탭의 결정석 내용 (이번 주, 캐릭터별 보스, 기록, 가격표)
class CrystalBody extends StatelessWidget {
  const CrystalBody(this.g, {super.key});

  final Game g;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeekPanel(g, now),
        ...const CrystalScreen()._routinePanels(context, g),
        _HistoryPanel(g, now),
        _PricePanel(g),
      ],
    );
  }
}

/// 메이플 탭의 메소 목표 섹션
class CrystalGoalSection extends StatelessWidget {
  const CrystalGoalSection(this.g, {super.key});

  final Game g;

  @override
  Widget build(BuildContext context) => _GoalPanel(g, DateTime.now());
}
