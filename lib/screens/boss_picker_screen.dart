import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/store_scope.dart';
import '../models/game.dart';
import '../ui/kit.dart';
import '../widgets/maple_widgets.dart';

/// 보스 선택: 캐릭터별로 보스마다 난이도 칩을 눌러 고르고, 파티 인원을 정한다.
/// 프리셋(검밑솔/하세이칼/노적노칼)으로 한 번에 채울 수 있다.
class BossPickerScreen extends StatefulWidget {
  const BossPickerScreen({super.key, required this.gameId, this.charName});

  final String gameId;
  final String? charName;

  @override
  State<BossPickerScreen> createState() => _BossPickerScreenState();
}

class _BossPickerScreenState extends State<BossPickerScreen> {
  late String? _char = widget.charName;
  bool _init = false;

  static const diffColors = {
    '이지': Color(0xFF6B7280),
    '노멀': Color(0xFF0E7490),
    '하드': Color(0xFFBE185D),
    '카오스': Color(0xFF92400E),
    '익스트림': Color(0xFFB91C1C),
  };

  List<String> _charNames(AppStore store, Game g) => {
        for (final c in store.characters) c.name,
        for (final c in g.chores)
          if (c.isBoss) ?c.charName,
        ?_char,
      }.toList();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final g = store.gameById(widget.gameId);
    if (g == null) return const AppScaffold(title: '보스 선택', body: SizedBox());
    final names = _charNames(store, g);
    if (!_init) {
      _init = true;
      _char ??= names.isEmpty ? null : names.first;
    }
    final plan = g.bossPlanOf(_char);
    final weekly = plan.entries.where((e) => !_isMonthly(e.key)).toList();
    final weeklySum = weekly.fold<int>(0, (a, e) => a + g.bossIncome(e.value.$3));
    final monthlySum =
        plan.entries.where((e) => _isMonthly(e.key)).fold<int>(0, (a, e) => a + g.bossIncome(e.value.$3));
    final over = weekly.length > weeklyCrystalLimit;

    void change(void Function() f) {
      f();
      g.recomputeCrystals(DateTime.now());
      store.commit();
    }

    return AppScaffold(
      title: '보스 선택',
      body: Column(
        children: [
          // 캐릭터 고르기
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                for (final n in names)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Pill(
                      label: n,
                      selected: n == _char,
                      onTap: () => setState(() => _char = n),
                    ),
                  ),
                _Pill(label: '+ 캐릭터', selected: false, onTap: () => _addChar(context)),
              ],
            ),
          ),
          // 요약 + 프리셋
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Ui.card, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_char ?? '캐릭터 미지정',
                              style: const TextStyle(fontSize: 13, color: Ui.subtext, fontWeight: FontWeight.w700)),
                          Text('주간 ${koreanNumber(weeklySum)}', style: Ui.title(22)),
                          if (monthlySum > 0)
                            Text('월간 +${koreanNumber(monthlySum)}',
                                style: const TextStyle(fontSize: 13, color: Ui.subtext)),
                        ],
                      ),
                    ),
                    Text(
                      '${weekly.length}/$weeklyCrystalLimit',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: over ? Ui.red : Ui.text),
                    ),
                  ],
                ),
                if (over)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('주간 결정석은 캐릭터당 $weeklyCrystalLimit개까지 팔 수 있어요',
                        style: const TextStyle(fontSize: 12, color: Ui.red)),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final p in BossPreset.values) ...[
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () => change(() => g.applyBossPreset(_char, p, newId)),
                          child: Text(p.label),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    IconButton(
                      tooltip: '전체 해제',
                      onPressed: plan.isEmpty ? null : () => change(() => g.clearBosses(_char)),
                      icon: const Icon(Icons.restart_alt),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _group(context, g, plan, '검밑솔 보스', bossCatalog.where((b) => !b.grandis && !b.monthly), change),
                _group(context, g, plan, '그란디스 보스', bossCatalog.where((b) => b.grandis), change),
                _group(context, g, plan, '월간 보스', bossCatalog.where((b) => b.monthly), change),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static bool _isMonthly(String boss) => bossCatalog.any((b) => b.name == boss && b.monthly);

  Widget _group(
    BuildContext context,
    Game g,
    Map<String, (String, int, Chore)> plan,
    String title,
    Iterable<BossDef> defs,
    void Function(void Function()) change,
  ) {
    return AppSection(
      title: title,
      child: Column(
        children: [
          for (final b in defs)
            _BossRow(
              def: b,
              selected: plan[b.name]?.$1,
              party: plan[b.name]?.$2 ?? 1,
              priceOf: (d) => g.priceOf('$d ${b.name}'),
              colors: diffColors,
              onDifficulty: (d) => change(() {
                final cur = plan[b.name];
                g.setBoss(_char, b.name, cur?.$1 == d ? null : d, cur?.$2 ?? 1, newId);
              }),
              onParty: (n) => change(() => g.setBoss(_char, b.name, plan[b.name]!.$1, n, newId)),
            ),
        ],
      ),
    );
  }

  Future<void> _addChar(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('캐릭터 추가'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '캐릭터 이름'),
          onSubmitted: (v) => Navigator.pop(d, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(d, ctrl.text.trim()), child: const Text('추가')),
        ],
      ),
    );
    ctrl.dispose();
    if (name != null && name.isNotEmpty) setState(() => _char = name);
  }
}

class _BossRow extends StatelessWidget {
  const _BossRow({
    required this.def,
    required this.selected,
    required this.party,
    required this.priceOf,
    required this.colors,
    required this.onDifficulty,
    required this.onParty,
  });

  final BossDef def;
  final String? selected;
  final int party;
  final int Function(String difficulty) priceOf;
  final Map<String, Color> colors;
  final ValueChanged<String> onDifficulty;
  final ValueChanged<int> onParty;

  @override
  Widget build(BuildContext context) {
    final on = selected != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: on ? Ui.text : Ui.subtext,
                    )),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final d in def.difficulties)
                      _DiffChip(
                        label: d,
                        color: colors[d]!,
                        selected: selected == d,
                        onTap: () => onDifficulty(d),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (on) ...[
            PopupMenuButton<int>(
              tooltip: '파티 인원',
              initialValue: party,
              onSelected: onParty,
              itemBuilder: (_) => [
                for (var n = 1; n <= 6; n++) PopupMenuItem(value: n, child: Text('$n인')),
              ],
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: Ui.field, borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('$party인', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const Icon(Icons.expand_more, size: 18, color: Ui.subtext),
                ]),
              ),
            ),
            SizedBox(
              width: 76,
              child: Text(
                koreanNumber(priceOf(selected!) ~/ party),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _DiffChip extends StatelessWidget {
  const _DiffChip({required this.label, required this.color, required this.selected, required this.onTap});

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? color : Colors.transparent,
          shape: StadiumBorder(side: BorderSide(color: selected ? color : Ui.line, width: 1.5)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36, minWidth: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? Ui.text : Ui.card,
        shape: StadiumBorder(side: BorderSide(color: selected ? Ui.text : Ui.line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              widthFactor: 1,
              child: Text(label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Ui.text,
                  )),
            ),
          ),
        ),
      );
}
