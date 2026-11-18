import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai/ai_service.dart';
import 'ai/autopilot.dart';
import 'ai/my_voice.dart';
import 'ai/voice.dart';
import 'config.dart';
import 'data/app_store.dart';
import 'data/capture.dart';
import 'desktop/desktop_shell.dart';
import 'data/store_scope.dart';
import 'data/sync_service.dart';
import 'maple/maple_service.dart';
import 'notify/notify_service.dart';
import 'screens/account_screen.dart';
import 'screens/home_shell.dart';
import 'screens/settings_screen.dart' show runAutoBackup;
import 'ui/kit.dart';
import 'ui/theme_controller.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Windows: 트레이 상주 + 자동 실행 (다른 기기는 null)
  final desktop = await DesktopShell.start(args);
  await initializeDateFormatting('ko_KR');
  final store = await AppStore.open();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  final sync = SyncService(store, Supabase.instance.client);
  final notify = await NotifyService.start(store);
  // Android: 다른 앱에서 공유한 글·링크 → 📥 수집함
  ShareIntake.start(store);
  final supabase = Supabase.instance.client;
  final maple = await MapleService.open(
    store,
    // 웹은 브라우저가 넥슨 API 직접 호출을 막아서, 로그인 상태면 Supabase 중계 함수로 보낸다
    proxy: () => !kIsWeb || supabase.auth.currentUser == null
        ? null
        : (path, query, key) async {
            final res = await supabase.functions.invoke(
              'nexon-proxy',
              body: {'path': path, 'query': query, 'key': key},
            );
            final data = res.data as Map<String, dynamic>;
            return ((data['status'] as num).toInt(), data['body'] as String);
          },
  );
  // '내 목소리': PC가 답을 내 목소리로 만들어 Storage에 올리면, 모든 기기가 받아서 재생
  final myVoice = await MyVoice.open();
  const bucket = 'voice';
  final ai = await AiService.open(
    store,
    voiceMaker: !MyVoice.supported
        ? null
        : (id, text, emotion) async {
            final uid = supabase.auth.currentUser?.id;
            if (!myVoice.enabled || uid == null) return null;
            final clip = await myVoice.speak(text, emotion);
            final path = '$uid/${id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.${clip.ext}';
            await supabase.storage
                .from(bucket)
                .uploadBinary(path, clip.bytes, fileOptions: FileOptions(contentType: clip.mime, upsert: true));
            return path;
          },
    voiceRemover: (paths) => supabase.storage.from(bucket).remove(paths),
    // 내 목소리 서버가 켜진 PC가 폰 질문을 먼저 잡는다 (집 PC와 회사 노트북이 같이 켜져 있을 때)
    voiceReady: !MyVoice.supported
        ? null
        : () async {
            if (!myVoice.enabled || supabase.auth.currentUser == null) return false;
            try {
              await myVoice.health();
              return true;
            } catch (_) {
              return false;
            }
          },
  );
  // PC 앱: 아침 브리핑·월요일 리포트 자동 실행 (설정에서 켬)
  final autopilot = ai.supported ? (await Autopilot.open(store, ai)..start()) : null;
  final theme = await ThemeController.open();
  final voice = await VoiceService.open()
    ..resolveAudio = (path) async =>
        supabase.auth.currentUser == null ? null : supabase.storage.from(bucket).createSignedUrl(path, 600);
  // PC: 하루 한 번 자동 백업 (문서\\MyPlanner\\backups)
  unawaited(runAutoBackup(store));
  Timer.periodic(const Duration(hours: 6), (_) => runAutoBackup(store));
  runApp(MyPlannerApp(
      store: store, sync: sync, notify: notify, maple: maple, ai: ai, voice: voice, myVoice: myVoice, desktop: desktop, autopilot: autopilot, theme: theme));
  maple.refreshStale();
  if (maple.hasKey) unawaited(maple.loadEvents().then((_) {}, onError: (_) {}));
}

class MyPlannerApp extends StatelessWidget {
  const MyPlannerApp({super.key, required this.store, this.sync, this.notify, this.maple, this.ai, this.voice, this.myVoice, this.desktop, this.autopilot, this.theme});

  final AppStore store;
  final SyncService? sync;
  final NotifyService? notify;
  final MapleService? maple;
  final AiService? ai;
  final VoiceService? voice;
  final MyVoice? myVoice;
  final DesktopShell? desktop;
  final Autopilot? autopilot;
  final ThemeController? theme;

  @override
  Widget build(BuildContext context) {
    // 테마가 바뀌면 토큰(Ui.*)을 바꾸고 앱 전체를 새로 그린다 (key 로 다시 만들기)
    Widget materialApp() {
      Ui.dark = theme?.isDark ?? false;
      return MaterialApp(
        key: ValueKey(Ui.dark),
        title: '마이플래너',
        scaffoldMessengerKey: captureMessenger,
        debugShowCheckedModeBanner: false,
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: appTheme(),
        home: const PasswordRecoveryGate(child: HomeShell()),
      );
    }

    final app = StoreScope(
      store: store,
      child: theme == null ? materialApp() : ListenableBuilder(listenable: theme!, builder: (_, _) => materialApp()),
    );
    Widget root = app;
    if (notify != null) root = NotifyScope(notify: notify!, child: root);
    if (maple != null) root = MapleScope(maple: maple!, child: root);
    if (ai != null) root = AiScope(ai: ai!, child: root);
    if (autopilot != null) root = AutopilotScope(autopilot: autopilot!, child: root);
    if (voice != null) root = VoiceScope(voice: voice!, myVoice: myVoice, child: root);
    if (sync != null) root = SyncScope(sync: sync!, child: root);
    if (desktop != null) root = DesktopScope(shell: desktop!, child: root);
    if (theme != null) root = ThemeScope(theme: theme!, child: root);
    return root;
  }
}
