import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game.dart';
import '../models/schedule.dart';
import 'sync_row.dart';

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

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

  /// id → 마지막으로 반영된 상태({'kind', 'data'}를 JSON 인코딩한 것). 변경 감지용.
  final Map<String, String> _known = {};

  /// id → 그 레코드가 마지막으로 바뀐 시각(UTC). 기기 간 병합 시 최신 우선.
  final Map<String, DateTime> _stamps = {};

  /// 아직 서버에 올리지 못한 변경.
  final Map<String, SyncRow> pending = {};

  /// 데이터 소유 계정. 다른 계정으로 로그인하면 로컬 데이터를 비운다.
  String? ownerId;

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
    }
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
  }

  Map<String, (String, Map<String, dynamic>)> _snapshot() => {
        for (final s in schedules) s.id: ('schedule', s.toJson()),
        for (final g in games) g.id: ('game', g.toJson()),
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
    final changed = _diff();
    _save();
    notifyListeners();
    if (changed) onLocalChange?.call();
  }

  /// 서버에서 받은 행들을 반영한다. 로컬이 더 최신이면 무시.
  void applyRemote(Iterable<SyncRow> rows) {
    var changed = false;
    for (final r in rows) {
      final local = _stamps[r.id];
      if (local != null && !r.updatedAt.isAfter(local)) continue;
      _stamps[r.id] = r.updatedAt;
      pending.remove(r.id);
      schedules.removeWhere((s) => s.id == r.id);
      final gi = games.indexWhere((g) => g.id == r.id);
      if (gi >= 0 && (r.deleted || r.kind != 'game')) games.removeAt(gi);
      if (r.deleted || r.data == null) {
        _known.remove(r.id);
      } else {
        // 서버(jsonb)는 키 순서를 바꾸므로 모델로 다시 인코딩한 값을 기준으로 삼는다.
        final Map<String, dynamic> data;
        if (r.kind == 'schedule') {
          final s = Schedule.fromJson(r.data!);
          schedules.add(s);
          data = s.toJson();
        } else {
          final g = Game.fromJson(r.data!);
          gi >= 0 ? games[gi] = g : games.add(g);
          data = g.toJson();
        }
        _known[r.id] = _encode(r.kind, data);
      }
      changed = true;
    }
    if (changed) {
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

  void toggleChore(Game g, Chore c) {
    final now = DateTime.now();
    c.lastDone = g.isChoreDone(c, now) ? null : now;
    commit();
  }
}
