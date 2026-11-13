import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../ai/ai_service.dart';
import '../ai/claude_cli.dart';
import '../data/store_scope.dart';
import '../models/ai_note.dart';
import '../ui/kit.dart';
import 'chat_screen.dart';

/// AI 화면: 빠른 입력 (이후 오늘 계획·코치·리포트·대화가 여기에 붙는다)
class AiScreen extends StatelessWidget {
  const AiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ai = AiScope.of(context);
    return AppScaffold(
      title: 'AI 비서',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (ai == null || !ai.supported)
            const AppSection(
              child: EmptyHint('AI 기능은 PC(Windows) 앱에서 내 컴퓨터의 Claude Code로 실행돼요. '
                  'PC에서 만든 계획·리포트는 여기에도 동기화돼서 보여요.'),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: StatCard(
              label: 'AI와 대화',
              value: '무엇이든 물어보세요',
              caption: '"다음 주 화요일 2시 치과 넣어줘" 처럼 말하면 확인 후 추가해 줘요',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
            ),
          ),
          _PlanSection(ai: ai != null && ai.supported ? ai : null),
          _ReportSection(ai: ai != null && ai.supported ? ai : null),
          if (!StoreScope.of(context).hideGames) _CoachSection(ai: ai != null && ai.supported ? ai : null),
          if (ai != null && ai.supported) ...[
            if (ai.running != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text('AI가 "${ai.running}" 하는 중… (보통 10~30초)', style: const TextStyle(color: Ui.subtext)),
                ]),
              ),
            _QuickAddSection(ai),
          ],
        ],
      ),
    );
  }
}

/// 자연어 → 일정/할 일 미리보기 → 저장
class _QuickAddSection extends StatefulWidget {
  const _QuickAddSection(this.ai);

  final AiService ai;

  @override
  State<_QuickAddSection> createState() => _QuickAddSectionState();
}

class _QuickAddSectionState extends State<_QuickAddSection> {
  final _text = TextEditingController();
  List<QuickItem>? _items;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_text.text.trim().isEmpty) return;
    setState(() {
      _error = null;
      _items = null;
    });
    try {
      final items = await widget.ai.quickAdd(_text.text);
      if (mounted) setState(() => _items = items);
    } on ClaudeCliException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.ai.running != null;
    return AppSection(
      title: '자연어로 빠르게 추가',
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _text,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '예: 내일 3시 팀회의, 목요일까지 보고서, 토요일 밤 9시 하드 윌 2인',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: busy ? null : _run,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('AI로 정리하기'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: const TextStyle(color: Ui.red)),
            ),
          if (_items != null) ...[
            const SizedBox(height: 12),
            if (_items!.isEmpty) const Text('추가할 항목을 찾지 못했어요.', style: TextStyle(color: Ui.subtext)),
            for (final it in _items!)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: it.selected,
                onChanged: (v) => setState(() => it.selected = v ?? false),
                title: Text(it.title),
                subtitle: Text([it.describe(), if (it.memo.isNotEmpty) it.memo].join(' · '),
                    style: TextStyle(color: it.game ? Ui.purple : Ui.subtext)),
              ),
            if (_items!.isNotEmpty)
              FilledButton(
                onPressed: () {
                  final n = widget.ai.applyQuickItems(_items!);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n개를 추가했어요')));
                  setState(() {
                    _items = null;
                    _text.clear();
                  });
                },
                child: Text('선택한 ${_items!.where((i) => i.selected).length}개 추가'),
              ),
          ],
        ],
      ),
    );
  }
}

String todayKey() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

/// 오늘 계획: 보기(모든 기기) + 만들기(PC)
class _PlanSection extends StatefulWidget {
  const _PlanSection({required this.ai});

  final AiService? ai;

  @override
  State<_PlanSection> createState() => _PlanSectionState();
}

class _PlanSectionState extends State<_PlanSection> {
  String? _error;

  Future<void> _make() async {
    setState(() => _error = null);
    try {
      await widget.ai!.planToday();
    } on ClaudeCliException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final plan = store.notes.where((n) => n.type == 'plan' && n.date == todayKey()).firstOrNull;
    final busy = widget.ai?.running != null;
    return AppSection(
      title: '오늘 계획',
      trailing: widget.ai == null
          ? null
          : TextButton.icon(
              onPressed: busy ? null : _make,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(plan == null ? '계획 짜기' : '다시 짜기'),
            ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) Text(_error!, style: const TextStyle(color: Ui.red)),
          if (plan == null)
            Text(
              widget.ai == null
                  ? '오늘 계획이 아직 없어요. PC 앱에서 만들면 여기에 보여요.'
                  : '오늘 일정·할 일·숙제를 보고 지금부터 시간표를 짜 줘요${store.hideGames ? ' (회사 모드라 게임은 빼고)' : ''}.',
              style: const TextStyle(color: Ui.subtext),
            )
          else
            PlanView(plan),
        ],
      ),
    );
  }
}

