/// 📥 수집 한 건 (`inbox` 행). 앱은 보여주기만 하고, 처리는 PC 마을이 한다.
class Capture {
  Capture({
    required this.id,
    required this.text,
    required this.source,
    required this.at,
    required this.done,
    required this.updatedAt,
  });

  final String id;
  final String text;

  /// 어디서 넣었는지 ('planner' 등)
  final String source;

  /// 넣은 시각 (UTC)
  final DateTime at;

  /// PC 마을이 처리함 (서버 행이 deleted)
  final bool done;

  /// 서버 행의 updated_at (최신 우선 병합용)
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'source': source,
        'at': at.toUtc().toIso8601String(),
        'done': done,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Capture.fromJson(Map<String, dynamic> j) => Capture(
        id: j['id'] as String,
        text: j['text'] as String,
        source: j['source'] as String? ?? '',
        at: DateTime.parse(j['at'] as String).toUtc(),
        done: j['done'] as bool? ?? false,
        updatedAt: DateTime.parse(j['updatedAt'] as String).toUtc(),
      );
}
