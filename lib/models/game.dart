enum ChorePeriod { daily, weekly }

/// 일일/주간 숙제. 게임의 초기화 시각이 지나면 자동으로 미완료 상태가 된다.
class Chore {
  Chore({
    required this.id,
    required this.title,
    required this.period,
    this.lastDone,
    this.bossId,
    this.partySize = 1,
    this.charName,
  });

  final String id;
  String title;
  ChorePeriod period;
  DateTime? lastDone;

  /// 보스 수확(결정석)이면 [Game.bosses]의 id. 주간 숙제로 취급된다.
  String? bossId;

  /// 파티 인원 — 결정석 판매 금액을 인원수로 나눈다.
  int partySize;

  /// 어느 캐릭터로 잡는지 (주간 결정석 판매 제한은 캐릭터별)
  String? charName;

  bool get isBoss => bossId != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'period': period.name,
        'lastDone': lastDone?.toIso8601String(),
        if (bossId != null) 'bossId': bossId,
        if (bossId != null) 'partySize': partySize,
        if (charName != null) 'charName': charName,
      };

  factory Chore.fromJson(Map<String, dynamic> j) => Chore(
        id: j['id'] as String,
        title: j['title'] as String,
        period: ChorePeriod.values.byName(j['period'] as String),
        lastDone: j['lastDone'] == null
            ? null
            : DateTime.parse(j['lastDone'] as String),
        bossId: j['bossId'] as String?,
        partySize: j['partySize'] as int? ?? 1,
        charName: j['charName'] as String?,
      );
}

/// 보스 결정석 판매 가격 (패치마다 바뀌므로 사용자가 입력·수정).
class BossPrice {
  BossPrice({required this.id, required this.name, this.price = 0, this.monthly = false});

  final String id;

  /// 예: '하드 루시드'
  String name;

  /// 결정석 1개 판매가 (메소)
  int price;

  /// 월간 보스 (검은 마법사 등)
  bool monthly;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        if (monthly) 'monthly': true,
      };

  factory BossPrice.fromJson(Map<String, dynamic> j) => BossPrice(
        id: j['id'] as String,
        name: j['name'] as String,
        price: j['price'] as int? ?? 0,
        monthly: j['monthly'] as bool? ?? false,
      );
}

/// 기본 결정석 가격표 (이름, 메소, 월간 여부)
/// 출처: matsu1207.tistory.com/757 "메이플스토리 보스 결정 가격 정리" (2026.10.16 수정, 10/22 변경가 반영)
/// 패치로 가격이 바뀌면 앱의 가격표에서 직접 고치면 된다.
const bossPriceTableDate = '2026.10.22';
const defaultBossPrices = <(String, int, bool)>[
  // 일반 보스
  ('이지 자쿰', 114000, false), ('노멀 자쿰', 349000, false), ('카오스 자쿰', 4040000, false),
  ('이지 매그너스', 411000, false), ('노멀 매그너스', 1160000, false), ('하드 매그너스', 4280000, false),
  ('노멀 힐라', 455000, false), ('하드 힐라', 1280000, false),
  ('카웅', 712000, false),
  ('이지 파풀라투스', 390000, false), ('노멀 파풀라투스', 1200000, false), ('카오스 파풀라투스', 6550000, false),
  ('노멀 피에르', 551000, false), ('카오스 피에르', 4080000, false),
  ('노멀 반반', 551000, false), ('카오스 반반', 4070000, false),
  ('노멀 블러디퀸', 551000, false), ('카오스 블러디퀸', 4070000, false),
  ('노멀 벨룸', 551000, false), ('카오스 벨룸', 4640000, false),
  ('이지 반 레온', 602000, false), ('노멀 반 레온', 830000, false), ('하드 반 레온', 1070000, false),
  ('이지 혼테일', 502000, false), ('노멀 혼테일', 576000, false), ('카오스 혼테일', 770000, false),
  ('이지 아카이럼', 656000, false), ('노멀 아카이럼', 1110000, false),
  ('노멀 핑크빈', 799000, false), ('카오스 핑크빈', 1320000, false),
  ('노멀 시그너스', 1360000, false),
  // 검밑솔
  ('노멀 스우', 8350000, false), ('하드 스우', 48900000, false), ('익스트림 스우', 545000000, false),
  ('노멀 데미안', 8750000, false), ('하드 데미안', 46400000, false),
  ('노멀 가디언 엔젤 슬라임', 12700000, false), ('카오스 가디언 엔젤 슬라임', 71300000, false),
  ('이지 루시드', 14900000, false), ('노멀 루시드', 17800000, false), ('하드 루시드', 59700000, false),
  ('이지 윌', 16100000, false), ('노멀 윌', 20500000, false), ('하드 윌', 73200000, false),
  ('노멀 더스크', 22000000, false), ('카오스 더스크', 66300000, false),
  ('노멀 진 힐라', 67600000, false), ('하드 진 힐라', 100000000, false),
  ('노멀 듄켈', 23700000, false), ('하드 듄켈', 89600000, false),
  ('하드 검은 마법사', 465000000, true), ('익스트림 검은 마법사', 5680000000, true),
  // 그란디스
  ('노멀 선택받은 세렌', 167000000, false), ('하드 선택받은 세렌', 302000000, false),
  ('익스트림 선택받은 세렌', 1840000000, false),
  ('이지 감시자 칼로스', 238000000, false), ('노멀 감시자 칼로스', 479000000, false),
  ('카오스 감시자 칼로스', 1230000000, false), ('익스트림 감시자 칼로스', 4104000000, false),
  ('이지 카링', 320000000, false), ('노멀 카링', 593000000, false), ('하드 카링', 1560000000, false),
  ('익스트림 카링', 4845000000, false),
  ('이지 최초의 대적자', 261000000, false), ('노멀 최초의 대적자', 532000000, false),
  ('하드 최초의 대적자', 1390000000, false), ('익스트림 최초의 대적자', 4712000000, false),
  ('이지 벨로나', 396000000, false), ('노멀 벨로나', 824000000, false), ('하드 벨로나', 2950000000, false),
  ('노멀 찬란한 흉성', 576000000, false), ('하드 찬란한 흉성', 2678000000, false),
  ('노멀 림보', 995000000, false), ('하드 림보', 2385000000, false), ('익스트림 림보', 7500000000, false),
  ('노멀 발드릭스', 1320000000, false), ('하드 발드릭스', 3078000000, false),
  ('익스트림 발드릭스', 9600000000, false),
  ('노멀 유피테르', 1560000000, false), ('하드 유피테르', 5387000000, false),
];

