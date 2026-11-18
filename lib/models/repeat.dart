/// 반복 규칙 (일정·할 일 공통). 저장: {"freq":"weekly","interval":1,"until":"2026-12-31"}
enum RepeatFreq { daily, weekdays, weekly, monthly }

class Repeat {
  const Repeat(this.freq, {this.interval = 1, this.until});

  final RepeatFreq freq;

  /// 몇 번째마다 (격주 = weekly·2)
  final int interval;

  /// 이 날까지 (날짜만, 없으면 계속)
  final DateTime? until;

  /// 화면에 고를 수 있는 반복
  static const choices = <(String, Repeat?)>[
    ('반복 안 함', null),
    ('매일', Repeat(RepeatFreq.daily)),
    ('평일 (월~금)', Repeat(RepeatFreq.weekdays)),
    ('매주', Repeat(RepeatFreq.weekly)),
    ('격주', Repeat(RepeatFreq.weekly, interval: 2)),
    ('매월', Repeat(RepeatFreq.monthly)),
  ];

  String label(DateTime start) {
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    final base = switch (freq) {
      RepeatFreq.daily => interval == 1 ? '매일' : '$interval일마다',
      RepeatFreq.weekdays => '평일',
      RepeatFreq.weekly => '${interval == 1 ? '매주' : interval == 2 ? '격주' : '$interval주마다'} ${wd[start.weekday - 1]}요일',
      RepeatFreq.monthly => '${interval == 1 ? '매월' : '$interval개월마다'} ${start.day}일',
    };
    return until == null ? base : '$base · ${until!.month}/${until!.day}까지';
  }

  bool sameRule(Repeat? o) => o != null && o.freq == freq && o.interval == interval;

  static DateTime _d(DateTime t) => DateTime(t.year, t.month, t.day);

  /// [start]에 시작한 반복이 [day]에 해당하는지
  bool occursOn(DateTime start, DateTime day) {
    final s = _d(start), d = _d(day);
    if (d.isBefore(s)) return false;
    if (until != null && d.isAfter(_d(until!))) return false;
    final n = interval < 1 ? 1 : interval;
    switch (freq) {
      case RepeatFreq.daily:
        return d.difference(s).inDays % n == 0;
      case RepeatFreq.weekdays:
        return d.weekday <= DateTime.friday;
      case RepeatFreq.weekly:
        final days = d.difference(s).inDays;
        return d.weekday == s.weekday && (days ~/ 7) % n == 0;
      case RepeatFreq.monthly:
        final months = (d.year - s.year) * 12 + d.month - s.month;
        if (months % n != 0) return false;
        // 31일 시작인데 그 달이 짧으면 말일에
        final last = DateTime(d.year, d.month + 1, 0).day;
        return d.day == (s.day > last ? last : s.day);
    }
  }

  /// [after] 다음(그날 포함 안 함)의 첫 회차 날짜. 끝났으면 null
  DateTime? nextAfter(DateTime start, DateTime after) {
    var d = _d(after).add(const Duration(days: 1));
    if (d.isBefore(_d(start))) d = _d(start);
    for (var i = 0; i < 800; i++) {
      if (until != null && d.isAfter(_d(until!))) return null;
      if (occursOn(start, d)) return d;
      d = d.add(const Duration(days: 1));
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'freq': freq.name,
        if (interval != 1) 'interval': interval,
        if (until != null) 'until': '${until!.year}-${until!.month.toString().padLeft(2, '0')}-${until!.day.toString().padLeft(2, '0')}',
      };

  static Repeat? fromJson(Object? j) {
    if (j is! Map) return null;
    final f = RepeatFreq.values.where((e) => e.name == j['freq']).firstOrNull;
    if (f == null) return null;
    return Repeat(f,
        interval: (j['interval'] as num?)?.toInt() ?? 1,
        until: j['until'] is String ? DateTime.tryParse(j['until'] as String) : null);
  }
}

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
