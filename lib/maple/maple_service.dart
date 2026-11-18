import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_store.dart';
import '../models/game.dart';
import '../models/maple_character.dart';
import '../models/schedule.dart';
import 'nexon_api.dart';

/// 검색 결과 미리보기 (아직 저장 안 함)
class MapleLookup {
  MapleLookup(this.character, this.stat);

  final MapleCharacter character;
  final Map<String, dynamic> stat;
}

/// 넥슨 API 키 관리 + 캐릭터 검색·갱신·과거 기록 불러오기.
/// API 키는 이 기기에만 저장한다 (동기화 안 함).
class MapleService extends ChangeNotifier {
  MapleService(this.store, this._prefs, {this.proxy}) {
    _key = _prefs.getString(_prefKey) ?? '';
  }

  static const _prefKey = 'nexon_api_key';

  /// 웹: 로그인 상태면 중계 서버를 돌려준다 (아니면 null → 넥슨 직접 호출)
  final NexonProxy? Function()? proxy;
  final AppStore store;
  final SharedPreferences _prefs;
  late String _key;

  /// 캐릭터별 진행 중 작업 (중복 갱신 방지·로딩 표시)
  final Set<String> busy = {};

  /// 장비는 크고 자주 안 바뀌므로 저장하지 않고 화면에서만 캐시
  final Map<String, Map<String, dynamic>> equipmentCache = {};
  final Map<String, Map<String, dynamic>> statCache = {};

  bool get hasKey => _key.isNotEmpty;
  String get key => _key;

  static Future<MapleService> open(AppStore store, {NexonProxy? Function()? proxy}) async =>
      MapleService(store, await SharedPreferences.getInstance(), proxy: proxy);

  void setKey(String k) {
    _key = k.trim();
    _prefs.setString(_prefKey, _key);
    notifyListeners();
  }

  NexonApi _api() {
    if (!hasKey) throw NexonApiException('설정에서 넥슨 Open API 키를 먼저 입력해 주세요.');
    return NexonApi(_key, proxy: proxy?.call());
  }

  /// 한국 시간 기준 날짜 'yyyy-MM-dd'
  static String kstDate(DateTime t) =>
      DateFormat('yyyy-MM-dd').format(t.toUtc().add(const Duration(hours: 9)));

  MapleCharacter _fromBasic(String id, String ocid, Map<String, dynamic> b, int? combat) =>
      MapleCharacter(
        id: id,
        name: b['character_name'] as String? ?? '',
        ocid: ocid,
        world: b['world_name'] as String? ?? '',
        job: b['character_class'] as String? ?? '',
        level: (b['character_level'] as num?)?.toInt() ?? 0,
        expRate: NexonApi.expRate(b),
        combatPower: combat,
        image: b['character_image'] as String? ?? '',
        guild: b['character_guild_name'] as String?,
        updatedAt: DateTime.now(),
      );

  /// 닉네임으로 찾기 (저장 안 함)
  Future<MapleLookup> search(String name) async {
    final api = _api();
    final ocid = await api.ocid(name.trim());
    final results = await Future.wait([api.basic(ocid), api.stat(ocid)]);
    final c = _fromBasic(newId(), ocid, results[0], NexonApi.combatPower(results[1]));
    c.putSnapshot(MapleSnapshot(
      date: kstDate(DateTime.now()),
      level: c.level,
      expRate: c.expRate,
      combatPower: c.combatPower,
    ));
    return MapleLookup(c, results[1]);
  }

  void add(MapleLookup l) {
    statCache[l.character.id] = l.stat;
    store.upsertCharacter(l.character);
  }

  /// 최신 정보로 갱신하고 오늘 기록을 남긴다.
  Future<void> refresh(MapleCharacter c) async {
    if (busy.contains(c.id)) return;
    busy.add(c.id);
    notifyListeners();
    try {
      final api = _api();
      final results = await Future.wait([api.basic(c.ocid), api.stat(c.ocid)]);
      statCache[c.id] = results[1];
      final fresh = _fromBasic(c.id, c.ocid, results[0], NexonApi.combatPower(results[1]));
      fresh.history.addAll(c.history);
      // 심볼 (실패해도 갱신은 계속, 이전 값 유지)
      try {
        final sym = await api.symbolEquipment(c.ocid);
        fresh.symbols.addAll([
          for (final s in (sym['symbol'] as List? ?? [])) if (s is Map) MapleSymbol.fromNexon(s.cast<String, dynamic>()),
        ]);
      } catch (_) {
        fresh.symbols.addAll(c.symbols);
      }
      fresh.putSnapshot(MapleSnapshot(
        date: kstDate(DateTime.now()),
        level: fresh.level,
        expRate: fresh.expRate,
        combatPower: fresh.combatPower,
      ));
      store.upsertCharacter(fresh);
      syncSymbolChore(fresh);
    } finally {
      busy.remove(c.id);
      notifyListeners();
    }
  }