/// 주간 결정석 판매 제한 (캐릭터당)
const weeklyCrystalLimit = 14;

/// 스펙업 목표. 예: "아이템 레벨 1640 → 1680", current=1640, target=1680.
class Goal {
  Goal({
    required this.id,
    required this.title,
    this.start = 0,
    this.current = 0,
    required this.target,
    this.unit = '',
    this.deadline,
    this.autoCharId,
    this.autoMetric,
    this.autoSince,
  });

  final String id;
  String title;
  double start;
  double current;
  double target;
  String unit;
  DateTime? deadline;

  /// 메이플 캐릭터와 연결되면 [current]를 캐릭터 갱신 때 자동으로 채운다.
  String? autoCharId;

  /// 'level' (레벨+경험치%), 'combat' (전투력), 'crystal' (결정석 누적 수익)
  String? autoMetric;

  /// 'crystal' 목표: 이 주(주 시작일) 이후 수익만 합산
  String? autoSince;

  double get progress {
    final span = target - start;
    if (span == 0) return current >= target ? 1 : 0;
    return ((current - start) / span).clamp(0, 1).toDouble();
  }

  bool get achieved => progress >= 1;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start': start,
        'current': current,
        'target': target,
        'unit': unit,
        'deadline': deadline?.toIso8601String(),
        if (autoCharId != null) 'autoCharId': autoCharId,
        if (autoMetric != null) 'autoMetric': autoMetric,
        if (autoSince != null) 'autoSince': autoSince,
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String,
        title: j['title'] as String,
        start: (j['start'] as num? ?? 0).toDouble(),
        current: (j['current'] as num? ?? 0).toDouble(),
        target: (j['target'] as num).toDouble(),
        unit: j['unit'] as String? ?? '',
        deadline: j['deadline'] == null
            ? null
            : DateTime.parse(j['deadline'] as String),
        autoCharId: j['autoCharId'] as String?,
        autoMetric: j['autoMetric'] as String?,
        autoSince: j['autoSince'] as String?,
      );
}

class Game {
  Game({
    required this.id,
    required this.name,
    this.colorValue = 0xFF5C6BC0,
    this.resetHour = 6,
    this.weeklyResetWeekday = DateTime.wednesday,
    List<Goal>? goals,
    List<Chore>? chores,
    List<BossPrice>? bosses,
    Map<String, int>? crystalWeeks,
  })  : goals = goals ?? [],
        chores = chores ?? [],
        bosses = bosses ?? [],
        crystalWeeks = crystalWeeks ?? {};

