import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'my_voice.dart';

/// 음성 대화: 말하기(음성 인식) + 듣기(답 읽어주기)
/// - 음성 인식: Android·웹(Chrome)·애플 기기. Windows 인식기는 한국어가 없어서 Win+H 안내.
/// - 읽어주기: 모든 기기
class VoiceService extends ChangeNotifier {
  VoiceService(this._prefs);

  static const _speakKey = 'voice_speak_replies';
  static const _handsFreeKey = 'voice_hands_free';
  final SharedPreferences _prefs;
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  AudioPlayer? _player;

  /// '내 목소리' 음성 파일 경로 → 재생할 주소 (main에서 Supabase 서명 URL로 연결)
  Future<String?> Function(String audio)? resolveAudio;

  bool _sttReady = false;
  bool _ttsReady = false;
  bool listening = false;
  bool speaking = false;

  /// 듣는 중에 지금까지 알아들은 말
  String partial = '';
  String? error;

  static Future<VoiceService> open() async => VoiceService(await SharedPreferences.getInstance());

  /// 이 기기에서 한국어 음성 인식을 쓸 수 있는지
  static bool get sttSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  bool get speakReplies => _prefs.getBool(_speakKey) ?? true;

  set speakReplies(bool v) {
    _prefs.setBool(_speakKey, v);
    if (!v) stopSpeaking();
    notifyListeners();
  }

  /// 답을 다 읽으면 자동으로 다시 듣기
  bool get handsFree => _prefs.getBool(_handsFreeKey) ?? false;

  set handsFree(bool v) {
    _prefs.setBool(_handsFreeKey, v);
    notifyListeners();
  }

  Future<bool> _initStt() async {
    if (_sttReady) return true;
    if (!sttSupported) return false;
    try {
      _sttReady = await _stt.initialize(
        onError: (e) {
          error = e.errorMsg == 'error_no_match' ? '잘 못 들었어요. 다시 말해 주세요.' : '음성 인식 오류: ${e.errorMsg}';
          listening = false;
          notifyListeners();
        },
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') {
            listening = false;
            notifyListeners();
          }
        },
      );
    } catch (e) {
      _sttReady = false;
      error = '마이크를 쓸 수 없어요: $e';
    }
    if (!_sttReady) error ??= '이 기기에서 음성 인식을 쓸 수 없어요 (마이크 권한을 확인해 주세요).';
    return _sttReady;
  }

  Future<void> _initTts() async {
    if (_ttsReady) return;
    try {
      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate(kIsWeb ? 1.0 : 0.5);
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
    _ttsReady = true;
  }

  /// 한 번 듣고, 말이 끝나면 [onFinal]로 문장을 넘긴다.
  Future<void> listen(void Function(String text) onFinal) async {
    error = null;
    partial = '';
    await stopSpeaking();
    if (!await _initStt()) {
      notifyListeners();
      return;
    }
    listening = true;
    notifyListeners();
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) {
        partial = r.recognizedWords;
        notifyListeners();
        if (r.finalResult) {
          listening = false;
          notifyListeners();
          if (r.recognizedWords.trim().isNotEmpty) onFinal(r.recognizedWords.trim());
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: 'ko_KR',
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 2),
        listenFor: const Duration(seconds: 30),
        partialResults: true,
      ),
    );
  }

  Future<void> stopListening() async {
    await _stt.stop();
    listening = false;
    notifyListeners();
  }

  /// 읽어주기 (끝날 때까지 기다린다). [audio]가 있으면 내 목소리 파일, 안 되면 기본 음성.
  Future<void> speak(String text, {String? audio}) async {
    if (text.trim().isEmpty) return;
    speaking = true;
    notifyListeners();
    try {
      if (audio == null || !await _playAudio(audio)) {
        await _initTts();
        await _tts.speak(spokenText(text));
      }
    } catch (_) {
    } finally {
      speaking = false;
      notifyListeners();
    }
  }

  Future<bool> _playAudio(String audio) async {
    try {
      final url = await resolveAudio?.call(audio);
      if (url == null) return false;
      final p = _player ??= AudioPlayer();
      final done = p.onPlayerComplete.first;
      await p.play(UrlSource(url));
      // 사용자가 '그만'을 누르면 stop → 완료 이벤트가 안 올 수 있어서 상태도 같이 본다
      await Future.any([
        done,
        p.onPlayerStateChanged.firstWhere((s) => s == PlayerState.stopped),
      ]).timeout(const Duration(minutes: 3));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stopSpeaking() async {
    if (!speaking) return;
    try {
      await _tts.stop();
      await _player?.stop();
    } catch (_) {}
    speaking = false;
    notifyListeners();
  }
}

/// 읽어줄 때 이모지·기호 정리
String spokenText(String s) => s
    .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true), '')
    .replaceAll(RegExp(r'[*#`>·→]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class VoiceScope extends InheritedNotifier<VoiceService> {
  const VoiceScope({super.key, required VoiceService voice, this.myVoice, required super.child})
      : super(notifier: voice);

  /// PC의 '내 목소리' 서버 설정 (PC 앱에서만)
  final MyVoice? myVoice;

  static MyVoice? myVoiceOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VoiceScope>()?.myVoice;

  static VoiceService? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VoiceScope>()?.notifier;
}
