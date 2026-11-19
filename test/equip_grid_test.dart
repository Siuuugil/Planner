import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_planner/screens/character_screen.dart';

void main() {
  testWidgets('장비창: 공식 배치 칸에 놓이고, 모르는 슬롯은 아래에 이어 붙는다', (t) async {
    final items = [
      {'item_equipment_slot': '모자', 'item_name': '앱솔 모자', 'item_icon': '', 'starforce': '22'},
      {'item_equipment_slot': '무기', 'item_name': '제네시스 무기', 'item_icon': '', 'potential_option_grade': '레전드리'},
      {'item_equipment_slot': '새 슬롯', 'item_name': '새 장비', 'item_icon': ''},
    ];
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(width: 360, child: EquipGrid(items: items))),
    ));
    expect(find.text('★22'), findsOneWidget);
    expect(find.byTooltip('앱솔 모자'), findsOneWidget);
    expect(find.byTooltip('새 장비'), findsOneWidget);
    expect(find.byTooltip('반지1'), findsOneWidget); // 빈 칸도 이름으로
    final hat = t.getTopLeft(find.byTooltip('앱솔 모자'));
    final weapon = t.getTopLeft(find.byTooltip('제네시스 무기'));
    expect(hat.dx > weapon.dx, isTrue); // 모자는 오른쪽 위, 무기는 아래 가운데
    expect(hat.dy < weapon.dy, isTrue);
    expect(t.takeException(), isNull);
  });
}
