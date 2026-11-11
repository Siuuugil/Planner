import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_store.dart';
import '../data/store_scope.dart';
import '../maple/maple_service.dart';
import '../maple/nexon_api.dart';
import '../models/game.dart';
import '../models/maple_character.dart';
import '../ui/growth_chart.dart';
import '../ui/kit.dart';
import '../widgets/game_widgets.dart';
import '../widgets/maple_widgets.dart';

/// 캐릭터 상세: 정보 카드, 성장 그래프, 연결된 목표, 주요 스탯, 장비.
class CharacterScreen extends StatelessWidget {
  const CharacterScreen({super.key, required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final maple = MapleScope.of(context)!;
    final c = store.characterById(characterId);
    if (c == null) return const AppScaffold(title: '', body: SizedBox());
    final busy = maple.busy.contains(c.id);

    Future<void> run(Future<void> Function() f) async {
      try {
        await f();
      } on NexonApiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }

    return AppScaffold(
      title: c.name,
      actions: [
        IconButton(
          tooltip: '갱신',
          icon: const Icon(Icons.refresh),
          onPressed: busy ? null : () => run(() => maple.refresh(c)),
        ),
        IconButton(
          tooltip: '캐릭터 삭제',
          icon: const Icon(Icons.delete),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (d) => AlertDialog(
                title: Text('${c.name} 삭제'),
                content: const Text('성장 기록도 함께 삭제돼요. 연결된 목표는 남지만 자동 갱신이 멈춰요.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
                  FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('삭제')),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              Navigator.pop(context);
              store.deleteCharacter(c);
            }
          },
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _InfoPanel(c, busy: busy),
          _GrowthPanel(c, maple: maple, run: run),
          _GoalsPanel(c),
          _StatPanel(c, maple: maple, run: run),
          _EquipPanel(c, maple: maple, run: run),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel(this.c, {required this.busy});

  final MapleCharacter c;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return AppSection(
      title: '캐릭터 정보',
      accent: Ui.green,
      trailing: busy
          ? const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Ui.subtext)),
            )
          : null,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Ui.accentSoft, Ui.bg],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Ui.text, width: 2),
            ),
            child: NexonImage(c.image, size: 110),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: const TextStyle(fontSize: 22)),
                Text('Lv.${c.level}  ${c.job}', style: const TextStyle(fontSize: 16, color: Ui.accent)),
                Text([c.world, if (c.guild != null && c.guild!.isNotEmpty) '길드 ${c.guild}'].join(' · '),
                    style: const TextStyle(color: Ui.subtext, fontSize: 13)),
                const SizedBox(height: 8),
                GaugeBar(value: c.expRate / 100, label: 'EXP ${c.expRate.toStringAsFixed(3)}%'),
                const SizedBox(height: 6),
                if (c.combatPower != null)
                  Text('⚔️ 전투력 ${koreanNumber(c.combatPower!)}', style: const TextStyle(fontSize: 16)),
                if (c.updatedAt != null)
                  Text('갱신 ${DateFormat('M/d HH:mm').format(c.updatedAt!)}',
                      style: const TextStyle(color: Ui.subtext, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowthPanel extends StatefulWidget {
  const _GrowthPanel(this.c, {required this.maple, required this.run});

  final MapleCharacter c;
  final MapleService maple;
  final Future<void> Function(Future<void> Function()) run;

  @override
  State<_GrowthPanel> createState() => _GrowthPanelState();
}

class _GrowthPanelState extends State<_GrowthPanel> {
  bool _combat = false;
  String? _progress;

  @override
  Widget build(BuildContext context) {
    final h = widget.c.history;
    final pts = _combat ? h.where((x) => x.combatPower != null).toList() : h;
    return AppSection(
      title: '성장 기록',
      accent: const Color(0xFF4F8EDC),
      trailing: CountBadge('${h.length}일'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('레벨')),
              ButtonSegment(value: true, label: Text('전투력')),
            ],
            selected: {_combat},
            onSelectionChanged: (s) => setState(() => _combat = s.first),
          ),
          const SizedBox(height: 10),
          GrowthChart(
            dates: [for (final p in pts) p.date],
            values: [for (final p in pts) _combat ? p.combatPower!.toDouble() : p.levelProgress],
            format: _combat ? koreanNumber : (v) => 'Lv.${v.toStringAsFixed(2)}',
            color: _combat ? const Color(0xFFE53935) : Ui.accent,
          ),
          if (pts.length >= 2) _summary(pts),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.history),
            label: Text(_progress ?? '지난 14일 기록 불러오기'),
            onPressed: _progress != null
                ? null
                : () => widget.run(() async {
                      try {
                        final n = await widget.maple.backfill(widget.c, onProgress: (d, t) {
                          if (mounted) setState(() => _progress = '불러오는 중 $d/$t');
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(n == 0 ? '새로 불러온 기록이 없어요' : '$n일치 기록을 불러왔어요')));
                        }
                      } finally {
                        if (mounted) setState(() => _progress = null);
                      }
                    }),
          ),
        ],
      ),
    );
  }

  Widget _summary(List<MapleSnapshot> pts) {
    final a = pts.first, b = pts.last;
    final days = DateTime.parse(b.date).difference(DateTime.parse(a.date)).inDays;
    final text = _combat
        ? '$days일 동안 전투력 +${koreanNumber(b.combatPower! - a.combatPower!)}'
        : '$days일 동안 +${(b.levelProgress - a.levelProgress).toStringAsFixed(2)} 레벨';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
    );
  }
}

