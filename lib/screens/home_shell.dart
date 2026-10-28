import 'package:flutter/material.dart';

import '../models/task.dart';
import '../ui/maple.dart';
import 'calendar_screen.dart';
import 'games_screen.dart';
import 'task_list_screen.dart';
import 'today_screen.dart';

/// 하단 탭(폰) / 좌측 레일(PC·태블릿)로 화면을 전환한다.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    TodayScreen(),
    CalendarScreen(),
    TaskListScreen(category: TaskCategory.work),
    TaskListScreen(category: TaskCategory.etc),
    GamesScreen(),
  ];
  static const _items = [
    (Icons.today_outlined, Icons.today, '오늘'),
    (Icons.calendar_month_outlined, Icons.calendar_month, '일정'),
    (Icons.work_outline, Icons.work, '업무'),
    (Icons.checklist_outlined, Icons.checklist, '기타'),
    (Icons.sports_esports_outlined, Icons.sports_esports, '게임'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final body = IndexedStack(index: _index, children: _pages);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('🍁', style: TextStyle(fontSize: 30)),
              ),
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
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
            Container(width: 3, color: Maple.gold),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Maple.gold, width: 3)),
        ),
        child: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final (icon, selected, label) in _items)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selected),
              label: label,
            ),
        ],
        ),
      ),
    );
  }
}
