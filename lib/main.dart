import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/app_store.dart';
import 'data/store_scope.dart';
import 'data/sync_service.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  final store = await AppStore.open();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  final sync = SyncService(store, Supabase.instance.client);
  runApp(GamePlannerApp(store: store, sync: sync));
}

class GamePlannerApp extends StatelessWidget {
  const GamePlannerApp({super.key, required this.store, this.sync});

  final AppStore store;
  final SyncService? sync;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5C6BC0);
    final app = StoreScope(
      store: store,
      child: MaterialApp(
        title: '게임 플래너',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: seed,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const HomeShell(),
      ),
    );
    return sync == null ? app : SyncScope(sync: sync!, child: app);
  }
}
