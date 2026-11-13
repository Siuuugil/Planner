import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/app_store.dart';
import 'data/store_scope.dart';
import 'data/sync_service.dart';
import 'maple/maple_service.dart';
import 'notify/notify_service.dart';
import 'screens/account_screen.dart';
import 'screens/home_shell.dart';
import 'ui/kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  final store = await AppStore.open();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  final sync = SyncService(store, Supabase.instance.client);
  final notify = await NotifyService.start(store);
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
  runApp(MyPlannerApp(store: store, sync: sync, notify: notify, maple: maple));
  maple.refreshStale();
}

class MyPlannerApp extends StatelessWidget {
  const MyPlannerApp({super.key, required this.store, this.sync, this.notify, this.maple});

  final AppStore store;
  final SyncService? sync;
  final NotifyService? notify;
  final MapleService? maple;

  @override
  Widget build(BuildContext context) {
    final app = StoreScope(
      store: store,
      child: MaterialApp(
        title: '마이플래너',
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
      ),
    );
    Widget root = app;
    if (notify != null) root = NotifyScope(notify: notify!, child: root);
    if (maple != null) root = MapleScope(maple: maple!, child: root);
    if (sync != null) root = SyncScope(sync: sync!, child: root);
    return root;
  }
}
