import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_planner/ai/ai_service.dart';
import 'package:game_planner/data/app_store.dart';
import 'package:game_planner/data/store_scope.dart';
import 'package:game_planner/models/ai_note.dart';
import 'package:game_planner/screens/chat_screen.dart';
import 'package:game_planner/ui/kit.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  testWidgets('대화 화면: 기다리는 요청·답·오류 표시, 보내면 PC가 답한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(prefs);
    final ai = AiService(store, prefs, askOverride: (_) async => {'reply': '좋아요, 보고서부터!', 'actions': []});
    ai.serveRemote = false; // 미리 넣은 요청은 그대로 두고 화면만 확인
    final now = DateTime.now();
    store.saveNote(AiNote(id: 'chat:a', type: 'chat', title: '폰 질문', body: '', createdAt: now, status: 'working'));
    store.saveNote(AiNote(id: 'chat:b', type: 'chat', title: '실패한 질문', body: '로그인 필요', createdAt: now, status: 'error'));

    await tester.pumpWidget(StoreScope(
      store: store,
      child: AiScope(ai: ai, child: MaterialApp(theme: appTheme(), home: const ChatScreen())),
    ));
    expect(find.text('PC가 답하는 중…'), findsOneWidget);
    expect(find.textContaining('답을 못 받았어요'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '오늘 뭐 해?');
    await tester.tap(find.byTooltip('보내기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('좋아요, 보고서부터!'), findsOneWidget);
  });

  group('대화 지우기', () {
    late AppStore store;
    late AiService ai;
    final removed = <String>[];
    setUp(() async {
      removed.clear();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = AppStore(prefs);
      ai = AiService(store, prefs, supportedOverride: false, voiceRemover: (p) async => removed.addAll(p));
    });

    AiNote chat(String id, {String q = '질문', String a = '답', String? audio, String? status}) =>
        AiNote(id: id, type: 'chat', title: q, body: a, createdAt: DateTime(2026, 11, 18), audio: audio, status: status,
            actions: [{'type': 'add_task', 'title': 'x'}]);

    test('AI 답만 지우면 질문은 남고 제안·음성 파일도 지운다', () {
      store.saveNote(chat('c1', audio: 'u/c1.mp3'));
      ai.deleteChatPart(store.notes.single, question: false);
      final n = store.notes.single;
      expect((n.title, n.body, n.audio), ('질문', '', null));
      expect(n.actions, isEmpty);
      expect(removed, ['u/c1.mp3']);
    });

    test('내 말만 지우면 답은 남고, 둘 다 지우면 통째로 사라진다', () {
      store.saveNote(chat('c2'));
      ai.deleteChatPart(store.notes.single, question: true);
      expect((store.notes.single.title, store.notes.single.body), ('', '답'));
      ai.deleteChatPart(store.notes.single, question: false);
      expect(store.notes, isEmpty);
    });

    test('답을 기다리는 질문을 지우면 요청째 취소', () {
      store.saveNote(chat('c3', a: '', status: 'pending'));
      ai.deleteChatPart(store.notes.single, question: true);
      expect(store.notes, isEmpty);
    });

    testWidgets('말풍선 우클릭 → 삭제', (tester) async {
      store.saveNote(AiNote(id: 'c4', type: 'chat', title: '안녕', body: '반가워요', createdAt: DateTime.now()));
      await tester.pumpWidget(StoreScope(
        store: store,
        child: AiScope(ai: ai, child: MaterialApp(theme: appTheme(), home: const ChatScreen())),
      ));
      await tester.tap(find.text('반가워요'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI 답 삭제'));
      await tester.pumpAndSettle();
      expect(find.text('반가워요'), findsNothing);
      expect(find.text('안녕'), findsOneWidget);
      expect(store.notes.single.body, '');
    });
  });
}
