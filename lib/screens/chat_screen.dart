import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../ai/ai_service.dart';
import '../ai/claude_cli.dart';
import '../data/store_scope.dart';
import '../models/ai_note.dart';
import '../ui/kit.dart';

/// AI와 대화. 바꾸는 일은 제안 카드로 오고, '적용'을 눌러야 반영된다.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  String? _pending;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  Future<void> _send(AiService ai) async {
    final text = _input.text.trim();
    if (text.isEmpty || ai.running != null) return;
    _input.clear();
    setState(() {
      _pending = text;
      _error = null;
    });
    _toBottom();
    try {
      await ai.chat(text);
    } on ClaudeCliException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _pending = null);
      _toBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ai = AiScope.of(context);
    final canSend = ai != null && ai.supported;
    final chats = store.notes.where((n) => n.type == 'chat').toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI와 대화'),
        actions: [
          if (chats.isNotEmpty)
            IconButton(
              tooltip: '대화 지우기',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                for (final c in chats) {
                  store.deleteNote(c);
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                if (chats.isEmpty && _pending == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      canSend
                          ? '예: "오늘 뭐부터 하면 좋아?", "다음 주 화요일 2시 치과 넣어줘", '
                              '"보고서 끝냈어", "이번 주 보스 뭐 남았어?"'
                          : '대화는 PC 앱에서 할 수 있어요. PC에서 나눈 대화가 여기에 보여요.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Ui.subtext, height: 1.6),
                    ),
                  ),
                for (final c in chats) ...[
                  _Bubble(text: c.title, mine: true),
                  _Bubble(text: c.body, mine: false, time: c.createdAt),
                  for (final a in c.actions) _ActionCard(note: c, action: a, enabled: canSend),
                ],
                if (_pending != null) ...[
                  _Bubble(text: _pending!, mine: true),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('생각하는 중…', style: TextStyle(color: Ui.subtext)),
                    ]),
                  ),
                ],
                if (_error != null) Text(_error!, style: const TextStyle(color: Ui.red)),
              ],
            ),
          ),
          if (canSend)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: const BoxDecoration(
                  color: Ui.card,
                  border: Border(top: BorderSide(color: Ui.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(ai),
                        decoration: const InputDecoration(hintText: '메시지'),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: '보내기',
                      onPressed: ai.running != null ? null : () => _send(ai),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine, this.time});

  final String text;
  final bool mine;
  final DateTime? time;

  @override
  Widget build(BuildContext context) => Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: mine ? Ui.text : Ui.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: TextStyle(color: mine ? Colors.white : Ui.text, height: 1.45)),
              if (time != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(DateFormat('M/d HH:mm').format(time!),
                      style: const TextStyle(fontSize: 11, color: Ui.subtext)),
                ),
            ],
          ),
        ),
      );
}

/// AI가 제안한 작업 카드: 적용하면 결과를 기록해 다시 적용되지 않게 한다
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.note, required this.action, required this.enabled});

  final AiNote note;
  final Map<String, dynamic> action;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final applied = action['applied'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 6, right: 40),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Ui.line),
      ),
      child: Row(
        children: [
          Icon(applied == null ? Icons.lightbulb_outline : Icons.check_circle, size: 18, color: Ui.accent),
          const SizedBox(width: 8),
          Expanded(child: Text(describeAction(action), style: const TextStyle(fontSize: 13.5))),
          if (applied != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(applied, style: const TextStyle(fontSize: 12, color: Ui.subtext)),
            )
          else
            TextButton(
              onPressed: !enabled
                  ? null
                  : () {
                      final ai = AiScope.of(context)!;
                      final store = StoreScope.read(context);
                      action['applied'] = ai.applyAction(action);
                      store.commit();
                    },
              child: const Text('적용'),
            ),
        ],
      ),
    );
  }
}
