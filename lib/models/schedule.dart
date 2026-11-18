import 'repeat.dart';

/// 일반 일정 하나. [gameId]가 있으면 해당 게임과 연결된 일정(레이드, 이벤트 등)이다.
/// [repeat]이 있으면 반복 일정: 저장은 한 번(시작일 + 규칙), 날짜마다 [occurrence]로 펼쳐서 보여 준다.
class Schedule {
  Schedule({
    required this.id,
    required this.title,
    required this.start,
    this.allDay = false,
    this.memo = '',
    this.done = false,
    this.gameId,
    this.repeat,
    Set<String>? doneDates,
    Set<String>? skipDates,
    Map<String, dynamic>? extra,
  })  : doneDates = doneDates ?? {},
        skipDates = skipDates ?? {},
        extra = extra ?? {};

  final String id;
  String title;
  DateTime start;
  bool allDay;
  String memo;

  /// 반복이 아닐 때의 완료. 반복 일정은 [doneDates]
  bool done;
  String? gameId;
  Repeat? repeat;

  /// 반복 일정에서 끝낸 날짜들 'yyyy-MM-dd'
  final Set<String> doneDates;

  /// 반복 일정에서 뺀 날짜들 (이날만 삭제)
  final Set<String> skipDates;

  /// 이 버전이 모르는 필드 (다른 앱·새 버전이 넣은 것) — 그대로 다시 저장해서 지워지지 않게
  final Map<String, dynamic> extra;

  static const _known = {'id', 'title', 'start', 'allDay', 'memo', 'done', 'gameId', 'repeat', 'doneDates', 'skipDates'};

  /// 펼친 회차라면 원래 일정 (저장하지 않음)
  Schedule? series;

  bool get isRepeat => repeat != null;

  /// 저장된 원래 일정 (회차면 시리즈, 아니면 자기)
  Schedule get root => series ?? this;

  /// [day]에 열리는지 (반복 포함)
  bool occursOn(DateTime day) => repeat == null
      ? start.year == day.year && start.month == day.month && start.day == day.day
      : !skipDates.contains(dayKey(day)) && repeat!.occursOn(start, day);

  /// [day] 회차 (반복 아니면 자기 자신)
  Schedule occurrence(DateTime day) {
    if (repeat == null) return this;
    final o = Schedule(
      id: id,
      title: title,
      start: DateTime(day.year, day.month, day.day, start.hour, start.minute),
      allDay: allDay,
      memo: memo,
      done: doneDates.contains(dayKey(day)),
      gameId: gameId,
      repeat: repeat,
      doneDates: doneDates,
      skipDates: skipDates,
    );
    o.series = this;
    return o;
  }

  /// 완료 표시 (반복이면 그 날짜만)
  void setDone(bool v) {
    final r = root;
    if (r.repeat == null) {
      r.done = v;
      done = v;
      return;
    }
    final k = dayKey(start);
    v ? r.doneDates.add(k) : r.doneDates.remove(k);
    done = v;
  }

  Map<String, dynamic> toJson() => {
        ...extra,
        'id': id,
        'title': title,
        'start': start.toIso8601String(),
        'allDay': allDay,
        'memo': memo,
        'done': done,
        'gameId': gameId,
        if (repeat != null) 'repeat': repeat!.toJson(),
        if (doneDates.isNotEmpty) 'doneDates': (doneDates.toList()..sort()),
        if (skipDates.isNotEmpty) 'skipDates': (skipDates.toList()..sort()),
      };

  factory Schedule.fromJson(Map<String, dynamic> j) => Schedule(
        id: j['id'] as String,
        title: j['title'] as String,
        start: DateTime.parse(j['start'] as String),
        allDay: j['allDay'] as bool? ?? false,
        memo: j['memo'] as String? ?? '',
        done: j['done'] as bool? ?? false,
        gameId: j['gameId'] as String?,
        repeat: Repeat.fromJson(j['repeat']),
        doneDates: {for (final d in (j['doneDates'] as List? ?? [])) '$d'},
        skipDates: {for (final d in (j['skipDates'] as List? ?? [])) '$d'},
        extra: {for (final e in j.entries) if (!_known.contains(e.key)) e.key: e.value},
      );
}
