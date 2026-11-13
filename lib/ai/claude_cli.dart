/// PC 앱에서 내 컴퓨터의 Claude Code CLI(`claude -p`)로 AI 기능을 실행한다.
/// 웹·폰에서는 [ClaudeCli.supported]가 false.
library;

export 'claude_cli_stub.dart' if (dart.library.io) 'claude_cli_io.dart';
