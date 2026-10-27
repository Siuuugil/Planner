import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game.dart';
import '../models/schedule.dart';

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 앱 전체 상태. 기기 로컬(SharedPreferences)에 JSON으로 저장한다.
class AppStore extends ChangeNotifier {
  AppStore(this._prefs) {
    _load();
  }

  static const _key = 'app_data_v1';
  final SharedPreferences _prefs;

  final List<Schedule> schedules = [];
  final List<Game> games = [];

  static Future<AppStore> open() async =>
      AppStore(await SharedPreferences.getInstance());

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    schedules.addAll((j['schedules'] as List? ?? [])
        .map((e) => Schedule.fromJson(e as Map<String, dynamic>)));
    games.addAll((j['games'] as List? ?? [])
        .map((e) => Game.fromJson(e as Map<String, dynamic>)));
  }

  /// 변경 후 호출: 저장하고 화면 갱신.
  void commit() {
    _prefs.setString(
      _key,
      jsonEncode({
        'schedules': schedules.map((s) => s.toJson()).toList(),
        'games': games.map((g) => g.toJson()).toList(),
      }),
    );
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
