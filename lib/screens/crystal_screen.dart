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
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          CrystalBody(g),
          _GoalPanel(g, now),
        ],
      ),
    );
  }
}

/// 결정석 화면 공통 색
const _weekColor = Color(0xFFE8833A);
const _monthColor = Color(0xFF7C3AED);
const _historyColor = Color(0xFF4F8EDC);

/// 맨 위 요약: 이번 주(주간 보스) 수익 + 월간 보스는 따로 한 줄
class _WeekPanel extends StatelessWidget {
  const _WeekPanel(this.g, this.now);

  final Game g;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final boss = g.chores.where((c) => c.isBoss && !g.isMonthly(c)).toList();
    final monthly = g.chores.where(g.isMonthly).toList();
    final expected = boss.fold<int>(0, (a, c) => a + g.bossIncome(c));
    final earned = boss.where((c) => g.isChoreDone(c, now)).fold<int>(0, (a, c) => a + g.bossIncome(c));
    final start = g.periodStart(ChorePeriod.weekly, now);
    final reset = DateTime(start.year, start.month, start.day + 7, g.resetHour);
    final left = reset.difference(now);
    final mExpected = monthly.fold<int>(0, (a, c) => a + g.bossIncome(c));
    final mEarned = monthly.where((c) => g.isChoreDone(c, now)).fold<int>(0, (a, c) => a + g.bossIncome(c));

    final rate = expected == 0 ? 0.0 : earned / expected;
    const muted = Color(0xFFA9ADB8);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
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
                child: Text('이번 주 결정석 · 주간 보스',
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
          if (boss.any((c) => g.isEos(c.charName)))
            Text('에오스 결정석은 ×${g.eosRate}로 본캐 월드 메소로 환산해 합산했어요',
                style: const TextStyle(fontSize: 12, color: muted)),
          if (monthly.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Color(0xFF3A3E4A)),
            ),
            Row(
              children: [
                const Icon(Icons.nightlight_round, size: 16, color: Color(0xFFC4B5FD)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('${monthStartLabel(g, now)} 월간 보스 (따로 계산)',
                      style: const TextStyle(fontSize: 12.5, color: muted)),
                ),
                Text('${koreanNumber(mEarned)} / ${koreanNumber(mExpected)}',
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFFC4B5FD), fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// '11월'
String monthStartLabel(Game g, DateTime now) => '${g.monthStart(now).month}월';

/// 큰 버튼 두 개: 보스 고르기 · 가격표
class _ActionRow extends StatelessWidget {
  const _ActionRow(this.g);

  final Game g;

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, Color color, String title, String sub, VoidCallback onTap) => Expanded(
          child: Material(
            color: Ui.card,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          Text(sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Ui.subtext)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          tile(Icons.sports_martial_arts, _weekColor, '보스 고르기', '캐릭터별 보스 설정',
              () => showBossChoreEditor(context, g)),
          const SizedBox(width: 10),
          tile(Icons.sell_outlined, const Color(0xFF6D4C41), '가격표', '결정석 가격 수정',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => _PriceScreen(gameId: g.id)))),
        ],
      ),
    );
  }
}

