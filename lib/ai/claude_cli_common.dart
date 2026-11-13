import 'dart:convert';

class ClaudeCliException implements Exception {
  const ClaudeCliException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// `claude -p --output-format json` 출력에서 답 JSON 객체를 꺼낸다.
/// (구조화 출력이 있으면 그것, 없으면 result 글에서 첫 '{'~마지막 '}')
Map<String, dynamic> parseCliOutput(String stdout) {
  final Map<String, dynamic> outer;
  try {
    outer = jsonDecode(stdout.trim()) as Map<String, dynamic>;
  } catch (_) {
    throw ClaudeCliException('Claude CLI 응답을 읽지 못했어요: ${_short(stdout)}');
  }
  if (outer['is_error'] == true) {
    throw ClaudeCliException('Claude CLI 오류: ${_short('${outer['result'] ?? outer['subtype']}')}');
  }
  final structured = outer['structured_output'];
  if (structured is Map<String, dynamic>) return structured;
  final text = '${outer['result'] ?? ''}';
  final a = text.indexOf('{'), b = text.lastIndexOf('}');
  if (a < 0 || b <= a) throw ClaudeCliException('AI 답에 JSON이 없어요: ${_short(text)}');
  try {
    return jsonDecode(text.substring(a, b + 1)) as Map<String, dynamic>;
  } catch (_) {
    throw ClaudeCliException('AI 답의 JSON을 읽지 못했어요: ${_short(text)}');
  }
}

String _short(String s) => s.length > 200 ? '${s.substring(0, 200)}…' : s;
