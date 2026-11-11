/// 하루치 성장 기록.
class MapleSnapshot {
  MapleSnapshot({
    required this.date,
    required this.level,
    required this.expRate,
    this.combatPower,
  });

  /// 'yyyy-MM-dd' (한국 시간 기준)
  final String date;
  final int level;

  /// 경험치 % (0~100)
  final double expRate;
  final int? combatPower;

  /// 레벨 + 경험치 비율 (예: 276.45) — 그래프·목표용
  double get levelProgress => level + expRate / 100;

  Map<String, dynamic> toJson() => {
        'date': date,
        'level': level,
        'expRate': expRate,
        'combatPower': combatPower,
      };

  factory MapleSnapshot.fromJson(Map<String, dynamic> j) => MapleSnapshot(
        date: j['date'] as String,
        level: j['level'] as int,
        expRate: (j['expRate'] as num).toDouble(),
        combatPower: j['combatPower'] as int?,
      );
}

/// 넥슨 Open API로 불러온 메이플스토리 캐릭터.
class MapleCharacter {
  MapleCharacter({
    required this.id,
    required this.name,
    required this.ocid,
    this.world = '',
    this.job = '',
    this.level = 0,
    this.expRate = 0,
    this.combatPower,
    this.image = '',
    this.guild,
    this.updatedAt,
    List<MapleSnapshot>? history,
  }) : history = history ?? [];

  final String id;
  String name;
  String ocid;
  String world;
  String job;
  int level;
  double expRate;
  int? combatPower;
  String image;
  String? guild;
  DateTime? updatedAt;

  /// 날짜순 성장 기록 (하루 1개)
  final List<MapleSnapshot> history;

  double get levelProgress => level + expRate / 100;

  /// 같은 날짜 기록은 덮어쓰고 날짜순 유지.
  void putSnapshot(MapleSnapshot s) {
    history.removeWhere((h) => h.date == s.date);
    history.add(s);
    history.sort((a, b) => a.date.compareTo(b.date));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ocid': ocid,
        'world': world,
        'job': job,
        'level': level,
        'expRate': expRate,
        'combatPower': combatPower,
        'image': image,
        'guild': guild,
        'updatedAt': updatedAt?.toIso8601String(),
        'history': history.map((h) => h.toJson()).toList(),
      };

  factory MapleCharacter.fromJson(Map<String, dynamic> j) => MapleCharacter(
        id: j['id'] as String,
        name: j['name'] as String,
        ocid: j['ocid'] as String,
        world: j['world'] as String? ?? '',
        job: j['job'] as String? ?? '',
        level: j['level'] as int? ?? 0,
        expRate: (j['expRate'] as num? ?? 0).toDouble(),
        combatPower: j['combatPower'] as int?,
        image: j['image'] as String? ?? '',
        guild: j['guild'] as String?,
        updatedAt: j['updatedAt'] == null ? null : DateTime.parse(j['updatedAt'] as String),
        history: (j['history'] as List? ?? [])
            .map((e) => MapleSnapshot.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