/// 캐릭터별 이번 주 보스 체크 (주간 보스만)
List<Widget> _weeklyPanels(BuildContext context, Game g) {
  final boss = g.chores.where((c) => c.isBoss && !g.isMonthly(c)).toList();
  if (boss.isEmpty) {
    return [
      AppSection(
        title: '이번 주 보스 체크',
        icon: Icons.task_alt,
        accent: _weekColor,
        subtitle: '아직 고른 보스가 없어요. 위의 "보스 고르기"에서 캐릭터별로 고르세요.',
        child: const SizedBox(height: 6),
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
        title: '이번 주 보스 · ${e.key}',
        icon: Icons.task_alt,
        accent: _weekColor,
        subtitle: g.isEos(e.key)
            ? '에오스 캐릭터 (결정석 ×${g.eosRate} → 본캐 메소) · 잡으면 눌러서 체크'
            : '잡으면 눌러서 체크 · 오른쪽 "변경"으로 보스 바꾸기',
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          CountBadge('${e.value.where((c) => g.isChoreDone(c, now)).length}/${e.value.length}'),
          TextButton(
            onPressed: () => showBossChoreEditor(context, g, existing: e.value.first),
            child: const Text('변경'),
          ),
        ]),
        child: Column(
          children: [
            if (e.value.length > weeklyCrystalLimit)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
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

/// 월간 보스 (검은 마법사 등): 주간 수익·판매 한도와 따로
class _MonthlyPanel extends StatelessWidget {
  const _MonthlyPanel(this.g, this.now);

  final Game g;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final monthly = g.chores.where(g.isMonthly).toList();
    if (monthly.isEmpty) return const SizedBox.shrink();
    final earned = g.crystalMonthly[g.monthKey(now)] ?? 0;
    final past = g.crystalMonthly.entries.where((e) => e.key != g.monthKey(now) && e.value > 0).toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return AppSection(
      title: '월간 보스 · ${monthStartLabel(g, now)}',
      icon: Icons.nightlight_round,
      accent: _monthColor,
      subtitle: '매월 1일 초기화 · 주간 수익과 판매 한도(12개)에는 안 들어가요',
      trailing: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(koreanNumber(earned),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _monthColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...withDividers(monthly.map((c) => ChoreTile(game: g, chore: c))),
          if (past.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Text(
                '지난 달: ${past.take(4).map((e) => '${int.parse(e.key.substring(6))}월 ${koreanNumber(e.value)}').join(' · ')}',
                style: const TextStyle(fontSize: 12.5, color: Ui.subtext),
              ),
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
    final values = [for (final w in weeks) g.weekIncome[key(w)] ?? 0];
    final recorded = g.weekIncome.values.where((v) => v > 0).toList();
    final avg = recorded.isEmpty ? 0 : recorded.reduce((a, b) => a + b) ~/ recorded.length;
    final total = g.weekIncome.values.fold<int>(0, (a, b) => a + b);
    final month = g.weekIncome.entries
        .where((e) => e.key.startsWith(DateFormat('yyyy-MM').format(now)))
        .fold<int>(0, (a, e) => a + e.value);
    final maxV = values.fold<int>(1, math.max);

    final monthlyTotal = g.crystalMonthly.values.fold<int>(0, (a, b) => a + b);
    return AppSection(
      title: '주간 수익 기록',
      icon: Icons.bar_chart_rounded,
      accent: _historyColor,
      subtitle: '최근 12주 · 주간 보스만 (월간 보스는 따로)',
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
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
              _chip('이번 달 주간', koreanNumber(month)),
              _chip('누적', koreanNumber(total)),
              if (monthlyTotal > 0) _chip('월간 보스 누적', koreanNumber(monthlyTotal)),
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
    // 한 주 속도 = 주간 보스 + 월간 보스를 주 단위로 나눈 값
    final weekly = boss.fold<int>(0, (a, c) => a + (g.isMonthly(c) ? g.bossIncome(c) * 12 ~/ 52 : g.bossIncome(c)));

    return AppSection(
      title: '메소 목표',
      icon: Icons.flag_outlined,
      accent: const Color(0xFF9C6ADE),
      subtitle: '결정석 수익(주간 + 월간)이 자동으로 쌓여요',
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
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final store = StoreScope.of(context);
    // 목록에서 뺀 저가 보스는 숨긴다 (쓰는 중이거나 직접 추가한 건 보임)
    final used = {for (final c in g.chores) c.bossId};
    final visible = g.bosses
        .where((b) => isListedBoss(b.name) || used.contains(b.id) || !defaultBossPrices.any((e) => e.$1 == b.name))
        .toList();
    final priced = visible.where((b) => b.price > 0).length;
    final list = [...visible]..sort((a, b) => b.price.compareTo(a.price));

    return AppSection(
      title: '결정석 가격표',
      icon: Icons.sell_outlined,
      accent: const Color(0xFF6D4C41),
      subtitle: '보스를 누르면 가격을 고칠 수 있어요',
      trailing: CountBadge('$priced/${visible.length}'),
      child: !_open && g.bosses.isNotEmpty
          ? const SizedBox.shrink()
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
                      leading: BossIcon(splitBossName(b.name).$2, size: 32),
                      title: Text(b.monthly || isMonthlyBossName(b.name) ? '${b.name} (월간)' : b.name),
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

/// 결정석 가격표 화면
class _PriceScreen extends StatelessWidget {
  const _PriceScreen({required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context) {
    final g = StoreScope.of(context).gameById(gameId);
    return AppScaffold(
      title: '결정석 가격표',
      body: g == null ? const SizedBox() : ListView(padding: const EdgeInsets.only(bottom: 32), children: [_PricePanel(g)]),
    );
  }
}

/// 메이플 탭의 결정석 내용: 요약 → 버튼(보스 고르기·가격표) → 이번 주 보스 → 월간 보스 → 기록
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
        _ActionRow(g),
        ..._weeklyPanels(context, g),
        _MonthlyPanel(g, now),
        _HistoryPanel(g, now),
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
