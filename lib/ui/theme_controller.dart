import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 화면 테마: 'system'(기기 설정 따라) · 'light' · 'dark'. 기기마다 따로.
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController(this._prefs) {
    WidgetsBinding.instance.addObserver(this);
  }

  final SharedPreferences _prefs;

  static Future<ThemeController> open() async => ThemeController(await SharedPreferences.getInstance());

  String get mode => _prefs.getString('theme_mode') ?? 'system';

  set mode(String v) {
    _prefs.setString('theme_mode', v);
    notifyListeners();
  }

  bool get isDark => switch (mode) {
        'dark' => true,
        'light' => false,
        _ => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
      };

  /// 기기의 다크 모드가 바뀌면 (시스템 따라가기일 때) 다시 그림
  @override
  void didChangePlatformBrightness() {
    if (mode == 'system') notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({super.key, required ThemeController theme, required super.child}) : super(notifier: theme);

  static ThemeController? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;
}
