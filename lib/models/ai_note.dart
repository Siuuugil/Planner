/// AI 계획 속 한 칸 (시간대별)
class PlanBlock {
  PlanBlock({required this.start, required this.end, required this.title, this.kind = 'personal', this.note = ''});

  /// 'HH:mm'
  final String start;
  final String end;
  final String title;

  /// 'work' | 'personal' | 'game' | 'break'
  final String kind;
  final String note;

  Map<String, dynamic> toJson() => {'start': start, 'end': end, 'title': title, 'kind': kind, 'note': note};

  factory PlanBlock.fromJson(Map<String, dynamic> j) => PlanBlock(
        start: '${j['start'] ?? ''}',
        end: '${j['end'] ?? ''}',
        title: '${j['title'] ?? ''}',
        kind: '${j['kind'] ?? 'personal'}',
        note: '${j['note'] ?? ''}',
      );
}

/// AI가 만든 결과 (PC에서 만들고 모든 기기에서 본다)
class AiNote {
  AiNote({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.date,
    List<PlanBlock>? blocks,
    List<String>? bullets,
  })  : blocks = blocks ?? [],
        bullets = bullets ?? [];

  final String id;

  /// 'plan' | 'report' | 'coach' | 'chat'
  final String type;
  final String title;

  /// 본문 (요약·답변)
  final String body;
  final DateTime createdAt;

  /// 계획·리포트의 대상 날짜 'yyyy-MM-dd'
  final String? date;
  final List<PlanBlock> blocks;

  /// 짧은 팁·요점
  final List<String> bullets;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        if (date != null) 'date': date,
        if (blocks.isNotEmpty) 'blocks': blocks.map((b) => b.toJson()).toList(),
        if (bullets.isNotEmpty) 'bullets': bullets,
      };

  factory AiNote.fromJson(Map<String, dynamic> j) => AiNote(
        id: j['id'] as String,
        type: j['type'] as String,
        title: '${j['title'] ?? ''}',
        body: '${j['body'] ?? ''}',
        createdAt: DateTime.parse(j['createdAt'] as String),
        date: j['date'] as String?,
        blocks: [for (final b in (j['blocks'] as List? ?? [])) PlanBlock.fromJson(b as Map<String, dynamic>)],
        bullets: [for (final b in (j['bullets'] as List? ?? [])) '$b'],
      );
}
