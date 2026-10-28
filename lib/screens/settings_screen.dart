import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../notify/notify_service.dart';
import '../ui/maple.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notify = NotifyScope.of(context);
    return MapleScaffold(
      title: '설정',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (notify == null)
            const MaplePanel(
              icon: '🔔',
              title: '알림',
              child: MapleEmpty('이 기기에서는 알림을 쓸 수 없어요'),
            )
          else ...[
            _NotifyPanel(notify),
            _UpcomingPanel(notify),
          ],
        ],
      ),
    );
  }
}

class _NotifyPanel extends StatelessWidget {
  const _NotifyPanel(this.n);

  final NotifyService n;

  @override
  Widget build(BuildContext context) {
    final s = n.settings;
    Widget pick(String label, int value, List<int> options, String Function(int) fmt,
            void Function(int) onChanged) =>
        ListTile(
          enabled: s.enabled,
          title: Text(label),
          trailing: DropdownButton<int>(
            value: options.contains(value) ? value : options.first,
            underline: const SizedBox(),
            borderRadius: BorderRadius.circular(10),
            dropdownColor: Maple.cream,
            style: const TextStyle(fontFamily: Maple.font, fontSize: 16, color: Maple.brown),
            items: [for (final o in options) DropdownMenuItem(value: o, child: Text(fmt(o)))],
            onChanged: s.enabled ? (v) => onChanged(v!) : null,
          ),
        );

    return MaplePanel(
      icon: '🔔',
      title: '알림',
      child: Column(
        children: withDividers([
          SwitchListTile(
            title: const Text('알림 받기'),
            subtitle: Text(kIsWeb
                ? '웹은 이 페이지가 열려 있을 때만 알림이 와요'
                : '일정 시작 전, 마감일, 숙제 초기화 전에 알려줘요'),
            value: s.enabled,
            onChanged: (v) async {
              if (v) await n.requestPermission();
              n.update(s.copyWith(enabled: v));
            },
          ),
          pick('일정 알림', s.scheduleLeadMinutes, const [0, 5, 10, 15, 30, 60, 120],
              (m) => m == 0 ? '끄기' : m >= 60 ? '${m ~/ 60}시간 전' : '$m분 전',
              (v) => n.update(s.copyWith(scheduleLeadMinutes: v))),
          pick('마감·종일 일정 알림 시각', s.taskHour, List.generate(24, (h) => h),
              (h) => '$h시', (v) => n.update(s.copyWith(taskHour: v))),
          pick('숙제 초기화 알림', s.choreHoursBefore, const [0, 1, 2, 3, 4, 6, 12],
              (h) => h == 0 ? '끄기' : '$h시간 전', (v) => n.update(s.copyWith(choreHoursBefore: v))),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('알림 권한 허용'),
                  onPressed: () async {
                    final ok = await n.requestPermission();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? '알림이 허용됐어요' : '알림이 허용되지 않았어요. 기기/브라우저 설정을 확인해 주세요.'),
                      ));
                    }
                  },
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('테스트 알림'),
                  onPressed: n.test,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _UpcomingPanel extends StatelessWidget {
  const _UpcomingPanel(this.n);

  final NotifyService n;

  @override
  Widget build(BuildContext context) {
    final list = n.upcoming.take(8).toList();
    return MaplePanel(
      icon: '⏰',
      title: '예정된 알림',
      trailing: MapleBadge('${n.upcoming.length}'),
      child: list.isEmpty
          ? const MapleEmpty('7일 안에 예정된 알림이 없어요')
          : Column(
              children: withDividers(list.map((r) => ListTile(
                    dense: true,
                    title: Text(r.title),
                    subtitle: Text(
                        '${DateFormat('M/d (E) HH:mm', 'ko_KR').format(r.when)} · ${r.body}'),
                  ))),
            ),
    );
  }
}
