import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/app_store.dart' show AppStore;
import '../data/store_scope.dart';
import '../models/schedule.dart';
import '../ui/kit.dart';
import '../widgets/schedule_widgets.dart';
import '../widgets/task_widgets.dart';

/// 캘린더: 일정 + 마감일 있는 할 일
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  List<Object> _events(AppStore store, DateTime day) => [
        ...store.schedulesOn(day).where((s) => !store.hideGames || s.gameId == null),
        ...store.tasks.where((t) => t.due != null && isSameDay(t.due, day)),
      ];

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final all = store.schedulesOn(_selected);
    final schedules = all.where((s) => s.gameId == null).toList();
    final gameSchedules = store.hideGames ? <Schedule>[] : all.where((s) => s.gameId != null).toList();
    final tasks = store.tasks.where((t) => t.due != null && isSameDay(t.due, _selected)).toList();
    const day = TextStyle(fontSize: 14, color: Ui.text);
    const weekend = TextStyle(fontSize: 14, color: Ui.red);

    return AppScaffold(
      title: '캘린더',
      floatingActionButton: FloatingActionButton(
        tooltip: '일정 추가',
        onPressed: () => showScheduleEditor(context, day: _selected),
        child: const Icon(Icons.add, size: 28),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          AppSection(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
            child: TableCalendar<Object>(
              locale: 'ko_KR',
              firstDay: DateTime(2000),
              lastDay: DateTime(2100),
              focusedDay: _focused,
              calendarFormat: _format,
              availableCalendarFormats: const {
                CalendarFormat.month: '월',
                CalendarFormat.twoWeeks: '2주',
                CalendarFormat.week: '주',
              },
              selectedDayPredicate: (d) => isSameDay(d, _selected),
              eventLoader: (d) => _events(store, d),
              onDaySelected: (selected, focused) => setState(() {
                _selected = selected;
                _focused = focused;
              }),
              onFormatChanged: (f) => setState(() => _format = f),
              onPageChanged: (f) => setState(() => _focused = f),
              calendarBuilders: CalendarBuilders<Object>(
                // 점 색: 일상·업무 주황, 게임 보라
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;
                  final dots = events.take(3).map((e) => e is Schedule && e.gameId != null ? Ui.purple : Ui.accent);
                  return Positioned(
                    bottom: 5,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final c in dots)
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  );
                },
              ),
              headerStyle: HeaderStyle(
                titleTextStyle: Ui.title(18),
                formatButtonTextStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                formatButtonDecoration: BoxDecoration(
                  border: Border.all(color: Ui.line, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                leftChevronIcon: const Icon(Icons.chevron_left, color: Ui.text),
                rightChevronIcon: const Icon(Icons.chevron_right, color: Ui.text),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(fontSize: 12, color: Ui.subtext),
                weekendStyle: TextStyle(fontSize: 12, color: Ui.red),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: day,
                weekendTextStyle: weekend,
                outsideTextStyle: const TextStyle(fontSize: 14, color: Ui.ring),
                todayDecoration: const BoxDecoration(color: Ui.accentSoft, shape: BoxShape.circle),
                todayTextStyle: const TextStyle(fontSize: 14, color: Ui.text, fontWeight: FontWeight.w700),
                selectedDecoration: const BoxDecoration(color: Ui.text, shape: BoxShape.circle),
                selectedTextStyle: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w700),
                markerDecoration: const BoxDecoration(color: Ui.accent, shape: BoxShape.circle),
                markerSize: 5,
                markersMaxCount: 3,
              ),
            ),
          ),
          AppSection(
            title: '${DateFormat('M월 d일 EEEE', 'ko_KR').format(_selected)} · 일상·업무',
            trailing: CountBadge('${schedules.length + tasks.length}'),
            child: schedules.isEmpty && tasks.isEmpty
                ? const EmptyHint('일정이 없어요')
                : Column(children: [
                    ...schedules.map((s) => ScheduleTile(schedule: s)),
                    ...tasks.map((t) => TaskTile(task: t, showCategory: true)),
                  ]),
          ),
          if (gameSchedules.isNotEmpty)
            AppSection(
              title: '게임 일정',
              accent: Ui.purple,
              trailing: CountBadge('${gameSchedules.length}'),
              child: Column(children: gameSchedules.map((s) => ScheduleTile(schedule: s)).toList()),
            ),
        ],
      ),
    );
  }
}
