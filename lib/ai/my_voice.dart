import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// '내 목소리' 서버(PC의 voice_server/server.py)에 말을 시키는 클라이언트.
/// 서버는 127.0.0.1 에서만 열리니 PC 앱에서만 쓴다.
class MyVoice {
  MyVoice(this._prefs, {http.Client? client}) : _http = client ?? http.Client();

  static const _onKey = 'my_voice_on';
  static const _urlKey = 'my_voice_url';
  static const defaultUrl = 'http://127.0.0.1:9800';

  final SharedPreferences _prefs;
  final http.Client _http;

  static Future<MyVoice> open() async => MyVoice(await SharedPreferences.getInstance());

  /// 데스크톱 앱에서만 (웹·폰은 PC가 만든 음성 파일을 받아서 재생)
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  bool get enabled => _prefs.getBool(_onKey) ?? false;
  set enabled(bool v) => _prefs.setBool(_onKey, v);

  String get url => _prefs.getString(_urlKey) ?? defaultUrl;
  set url(String v) {
    final t = v.trim().replaceAll(RegExp(r'/+$'), '');
    _prefs.setString(_urlKey, t.isEmpty ? defaultUrl : t);
  }

  /// 연결 확인: "gptsovits · 감정 5개" 같은 설명
  Future<String> health() async {
    final res = await _http.get(Uri.parse('$url/health')).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) throw MyVoiceException('서버 응답 ${res.statusCode}');
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final emotions = (j['emotions'] as List? ?? []).join(', ');
    return '${j['engine']} 엔진 · 감정: $emotions · ${j['format']}';
  }

  /// 글 → 내 목소리 오디오 (mp3 또는 wav)
  Future<VoiceClip> speak(String text, String emotion) async {
    final res = await _http
        .post(Uri.parse('$url/speak'),
            headers: {'Content-Type': 'application/json'}, body: jsonEncode({'text': text, 'emotion': emotion}))
        .timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) {
      String msg = '서버 응답 ${res.statusCode}';
      try {
        msg = (jsonDecode(utf8.decode(res.bodyBytes)) as Map)['error'] as String? ?? msg;
      } catch (_) {}
      throw MyVoiceException(msg);
    }
    final mime = res.headers['content-type'] ?? 'audio/wav';
    return VoiceClip(res.bodyBytes, mime.contains('mpeg') ? 'mp3' : 'wav', mime);
  }
}

class VoiceClip {
  VoiceClip(this.bytes, this.ext, this.mime);

  final Uint8List bytes;
  final String ext;
  final String mime;
}

class MyVoiceException implements Exception {
  MyVoiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
