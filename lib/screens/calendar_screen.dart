import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/store_scope.dart';
import '../ui/maple.dart';
import '../widgets/schedule_widgets.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final items = store.schedulesOn(_selected);
    const dayText = TextStyle(fontFamily: Maple.font, color: Maple.brown);

    return MapleScaffold(
      title: '일정',
      floatingActionButton: FloatingActionButton(
        tooltip: '일정 추가',
        onPressed: () => showScheduleEditor(context, day: _selected),
        child: const Icon(Icons.add, size: 30),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          MaplePanel(
            icon: '🗓️',
            title: DateFormat('yyyy년 M월', 'ko_KR').format(_focused),
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: TableCalendar(
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
              eventLoader: store.schedulesOn,
              onDaySelected: (selected, focused) => setState(() {
                _selected = selected;
                _focused = focused;
              }),
              onFormatChanged: (f) => setState(() => _format = f),
              onPageChanged: (f) => setState(() => _focused = f),
              headerStyle: HeaderStyle(
                titleTextStyle: dayText.copyWith(fontSize: 17),
                formatButtonTextStyle: dayText.copyWith(fontSize: 13),
                formatButtonDecoration: BoxDecoration(
                  color: Maple.creamLight,
                  border: Border.all(color: Maple.brownMid, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                leftChevronIcon: const Icon(Icons.chevron_left, color: Maple.brown),
                rightChevronIcon: const Icon(Icons.chevron_right, color: Maple.brown),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: dayText.copyWith(fontSize: 13, color: Maple.brownMid),
                weekendStyle: dayText.copyWith(fontSize: 13, color: const Color(0xFFD84315)),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: dayText,
                weekendTextStyle: dayText.copyWith(color: const Color(0xFFD84315)),
                outsideTextStyle: dayText.copyWith(color: Maple.brownSoft),
                todayDecoration: BoxDecoration(
                  color: Maple.gold.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Maple.brownMid, width: 1.5),
                ),
                todayTextStyle: dayText,
                selectedDecoration: BoxDecoration(
                  color: Maple.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Maple.brown, width: 2),
                ),
                selectedTextStyle: dayText.copyWith(
                  color: Colors.white,
                  shadows: Maple.outline(Maple.brown, 1),
                ),
                markerDecoration: const BoxDecoration(color: Maple.leaf, shape: BoxShape.circle),
                markersMaxCount: 3,
              ),
            ),
          ),
          MaplePanel(
            icon: '📅',
            title: DateFormat('M월 d일 (E)', 'ko_KR').format(_selected),
            trailing: MapleBadge('${items.length}'),
            child: items.isEmpty
                ? const MapleEmpty('일정이 없어요')
                : Column(children: withDividers(items.map((s) => ScheduleTile(schedule: s)))),
          ),
        ],
      ),
    );
  }
}
