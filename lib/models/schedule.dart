/// 일반 일정 하나. [gameId]가 있으면 해당 게임과 연결된 일정(레이드, 이벤트 등)이다.
class Schedule {
  Schedule({
    required this.id,
    required this.title,
    required this.start,
    this.allDay = false,
    this.memo = '',
    this.done = false,
    this.gameId,
  });

  final String id;
  String title;
  DateTime start;
  bool allDay;
  String memo;
  bool done;
  String? gameId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start': start.toIso8601String(),
        'allDay': allDay,
        'memo': memo,
        'done': done,
        'gameId': gameId,
      };

  factory Schedule.fromJson(Map<String, dynamic> j) => Schedule(
        id: j['id'] as String,
        title: j['title'] as String,
        start: DateTime.parse(j['start'] as String),
        allDay: j['allDay'] as bool? ?? false,
        memo: j['memo'] as String? ?? '',
        done: j['done'] as bool? ?? false,
        gameId: j['gameId'] as String?,
      );
}
