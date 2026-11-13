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
}