  final String id;
  String name;
  int colorValue;

  /// 일일 초기화 시각 (0~23). 국내 게임은 대부분 오전 6시.
  int resetHour;

  /// 주간 초기화 요일 (DateTime.monday ~ DateTime.sunday).
  int weeklyResetWeekday;
  final List<Goal> goals;
  final List<Chore> chores;

  /// 보스 결정석 가격표
  final List<BossPrice> bosses;

  /// 주간 결정석 수익 기록: 주 시작일('yyyy-MM-dd') → 메소
  final Map<String, int> crystalWeeks;

  BossPrice? bossById(String? id) {
    for (final b in bosses) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// 기본 가격표 적용: 없는 보스는 추가, 같은 이름은 가격을 최신값으로. 바뀐 개수 반환.
  int applyDefaultBossPrices(String Function() newId) {
    var changed = 0;
    for (final (name, price, monthly) in defaultBossPrices) {
      final i = bosses.indexWhere((b) => b.name == name);
      if (i < 0) {
        bosses.add(BossPrice(id: newId(), name: name, price: price, monthly: monthly));
        changed++;
      } else if (bosses[i].price != price) {
        bosses[i].price = price;
        changed++;
      }
    }
    return changed;
  }

  /// 보스 1회 클리어 수익 (파티 인원으로 나눔)
  int bossIncome(Chore c) {
    final b = bossById(c.bossId);
    if (b == null) return 0;
    return b.price ~/ (c.partySize < 1 ? 1 : c.partySize);
  }

  /// 이번 주 키 (주간 초기화 기준 시작일)
  String weekKey(DateTime now) {
    final s = periodStart(ChorePeriod.weekly, now);
    return '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}';
  }

  /// 이번 주 결정석 수익을 다시 계산해 기록하고, 결정석 목표의 현재값을 맞춘다.
  void recomputeCrystals(DateTime now) {
    final boss = chores.where((c) => c.isBoss);
    final earned = boss.where((c) => isChoreDone(c, now)).fold<int>(0, (a, c) => a + bossIncome(c));
    final key = weekKey(now);
    if (earned > 0 || crystalWeeks.containsKey(key)) crystalWeeks[key] = earned;
    for (final g in goals) {
      if (g.autoMetric != 'crystal') continue;
      final since = g.autoSince ?? '';
      g.current = crystalWeeks.entries
          .where((e) => e.key.compareTo(since) >= 0)
          .fold<int>(0, (a, e) => a + e.value)
          .toDouble();
    }
  }
  /// [now] 기준으로 [period]가 시작된 시각.
  DateTime periodStart(ChorePeriod period, DateTime now) {
    var base = DateTime(now.year, now.month, now.day, resetHour);
    if (now.isBefore(base)) {
      base = DateTime(base.year, base.month, base.day - 1, resetHour);
    }
    if (period == ChorePeriod.weekly) {
      final back = (base.weekday - weeklyResetWeekday + 7) % 7;
      base = DateTime(base.year, base.month, base.day - back, resetHour);
    }
    return base;
  }

  bool isChoreDone(Chore c, DateTime now) =>
      c.lastDone != null && !c.lastDone!.isBefore(periodStart(c.period, now));

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'resetHour': resetHour,
        'weeklyResetWeekday': weeklyResetWeekday,
        'goals': goals.map((g) => g.toJson()).toList(),
        'chores': chores.map((c) => c.toJson()).toList(),
        if (bosses.isNotEmpty) 'bosses': bosses.map((b) => b.toJson()).toList(),
        if (crystalWeeks.isNotEmpty) 'crystalWeeks': crystalWeeks,
      };

  factory Game.fromJson(Map<String, dynamic> j) => Game(
        id: j['id'] as String,
        name: j['name'] as String,
        colorValue: j['colorValue'] as int? ?? 0xFF5C6BC0,
        resetHour: j['resetHour'] as int? ?? 6,
        weeklyResetWeekday:
            j['weeklyResetWeekday'] as int? ?? DateTime.wednesday,
        goals: (j['goals'] as List? ?? [])
            .map((e) => Goal.fromJson(e as Map<String, dynamic>))
            .toList(),
        chores: (j['chores'] as List? ?? [])
            .map((e) => Chore.fromJson(e as Map<String, dynamic>))
            .toList(),
        bosses: (j['bosses'] as List? ?? [])
            .map((e) => BossPrice.fromJson(e as Map<String, dynamic>))
            .toList(),
        crystalWeeks: (j['crystalWeeks'] as Map? ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
      );
}
