import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

import 'app_store.dart';

Future<String?> saveBackupFile(String name, String text) async {
  final bytes = Uint8List.fromList(utf8.encode(text));
  if (Platform.isAndroid || Platform.isIOS) {
    // 폰: 공유 시트로 (드라이브·카톡 나에게·파일 앱 등에 저장)
    final r = await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'application/json', name: name)],
      fileNameOverrides: [name],
      subject: '마이플래너 백업',
    ));
    return r.status == ShareResultStatus.dismissed ? null : '공유했어요: $name';
  }
  final loc = await getSaveLocation(
    suggestedName: name,
    acceptedTypeGroups: const [XTypeGroup(label: 'JSON', extensions: ['json'])],
  );
  if (loc == null) return null;
  await File(loc.path).writeAsBytes(bytes);
  return '저장했어요: ${loc.path}';
}

String? autoBackupDir() {
  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return null;
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (home == null) return null;
  return '$home${Platform.pathSeparator}Documents${Platform.pathSeparator}MyPlanner${Platform.pathSeparator}backups';
}

/// PC: 오늘 백업이 없으면 만들고, 14개 넘으면 오래된 것부터 지운다
Future<String?> autoBackup(AppStore store, String Function() exportText) async {
  final dir = autoBackupDir();
  if (dir == null) return null;
  final d = Directory(dir);
  await d.create(recursive: true);
  final now = DateTime.now();
  final day = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final f = File('$dir${Platform.pathSeparator}myplanner-$day.json');
  if (!await f.exists()) await f.writeAsString(exportText());
  final all = (await d.list().where((e) => e is File && e.path.endsWith('.json')).cast<File>().toList())
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final old in all.take(all.length > 14 ? all.length - 14 : 0)) {
    await old.delete();
  }
  return f.path;
}
