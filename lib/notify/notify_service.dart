import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../data/app_store.dart';
import 'reminders.dart';

/// 일정·마감·숙제 알림.
/// - Android/Windows: OS에 예약 알림을 등록 (앱이 꺼져 있어도 울림)
/// - 웹: 브라우저가 예약 알림을 지원하지 않아 앱이 열려 있는 동안만 울림
class NotifyService extends ChangeNotifier {
  NotifyService._(this.store, this._prefs, this._plugin);

  static const _key = 'notify_settings_v1';
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      '일정·숙제 알림',
      channelDescription: '일정 시작, 마감일, 게임 숙제 초기화 전 알림',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  final AppStore store;
  final SharedPreferences _prefs;
  final FlutterLocalNotificationsPlugin _plugin;
  NotifySettings settings = const NotifySettings();
  List<Reminder> upcoming = [];
  Timer? _debounce;
  Timer? _webTicker;
  DateTime _webLastCheck = DateTime.now();

  static Future<NotifyService?> start(AppStore store) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final plugin = FlutterLocalNotificationsPlugin();
      tz.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      }
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          windows: WindowsInitializationSettings(
            appName: '마이플래너',
            appUserModelId: 'Siuuugil.MyPlanner',
            guid: '49426e81-c5d2-4151-a9dd-4864cec0e3a0',
          ),
        ),
      );
      final s = NotifyService._(store, prefs, plugin);
      final raw = prefs.getString(_key);
      if (raw != null) {
        s.settings = NotifySettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
      store.addListener(s._schedule);
      if (kIsWeb) {
        s._webTicker = Timer.periodic(const Duration(seconds: 30), (_) => s._webTick());
      } else if (s.settings.enabled) {
        await s.requestPermission();
      }
      s._schedule();
      return s;
    } catch (e) {
      debugPrint('알림 초기화 실패: $e');
      return null;
    }
  }

  /// 웹은 반드시 버튼을 눌렀을 때 호출해야 한다.
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      final web = _plugin.resolvePlatformSpecificImplementation<
          WebFlutterLocalNotificationsPlugin>();
      return await web?.requestNotificationsPermission() ?? false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  void update(NotifySettings s) {
    settings = s;
    _prefs.setString(_key, jsonEncode(s.toJson()));
    _schedule();
    notifyListeners();
  }

  Future<void> test() => _plugin.show(
        id: 1,
        title: '🍁 마이플래너',
        body: '알림이 잘 와요!',
        notificationDetails: _details,
      );

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), _apply);
  }

  Future<void> _apply() async {
    upcoming = planReminders(store, settings, DateTime.now());
    notifyListeners();
    if (kIsWeb) return;
    try {
      await _plugin.cancelAll();
      for (final r in upcoming) {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: tz.TZDateTime.from(r.when, tz.local),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('알림 예약 실패: $e');
    }
  }

  void _webTick() {
    final now = DateTime.now();
    for (final r in upcoming) {
      if (r.when.isAfter(_webLastCheck) && !r.when.isAfter(now)) {
        _plugin.show(id: r.id, title: r.title, body: r.body, notificationDetails: _details);
      }
    }
    _webLastCheck = now;
    // 지나간 알림 정리 + 새 기간 반영
    if (upcoming.isNotEmpty && upcoming.first.when.isBefore(now)) _schedule();
  }

  @override
  void dispose() {
    store.removeListener(_schedule);
    _debounce?.cancel();
    _webTicker?.cancel();
    super.dispose();
  }
}

class NotifyScope extends InheritedNotifier<NotifyService> {
  const NotifyScope({super.key, required NotifyService notify, required super.child})
      : super(notifier: notify);

  static NotifyService? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NotifyScope>()?.notifier;
}
