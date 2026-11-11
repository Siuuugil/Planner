import 'package:flutter/material.dart';

import '../ui/kit.dart';
import 'calendar_screen.dart';
import 'maple_screen.dart';
import 'task_list_screen.dart';
import 'today_screen.dart';

/// 하단 탭(폰) / 좌측 레일(PC·태블릿): 홈 · 캘린더 · 할 일 · 메이플
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, '홈'),
    (Icons.calendar_month_outlined, Icons.calendar_month, '캘린더'),
    (Icons.checklist_rounded, Icons.checklist_rounded, '할 일'),
    (Icons.local_fire_department_outlined, Icons.local_fire_department, '메이플'),
  ];

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final pages = [
      TodayScreen(onOpenMaple: () => _go(3)),
      const CalendarScreen(),
      const TaskListScreen(),
      const MapleScreen(),
    ];
    final body = IndexedStack(index: _index, children: pages);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final (icon, selected, label) in _items)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selected),
                    label: Text(label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, color: Ui.line),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ui.line))),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          destinations: [
            for (final (icon, selected, label) in _items)
              NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label),
          ],
        ),
      ),
    );
  }
}
