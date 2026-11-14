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
    List<Map<String, dynamic>>? actions,
    this.status,
    this.emotion,
    this.audio,
  })  : blocks = blocks ?? [],
        bullets = bullets ?? [],
        actions = actions ?? [];

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

  /// 대화: AI가 제안한 작업 (사용자가 확인하면 적용)
  final List<Map<String, dynamic>> actions;

  /// 폰·웹에서 보낸 대화 요청의 상태: 'pending'(PC 대기) · 'working'(PC가 답하는 중) · 'error'.
  /// 답이 끝나면 null.
  final String? status;

  /// 대화 답의 감정 (AI가 고름): neutral · happy · calm · sad · excited
  final String? emotion;

  /// '내 목소리'로 만든 음성 파일 (Supabase Storage 'voice' 버킷 경로)
  final String? audio;

  bool get waiting => status == 'pending' || status == 'working';

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        if (date != null) 'date': date,
        if (blocks.isNotEmpty) 'blocks': blocks.map((b) => b.toJson()).toList(),
        if (bullets.isNotEmpty) 'bullets': bullets,
        if (actions.isNotEmpty) 'actions': actions,
        if (status != null) 'status': status,
        if (emotion != null) 'emotion': emotion,
        if (audio != null) 'audio': audio,
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
        actions: [for (final a in (j['actions'] as List? ?? [])) (a as Map).cast<String, dynamic>()],
        status: j['status'] as String?,
        emotion: j['emotion'] as String?,
        audio: j['audio'] as String?,
      );

  AiNote withVoice({String? emotion, String? audio}) => AiNote(
        id: id, type: type, title: title, body: body, createdAt: createdAt, date: date,
        blocks: blocks, bullets: bullets, actions: actions, status: status,
        emotion: emotion ?? this.emotion, audio: audio ?? this.audio,
      );
}