  // ── 심볼 ──

  /// 심볼 일일 퀘스트를 숙제로 자동 관리 (만렙 아닌 심볼이 있으면 숙제를 두고, 다 만렙이면 뺌)
  bool get autoSymbolChore => _prefs.getBool('auto_symbol_chore') ?? true;
  set autoSymbolChore(bool v) {
    _prefs.setBool('auto_symbol_chore', v);
    notifyListeners();
  }

  /// 하루에 모으는 심볼 개수 (지역 하나당, 기본: 아케인 20 · 어센틱 10 · 그랜드 어센틱 10)
  int dailyGain(MapleSymbol s) =>
      _prefs.getInt(s.isArcane ? 'sym_daily_arcane' : s.isGrand ? 'sym_daily_grand' : 'sym_daily_auth') ??
      (s.isArcane ? 20 : 10);
  void setDailyGain(String kind, int v) {
    _prefs.setInt('sym_daily_$kind', v);
    notifyListeners();
  }

  /// 만렙까지 남은 날 (공식을 모르면 null)
  int? daysToMax(MapleSymbol s) {
    final left = s.toMax;
    if (left == null) return null;
    final g = dailyGain(s);
    return g <= 0 ? null : (left / g).ceil();
  }

  /// 캐릭터의 '심볼 일일 퀘스트' 숙제 맞추기 (id 가 정해져 있어 여러 기기에서 겹치지 않음)
  void syncSymbolChore(MapleCharacter c) {
    if (!autoSymbolChore || c.symbols.isEmpty) return;
    final g = store.mapleGame();
    final id = 'sym-${c.id}';
    final open = c.symbols.where((s) => !s.isMax).toList();
    final i = g.chores.indexWhere((x) => x.id == id);
    if (open.isEmpty) {
      if (i >= 0) {
        g.chores.removeAt(i);
        store.commit();
      }
      return;
    }
    final arc = open.where((s) => s.isArcane).length, auth = open.length - arc;
    final title = '심볼 일일 · ${c.name} (${[if (arc > 0) '아케인 $arc', if (auth > 0) '어센틱 $auth'].join(' · ')})';
    if (i >= 0) {
      if (g.chores[i].title == title) return;
      g.chores[i].title = title;
    } else {
      g.chores.add(Chore(id: id, title: title, period: ChorePeriod.daily, charName: c.name));
    }
    store.commit();
  }

  // ── 이벤트 공지 ──

  /// 진행 중인 이벤트 (6시간 캐시)
  List<NexonEvent> events = [];
  DateTime? _eventsAt;

  /// 이벤트 끝나는 날을 캘린더에 자동으로 넣기
  bool get autoEventSchedules => _prefs.getBool('auto_event_schedules') ?? true;
  set autoEventSchedules(bool v) {
    _prefs.setBool('auto_event_schedules', v);
    notifyListeners();
  }

  Future<List<NexonEvent>> loadEvents({bool force = false}) async {
    if (!force && _eventsAt != null && DateTime.now().difference(_eventsAt!) < const Duration(hours: 6)) return events;
    final j = await _api().noticeEvents();
    events = [
      for (final e in (j['event_notice'] as List? ?? [])) if (e is Map) NexonEvent.fromJson(e.cast<String, dynamic>()),
    ]..sort((a, b) => (a.end ?? DateTime(2100)).compareTo(b.end ?? DateTime(2100)));
    _eventsAt = DateTime.now();
    if (autoEventSchedules) addEventSchedules();
    notifyListeners();
    return events;
  }

