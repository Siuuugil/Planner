/// 서버 `items` 테이블의 한 행. 일정/게임 하나를 통째로 담는다.
class SyncRow {
  SyncRow({
    required this.id,
    required this.kind,
    required this.data,
    required this.deleted,
    required this.updatedAt,
  });

  final String id;

  /// 'schedule' 또는 'game'
  final String kind;
  final Map<String, dynamic>? data;
  final bool deleted;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'data': data,
        'deleted': deleted,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory SyncRow.fromJson(Map<String, dynamic> j) => SyncRow(
        id: j['id'] as String,
        kind: j['kind'] as String,
        data: (j['data'] as Map?)?.cast<String, dynamic>(),
        deleted: j['deleted'] as bool? ?? false,
        updatedAt: DateTime.parse(j['updated_at'] as String).toUtc(),
      );
}
