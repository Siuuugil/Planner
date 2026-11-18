import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../maple/maple_service.dart';
import '../maple/nexon_api.dart';
import '../models/maple_character.dart';
import '../ui/kit.dart';
import '../widgets/maple_widgets.dart';

/// 심볼: 레벨/만렙, 성장치, 만렙까지 남은 날 (하루에 모으는 개수는 바꿀 수 있음)
class SymbolSection extends StatelessWidget {
  const SymbolSection(this.c, {super.key});

  final MapleCharacter c;

  @override
  Widget build(BuildContext context) {
    final maple = MapleScope.of(context);
    if (maple == null) return const SizedBox.shrink();
    final open = c.symbols.where((s) => !s.isMax).toList();
    final days = [for (final s in open) maple.daysToMax(s)].whereType<int>().toList();
    final longest = days.isEmpty ? null : days.reduce((a, b) => a > b ? a : b);
    return AppSection(
      title: '심볼',
      icon: Icons.auto_awesome_motion_outlined,
      accent: Ui.maple,
      subtitle: c.symbols.isEmpty
          ? '캐릭터를 갱신하면 심볼을 불러와요'
          : open.isEmpty
              ? '모든 심볼이 만렙이에요 🎉'
              : '만렙 안 된 심볼 ${open.length}개${longest == null ? '' : ' · 전부 만렙까지 약 $longest일'}'
                  '${maple.autoSymbolChore ? ' · 일일 퀘스트는 숙제에 자동으로 들어가요' : ''}',
      trailing: IconButton(
        tooltip: '하루에 모으는 개수',
        icon: Icon(Icons.tune, size: 20, color: Ui.subtext),
        onPressed: () => _editGains(context, maple),
      ),
      child: Column(
        children: [
          for (final s in c.symbols)
            ListTile(
              dense: true,
              leading: s.icon.isEmpty ? const Icon(Icons.blur_circular) : NexonImage(s.icon, size: 36),
              title: Text(s.region, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: s.isMax
                  ? const Text('만렙')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        GaugeBar(value: s.require <= 0 ? 0 : (s.growth / s.require).clamp(0, 1).toDouble(), height: 5),
                        const SizedBox(height: 3),
                        Text('${s.growth}/${s.require} · ${_daysLabel(maple, s)}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
              trailing: Text('Lv.${s.level}/${s.maxLevel}',
                  style: TextStyle(fontWeight: FontWeight.w800, color: s.isMax ? Ui.green : Ui.text)),
            ),
        ],
      ),
    );
  }

  static String _daysLabel(MapleService m, MapleSymbol s) {
    final d = m.daysToMax(s);
    if (d == null) return '만렙까지 계산은 아케인·어센틱만 돼요';
    return '만렙까지 약 $d일 (하루 ${m.dailyGain(s)}개)';
  }

  Future<void> _editGains(BuildContext context, MapleService m) async {
    final arc = TextEditingController(text: '${m.dailyGain(MapleSymbol(name: '아케인', level: 1))}');
    final auth = TextEditingController(text: '${m.dailyGain(MapleSymbol(name: '어센틱', level: 1))}');
    var auto = m.autoSymbolChore;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: const Text('심볼 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: arc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '아케인 하루 개수 (지역당)')),
              TextField(controller: auth, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '어센틱 하루 개수 (지역당)')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('일일 퀘스트를 숙제로 자동 관리'),
                value: auto,
                onChanged: (v) => setD(() => auto = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('저장')),
          ],
        ),
      ),
    );
    if (ok == true) {
      m.setDailyGain('arcane', int.tryParse(arc.text) ?? 20);
      m.setDailyGain('auth', int.tryParse(auth.text) ?? 10);
      m.autoSymbolChore = auto;
      if (auto) m.syncSymbolChore(c);
    }
    arc.dispose();
    auth.dispose();
  }
}

/// 진행 중인 메이플 이벤트 (넥슨 공지) + 끝나는 날 자동 일정
class EventSection extends StatefulWidget {
  const EventSection({super.key});

  @override
  State<EventSection> createState() => _EventSectionState();
}

class _EventSectionState extends State<EventSection> {
  String? _error;
  bool _loading = false;
  bool _started = false;

  Future<void> _load(MapleService m, {bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await m.loadEvents(force: force);
    } on NexonApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final m = MapleScope.of(context);
    if (m == null || !m.hasKey) return const SizedBox.shrink();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(m));
    }
    final now = DateTime.now();
    final list = m.events.where((e) => e.end == null || e.end!.isAfter(now)).take(8).toList();
    return AppSection(
      title: '진행 중인 이벤트',
      icon: Icons.celebration_outlined,
      accent: Ui.purple,
      subtitle: m.autoEventSchedules ? '끝나는 날이 캘린더에 자동으로 들어가요 (게임 일정)' : '넥슨 이벤트 공지',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: m.autoEventSchedules ? '자동 일정 끄기' : '끝나는 날 자동 일정 켜기',
          icon: Icon(m.autoEventSchedules ? Icons.event_available : Icons.event_busy, size: 20, color: Ui.subtext),
          onPressed: () {
            m.autoEventSchedules = !m.autoEventSchedules;
            if (m.autoEventSchedules) m.addEventSchedules();
          },
        ),
        IconButton(
          tooltip: '새로고침',
          icon: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.refresh, size: 20, color: Ui.subtext),
          onPressed: _loading ? null : () => _load(m, force: true),
        ),
      ]),
      child: _error != null
          ? Padding(padding: const EdgeInsets.all(14), child: Text(_error!, style: TextStyle(color: Ui.red)))
          : list.isEmpty
              ? EmptyHint(_loading ? '불러오는 중…' : '진행 중인 이벤트가 없어요')
              : Column(
                  children: [
                    for (final e in list)
                      ListTile(
                        dense: true,
                        title: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(e.end == null
                            ? ''
                            : '${DateFormat('M/d (E)', 'ko_KR').format(e.end!)} 끝 · ${_dday(e.end!, now)}'),
                        trailing: Icon(Icons.open_in_new, size: 18, color: Ui.subtext),
                        onTap: e.url.isEmpty ? null : () => launchUrl(Uri.parse(e.url), mode: LaunchMode.externalApplication),
                      ),
                  ],
                ),
    );
  }

  static String _dday(DateTime end, DateTime now) {
    final d = DateTime(end.year, end.month, end.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    return d <= 0 ? '오늘 끝' : 'D-$d';
  }
}
