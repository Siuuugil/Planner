import 'package:flutter/material.dart';

import '../maple/maple_service.dart';
import '../maple/nexon_api.dart';
import '../models/game.dart';
import '../models/maple_character.dart';
import '../ui/kit.dart';

/// 85321234 → '8532만', 123456789 → '1억 2345만'
String koreanNumber(num v) {
  final n = v.round();
  if (n.abs() < 10000) return '$n';
  final eok = n ~/ 100000000;
  final man = (n % 100000000) ~/ 10000;
  if (eok == 0) return '$man만';
  return man == 0 ? '$eok억' : '$eok억 $man만';
}

/// 넥슨 서버의 캐릭터·아이템 이미지 (도트 느낌 그대로 확대)
class NexonImage extends StatelessWidget {
  const NexonImage(this.url, {super.key, this.size = 64});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? const Center(child: Text('🍁', style: TextStyle(fontSize: 28)))
            : Image.network(
                url,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                errorBuilder: (_, _, _) =>
                    const Center(child: Text('🍁', style: TextStyle(fontSize: 28))),
              ),
      );
}

/// 목록용 한 줄 캐릭터 정보.
class CharacterRow extends StatelessWidget {
  const CharacterRow({super.key, required this.character, this.onTap, this.busy = false});

  final MapleCharacter character;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = character;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Ui.field,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Ui.subtext, width: 1.5),
              ),
              child: NexonImage(c.image, size: 64),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(c.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 6),
                      Text('Lv.${c.level}', style: const TextStyle(color: Ui.accent, fontSize: 16)),
                      if (busy) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                            width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ],
                  ),
                  Text('${c.world} · ${c.job}',
                      style: const TextStyle(color: Ui.subtext, fontSize: 13)),
                  const SizedBox(height: 4),
                  GaugeBar(value: c.expRate / 100, height: 14, label: 'EXP ${c.expRate.toStringAsFixed(3)}%'),
                  if (c.combatPower != null) ...[
                    const SizedBox(height: 3),
                    Text('⚔️ 전투력 ${koreanNumber(c.combatPower!)}', style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 닉네임 검색 → 미리보기 → 추가.
Future<void> showCharacterSearch(BuildContext context, MapleService maple) =>
    showDialog(context: context, builder: (_) => _SearchDialog(maple));

class _SearchDialog extends StatefulWidget {
  const _SearchDialog(this.maple);

  final MapleService maple;

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;
  MapleLookup? _found;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _found = null;
    });
    try {
      final r = await widget.maple.search(n);
      if (!mounted) return;
      setState(() => _found = r);
    } on NexonApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final already = _found != null &&
        widget.maple.store.characters.any((c) => c.ocid == _found!.character.ocid);
    return AlertDialog(
      title: const Text('🔍 캐릭터 검색'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: '닉네임'),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _busy ? null : _search, child: const Text('검색')),
              ],
            ),
            const SizedBox(height: 12),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (_found != null)
              Container(
                decoration: BoxDecoration(
                  color: Ui.field,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Ui.subtext, width: 1.5),
                ),
                child: CharacterRow(character: _found!.character),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
        if (_found != null)
          FilledButton(
            onPressed: already
                ? null
                : () {
                    widget.maple.add(_found!);
                    Navigator.pop(context);
                  },
            child: Text(already ? '이미 추가됨' : '내 캐릭터로 추가'),
          ),
      ],
    );
  }
}

/// 보스 아이콘 (게임 내 25px 아이콘을 도트 그대로 확대). [dim]이면 흑백·반투명.
class BossIcon extends StatelessWidget {
  const BossIcon(this.boss, {super.key, this.size = 40, this.dim = false});

  /// '루시드' 처럼 난이도 없는 보스 이름 ('하드 루시드'도 받아서 잘라 쓴다)
  final String boss;
  final double size;
  final bool dim;

  static const _grey = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final name = splitBossName(boss).$2;
    final icon = bossIconOf(name);
    Widget child = icon == null
        ? Center(
            child: Text(name.characters.first,
                style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w800, color: Ui.subtext)),
          )
        : Image.asset(
            'assets/bosses/$icon.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          );
    if (dim) child = Opacity(opacity: 0.45, child: ColorFiltered(colorFilter: _grey, child: child));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Ui.field,
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(color: dim ? Ui.line : const Color(0x22000000)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