/// 계획 시간표
class PlanView extends StatelessWidget {
  const PlanView(this.plan, {super.key});

  final AiNote plan;

  static const colors = {'work': Ui.blue, 'personal': Ui.accent, 'game': Ui.purple, 'break': Ui.green};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (plan.body.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(plan.body, style: const TextStyle(height: 1.5)),
          ),
        for (final b in plan.blocks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 92,
                  child: Text('${b.start}–${b.end}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Ui.subtext)),
                ),
                Container(
                  width: 4,
                  height: 36,
                  margin: const EdgeInsets.only(right: 10, top: 2),
                  decoration: BoxDecoration(
                    color: colors[b.kind] ?? Ui.ring,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      if (b.note.isNotEmpty)
                        Text(b.note, style: const TextStyle(fontSize: 12.5, color: Ui.subtext)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (plan.bullets.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final t in plan.bullets)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('· $t', style: const TextStyle(fontSize: 13, color: Ui.subtext)),
            ),
        ],
      ],
    );
  }
}

/// AI 노트 한 건 (리포트·코치 답변)
class NoteCard extends StatelessWidget {
  const NoteCard(this.note, {super.key, this.showTitle = true, this.bulletsTitle});

  final AiNote note;
  final bool showTitle;
  final String? bulletsTitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTitle)
            Text(note.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          Text(DateFormat('M/d HH:mm').format(note.createdAt),
              style: const TextStyle(fontSize: 11.5, color: Ui.subtext)),
          const SizedBox(height: 6),
          Text(note.body, style: const TextStyle(height: 1.5)),
          if (note.bullets.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (bulletsTitle != null)
              Text(bulletsTitle!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            for (final b in note.bullets)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('→ $b', style: const TextStyle(fontSize: 13.5)),
              ),
          ],
        ],
      );
}

class _ReportSection extends StatefulWidget {
  const _ReportSection({required this.ai});

  final AiService? ai;

  @override
  State<_ReportSection> createState() => _ReportSectionState();
}

class _ReportSectionState extends State<_ReportSection> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final report = store.notes.where((n) => n.type == 'report').firstOrNull;
    return AppSection(
      title: '주간 리포트',
      trailing: widget.ai == null
          ? null
          : TextButton.icon(
              onPressed: widget.ai!.running != null
                  ? null
                  : () async {
                      setState(() => _error = null);
                      try {
                        await widget.ai!.weeklyReport();
                      } on ClaudeCliException catch (e) {
                        if (mounted) setState(() => _error = e.message);
                      }
                    },
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('지난 7일 정리'),
            ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) Text(_error!, style: const TextStyle(color: Ui.red)),
          if (report == null)
            const Text('지난 7일 동안 한 일과 결정석·성장을 돌아보고 다음 주 할 일을 정리해 줘요.',
                style: TextStyle(color: Ui.subtext))
          else
            NoteCard(report, bulletsTitle: '다음 주에 할 것'),
        ],
      ),
    );
  }
}

class _CoachSection extends StatefulWidget {
  const _CoachSection({required this.ai});

  final AiService? ai;

  @override
  State<_CoachSection> createState() => _CoachSectionState();
}

class _CoachSectionState extends State<_CoachSection> {
  final _q = TextEditingController();
  String? _error;

  static const presets = ['다음 레벨업 언제쯤?', '이번 주 결정석 더 벌려면?', '메소 목표 언제 달성해?', '지금 제일 먼저 할 스펙업은?'];

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _ask(String q) async {
    if (q.trim().isEmpty) return;
    setState(() => _error = null);
    try {
      await widget.ai!.coach(q.trim());
      _q.clear();
    } on ClaudeCliException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final answers = store.notes.where((n) => n.type == 'coach').take(5).toList();
    final busy = widget.ai?.running != null;
    return AppSection(
      title: '메이플 코치',
      accent: Ui.purple,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.ai != null) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in presets)
                  ActionChip(label: Text(p), onPressed: busy ? null : () => _ask(p)),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _q,
              enabled: !busy,
              onSubmitted: _ask,
              decoration: InputDecoration(
                hintText: '캐릭터·결정석·목표에 대해 물어보세요',
                suffixIcon: IconButton(
                  tooltip: '질문',
                  icon: const Icon(Icons.arrow_upward_rounded),
                  onPressed: busy ? null : () => _ask(_q.text),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Ui.red)),
              ),
            const SizedBox(height: 12),
          ],
          if (answers.isEmpty)
            const Text('레벨업 예상일, 결정석, 메소 목표 같은 걸 앱이 계산한 숫자로 답해 줘요.',
                style: TextStyle(color: Ui.subtext))
          else
            for (final a in answers)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: NoteCard(a),
              ),
        ],
      ),
    );
  }
}
