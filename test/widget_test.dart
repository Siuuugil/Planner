import 'package:flutter_test/flutter_test.dart';
import 'package:game_planner/data/app_store.dart';
import 'package:game_planner/main.dart';
import 'package:game_planner/models/game.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('숙제 초기화 시각', () {
    // 초기화: 매일 6시, 주간은 수요일 6시
    final game = Game(id: 'g', name: 'test');

    test('일일: 6시 이전이면 전날 6시가 기준', () {
      expect(
        game.periodStart(ChorePeriod.daily, DateTime(2026, 10, 27, 5, 59)),
        DateTime(2026, 10, 26, 6),
      );
      expect(
        game.periodStart(ChorePeriod.daily, DateTime(2026, 10, 27, 6)),
        DateTime(2026, 10, 27, 6),
      );
    });

    test('주간: 직전 수요일 6시가 기준', () {
      // 2026-10-27은 화요일 → 직전 수요일은 10/21
      expect(
        game.periodStart(ChorePeriod.weekly, DateTime(2026, 10, 27, 12)),
        DateTime(2026, 10, 21, 6),
      );
      // 수요일 5시는 아직 지난주
      expect(
        game.periodStart(ChorePeriod.weekly, DateTime(2026, 10, 28, 5)),
        DateTime(2026, 10, 21, 6),
      );
      expect(
        game.periodStart(ChorePeriod.weekly, DateTime(2026, 10, 28, 6)),
        DateTime(2026, 10, 28, 6),
      );
    });

    test('완료 후 초기화가 지나면 미완료', () {
      final chore = Chore(
        id: 'c',
        title: 'daily',
        period: ChorePeriod.daily,
        lastDone: DateTime(2026, 10, 27, 23),
      );
      expect(game.isChoreDone(chore, DateTime(2026, 10, 28, 5)), isTrue);
      expect(game.isChoreDone(chore, DateTime(2026, 10, 28, 6)), isFalse);
    });
  });

  test('목표 진행률', () {
    final goal = Goal(id: 'x', title: 'ilvl', start: 1640, current: 1660, target: 1680);
    expect(goal.progress, 0.5);
    expect(goal.achieved, isFalse);
  });

  testWidgets('앱 실행 후 탭 전환', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ko_KR');
    final store = await AppStore.open();
    await tester.pumpWidget(MyPlannerApp(store: store));

    expect(find.text('지금 할 일'), findsOneWidget);
    await tester.tap(find.text('할 일').last);
    await tester.pumpAndSettle();
    expect(find.text('할 일이 없어요'), findsOneWidget);
    await tester.tap(find.text('메이플').last);
    await tester.pumpAndSettle();
    expect(find.text('일일 숙제'), findsOneWidget);
    await tester.tap(find.text('결정석'));
    await tester.pumpAndSettle();
    expect(find.text('보스 수확 등록하기'), findsOneWidget);
  });
}
