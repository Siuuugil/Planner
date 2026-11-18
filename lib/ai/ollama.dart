import 'dart:convert';

import 'package:http/http.dart' as http;

import 'claude_cli.dart' show ClaudeCliException;

/// PC의 Ollama(로컬 모델)로 묻기. 대화 엔진을 '로컬'로 고르면 대화만 이걸로 답한다.
/// 실패는 Claude 와 같은 [ClaudeCliException]으로 알려서 화면 처리를 같이 쓴다.
class OllamaClient {
  OllamaClient({this.url = 'http://127.0.0.1:11434', http.Client? client}) : _http = client ?? http.Client();

  final String url;
  final http.Client _http;

  String get _base => url.replaceAll(RegExp(r'/+$'), '');

  /// 설치된 모델 이름들
  Future<List<String>> models() async {
    final res = await _http.get(Uri.parse('$_base/api/tags')).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) throw ClaudeCliException('Ollama 응답 ${res.statusCode}');
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return [for (final m in (j['models'] as List? ?? [])) if (m is Map) '${m['name']}'];
  }

  /// 프롬프트 하나를 보내고 JSON 객체로 받는다 (format: json, 생각 끔)
  Future<Map<String, dynamic>> ask(String model, String prompt) async {
    if (model.trim().isEmpty) throw ClaudeCliException('설정에서 Ollama 모델을 골라 주세요');
    final http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse('$_base/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
              'stream': false,
              'format': 'json',
              'think': false,
              'options': {'temperature': 0.8},
            }),
          )
          .timeout(const Duration(minutes: 3));
    } catch (e) {
      throw ClaudeCliException('Ollama에 연결하지 못했어요 ($_base). Ollama가 켜져 있는지 확인해 주세요.');
    }
    if (res.statusCode != 200) {
      var msg = 'Ollama 응답 ${res.statusCode}';
      try {
        msg = '${(jsonDecode(utf8.decode(res.bodyBytes)) as Map)['error'] ?? msg}';
      } catch (_) {}
      throw ClaudeCliException(msg);
    }
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final content = '${(j['message'] as Map?)?['content'] ?? ''}';
    return parseJsonObject(content);
  }
}

/// 모델 답에서 JSON 객체 꺼내기 (앞뒤 군더더기·<think> 블록·코드블록이 있어도)
Map<String, dynamic> parseJsonObject(String text) {
  var t = text.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();
  final a = t.indexOf('{'), b = t.lastIndexOf('}');
  if (a < 0 || b <= a) {
    // JSON 을 안 지키고 그냥 말로 답했으면 그 말을 답으로
    if (t.isNotEmpty) return {'reply': t};
    throw ClaudeCliException('로컬 모델이 빈 답을 줬어요');
  }
  t = t.substring(a, b + 1);
  try {
    return (jsonDecode(t) as Map).cast<String, dynamic>();
  } catch (_) {
    return {'reply': text.trim()};
  }
}
