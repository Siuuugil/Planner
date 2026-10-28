import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_store.dart';
import 'sync_row.dart';

enum SyncStatus { signedOut, syncing, synced, failed }

/// 로그인한 계정의 Supabase `items` 테이블과 [AppStore]를 맞춘다.
/// - 로그인/앱 복귀/로컬 변경 시: 전체 받아서 병합 → 대기 중 변경 업로드
/// - 다른 기기의 변경은 Realtime으로 즉시 반영
class SyncService extends ChangeNotifier {
  SyncService(this.store, this.client) {
    store.onLocalChange = _schedulePush;
    _authSub = client.auth.onAuthStateChange.listen((_) => _onAuthChanged());
    _lifecycle = AppLifecycleListener(onResume: sync);
    _retry = Timer.periodic(const Duration(minutes: 1), (_) {
      if (store.pending.isNotEmpty) sync();
    });
    _onAuthChanged();
  }

  final AppStore store;
  final SupabaseClient client;

  late final StreamSubscription<AuthState> _authSub;
  late final AppLifecycleListener _lifecycle;
  late final Timer _retry;
  Timer? _debounce;
  RealtimeChannel? _channel;
  String? _subscribedUid;
  bool _running = false;
  bool _again = false;

  SyncStatus status = SyncStatus.signedOut;
  String? lastError;
  DateTime? lastSynced;

  User? get user => client.auth.currentUser;

  void _onAuthChanged() {
    final uid = user?.id;
    if (uid == _subscribedUid) return;
    _subscribedUid = uid;
    _channel?.unsubscribe();
    _channel = null;
    if (uid == null) {
      status = SyncStatus.signedOut;
      notifyListeners();
      return;
    }
    if (store.ownerId != null && store.ownerId != uid) store.clearAll();
    store.setOwner(uid);
    _channel = client
        .channel('items-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (p) {
            if (p.newRecord.isNotEmpty) {
              store.applyRemote([SyncRow.fromJson(p.newRecord)]);
            }
          },
        )
        .subscribe();
    sync();
  }

  void _schedulePush() {
    if (user == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), sync);
  }

  Future<void> sync() async {
    if (user == null) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    status = SyncStatus.syncing;
    notifyListeners();
    try {
      final rows = await client
          .from('items')
          .select('id, kind, data, deleted, updated_at');
      store.applyRemote(rows.map(SyncRow.fromJson));

      final batch = store.pending.values.toList();
      if (batch.isNotEmpty) {
        await client.from('items').upsert(
              [
                for (final r in batch) {...r.toJson(), 'user_id': user!.id},
              ],
              onConflict: 'user_id,id',
            );
        store.markPushed(batch);
      }
      status = SyncStatus.synced;
      lastError = null;
      lastSynced = DateTime.now();
    } catch (e) {
      status = SyncStatus.failed;
      lastError = '$e';
    } finally {
      _running = false;
      notifyListeners();
    }
    if (_again) {
      _again = false;
      await sync();
    }
  }

  /// 성공 시 null, 아니면 사용자에게 보여줄 메시지.
  Future<String?> signIn(String email, String password) async {
    try {
      await client.auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return _authMessage(e);
    } catch (e) {
      return '연결 실패: $e';
    }
  }

  Future<String?> signUp(String email, String password) async {
    try {
      final res = await client.auth.signUp(email: email, password: password);
      if (res.session == null) {
        return '확인 메일을 보냈어요. 메일의 링크를 누른 뒤 로그인해 주세요.';
      }
      return null;
    } on AuthException catch (e) {
      return _authMessage(e);
    } catch (e) {
      return '연결 실패: $e';
    }
  }

  /// 로그아웃하면 이 기기의 데이터는 지운다 (서버에는 남아 있음).
  Future<void> signOut() async {
    await client.auth.signOut();
    store.clearAll();
  }

  String _authMessage(AuthException e) => switch (e.code) {
        'invalid_credentials' => '이메일 또는 비밀번호가 틀렸어요.',
        'email_not_confirmed' => '메일함에서 가입 확인 링크를 먼저 눌러 주세요.',
        'user_already_exists' => '이미 가입된 이메일이에요. 로그인해 주세요.',
        'weak_password' => '비밀번호가 너무 약해요 (6자 이상).',
        'over_email_send_rate_limit' => '메일 발송 한도 초과. 잠시 후 다시 시도해 주세요.',
        _ => e.message,
      };

  @override
  void dispose() {
    _authSub.cancel();
    _lifecycle.dispose();
    _retry.cancel();
    _debounce?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }
}

class SyncScope extends InheritedNotifier<SyncService> {
  const SyncScope({super.key, required SyncService sync, required super.child})
      : super(notifier: sync);

  /// 동기화 미설정(테스트 등)이면 null.
  static SyncService? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SyncScope>()?.notifier;
}
