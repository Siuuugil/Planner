import 'claude_cli_common.dart';

export 'claude_cli_common.dart';

class ClaudeCli {
  static bool get supported => false;

  static Future<Map<String, dynamic>> ask(String prompt, {String executable = 'claude'}) =>
      throw const ClaudeCliException('AI 기능은 PC(Windows) 앱에서만 쓸 수 있어요.');

  static Future<String> version({String executable = 'claude'}) =>
      throw const ClaudeCliException('AI 기능은 PC(Windows) 앱에서만 쓸 수 있어요.');
}
