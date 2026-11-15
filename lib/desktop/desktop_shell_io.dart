import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Windows PC 앱: 창을 닫아도 트레이(작업 표시줄 오른쪽 아래)에서 계속 실행,
/// 윈도우 시작 시 자동 실행 (창 없이 트레이로).
/// 계속 켜져 있어야 폰에서 보낸 AI 대화·음성에 PC가 답하고, 알림도 정확히 울린다.
class DesktopShell extends ChangeNotifier with TrayListener, WindowListener {
  DesktopShell._(this._prefs);

  static const _trayKey = 'close_to_tray';
  final SharedPreferences _prefs;
  bool _autoStart = false;

  static Future<DesktopShell?> start(List<String> args) async {
    if (!Platform.isWindows) return null;
    final shell = DesktopShell._(await SharedPreferences.getInstance());
    try {
      await shell._init();
    } catch (e) {
      debugPrint('트레이 준비 실패: $e');
    }
    return shell;
  }

  Future<void> _init() async {
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    await windowManager.setPreventClose(closeToTray);

    await trayManager.setIcon('assets/tray/app_icon.ico');
    await trayManager.setToolTip('마이플래너');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'open', label: '마이플래너 열기'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: '완전히 종료'),
    ]));
    trayManager.addListener(this);

    // 레지스트리 시작 프로그램에 '--minimized' 로 등록 (켜질 때 창 없이 트레이로)
    launchAtStartup.setup(appName: 'MyPlanner', appPath: Platform.resolvedExecutable, args: ['--minimized']);
    _autoStart = await launchAtStartup.isEnabled();
    if (voiceServerAvailable && startVoiceServer) await _launchVoiceServer();
    // 처음 한 번은 자동 실행을 켜 둔다 (설정에서 끌 수 있음)
    if (!(_prefs.getBool('auto_start_asked') ?? false)) {
      _prefs.setBool('auto_start_asked', true);
      await setAutoStart(true);
    }
  }

  /// 창 닫기(X)를 누르면 종료 대신 트레이로 숨기기 (기본 켜짐)
  bool get closeToTray => _prefs.getBool(_trayKey) ?? true;

  set closeToTray(bool v) {
    _prefs.setBool(_trayKey, v);
    windowManager.setPreventClose(v);
    notifyListeners();
  }

  /// 설치 스크립트가 만든 '내 목소리' 서버 실행 파일
  static const voiceServerBat = r'C:\MyPlannerVoice\voice_server\start_voice_server.bat';

  bool get voiceServerAvailable => File(voiceServerBat).existsSync();

  /// 앱이 켜질 때 '내 목소리' 서버도 같이 켜기 (최소화된 창으로)
  bool get startVoiceServer => _prefs.getBool('start_voice_server') ?? false;

  set startVoiceServer(bool v) {
    _prefs.setBool('start_voice_server', v);
    if (v) _launchVoiceServer();
    notifyListeners();
  }

  Future<void> _launchVoiceServer() async {
    // 이미 켜져 있으면 그냥 둔다
    try {
      final s = await Socket.connect('127.0.0.1', 9800, timeout: const Duration(milliseconds: 500));
      s.destroy();
      return;
    } catch (_) {}
    try {
      // cmd 의 start 는 따옴표 처리가 까다로워서 PowerShell Start-Process 로 최소화 실행
      await Process.start(
        'powershell',
        [
          '-NoProfile',
          '-WindowStyle',
          'Hidden',
          '-Command',
          "Start-Process -FilePath '$voiceServerBat' -WorkingDirectory '${File(voiceServerBat).parent.path}' -WindowStyle Minimized",
        ],
        mode: ProcessStartMode.detached,
      );
    } catch (e) {
      debugPrint('음성 서버 실행 실패: $e');
    }
  }

  /// 윈도우 시작 시 자동 실행
  bool get autoStart => _autoStart;

  Future<void> setAutoStart(bool v) async {
    try {
      v ? await launchAtStartup.enable() : await launchAtStartup.disable();
      _autoStart = await launchAtStartup.isEnabled();
    if (voiceServerAvailable && startVoiceServer) await _launchVoiceServer();
    } catch (e) {
      debugPrint('자동 실행 설정 실패: $e');
    }
    notifyListeners();
  }

  Future<void> _show() async {
    await windowManager.show();
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.focus();
  }

  Future<void> _quit() async {
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() async {
    if (closeToTray) {
      await windowManager.hide();
    } else {
      await _quit();
    }
  }

  @override
  void onTrayIconMouseDown() => _show();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        _show();
      case 'quit':
        _quit();
    }
  }
}

class DesktopScope extends InheritedNotifier<DesktopShell> {
  const DesktopScope({super.key, required DesktopShell shell, required super.child}) : super(notifier: shell);

  static DesktopShell? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<DesktopScope>()?.notifier;
}
