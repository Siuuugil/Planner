import 'app_store.dart';

/// 백업 글을 파일로 내보낸다. 저장한 곳(또는 안내 문구)을 돌려준다. 취소하면 null
Future<String?> saveBackupFile(String name, String text) async => null;

/// PC 자동 백업 (하루 한 번, 최근 14개). 지원 안 하면 null
Future<String?> autoBackup(AppStore store, String Function() exportText) async => null;

/// 자동 백업 폴더 (지원 안 하면 null)
String? autoBackupDir() => null;
