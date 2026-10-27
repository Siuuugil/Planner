import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/store_scope.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('일정')),
      floatingActionButton: FloatingActionButton(
        tooltip: '일정 추가',
        onPressed: () => showScheduleEditor(context, day: _selected),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          TableCalendar(
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
            onPageChanged: (f) => _focused = f,
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      '일정이 없어요',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 88),
                    children: [for (final s in items) ScheduleTile(schedule: s)],
                  ),
          ),
        ],
      ),
    );
  }
}
