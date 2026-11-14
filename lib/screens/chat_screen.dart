import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../ai/ai_service.dart';
import '../ai/claude_cli.dart';
import '../ai/voice.dart';
import '../data/store_scope.dart';
import '../data/sync_service.dart';
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

  /// 이미 읽어줬거나 화면을 열 때 있던 답 (새로 온 답만 읽어준다)
  final Set<String> _heard = {};
  bool _primed = false;
  VoiceService? _voice;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _voice?.stopSpeaking();
    _voice?.stopListening();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _voice = VoiceScope.of(context);
    final chats = StoreScope.of(context).notes.where((n) => n.type == 'chat');
    if (!_primed) {
      _primed = true;
      _heard.addAll(chats.where((c) => !c.waiting).map((c) => c.id));
      return;
    }
    // 새로 도착한 답 → 읽어주고, 핸즈프리면 다시 듣기
    for (final c in chats) {
      if (c.waiting || c.status == 'error' || c.body.isEmpty || !_heard.add(c.id)) continue;
      _toBottom();
      _speakThenListen(c);
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  Future<void> _speakThenListen(AiNote note) async {
    final voice = _voice;
    if (voice == null || !voice.speakReplies) return;
    await voice.speak(note.body, audio: note.audio);
    if (!mounted || !voice.handsFree || !VoiceService.sttSupported) return;
    await voice.listen((t) => _sendText(t));
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    _sendText(text);
  }

  /// PC: 바로 Claude에게 묻는다. 폰·웹: 요청을 동기화로 보내고 PC 앱이 답한다.
  Future<void> _sendText(String text) async {
    final ai = AiScope.of(context);
    if (ai == null) return;
    if (!ai.supported) {
      ai.requestChat(text);
      setState(() => _error = null);
      _toBottom();
      return;
    }
    if (ai.running != null) return;
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
    final voice = VoiceScope.of(context);
    final sync = SyncScope.of(context);
    final onPc = ai != null && ai.supported;
    final signedIn = sync?.user != null;
    final canSend = ai != null && (onPc || signedIn);
    final canTalk = canSend && VoiceService.sttSupported && voice != null;
    final chats = store.notes.where((n) => n.type == 'chat').toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI와 대화'),
        actions: [
          if (voice != null)
            IconButton(
              tooltip: voice.speakReplies ? '답 읽어주기 끄기' : '답 읽어주기 켜기',
              icon: Icon(voice.speakReplies ? Icons.volume_up_rounded : Icons.volume_off_rounded),
              onPressed: () => voice.speakReplies = !voice.speakReplies,
            ),
          if (canTalk)
            IconButton(
              tooltip: voice.handsFree ? '핸즈프리 끄기' : '핸즈프리: 답을 다 읽으면 다시 듣기',
              icon: Icon(voice.handsFree ? Icons.headset_mic_rounded : Icons.headset_off_rounded),
              color: voice.handsFree ? Ui.accent : null,
              onPressed: () => voice.handsFree = !voice.handsFree,
            ),
          if (chats.isNotEmpty)
            IconButton(
              tooltip: '대화 지우기',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ai != null ? ai.deleteChats(chats) : chats.forEach(store.deleteNote),
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
                      !canSend
                          ? '폰·웹에서 대화하려면 로그인해 주세요. PC 앱이 같은 계정으로 켜져 있으면 PC의 Claude가 답해요.'
                          : '예: "오늘 뭐부터 하면 좋아?", "다음 주 화요일 2시 치과 넣어줘", '
                              '"보고서 끝냈어", "이번 주 보스 뭐 남았어?"'
                              '${onPc ? '\n\n한국어 음성 입력: 입력칸을 누르고 Win + H' : '\n\n🎤 를 누르고 말하면 돼요. 답은 PC 앱(같은 계정으로 켜져 있어야 함)이 해요.'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Ui.subtext, height: 1.6),
                    ),
                  ),
                for (final c in chats) ...[
                  _Bubble(text: c.title, mine: true),
                  if (c.waiting)
                    _Waiting(c.status == 'working' ? 'PC가 답하는 중…' : 'PC 앱이 받기를 기다리는 중…')
                  else if (c.status == 'error')
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('답을 못 받았어요: ${c.body}', style: const TextStyle(color: Ui.red)),
                    )
                  else
                    _Bubble(
                      text: c.body,
                      mine: false,
                      time: c.createdAt,
                      onSpeak: voice == null ? null : () => voice.speak(c.body, audio: c.audio),
                      myVoice: c.audio != null,
                    ),
                  for (final a in c.actions) _ActionCard(note: c, action: a, enabled: canSend),
                ],
                if (_pending != null) ...[
                  _Bubble(text: _pending!, mine: true),
                  const _Waiting('생각하는 중…'),
                ],
                if (_error != null) Text(_error!, style: const TextStyle(color: Ui.red)),
              ],
            ),
          ),
          if (voice != null && (voice.listening || voice.speaking || voice.error != null))
            _VoiceBar(voice),
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
                    if (canTalk)
                      IconButton(
                        tooltip: voice.listening ? '그만 듣기' : '말하기',
                        color: voice.listening ? Ui.red : Ui.accent,
                        icon: Icon(voice.listening ? Icons.stop_circle_rounded : Icons.mic_rounded),
                        onPressed: () => voice.listening
                            ? voice.stopListening()
                            : voice.listen((t) => _sendText(t)),
                      ),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(hintText: onPc ? '메시지 (음성: Win + H)' : '메시지'),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: '보내기',
                      onPressed: onPc && ai.running != null ? null : _send,
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

class _Waiting extends StatelessWidget {
  const _Waiting(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Ui.subtext)),
        ]),
      );
}

/// 듣는 중(알아들은 말) · 읽는 중 · 오류
class _VoiceBar extends StatelessWidget {
  const _VoiceBar(this.voice);

  final VoiceService voice;

  @override
  Widget build(BuildContext context) {
    final (icon, text, color) = voice.listening
        ? (Icons.graphic_eq_rounded, voice.partial.isEmpty ? '듣고 있어요…' : voice.partial, Ui.accent)
        : voice.speaking
            ? (Icons.volume_up_rounded, '읽는 중…', Ui.subtext)
            : (Icons.error_outline, voice.error ?? '', Ui.red);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      color: const Color(0xFFFBF7F1),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: color))),
        if (voice.speaking)
          TextButton(onPressed: voice.stopSpeaking, child: const Text('그만')),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine, this.time, this.onSpeak, this.myVoice = false});

  final String text;
  final bool mine;
  final DateTime? time;
  final VoidCallback? onSpeak;

  /// 내 목소리 음성이 붙은 답
  final bool myVoice;

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
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(DateFormat('M/d HH:mm').format(time!),
                        style: const TextStyle(fontSize: 11, color: Ui.subtext)),
                    if (onSpeak != null)
                      InkWell(
                        onTap: onSpeak,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(myVoice ? Icons.record_voice_over_outlined : Icons.volume_up_outlined,
                              size: 15, color: myVoice ? Ui.accent : Ui.subtext),
                        ),
                      ),
                  ]),
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
