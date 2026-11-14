import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_planner/ai/ai_service.dart';
import 'package:game_planner/ai/my_voice.dart';
import 'package:game_planner/data/app_store.dart';
import 'package:game_planner/models/ai_note.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  test('AI가 고른 감정을 읽고, 모르는 감정은 보통으로', () {
    final now = DateTime(2026, 11, 14);
    expect(parseChat({'reply': '잘했어요!', 'emotion': 'happy'}, 'q', now).emotion, 'happy');
    expect(parseChat({'reply': '음', 'emotion': 'angry'}, 'q', now).emotion, 'neutral');
    expect(parseChat({'reply': '음'}, 'q', now).emotion, 'neutral');
  });

  test('감정·음성 경로는 JSON으로 오간다', () {
    final n = AiNote(id: 'chat:1', type: 'chat', title: 'q', body: 'a', createdAt: DateTime(2026, 11, 14))
        .withVoice(emotion: 'calm', audio: 'u/chat_1.mp3');
    final back = AiNote.fromJson(n.toJson());
    expect((back.emotion, back.audio), ('calm', 'u/chat_1.mp3'));
  });

  group('PC가 답에 내 목소리 붙이기', () {
    Future<(AppStore, AiService, List<String>)> setup(
        Future<String?> Function(String, String, String) maker) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore(prefs);
      final removed = <String>[];
      final ai = AiService(store, prefs,
          askOverride: (_) async => {'reply': '보스 다 잡았네요!', 'emotion': 'excited', 'actions': []},
          voiceMaker: maker,
          voiceRemover: (p) async => removed.addAll(p));
      return (store, ai, removed);
    }

    test('폰 요청에 답하면 감정에 맞는 음성 파일이 같이 저장된다', () async {
      final calls = <String>[];
      final (store, _, _) = await setup((id, text, emotion) async {
        calls.add('$id|$text|$emotion');
        return 'u/$id.mp3';
      });
      store.saveNote(AiNote(id: 'chat:9', type: 'chat', title: '이번 주 어때?', body: '', createdAt: DateTime.now(), status: 'pending'));
      await pumpEventQueue();
      final n = store.notes.single;
      expect(n.status, isNull);
      expect(n.audio, 'u/chat:9.mp3');
      expect(n.emotion, 'excited');
      expect(calls, ['chat:9|보스 다 잡았네요!|excited']);
    });

    test('음성 만들기가 실패해도 글 답은 온다, 지우면 파일도 지운다', () async {
      final (store, ai, removed) = await setup((_, _, _) async => throw MyVoiceException('서버 꺼짐'));
      final note = await ai.chat('안녕');
      expect(note.body, '보스 다 잡았네요!');
      expect(note.audio, isNull);

      store.saveNote(note.withVoice(audio: 'u/a.mp3'));
      ai.deleteChats(store.notes.where((n) => n.type == 'chat').toList());
      await pumpEventQueue();
      expect(store.notes, isEmpty);
      expect(removed, ['u/a.mp3']);
    });
  });

  test('음성 서버 클라이언트: 연결 확인 · mp3 받기 · 오류 메시지', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    late Map<String, dynamic> sent;
    final mv = MyVoice(prefs, client: MockClient((req) async {
      if (req.url.path == '/health') {
        return http.Response(jsonEncode({'engine': 'gptsovits', 'emotions': ['happy', 'neutral'], 'format': 'mp3'}), 200);
      }
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      if (sent['text'] == '') return http.Response.bytes(utf8.encode(jsonEncode({'error': 'text 가 비어 있어요'})), 400);
      return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200, headers: {'content-type': 'audio/mpeg'});
    }));
    expect(mv.url, MyVoice.defaultUrl);
    mv.url = 'http://127.0.0.1:9900/';
    expect(mv.url, 'http://127.0.0.1:9900');
    expect(await mv.health(), contains('gptsovits'));
    final clip = await mv.speak('안녕', 'happy');
    expect((clip.ext, clip.bytes.length, sent['emotion']), ('mp3', 3, 'happy'));
    expect(() => mv.speak('', 'neutral'),
        throwsA(isA<MyVoiceException>().having((e) => e.message, 'message', contains('비어'))));
  });
}
