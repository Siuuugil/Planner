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
          ? Padding(
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
              gradient: LinearGradient(
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
                Text('Lv.${c.level}  ${c.job}', style: TextStyle(fontSize: 16, color: Ui.accent)),
                Text([c.world, if (c.guild != null && c.guild!.isNotEmpty) '길드 ${c.guild}'].join(' · '),
                    style: TextStyle(color: Ui.subtext, fontSize: 13)),
                const SizedBox(height: 8),
                GaugeBar(value: c.expRate / 100, label: 'EXP ${c.expRate.toStringAsFixed(3)}%'),
                const SizedBox(height: 6),
                if (c.combatPower != null)
                  Text('⚔️ 전투력 ${koreanNumber(c.combatPower!)}', style: const TextStyle(fontSize: 16)),
                if (c.updatedAt != null)
                  Text('갱신 ${DateFormat('M/d HH:mm').format(c.updatedAt!)}',
                      style: TextStyle(color: Ui.subtext, fontSize: 12)),
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

class _EquipPanel extends StatefulWidget {
  const _EquipPanel(this.c, {required this.maple, required this.run});

  final MapleCharacter c;
  final MapleService maple;
  final Future<void> Function(Future<void> Function()) run;

  @override
  State<_EquipPanel> createState() => _EquipPanelState();
}

class _EquipPanelState extends State<_EquipPanel> {
  int? _preset;

  @override
  Widget build(BuildContext context) {
    final c = widget.c, maple = widget.maple;
    final eq = maple.equipmentCache[c.id];
    List<Map<String, dynamic>> list(String key) => (eq?[key] as List? ?? []).cast<Map<String, dynamic>>();
    final presets = [for (var n = 1; n <= 3; n++) if (list('item_equipment_preset_$n').isNotEmpty) n];
    final current = (eq?['preset_no'] as num?)?.toInt();
    final shown = _preset ?? current;
    final items = shown != null && presets.contains(shown) ? list('item_equipment_preset_$shown') : list('item_equipment');
    return AppSection(
      title: '장비',
      accent: const Color(0xFF6D4C41),
      trailing: eq == null
          ? null
          : IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '다시 불러오기',
              icon: Icon(Icons.refresh, color: Ui.subtext),
              onPressed: () => widget.run(() => maple.equipment(c, force: true)),
            ),
      child: eq == null
          ? Padding(
              padding: const EdgeInsets.all(10),
              child: Center(
                child: OutlinedButton(
                  onPressed: () => widget.run(() => maple.equipment(c)),
                  child: const Text('장비 불러오기'),
                ),
              ),
            )
          : items.isEmpty
              ? const EmptyHint('장착한 장비가 없어요')
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Column(
                    children: [
                      EquipGrid(items: items, characterImage: c.image),
                      if (presets.length > 1) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('프리셋', style: TextStyle(color: Ui.subtext, fontSize: 13)),
                            const SizedBox(width: 8),
                            for (final n in presets)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: ChoiceChip(
                                  label: Text(n == current ? '$n ✓' : '$n'),
                                  selected: n == shown,
                                  onSelected: (_) => setState(() => _preset = n),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

/// 메이플 공식 장비창 배치 (가운데 캐릭터, 왼쪽 반지·펜던트, 오른쪽 방어구, 아래 무기·장신구)
class EquipGrid extends StatelessWidget {
  const EquipGrid({super.key, required this.items, this.characterImage = ''});

  final List<Map<String, dynamic>> items;
  final String characterImage;

  static const _p = '';

  /// 칸 배치 (넥슨 API item_equipment_slot 이름). '' = 캐릭터 그림, null = 빈 칸
  static const layout = <List<String?>>[
    ['반지4', '포켓 아이템', _p, _p, _p, '모자', '망토'],
    ['반지3', '펜던트2', _p, _p, _p, '상의', '장갑'],
    ['반지2', '펜던트', _p, _p, _p, '하의', '신발'],
    ['반지1', '벨트', _p, _p, _p, '어깨장식', null],
    ['얼굴장식', '눈장식', '무기', '보조무기', '엠블렘', '귀고리', '기계 심장'],
    ['훈장', '뱃지'],
  ];

  @override
  Widget build(BuildContext context) {
    final bySlot = {for (final i in items) '${i['item_equipment_slot'] ?? ''}': i};
    final known = {for (final r in layout) ...r.whereType<String>()};
    final extra = [for (final e in bySlot.entries) if (!known.contains(e.key)) e.key];
    final rows = [
      ...layout,
      // 배치에 없는 칸(새 슬롯 등)은 맨 아래에 이어서
      for (var k = 0; k < extra.length; k += 7) extra.sublist(k, (k + 7).clamp(0, extra.length)),
    ];
    return LayoutBuilder(builder: (context, box) {
      const gap = 4.0;
      final cell = ((box.maxWidth - gap * 6) / 7).clamp(30.0, 50.0);
      final w = cell * 7 + gap * 6;
      double at(int n) => n * (cell + gap);
      return Center(
        child: SizedBox(
          width: w,
          height: at(rows.length) - gap,
          child: Stack(
            children: [
              Positioned(
                left: at(2),
                top: 0,
                width: cell * 3 + gap * 2,
                height: cell * 4 + gap * 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: Ui.soft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Ui.line, width: 1.5),
                  ),
                  child: Center(child: NexonImage(characterImage, size: cell * 3)),
                ),
              ),
              for (final (r, row) in rows.indexed)
                for (final (col, slot) in row.indexed)
                  if (slot != null && slot != _p)
                    Positioned(
                      left: at(col),
                      top: at(r),
                      width: cell,
                      height: cell,
                      child: _EquipCell(slot: slot, item: bySlot[slot]),
                    ),
            ],
          ),
        ),
      );
    });
  }
}

Color _gradeColor(String? g) => switch (g) {
      '레어' => const Color(0xFF3FA9F5),
      '에픽' => const Color(0xFF9C5FD6),
      '유니크' => const Color(0xFFF2B01E),
      '레전드리' => const Color(0xFF6BBF3B),
      _ => Ui.line,
    };

class _EquipCell extends StatelessWidget {
  const _EquipCell({required this.slot, this.item});

  final String slot;
  final Map<String, dynamic>? item;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final star = int.tryParse('${i?['starforce'] ?? 0}') ?? 0;
    final box = Container(
      decoration: BoxDecoration(
        color: Ui.field,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: i == null ? Ui.line : _gradeColor(i['potential_option_grade'] as String?), width: 2),
      ),
      child: i == null
          ? Center(
              child: Text(slot.replaceAll(' 아이템', ''),
                  textAlign: TextAlign.center, style: TextStyle(color: Ui.subtext, fontSize: 9)),
            )
          : Stack(
              children: [
                Center(child: NexonImage('${i['item_icon'] ?? ''}', size: 32)),
                if (star > 0)
                  Positioned(
                    right: 1,
                    bottom: 0,
                    child: Text('★$star',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: star >= 22 ? const Color(0xFFD84315) : Ui.subtext)),
                  ),
              ],
            ),
    );
    if (i == null) return Tooltip(message: slot, child: box);
    return Tooltip(
      message: '${i['item_name'] ?? ''}',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => showModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (_) => SafeArea(child: SingleChildScrollView(child: _ItemDetail(i))),
        ),
        child: box,
      ),
    );
  }
}

