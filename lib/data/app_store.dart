import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_note.dart';
import '../models/game.dart';
import '../models/maple_character.dart';
import '../models/schedule.dart';
import '../models/task.dart';
import 'sync_row.dart';

final _rand = Random();
var _seq = 0;

/// 고유 id: 시각 + 순번 + 난수.
/// (웹은 시각 정밀도가 밀리초라 반복문에서 시각만 쓰면 id가 겹친다)
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
    '${(_seq++ % 1296).toRadixString(36).padLeft(2, '0')}'
    '${_rand.nextInt(1 << 30).toRadixString(36)}';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 앱 전체 상태. 기기 로컬(SharedPreferences)에 JSON으로 저장하고,
/// 바뀐 레코드는 [pending]에 쌓아 두었다가 동기화 시 서버로 올린다.
class AppStore extends ChangeNotifier {
  AppStore(this._prefs, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    _load();
  }

  static const _key = 'app_data_v1';
  static const _syncKey = 'sync_state_v1';
  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  final List<Schedule> schedules = [];
  final List<Game> games = [];
  final List<Task> tasks = [];
  final List<MapleCharacter> characters = [];

  /// 숙제·보스 완료 체크 (id → 기록)
  final Map<String, DoneMark> marks = {};

  /// AI가 만든 계획·리포트·답변 (최근 것이 앞)
  final List<AiNote> notes = [];

  /// id → 마지막으로 반영된 상태({'kind', 'data'}를 JSON 인코딩한 것). 변경 감지용.
  final Map<String, String> _known = {};

  /// id → 그 레코드가 마지막으로 바뀐 시각(UTC). 기기 간 병합 시 최신 우선.
  final Map<String, DateTime> _stamps = {};

  /// 아직 서버에 올리지 못한 변경.
  final Map<String, SyncRow> pending = {};

  /// 데이터 소유 계정. 다른 계정으로 로그인하면 로컬 데이터를 비운다.
  String? ownerId;

  /// 게임 숨기기 (회사 모드). 기기별 설정이라 동기화하지 않는다.
  bool get hideGames => _prefs.getBool('hide_games') ?? false;

  set hideGames(bool v) {
    _prefs.setBool('hide_games', v);
    notifyListeners();
  }

  /// 사용자가 로컬에서 무언가를 바꿨을 때 호출 (동기화 예약용).
  VoidCallback? onLocalChange;