  /// 이벤트 끝나는 날에 종일 일정 '⏰ 이벤트 끝: …' (id 가 공지 번호로 정해져 있어 여러 기기에서도 하나).
  /// 한 번 넣었거나 이미 본 공지는 다시 넣지 않는다 (지운 일정이 되살아나지 않게). 넣은 개수
  int addEventSchedules() {
    final seen = (_prefs.getStringList('nx_event_seen') ?? []).toSet();
    final now = DateTime.now();
    var added = 0;
    for (final e in events) {
      final id = 'nx-evt-${e.id}';
      if (e.end == null || e.end!.isBefore(now) || e.end!.isAfter(now.add(const Duration(days: 90)))) continue;
      if (seen.contains(id)) continue;
      seen.add(id);
      if (store.schedules.any((s) => s.id == id)) continue;
      store.schedules.add(Schedule(
        id: id,
        title: '⏰ 이벤트 끝: ${e.title}',
        start: DateTime(e.end!.year, e.end!.month, e.end!.day),
        allDay: true,
        memo: e.url,
        gameId: store.mapleGame().id,
      ));
      added++;
    }
    _prefs.setStringList('nx_event_seen', seen.toList());
    if (added > 0) store.commit();
    return added;
  }

  /// 앱 시작 시: 1시간 넘게 안 갱신한 캐릭터만 조용히 갱신
  Future<void> refreshStale() async {
    if (!hasKey) return;
    for (final c in List.of(store.characters)) {
      final t = c.updatedAt;
      if (t != null && DateTime.now().difference(t) < const Duration(hours: 1)) continue;
      try {
        await refresh(c);
      } catch (_) {}
    }
  }

  /// 지난 [days]일 기록 불러오기 (하루당 API 2회). 이미 있는 날짜는 건너뜀.
  Future<int> backfill(MapleCharacter c, {int days = 14, void Function(int done, int total)? onProgress}) async {
    if (busy.contains(c.id)) return 0;
    busy.add(c.id);
    notifyListeners();
    var added = 0;
    try {
      final api = _api();
      final have = c.history.map((h) => h.date).toSet();
      final today = DateTime.now().toUtc().add(const Duration(hours: 9));
      for (var k = 1; k <= days; k++) {
        onProgress?.call(k - 1, days);
        final date = DateFormat('yyyy-MM-dd').format(today.subtract(Duration(days: k)));
        if (have.contains(date)) continue;
        try {
          final r = await Future.wait([api.basic(c.ocid, date: date), api.stat(c.ocid, date: date)]);
          final lv = (r[0]['character_level'] as num?)?.toInt();
          if (lv == null) continue; // 캐릭터 생성 전 등
          c.putSnapshot(MapleSnapshot(
            date: date,
            level: lv,
            expRate: NexonApi.expRate(r[0]),
            combatPower: NexonApi.combatPower(r[1]),
          ));
          added++;
        } on NexonApiException catch (e) {
          if (e.code == 'OPENAPI00007' || e.code == 'OPENAPI00005') rethrow;
        }
      }
      onProgress?.call(days, days);
      if (added > 0) store.upsertCharacter(c);
      return added;
    } finally {
      busy.remove(c.id);
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> equipment(MapleCharacter c, {bool force = false}) async {
    if (!force && equipmentCache[c.id] != null) return equipmentCache[c.id]!;
    final e = await _api().itemEquipment(c.ocid);
    equipmentCache[c.id] = e;
    notifyListeners();
    return e;
  }

  Future<Map<String, dynamic>> stat(MapleCharacter c, {bool force = false}) async {
    if (!force && statCache[c.id] != null) return statCache[c.id]!;
    final s = await _api().stat(c.ocid);
    statCache[c.id] = s;
    notifyListeners();
    return s;
  }
}

/// 넥슨 이벤트 공지 하나
class NexonEvent {
  NexonEvent({required this.id, required this.title, required this.url, this.start, this.end, this.thumbnail = ''});

  final String id;
  final String title;
  final String url;
  final DateTime? start;
  final DateTime? end;
  final String thumbnail;

  factory NexonEvent.fromJson(Map<String, dynamic> j) => NexonEvent(
        id: '${j['notice_id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        url: '${j['url'] ?? ''}',
        start: DateTime.tryParse('${j['date_event_start'] ?? ''}')?.toLocal(),
        end: DateTime.tryParse('${j['date_event_end'] ?? ''}')?.toLocal(),
        thumbnail: '${j['thumbnail_url'] ?? ''}',
      );
}

class MapleScope extends InheritedNotifier<MapleService> {
  const MapleScope({super.key, required MapleService maple, required super.child})
      : super(notifier: maple);

  static MapleService? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MapleScope>()?.notifier;
}
