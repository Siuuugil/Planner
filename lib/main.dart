import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/app_store.dart';
import 'data/store_scope.dart';
import 'data/sync_service.dart';
import 'notify/notify_service.dart';
import 'screens/home_shell.dart';
import 'ui/maple.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  final store = await AppStore.open();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  final sync = SyncService(store, Supabase.instance.client);
  final notify = await NotifyService.start(store);
  runApp(MyPlannerApp(store: store, sync: sync, notify: notify));
}

class MyPlannerApp extends StatelessWidget {
  const MyPlannerApp({super.key, required this.store, this.sync, this.notify});

  final AppStore store;
  final SyncService? sync;
  final NotifyService? notify;

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
        theme: mapleTheme(),
        home: const HomeShell(),
      ),
    );
    Widget root = app;
    if (notify != null) root = NotifyScope(notify: notify!, child: root);
    if (sync != null) root = SyncScope(sync: sync!, child: root);
    return root;
  }
}