class _GoalsPanel extends StatelessWidget {
  const _GoalsPanel(this.c);

  final MapleCharacter c;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final linked = [
      for (final g in store.games)
        for (final goal in g.goals)
          if (goal.autoCharId == c.id) (g, goal),
    ];
    return AppSection(
      title: '스펙업 목표',
      accent: const Color(0xFF9C6ADE),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (linked.isEmpty)
            const EmptyHint('목표를 만들면 현재값이 캐릭터 정보로 자동 갱신돼요')
          else
            ...withDividers(linked.map((e) => GoalTile(game: e.$1, goal: e.$2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Text('🎯'),
                  label: const Text('레벨 목표'),
                  onPressed: () => _addGoal(context, store, 'level'),
                ),
                OutlinedButton.icon(
                  icon: const Text('⚔️'),
                  label: const Text('전투력 목표'),
                  onPressed: c.combatPower == null ? null : () => _addGoal(context, store, 'combat'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addGoal(BuildContext context, AppStore store, String metric) async {
    final isLevel = metric == 'level';
    final now = isLevel ? c.levelProgress : c.combatPower!.toDouble();
    final ctrl = TextEditingController(
      text: isLevel ? '${c.level + 1}' : '${(now * 1.1).round()}',
    );
    DateTime? deadline;
    final target = await showDialog<double>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text(isLevel ? '🎯 레벨 목표' : '⚔️ 전투력 목표'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('현재 ${isLevel ? 'Lv.${now.toStringAsFixed(2)}' : koreanNumber(now)}'),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: isLevel ? '목표 레벨' : '목표 전투력 (숫자)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.flag_outlined),
                  label: Text(deadline == null
                      ? '마감일 (선택)'
                      : DateFormat('yyyy.M.d (E)', 'ko_KR').format(deadline!)),
                  onPressed: () async {
                    final p = await showDatePicker(
                      context: d,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (p != null) setD(() => deadline = p);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('취소')),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(ctrl.text.replaceAll(',', '').trim());
                if (v != null && v > now) Navigator.pop(d, v);
              },
              child: const Text('만들기'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (target == null) return;
    final game = store.mapleGame();
    game.goals.add(Goal(
      id: newId(),
      title: isLevel ? '${c.name} 레벨' : '${c.name} 전투력',
      start: double.parse(now.toStringAsFixed(2)),
      current: double.parse(now.toStringAsFixed(2)),
      target: target,
      deadline: deadline,
      autoCharId: c.id,
      autoMetric: metric,
    ));
    store.commit();
  }
}

class _StatPanel extends StatefulWidget {
  const _StatPanel(this.c, {required this.maple, required this.run});

  final MapleCharacter c;
  final MapleService maple;
  final Future<void> Function(Future<void> Function()) run;

  @override
  State<_StatPanel> createState() => _StatPanelState();
}

class _StatPanelState extends State<_StatPanel> {
  bool _all = false;

  static const _main = [
    '전투력', '최대 HP', 'STR', 'DEX', 'INT', 'LUK', '공격력', '마력',
    '보스 몬스터 데미지', '방어율 무시', '데미지', '최종 데미지', '크리티컬 확률', '크리티컬 데미지',
    '스타포스', '아케인포스', '어센틱포스', '재사용 대기시간 감소 (%)', '아이템 드롭률', '메소 획득량',
  ];

  @override
  Widget build(BuildContext context) {
    final stat = widget.maple.statCache[widget.c.id];
    final list = [
      for (final s in (stat?['final_stat'] as List? ?? []))
        (s['stat_name'] as String, '${s['stat_value']}'),
    ];
    final shown = _all ? list : list.where((e) => _main.contains(e.$1)).toList();
    return AppSection(
      title: '스탯',
      accent: const Color(0xFFE8833A),
      trailing: stat == null
          ? null
          : IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: _all ? '주요 스탯만' : '전체 보기',
              icon: Icon(_all ? Icons.unfold_less : Icons.unfold_more, color: Ui.subtext),
              onPressed: () => setState(() => _all = !_all),
            ),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: stat == null
          ? Center(
              child: OutlinedButton(
                onPressed: () => widget.run(() => widget.maple.stat(widget.c)),
                child: const Text('스탯 불러오기'),
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final (k, v) in shown)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Ui.field,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Ui.line, width: 1.5),
                    ),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: '$k ', style: const TextStyle(color: Ui.subtext, fontSize: 13)),
                      TextSpan(
                        text: k == '전투력' ? koreanNumber(num.tryParse(v) ?? 0) : _fmt(v),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ])),
                  ),
              ],
            ),
    );
  }

  static String _fmt(String v) {
    final n = num.tryParse(v);
    if (n == null) return v;
    return n is int || n == n.roundToDouble()
        ? NumberFormat.decimalPattern('ko_KR').format(n)
        : v;
  }
}

