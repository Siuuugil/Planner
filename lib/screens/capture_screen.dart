import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/store_scope.dart';
import '../data/sync_service.dart';
import '../models/capture.dart';
import '../ui/kit.dart';

/// 📥 수집함: 한 줄 넣기 + 최근 수집과 PC 마을 처리 상태
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (StoreScope.read(context).addCapture(_ctrl.text) == null) return;
    _ctrl.clear();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('📥 수집함에 넣었어요'), duration: Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final signedOut = SyncScope.of(context)?.status == SyncStatus.signedOut;
    final list = store.recentCaptures;
    final waiting = list.where((c) => !c.done).length;
    return AppScaffold(
      title: '📥 수집함',
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        children: [
          AppSection(
            title: '넣기',
            icon: Icons.move_to_inbox_outlined,
            accent: Ui.accent,
            subtitle: '생각·링크를 적어 두면 PC 마을이 디스코드로 물어보고 정리해요. 다른 앱에서 공유 → 마이플래너도 돼요.',
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('captureScreenField'),
                    controller: _ctrl,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(hintText: '예: 이 글 나중에 읽기 https://…'),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _submit, child: const Text('넣기')),
              ],
            ),
          ),
          if (signedOut)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('로그인하지 않으면 이 기기에만 있고 PC 마을로 전달되지 않아요. (설정 → 계정)',
                  style: TextStyle(fontSize: 13, color: Ui.red)),
            ),
          AppSection(
            title: '최근 수집',
            trailing: list.isEmpty ? null : CountBadge(waiting == 0 ? '모두 처리됨' : '대기 $waiting'),
            child: list.isEmpty
                ? const EmptyHint('아직 수집한 게 없어요.')
                : Column(children: [for (final c in list) _CaptureRow(c, uploading: store.isCaptureUploading(c))]),
          ),
        ],
      ),
    );
  }
}

class _CaptureRow extends StatelessWidget {
  const _CaptureRow(this.c, {required this.uploading});

  final Capture c;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final (label, color) = c.done
        ? ('처리됨 ✓', Ui.green)
        : uploading
            ? ('올리는 중…', Ui.subtext)
            : ('PC 마을 대기', Ui.accent);
    final when = DateFormat('M/d HH:mm').format(c.at.toLocal());
    final from = c.source.isEmpty || c.source == 'planner' ? '' : ' · ${c.source}';
    return InkWell(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: c.text));
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('복사했어요'), duration: Duration(seconds: 1)));
      },
      child: Opacity(
        opacity: c.done ? 0.55 : 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$when$from · '),
                  TextSpan(text: label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                ]),
                style: const TextStyle(fontSize: 12, color: Ui.subtext),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
