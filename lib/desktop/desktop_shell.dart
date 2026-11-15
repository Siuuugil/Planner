// 웹·폰에서는 아무것도 안 하는 빈 구현, Windows 에서만 트레이·자동 실행
export 'desktop_shell_stub.dart' if (dart.library.io) 'desktop_shell_io.dart';
