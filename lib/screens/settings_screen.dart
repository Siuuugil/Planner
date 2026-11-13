import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/store_scope.dart';
import '../ai/ai_service.dart';
import '../ai/claude_cli.dart';
import '../maple/maple_service.dart';
import '../notify/notify_service.dart';
import '../ui/kit.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notify = NotifyScope.of(context);
    final maple = MapleScope.of(context);
    return AppScaffold(
      title: '설정',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          AppSection(
            title: '화면',
            child: SwitchListTile(
              title: const Text('게임 숨기기 (회사 모드)'),
              subtitle: const Text('홈·캘린더에서 게임 일정·숙제를 숨기고 메이플 탭도 감춰요. 이 기기에만 적용돼요.'),
              value: StoreScope.of(context).hideGames,
              onChanged: (v) => StoreScope.read(context).hideGames = v,
            ),
          ),
          if (notify == null)
            const AppSection(
              title: '알림',
              child: EmptyHint('이 기기에서는 알림을 쓸 수 없어요'),
            )
          else ...[
            _NotifyPanel(notify),
            _UpcomingPanel(notify),
          ],
          if (maple != null) _NexonKeyPanel(maple),
          if (AiScope.of(context) case final ai? when ai.supported) _AiPanel(ai),
        ],
      ),
    );
  }
}

class _NotifyPanel extends StatelessWidget {
  const _NotifyPanel(this.n);

  final NotifyService n;

  @override
  Widget build(BuildContext context) {
    final s = n.settings;
    Widget pick(String label, int value, List<int> options, String Function(int) fmt,
            void Function(int) onChanged) =>
        ListTile(
          enabled: s.enabled,
          title: Text(label),
          trailing: DropdownButton<int>(
            value: options.contains(value) ? value : options.first,
            underline: const SizedBox(),
            borderRadius: BorderRadius.circular(10),
            dropdownColor: Ui.card,
            style: const TextStyle(fontSize: 16, color: Ui.text),
            items: [for (final o in options) DropdownMenuItem(value: o, child: Text(fmt(o)))],
            onChanged: s.enabled ? (v) => onChanged(v!) : null,
          ),
        );

    return AppSection(
      title: '알림',
      child: Column(
        children: withDividers([
          SwitchListTile(
            title: const Text('알림 받기'),
            subtitle: Text(kIsWeb
                ? '웹은 이 페이지가 열려 있을 때만 알림이 와요'
                : '일정 시작 전, 마감일, 숙제 초기화 전에 알려줘요'),
            value: s.enabled,
            onChanged: (v) async {
              if (v) await n.requestPermission();
              n.update(s.copyWith(enabled: v));
            },
          ),
          pick('일정 알림', s.scheduleLeadMinutes, const [0, 5, 10, 15, 30, 60, 120],
              (m) => m == 0 ? '끄기' : m >= 60 ? '${m ~/ 60}시간 전' : '$m분 전',
              (v) => n.update(s.copyWith(scheduleLeadMinutes: v))),
          pick('마감·종일 일정 알림 시각', s.taskHour, List.generate(24, (h) => h),
              (h) => '$h시', (v) => n.update(s.copyWith(taskHour: v))),
          pick('숙제 초기화 알림', s.choreHoursBefore, const [0, 1, 2, 3, 4, 6, 12],
              (h) => h == 0 ? '끄기' : '$h시간 전', (v) => n.update(s.copyWith(choreHoursBefore: v))),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('알림 권한 허용'),
                  onPressed: () async {
                    final ok = await n.requestPermission();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? '알림이 허용됐어요' : '알림이 허용되지 않았어요. 기기/브라우저 설정을 확인해 주세요.'),
                      ));
                    }
                  },
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('테스트 알림'),
                  onPressed: n.test,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _UpcomingPanel extends StatelessWidget {
  const _UpcomingPanel(this.n);

  final NotifyService n;

  @override
  Widget build(BuildContext context) {
    final list = n.upcoming.take(8).toList();
    return AppSection(
      title: '예정된 알림',
      trailing: CountBadge('${n.upcoming.length}'),
      child: list.isEmpty
          ? const EmptyHint('7일 안에 예정된 알림이 없어요')
          : Column(
              children: withDividers(list.map((r) => ListTile(
                    dense: true,
                    title: Text(r.title),
                    subtitle: Text(
                        '${DateFormat('M/d (E) HH:mm', 'ko_KR').format(r.when)} · ${r.body}'),
                  ))),
            ),
    );
  }
}

class _NexonKeyPanel extends StatefulWidget {
  const _NexonKeyPanel(this.maple);

  final MapleService maple;

  @override
  State<_NexonKeyPanel> createState() => _NexonKeyPanelState();
}

class _NexonKeyPanelState extends State<_NexonKeyPanel> {
  late final _ctrl = TextEditingController(text: widget.maple.key);
  bool _show = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSection(
      title: '넥슨 Open API 키',
      accent: Ui.green,
      trailing: widget.maple.hasKey ? const CountBadge('연결됨') : null,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '1. openapi.nexon.com 에 넥슨 계정으로 로그인\n'
            '2. 애플리케이션 등록 → 메이플스토리 API 선택\n'
            '3. 발급된 API 키를 아래에 붙여넣기\n'
            '키는 이 기기에만 저장되고 동기화되지 않아요. 기기마다 한 번씩 넣어주세요.',
            style: TextStyle(color: Ui.subtext, fontSize: 13),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            obscureText: !_show,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'API 키',
              suffixIcon: IconButton(
                icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _show = !_show),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () {
                  widget.maple.setKey(_ctrl.text);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_ctrl.text.trim().isEmpty ? 'API 키를 지웠어요' : 'API 키를 저장했어요')),
                  );
                },
                child: const Text('저장'),
              ),
              if (widget.maple.hasKey)
                OutlinedButton(
                  onPressed: () {
                    _ctrl.clear();
                    widget.maple.setKey('');
                  },
                  child: const Text('키 지우기'),
                ),
            ],
          ),
          if (kIsWeb)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '웹 버전은 로그인한 상태에서만 캐릭터 갱신이 돼요 (Supabase 중계 서버를 거쳐요). '
                'API 키는 중계 서버에 저장되지 않아요.',
                style: TextStyle(color: Ui.subtext, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// AI (Claude Code CLI) 연결 설정 — PC 앱에서만 보인다
class _AiPanel extends StatefulWidget {
  const _AiPanel(this.ai);

  final AiService ai;

  @override
  State<_AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends State<_AiPanel> {
  late final _path = TextEditingController(text: widget.ai.executable);
  String? _status;

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    widget.ai.executable = _path.text;
    setState(() => _status = '확인 중…');
    try {
      final v = await widget.ai.checkCli();
      if (mounted) setState(() => _status = '연결됨: $v');
    } on ClaudeCliException catch (e) {
      if (mounted) setState(() => _status = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSection(
      title: 'AI (Claude Code CLI)',
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'AI 기능은 이 PC에 설치된 Claude Code로 실행돼요 (내 Claude 구독 사용, 따로 API 비용 없음).\n'
            '1. Claude Code 설치 (claude.com/claude-code)\n'
            '2. 터미널에서 claude 를 한 번 실행해 로그인\n'
            '3. 아래 "연결 확인"',
            style: TextStyle(color: Ui.subtext, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _path,
            decoration: const InputDecoration(labelText: 'claude 실행 파일 (보통 그대로 두면 돼요)'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _check, child: const Text('연결 확인')),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_status!, style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
