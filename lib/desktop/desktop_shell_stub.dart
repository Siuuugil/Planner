import 'package:flutter/widgets.dart';

/// 트레이 상주·자동 실행 (Windows 전용). 다른 곳에서는 null.
class DesktopShell extends ChangeNotifier {
  static Future<DesktopShell?> start(List<String> args) async => null;

  bool get closeToTray => false;
  set closeToTray(bool v) {}
  bool get autoStart => false;
  bool get voiceServerAvailable => false;
  bool get startVoiceServer => false;
  set startVoiceServer(bool v) {}
  Future<void> setAutoStart(bool v) async {}
}

class DesktopScope extends InheritedNotifier<DesktopShell> {
  const DesktopScope({super.key, required DesktopShell shell, required super.child}) : super(notifier: shell);

  static DesktopShell? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<DesktopScope>()?.notifier;
}
