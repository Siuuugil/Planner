/// 장착한 심볼 하나 (넥슨 symbol-equipment)
class MapleSymbol {
  MapleSymbol({required this.name, required this.level, this.growth = 0, this.require = 0, this.icon = ''});

  final String name;
  final int level;

  /// 지금 모은 성장치 / 다음 레벨에 필요한 성장치
  final int growth;
  final int require;
  final String icon;

  bool get isArcane => name.contains('아케인');
  bool get isGrand => name.contains('그랜드');
  bool get isAuthentic => name.contains('어센틱') && !isGrand;

  /// 만렙: 아케인 20, 어센틱·그랜드 어센틱 11
  int get maxLevel => isArcane ? 20 : 11;
  bool get isMax => level >= maxLevel;

  /// 지역 이름 ('아케인심볼 : 소멸의 여로' → '소멸의 여로')
  String get region => name.contains(':') ? name.split(':').last.trim() : name;

  /// 레벨 n → n+1 에 필요한 성장치 (공식이 알려진 것만: 아케인 n²+11, 어센틱 9n²+20n)
  static int? requireFor(MapleSymbol s, int n) => s.isArcane
      ? n * n + 11
      : s.isAuthentic
          ? 9 * n * n + 20 * n
          : null;

  /// 만렙까지 남은 성장치 (공식이 없는 그랜드 어센틱은 null)
  int? get toMax {
    if (isMax) return 0;
    var total = (require > 0 ? require : (requireFor(this, level) ?? 0)) - growth;
    for (var n = level + 1; n < maxLevel; n++) {
      final r = requireFor(this, n);
      if (r == null) return null;
      total += r;
    }
    return total < 0 ? 0 : total;
  }

  Map<String, dynamic> toJson() => {'name': name, 'level': level, 'growth': growth, 'require': require, 'icon': icon};

  factory MapleSymbol.fromJson(Map<String, dynamic> j) => MapleSymbol(
        name: '${j['name'] ?? ''}',
        level: (j['level'] as num?)?.toInt() ?? 0,
        growth: (j['growth'] as num?)?.toInt() ?? 0,
        require: (j['require'] as num?)?.toInt() ?? 0,
        icon: '${j['icon'] ?? ''}',
      );

  /// 넥슨 응답 한 줄
  factory MapleSymbol.fromNexon(Map<String, dynamic> j) => MapleSymbol(
        name: '${j['symbol_name'] ?? ''}',
        level: (j['symbol_level'] as num?)?.toInt() ?? 0,
        growth: (j['symbol_growth_count'] as num?)?.toInt() ?? 0,
        require: (j['symbol_require_growth_count'] as num?)?.toInt() ?? 0,
        icon: '${j['symbol_icon'] ?? ''}',
      );
}

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
    List<MapleSymbol>? symbols,
  })  : history = history ?? [],
        symbols = symbols ?? [];

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

  /// 장착한 심볼 (갱신할 때 같이 불러옴)
  final List<MapleSymbol> symbols;

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
        if (symbols.isNotEmpty) 'symbols': symbols.map((s) => s.toJson()).toList(),
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
        symbols: [for (final s in (j['symbols'] as List? ?? [])) if (s is Map) MapleSymbol.fromJson(s.cast<String, dynamic>())],
      );
}
