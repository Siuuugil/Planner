import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/capture_screen.dart';
import '../ui/kit.dart';
import 'app_store.dart';

/// 수집 결과 안내용 (공유로 들어올 땐 열린 화면이 없을 수 있어서 앱 전체 스낵바를 쓴다)
final captureMessenger = GlobalKey<ScaffoldMessengerState>();

void _toast(String msg) => captureMessenger.currentState
    ?.showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

/// Android: 다른 앱에서 "공유 → 마이플래너"로 보낸 글·링크를 📥 수집함(inbox 행)에 넣는다.
class ShareIntake {
  ShareIntake._(this.store);

  static const _channel = MethodChannel('myplanner/share');
  final AppStore store;

  /// Android가 아니면 아무것도 안 한다.
  static ShareIntake? start(AppStore store) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final s = ShareIntake._(store);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') await s._take();
    });
    s._take();
    return s;
  }

  Future<void> _take() async {
    try {
      final text = await _channel.invokeMethod<String>('takeShared');
      if (text == null) return;
      if (store.addCapture(text) != null) {
        // 첫 화면이 그려진 뒤에 안내
        WidgetsBinding.instance.addPostFrameCallback((_) => _toast('📥 수집함에 넣었어요'));
      }
    } on PlatformException catch (e) {
      debugPrint('share intake: $e');
    } on MissingPluginException {
      // 네이티브 쪽이 없는 환경 (테스트 등)
    }
  }
}

/// 📥 수집: 떠오른 생각이나 링크를 한 줄 적어 두면 PC 마을이 가져가 정리한다.
Future<void> showCaptureDialog(BuildContext context, AppStore store) async {
  final ctrl = TextEditingController();
  final messenger = ScaffoldMessenger.of(context);
  void submit(BuildContext dialog) {
    if (store.addCapture(ctrl.text) == null) return;
    Navigator.pop(dialog);
    messenger.showSnackBar(const SnackBar(content: Text('📥 수집함에 넣었어요'), duration: Duration(seconds: 2)));
  }

  await showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('📥 수집'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('생각·링크를 적어 두면 PC 마을이 디스코드로 물어보고 정리해요.',
              style: TextStyle(fontSize: 13, color: Ui.subtext)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('captureField'),
            controller: ctrl,
            autofocus: true,
            minLines: 1,
            maxLines: 5,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: '예: 이 글 나중에 읽기 https://…'),
            onSubmitted: (_) => submit(dialog),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(dialog);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CaptureScreen()));
          },
          child: const Text('최근 수집'),
        ),
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('취소')),
        FilledButton(onPressed: () => submit(dialog), child: const Text('넣기')),
      ],
    ),
  );
  ctrl.dispose();
}
