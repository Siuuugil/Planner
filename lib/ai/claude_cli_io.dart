import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'claude_cli_common.dart';

export 'claude_cli_common.dart';

class ClaudeCli {
  static bool get supported => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// 인자는 따옴표가 필요 없는 단어만 쓴다 (Windows의 claude.cmd는 셸을 거치기 때문).
  /// 지시와 데이터는 모두 표준 입력으로 보내고, 도구는 전부 막고, 빈 임시 폴더에서 실행한다.
  static const _args = [
    '-p',
    '--output-format',
    'json',
    '--no-session-persistence',
    '--disallowedTools',
    'Bash',
    'Edit',
    'Write',
    'Read',
    'Glob',
    'Grep',
    'WebFetch',
    'WebSearch',
    'NotebookEdit',
    'Task',
  ];

  static Future<Process> _start(String exe, List<String> args, String cwd) async {
    try {
      return await Process.start(exe, args, workingDirectory: cwd);
    } on ProcessException {
      // Windows의 npm 설치본(claude.cmd)은 셸로만 실행된다
      return Process.start(exe, args, workingDirectory: cwd, runInShell: true);
    }
  }

  static Future<(int, String, String)> _run(String exe, List<String> args, {String? stdin, Duration? timeout}) async {
    final dir = await Directory.systemTemp.createTemp('myplanner_ai_');
    try {
      final Process p;
      try {
        p = await _start(exe, args, dir.path);
      } on ProcessException {
        throw const ClaudeCliException(
            'claude 명령을 찾지 못했어요. Claude Code를 설치하고 터미널에서 한 번 로그인해 주세요.');
      }
      final out = p.stdout.transform(utf8.decoder).join();
      final err = p.stderr.transform(utf8.decoder).join();
      if (stdin != null) p.stdin.add(utf8.encode(stdin));
      await p.stdin.close();
      final code = await p.exitCode.timeout(timeout ?? const Duration(minutes: 3), onTimeout: () {
        p.kill();
        throw const ClaudeCliException('AI 응답이 너무 오래 걸려서 멈췄어요. 다시 시도해 주세요.');
      });
      return (code, await out, await err);
    } finally {
      unawaited(dir.delete(recursive: true).catchError((_) => dir));
    }
  }

  /// [prompt]를 보내고 답 JSON 객체를 돌려준다.
  static Future<Map<String, dynamic>> ask(String prompt, {String executable = 'claude'}) async {
    final (code, out, err) = await _run(executable, _args, stdin: prompt);
    if (out.trim().isEmpty) {
      throw ClaudeCliException(
          code == 0 ? 'Claude CLI가 아무 답도 하지 않았어요.' : 'Claude CLI 실행 실패: ${err.trim()}');
    }
    return parseCliOutput(out);
  }

  /// 연결 확인용 (`claude --version`)
  static Future<String> version({String executable = 'claude'}) async {
    final (code, out, err) = await _run(executable, ['--version'], timeout: const Duration(seconds: 20));
    if (code != 0) throw ClaudeCliException('claude 실행 실패: ${err.trim()}');
    return out.trim();
  }
}