  static Future<AppStore> open() async =>
      AppStore(await SharedPreferences.getInstance());

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      schedules.addAll((j['schedules'] as List? ?? [])
          .map((e) => Schedule.fromJson(e as Map<String, dynamic>)));
      games.addAll((j['games'] as List? ?? [])
          .map((e) => Game.fromJson(e as Map<String, dynamic>)));
      tasks.addAll((j['tasks'] as List? ?? [])
          .map((e) => Task.fromJson(e as Map<String, dynamic>)));
      characters.addAll((j['characters'] as List? ?? [])
          .map((e) => MapleCharacter.fromJson(e as Map<String, dynamic>)));
      notes.addAll((j['notes'] as List? ?? []).map((e) => AiNote.fromJson(e as Map<String, dynamic>)));
      for (final e in (j['marks'] as List? ?? [])) {
        final m = DoneMark.fromJson(e as Map<String, dynamic>);
        marks[m.id] = m;
      }
    }
    _migrateLegacyChecks();
    final sync = _prefs.getString(_syncKey);
    if (sync != null) {
      final j = jsonDecode(sync) as Map<String, dynamic>;
      _known.addAll((j['known'] as Map).cast<String, String>());
      (j['stamps'] as Map).forEach(
          (k, v) => _stamps[k as String] = DateTime.parse(v as String));
      for (final r in j['pending'] as List) {
        final row = SyncRow.fromJson(r as Map<String, dynamic>);
        pending[row.id] = row;
      }
      ownerId = j['ownerId'] as String?;
    } else if (_diff()) {
      // 동기화 도입 전 데이터: 전부 올릴 대상으로 표시.
      _save();
    }
    // 예전 버전(웹)에서 겹친 id로 만들어진 가격표 정리
    var fixed = false;
    for (final g in games) {
      fixed |= g.fixDuplicateIds(newId);
    }
    if (fixed && _diff()) _save();
    _hydrate();
  }

  /// 예전 버전: 게임 레코드 안 lastDone → 완료 기록으로 옮긴다
  void _migrateLegacyChecks() {
    for (final g in games) {
      for (final c in g.chores) {
        final at = c.lastDone;
        if (at == null || marks.values.any((m) => m.choreId == c.id)) continue;
        final week = g.weekKey(at);
        final id = DoneMark.idFor(c, week);
        marks[id] = DoneMark(
          id: id,
          gameId: g.id,
          choreId: c.id,
          at: at,
          week: c.isBoss ? week : null,
          income: c.isBoss ? g.bossIncome(c) : null,
        );
      }
    }
  }

  /// 완료 기록 → 숙제 완료 상태·결정석 수익·결정석 목표 현재값
  void _hydrate() {
    final now = _clock();
    for (final g in games) {
      final latest = <String, DateTime>{};
      g.crystalLive.clear();
      for (final m in marks.values) {
        if (m.gameId != g.id) continue;
        final prev = latest[m.choreId];
        if (prev == null || m.at.isAfter(prev)) latest[m.choreId] = m.at;
        if (m.week != null && m.income != null) {
          g.crystalLive[m.week!] = (g.crystalLive[m.week!] ?? 0) + m.income!;
        }
      }
      for (final c in g.chores) {
        c.lastDone = latest[c.id];
      }
      g.recomputeCrystals(now);
    }
  }

  Map<String, (String, Map<String, dynamic>)> _snapshot() => {
        for (final s in schedules) s.id: ('schedule', s.toJson()),
        for (final g in games) g.id: ('game', g.toJson()),
        for (final t in tasks) t.id: ('task', t.toJson()),
        for (final c in characters) c.id: ('maple', c.toJson()),
        for (final m in marks.values) m.id: ('mark', m.toJson()),
        for (final n in notes) n.id: ('ai', n.toJson()),
      };

  static String _encode(String kind, Map<String, dynamic>? data) =>
      jsonEncode({'kind': kind, 'data': data});

  /// 마지막 반영 이후 바뀐/삭제된 레코드를 [pending]에 기록한다.
  bool _diff() {
    final now = _clock().toUtc();
    final current = _snapshot();
    var changed = false;
    current.forEach((id, item) {
      final (kind, data) = item;
      final enc = _encode(kind, data);
      if (_known[id] == enc) return;
      _known[id] = enc;
      _stamps[id] = now;
      pending[id] = SyncRow(
          id: id, kind: kind, data: data, deleted: false, updatedAt: now);
      changed = true;
    });
    for (final id in _known.keys.toList()) {
      if (current.containsKey(id)) continue;
      final kind = (jsonDecode(_known.remove(id)!) as Map)['kind'] as String;
      _stamps[id] = now;
      pending[id] = SyncRow(
          id: id, kind: kind, data: null, deleted: true, updatedAt: now);
      changed = true;
    }
    return changed;
  }

  void _save() {
    _prefs.setString(
      _key,
      jsonEncode({
        'schedules': schedules.map((s) => s.toJson()).toList(),
        'games': games.map((g) => g.toJson()).toList(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'characters': characters.map((c) => c.toJson()).toList(),
        'marks': marks.values.map((m) => m.toJson()).toList(),
        'notes': notes.map((n) => n.toJson()).toList(),
      }),
    );
    _prefs.setString(
      _syncKey,
      jsonEncode({
        'known': _known,
        'stamps': _stamps.map((k, v) => MapEntry(k, v.toIso8601String())),
        'pending': pending.values.map((r) => r.toJson()).toList(),
        'ownerId': ownerId,
      }),
    );
  }

  /// 변경 후 호출: 저장하고 화면 갱신.
  void commit() {
    _hydrate();
    final changed = _diff();
    _save();
    notifyListeners();
    if (changed) onLocalChange?.call();
  }

  /// 서버에서 받은 행들을 반영한다. 로컬이 더 최신이면 무시.
  void applyRemote(Iterable<SyncRow> rows) {
    var changed = false;
    for (final r in rows) {
      // 이 버전이 모르는 종류(이후 버전에서 추가된 것)는 건드리지 않는다.
      if (!const {'schedule', 'game', 'task', 'maple', 'mark', 'ai'}.contains(r.kind)) continue;
      final local = _stamps[r.id];
      if (local != null && !r.updatedAt.isAfter(local)) continue;
      _stamps[r.id] = r.updatedAt;
      pending.remove(r.id);
      final si = schedules.indexWhere((x) => x.id == r.id);
      final gi = games.indexWhere((x) => x.id == r.id);
      final ti = tasks.indexWhere((x) => x.id == r.id);
      final ci = characters.indexWhere((x) => x.id == r.id);
      if (r.kind == 'ai') {
        notes.removeWhere((n) => n.id == r.id);
        if (r.deleted || r.data == null) {
          _known.remove(r.id);
        } else {
          final n = AiNote.fromJson(r.data!);
          notes.add(n);
          _known[r.id] = _encode(r.kind, n.toJson());
        }
        notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        changed = true;
        continue;
      }
      if (r.kind == 'mark') {
        if (r.deleted || r.data == null) {
          marks.remove(r.id);
          _known.remove(r.id);
        } else {
          final m = DoneMark.fromJson(r.data!);
          marks[m.id] = m;
          _known[r.id] = _encode(r.kind, m.toJson());
        }
        changed = true;
        continue;
      }
      if (r.deleted || r.data == null) {
        if (si >= 0) schedules.removeAt(si);
        if (gi >= 0) games.removeAt(gi);
        if (ti >= 0) tasks.removeAt(ti);
        if (ci >= 0) characters.removeAt(ci);
        _known.remove(r.id);
      } else {
        // 서버(jsonb)는 키 순서를 바꾸므로 모델로 다시 인코딩한 값을 기준으로 삼는다.
        final Map<String, dynamic> data;
        switch (r.kind) {
          case 'schedule':
            final x = Schedule.fromJson(r.data!);
            si >= 0 ? schedules[si] = x : schedules.add(x);
            data = x.toJson();
          case 'game':
            final x = Game.fromJson(r.data!);
            gi >= 0 ? games[gi] = x : games.add(x);
            data = x.toJson();
          case 'maple':
            final x = MapleCharacter.fromJson(r.data!);
            ci >= 0 ? characters[ci] = x : characters.add(x);
            data = x.toJson();
          default:
            final x = Task.fromJson(r.data!);
            ti >= 0 ? tasks[ti] = x : tasks.add(x);
            data = x.toJson();
        }
        _known[r.id] = _encode(r.kind, data);
      }
      changed = true;
    }
    if (changed) {
      _hydrate();
      _save();
      notifyListeners();
    }
  }

  /// 서버에 올라간 행을 대기열에서 뺀다 (그 사이 또 바뀐 건 남긴다).
  void markPushed(Iterable<SyncRow> rows) {
    for (final r in rows) {
      if (pending[r.id]?.updatedAt == r.updatedAt) pending.remove(r.id);
    }
    _save();
  }

  void setOwner(String? id) {
    ownerId = id;
    _save();
  }

  /// 로그아웃/계정 변경 시 이 기기의 데이터를 모두 지운다.
  void clearAll() {
    schedules.clear();
    games.clear();
    tasks.clear();
    characters.clear();
    marks.clear();
    notes.clear();
    _known.clear();
    _stamps.clear();
    pending.clear();
    ownerId = null;
    _save();
    notifyListeners();
  }

  Game? gameById(String? id) {
    for (final g in games) {
      if (g.id == id) return g;
    }
    return null;
  }

  List<Schedule> schedulesOn(DateTime day) =>
      schedules.where((s) => isSameDay(s.start, day)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  void upsertSchedule(Schedule s) {
    final i = schedules.indexWhere((e) => e.id == s.id);
    i < 0 ? schedules.add(s) : schedules[i] = s;
    commit();
  }

  void deleteSchedule(Schedule s) {
    schedules.removeWhere((e) => e.id == s.id);
    commit();
  }

  void upsertGame(Game g) {
    final i = games.indexWhere((e) => e.id == g.id);
    i < 0 ? games.add(g) : games[i] = g;
    commit();
  }

  void deleteGame(Game g) {
    games.removeWhere((e) => e.id == g.id);
    for (final s in schedules) {
      if (s.gameId == g.id) s.gameId = null;
    }
    commit();
  }

  List<Task> tasksIn(TaskCategory c) =>
      tasks.where((t) => t.category == c).toList();

  void upsertTask(Task t) {
    final i = tasks.indexWhere((e) => e.id == t.id);
    i < 0 ? tasks.add(t) : tasks[i] = t;
    commit();
  }

  void deleteTask(Task t) {
    tasks.removeWhere((e) => e.id == t.id);
    commit();
  }

  MapleCharacter? characterById(String? id) {
    for (final c in characters) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 캐릭터를 추가/갱신하고, 연결된 목표의 현재값을 맞춘다.
  void upsertCharacter(MapleCharacter c) {
    final i = characters.indexWhere((e) => e.id == c.id);
    i < 0 ? characters.add(c) : characters[i] = c;
    for (final g in games) {
      for (final goal in g.goals) {
        if (goal.autoCharId != c.id) continue;
        if (goal.autoMetric == 'combat' && c.combatPower != null) {
          goal.current = c.combatPower!.toDouble();
        } else if (goal.autoMetric == 'level') {
          goal.current = double.parse(c.levelProgress.toStringAsFixed(2));
        }
      }
    }
    commit();
  }

  void deleteCharacter(MapleCharacter c) {
    characters.removeWhere((e) => e.id == c.id);
    for (final g in games) {
      for (final goal in g.goals) {
        if (goal.autoCharId == c.id) goal.autoCharId = null;
      }
    }
    commit();
  }

  /// AI 결과 저장 (같은 id면 바꾸고, 최근 것이 앞). 오래된 대화·코치 답변은 50개까지만.
  void saveNote(AiNote n) {
    notes.removeWhere((x) => x.id == n.id);
    notes.insert(0, n);
    final old = notes.where((x) => x.type == 'chat' || x.type == 'coach').skip(50).toList();
    notes.removeWhere(old.contains);
    commit();
  }

  void deleteNote(AiNote n) {
    notes.removeWhere((x) => x.id == n.id);
    commit();
  }

  /// 숙제 체크/해제: 게임 레코드는 그대로 두고 완료 기록만 바꾼다
  void toggleChore(Game g, Chore c) {
    final now = _clock();
    if (g.isChoreDone(c, now)) {
      final start = g.periodStart(c.period, now);
      marks.removeWhere((_, m) => m.choreId == c.id && !m.at.isBefore(start));
    } else {
      final week = g.weekKey(now);
      final id = DoneMark.idFor(c, week);
      marks[id] = DoneMark(
        id: id,
        gameId: g.id,
        choreId: c.id,
        at: now,
        week: c.isBoss ? week : null,
        income: c.isBoss ? g.bossIncome(c) : null,
      );
    }
    commit();
  }

  /// '메이플'이 들어간 게임 (없으면 null)
  Game? findMapleGame() {
    for (final g in games) {
      if (g.name.contains('메이플')) return g;
    }
    return null;
  }

  /// '메이플'이 들어간 게임 (없으면 만들어서 추가)
  Game mapleGame() {
    for (final g in games) {
      if (g.name.contains('메이플')) return g;
    }
    final g = Game(
      id: newId(),
      name: '메이플스토리',
      colorValue: 0xFFF39B1E,
      resetHour: 0,
      weeklyResetWeekday: DateTime.thursday,
    );
    games.add(g);
    return g;
  }

  /// 결정석을 쓰는 게임 (보스 가격표나 보스 숙제가 있는 게임)
  Game? crystalGame() {
    for (final g in games) {
      if (g.bosses.isNotEmpty || g.chores.any((c) => c.isBoss)) return g;
    }
    return null;
  }
}
