import 'dart:convert';

import 'package:http/http.dart' as http;

class NexonApiException implements Exception {
  NexonApiException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// 넥슨 Open API (메이플스토리) 최소 클라이언트.
/// https://openapi.nexon.com — 헤더 `x-nxopen-api-key`
class NexonApi {
  NexonApi(this.apiKey, {http.Client? client}) : _client = client ?? http.Client();

  static const _base = 'https://open.api.nexon.com/maplestory/v1';
  final String apiKey;
  final http.Client _client;

  Future<Map<String, dynamic>> _get(String path, Map<String, String> query) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: query);
    final http.Response res;
    try {
      res = await _client.get(uri, headers: {'x-nxopen-api-key': apiKey});
    } catch (e) {
      throw NexonApiException('넥슨 API에 연결하지 못했어요. 인터넷 연결을 확인해 주세요. '
          '(웹 버전에서는 브라우저 보안 정책으로 막힐 수 있어요)');
    }
    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode == 200) return jsonDecode(body) as Map<String, dynamic>;

    String? code;
    String? msg;
    try {
      final err = (jsonDecode(body) as Map<String, dynamic>)['error'] as Map<String, dynamic>;
      code = err['name'] as String?;
      msg = err['message'] as String?;
    } catch (_) {}
    throw NexonApiException(_friendly(code, res.statusCode) ?? msg ?? '오류 (${res.statusCode})', code: code);
  }

  static String? _friendly(String? code, int status) => switch (code) {
        'OPENAPI00001' => '넥슨 API 서버 오류예요. 잠시 후 다시 시도해 주세요.',
        'OPENAPI00002' => 'API 키 권한이 없어요. 메이플스토리 API가 허용된 키인지 확인해 주세요.',
        'OPENAPI00003' => '잘못된 캐릭터 정보예요.',
        'OPENAPI00004' => '캐릭터를 찾을 수 없어요. 닉네임을 확인해 주세요.',
        'OPENAPI00005' => 'API 키가 올바르지 않아요. 설정에서 키를 확인해 주세요.',
        'OPENAPI00006' => '사용할 수 없는 API예요.',
        'OPENAPI00007' => 'API 호출 한도를 넘었어요. 잠시 후 다시 시도해 주세요.',
        'OPENAPI00009' => '아직 준비되지 않은 데이터예요. 잠시 후 다시 시도해 주세요.',
        'OPENAPI00010' => '넥슨 API 점검 중이에요.',
        'OPENAPI00011' => '넥슨 API 점검 중이에요.',
        _ => status == 429 ? 'API 호출 한도를 넘었어요.' : null,
      };

  static Map<String, String> _date(String? date) => date == null ? {} : {'date': date};

  Future<String> ocid(String characterName) async =>
      (await _get('/id', {'character_name': characterName}))['ocid'] as String;

  Future<Map<String, dynamic>> basic(String ocid, {String? date}) =>
      _get('/character/basic', {'ocid': ocid, ..._date(date)});

  Future<Map<String, dynamic>> stat(String ocid, {String? date}) =>
      _get('/character/stat', {'ocid': ocid, ..._date(date)});

  Future<Map<String, dynamic>> itemEquipment(String ocid) =>
      _get('/character/item-equipment', {'ocid': ocid});

  /// final_stat 목록에서 '전투력'
  static int? combatPower(Map<String, dynamic> stat) {
    for (final s in (stat['final_stat'] as List? ?? [])) {
      final m = s as Map<String, dynamic>;
      if (m['stat_name'] == '전투력') {
        return int.tryParse('${m['stat_value']}'.split('.').first);
      }
    }
    return null;
  }

  static double expRate(Map<String, dynamic> basic) =>
      double.tryParse('${basic['character_exp_rate']}') ?? 0;
}
