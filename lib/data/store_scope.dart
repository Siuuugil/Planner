import 'package:flutter/widgets.dart';

import 'app_store.dart';

/// 위젯 트리에 [AppStore]를 제공하고, 변경 시 의존 위젯을 다시 그린다.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// 리빌드 의존성 없이 읽기만 할 때 (콜백 안 등).
  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
