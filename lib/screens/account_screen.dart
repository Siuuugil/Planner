import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/store_scope.dart';
import '../data/sync_service.dart';
import '../ui/maple.dart';

/// 로그인/회원가입 및 동기화 상태.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.of(context)!;
    return MapleScaffold(
      title: '계정 · 동기화',
      body: ListView(
        children: [
          MaplePanel(
            icon: sync.user == null ? '🔑' : '☁️',
            title: sync.user == null ? '로그인' : '동기화',
            child: sync.user == null ? _SignInForm(sync) : _SyncInfo(sync),
          ),
        ],
      ),
    );
  }
}

class _SignInForm extends StatefulWidget {
  const _SignInForm(this.sync);

  final SyncService sync;

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(bool signUp) async {
    final email = _email.text.trim();
    final pw = _password.text;
    if (email.isEmpty || pw.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final msg = signUp
        ? await widget.sync.signUp(email, pw)
        : await widget.sync.signIn(email, pw);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const Text('🍁', textAlign: TextAlign.center, style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(
          '로그인하면 폰과 PC의 일정·숙제·목표가 자동으로 맞춰져요.\n'
          '로그인 전에 만든 데이터도 계정으로 올라가요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: hint),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: '이메일'),
        ),
        TextField(
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(labelText: '비밀번호 (6자 이상)'),
          onSubmitted: (_) => _run(false),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : () => _run(false),
          child: const Text('로그인'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : () => _run(true),
          child: const Text('처음이에요 (회원가입)'),
        ),
        if (_busy) const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_message!, textAlign: TextAlign.center),
          ),
      ],
    );
  }
}

class _SyncInfo extends StatelessWidget {
  const _SyncInfo(this.sync);

  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final (icon, label) = switch (sync.status) {
      SyncStatus.syncing => (Icons.sync, '동기화 중…'),
      SyncStatus.synced => (Icons.cloud_done_outlined, '동기화 완료'),
      SyncStatus.failed => (Icons.cloud_off_outlined, '동기화 실패 (인터넷 연결 확인)'),
      SyncStatus.signedOut => (Icons.cloud_outlined, '로그아웃됨'),
    };
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(sync.user!.email ?? ''),
          subtitle: const Text('로그인됨'),
        ),
        ListTile(
          leading: Icon(icon),
          title: Text(label),
          subtitle: Text([
            if (sync.lastSynced != null)
              '마지막: ${DateFormat('M/d HH:mm:ss').format(sync.lastSynced!)}',
            if (store.pending.isNotEmpty) '올릴 변경 ${store.pending.length}건',
          ].join(' · ')),
        ),
        if (sync.lastError != null && sync.status == SyncStatus.failed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              sync.lastError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: sync.status == SyncStatus.syncing ? null : sync.sync,
          icon: const Icon(Icons.sync),
          label: const Text('지금 동기화'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('로그아웃'),
                content: Text(store.pending.isEmpty
                    ? '이 기기의 데이터가 지워져요. 서버에 저장된 데이터는 다시 로그인하면 돌아와요.'
                    : '아직 올라가지 않은 변경 ${store.pending.length}건이 사라져요. 그래도 로그아웃할까요?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('로그아웃')),
                ],
              ),
            );
            if (ok == true) await sync.signOut();
          },
          child: const Text('로그아웃'),
        ),
      ],
    );
  }
}

/// 앱바에 넣는 동기화 상태 아이콘. 누르면 계정 화면.
class SyncButton extends StatelessWidget {
  const SyncButton({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.of(context);
    if (sync == null) return const SizedBox.shrink();
    final icon = switch (sync.status) {
      SyncStatus.signedOut => Icons.cloud_outlined,
      SyncStatus.syncing => Icons.sync,
      SyncStatus.synced => Icons.cloud_done_outlined,
      SyncStatus.failed => Icons.cloud_off_outlined,
    };
    return IconButton(
      tooltip: '계정 · 동기화',
      icon: Icon(icon),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AccountScreen()),
      ),
    );
  }
}
