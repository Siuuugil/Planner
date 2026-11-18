import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'app_store.dart';

Future<String?> saveBackupFile(String name, String text) async {
  final blob = web.Blob([text.toJS].toJS, web.BlobPropertyBag(type: 'application/json'));
  final url = web.URL.createObjectURL(blob);
  (web.HTMLAnchorElement()
        ..href = url
        ..download = name)
      .click();
  web.URL.revokeObjectURL(url);
  return '내려받기 폴더에 저장했어요: $name';
}

Future<String?> autoBackup(AppStore store, String Function() exportText) async => null;

String? autoBackupDir() => null;