/// 장비 하나 자세히 (잠재·에디셔널)
class _ItemDetail extends StatelessWidget {
  const _ItemDetail(this.i);

  final Map<String, dynamic> i;

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Ui.field,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _gradeColor(grade), width: 2),
                ),
                child: NexonImage('${i['item_icon'] ?? ''}', size: 44),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i['item_name'] ?? ''}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    Text(
                      ['${i['item_equipment_slot'] ?? ''}', if (star > 0) '★$star'].join(' · '),
                      style: TextStyle(color: star >= 22 ? const Color(0xFFD84315) : Ui.subtext, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pot.isNotEmpty) ...[
            Text('잠재능력 · ${grade ?? ''}', style: TextStyle(color: _gradeColor(grade), fontSize: 14)),
            for (final l in pot) Text('  $l', style: const TextStyle(fontSize: 14)),
          ],
          if (add.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('에디셔널 · ${addGrade ?? ''}', style: TextStyle(color: _gradeColor(addGrade), fontSize: 14)),
            for (final l in add) Text('  $l', style: const TextStyle(fontSize: 14)),
          ],
          if (pot.isEmpty && add.isEmpty) Text('잠재능력 없음', style: TextStyle(color: Ui.subtext, fontSize: 14)),
        ],
      ),
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

/// 메이플 탭에서 쓰는 장비 섹션
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
        _EquipPanel(c, maple: maple, run: run),
      ],
    );
  }
}