class _EquipPanel extends StatelessWidget {
  const _EquipPanel(this.c, {required this.maple, required this.run});

  final MapleCharacter c;
  final MapleService maple;
  final Future<void> Function(Future<void> Function()) run;

  @override
  Widget build(BuildContext context) {
    final eq = maple.equipmentCache[c.id];
    final items = (eq?['item_equipment'] as List? ?? []).cast<Map<String, dynamic>>();
    return AppSection(
      title: '장비',
      accent: const Color(0xFF6D4C41),
      trailing: eq == null
          ? null
          : IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '다시 불러오기',
              icon: const Icon(Icons.refresh, color: Ui.subtext),
              onPressed: () => run(() => maple.equipment(c, force: true)),
            ),
      child: eq == null
          ? Padding(
              padding: const EdgeInsets.all(10),
              child: Center(
                child: OutlinedButton(
                  onPressed: () => run(() => maple.equipment(c)),
                  child: const Text('장비 불러오기'),
                ),
              ),
            )
          : items.isEmpty
              ? const EmptyHint('장착한 장비가 없어요')
              : Column(children: withDividers(items.map((i) => _ItemTile(i)))),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile(this.i);

  final Map<String, dynamic> i;

  static Color gradeColor(String? g) => switch (g) {
        '레어' => const Color(0xFF3FA9F5),
        '에픽' => const Color(0xFF9C5FD6),
        '유니크' => const Color(0xFFF2B01E),
        '레전드리' => const Color(0xFF6BBF3B),
        _ => Ui.line,
      };

  @override
  Widget build(BuildContext context) {
    final star = int.tryParse('${i['starforce'] ?? 0}') ?? 0;
    final grade = i['potential_option_grade'] as String?;
    final addGrade = i['additional_potential_option_grade'] as String?;
    List<String> lines(String prefix) => [
          for (var k = 1; k <= 3; k++)
            if ((i['${prefix}_$k'] as String?)?.isNotEmpty == true) i['${prefix}_$k'] as String,
        ];
    final pot = lines('potential_option');
    final add = lines('additional_potential_option');

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Ui.field,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: gradeColor(grade), width: 2),
        ),
        child: NexonImage('${i['item_icon'] ?? ''}', size: 36),
      ),
      title: Text('${i['item_name'] ?? ''}', style: const TextStyle(fontSize: 15)),
      subtitle: Text(
        [
          '${i['item_equipment_slot'] ?? ''}',
          if (star > 0) '★$star',
          ?grade,
        ].join(' · '),
        style: TextStyle(color: star >= 22 ? const Color(0xFFD84315) : Ui.subtext, fontSize: 12),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pot.isNotEmpty) ...[
          Text('잠재능력 · ${grade ?? ''}', style: TextStyle(color: gradeColor(grade), fontSize: 13)),
          for (final l in pot) Text('  $l', style: const TextStyle(fontSize: 13)),
        ],
        if (add.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('에디셔널 · ${addGrade ?? ''}', style: TextStyle(color: gradeColor(addGrade), fontSize: 13)),
          for (final l in add) Text('  $l', style: const TextStyle(fontSize: 13)),
        ],
        if (pot.isEmpty && add.isEmpty)
          const Text('잠재능력 없음', style: TextStyle(color: Ui.subtext, fontSize: 13)),
      ],
    );
  }
}

/// 넥슨 API 호출 오류를 스낵바로 보여준다.
Future<void> runNexon(BuildContext context, Future<void> Function() f) async {
  try {
    await f();
  } on NexonApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// 메이플 탭에서 쓰는 성장 기록 섹션
class CharacterGrowthSection extends StatelessWidget {
  const CharacterGrowthSection(this.c, {super.key});

  final MapleCharacter c;

  @override
  Widget build(BuildContext context) =>
      _GrowthPanel(c, maple: MapleScope.of(context)!, run: (f) => runNexon(context, f));
}

/// 메이플 탭에서 쓰는 캐릭터 연결 목표 섹션
class CharacterGoalsSection extends StatelessWidget {
  const CharacterGoalsSection(this.c, {super.key});

  final MapleCharacter c;

  @override
  Widget build(BuildContext context) => _GoalsPanel(c);
}

/// 메이플 탭에서 쓰는 스탯 + 장비 섹션
class CharacterGearSection extends StatelessWidget {
  const CharacterGearSection(this.c, {super.key});

  final MapleCharacter c;

  @override
  Widget build(BuildContext context) {
    final maple = MapleScope.of(context)!;
    Future<void> run(Future<void> Function() f) => runNexon(context, f);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatPanel(c, maple: maple, run: run),
        _EquipPanel(c, maple: maple, run: run),
      ],
    );
  }
}
