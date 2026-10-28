import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 메이플스토리 느낌의 디자인 요소: 하늘 배경, 갈색 테두리 창, 주황 타이틀바,
/// EXP/HP/MP 게이지, 퀘스트 느낌표, 아이템 슬롯 체크박스.
/// (게임 리소스는 쓰지 않고 전부 코드로 그린다)
abstract final class Maple {
  static const skyTop = Color(0xFF6EC3F4);
  static const skyBottom = Color(0xFFDDF3FF);
  static const cream = Color(0xFFFFF6DF);
  static const creamLight = Color(0xFFFFFCF2);
  static const brown = Color(0xFF4E3426);
  static const brownMid = Color(0xFF8C6A55);
  static const brownSoft = Color(0x334E3426);
  static const orange = Color(0xFFF39B1E);
  static const orangeLight = Color(0xFFFFC857);
  static const gold = Color(0xFFFFD54F);
  static const leaf = Color(0xFF7CB342);
  static const navy = Color(0xFF263052);
  static const navyLight = Color(0xFF3A4675);
  static const hp = [Color(0xFFFF8A80), Color(0xFFE53935)];
  static const mp = [Color(0xFF82B1FF), Color(0xFF1E62D0)];
  static const exp = [Color(0xFFFFF59D), Color(0xFFF9C80E)];
  static const font = 'Jua';

  /// 글자 테두리 효과 (그림자 8방향)
  static List<Shadow> outline(Color c, [double w = 1.6]) => [
        for (var i = 0; i < 8; i++)
          Shadow(
            color: c,
            offset: Offset(
              w * math.cos(i * math.pi / 4),
              w * math.sin(i * math.pi / 4),
            ),
          ),
      ];

  static TextStyle titleText([double size = 18]) => TextStyle(
        fontFamily: font,
        fontSize: size,
        color: Colors.white,
        shadows: outline(brown),
      );
}

ThemeData mapleTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Maple.orange,
    primary: Maple.orange,
    onPrimary: Colors.white,
    secondary: Maple.leaf,
    surface: Maple.cream,
    onSurface: Maple.brown,
    error: const Color(0xFFD84315),
  );
  const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    side: BorderSide(color: Maple.brown, width: 2.5),
  );
  final buttonText = TextStyle(fontFamily: Maple.font, fontSize: 16, shadows: Maple.outline(Maple.brown, 1.2));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: Maple.font,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Maple.cream,
    dividerColor: Maple.brownSoft,
    hintColor: Maple.brownMid,
    textTheme: const TextTheme().apply(bodyColor: Maple.brown, displayColor: Maple.brown),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      centerTitle: false,
      titleTextStyle: Maple.titleText(24),
      iconTheme: IconThemeData(color: Colors.white, shadows: Maple.outline(Maple.brown, 1.2)),
      actionsIconTheme: IconThemeData(color: Colors.white, shadows: Maple.outline(Maple.brown, 1.2)),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Maple.cream,
      surfaceTintColor: Colors.transparent,
      shape: shape,
      titleTextStyle: TextStyle(fontFamily: Maple.font, fontSize: 22, color: Maple.brown),
    ),
    datePickerTheme: const DatePickerThemeData(backgroundColor: Maple.cream, shape: shape),
    timePickerTheme: const TimePickerThemeData(backgroundColor: Maple.cream, shape: shape),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Maple.creamLight,
      isDense: true,
      labelStyle: TextStyle(color: Maple.brownMid),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Maple.brownMid, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Maple.brownMid, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Maple.orange, width: 2.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Maple.orange,
        foregroundColor: Colors.white,
        textStyle: buttonText,
        side: const BorderSide(color: Maple.brown, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Maple.creamLight,
        foregroundColor: Maple.brown,
        textStyle: const TextStyle(fontFamily: Maple.font, fontSize: 15),
        side: const BorderSide(color: Maple.brownMid, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Maple.brown,
        textStyle: const TextStyle(fontFamily: Maple.font, fontSize: 15),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Maple.creamLight,
        foregroundColor: Maple.brown,
        selectedBackgroundColor: Maple.orangeLight,
        selectedForegroundColor: Maple.brown,
        side: const BorderSide(color: Maple.brownMid, width: 1.5),
        textStyle: const TextStyle(fontFamily: Maple.font, fontSize: 15),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Maple.brownMid),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Maple.orange : Maple.creamLight),
      trackOutlineColor: const WidgetStatePropertyAll(Maple.brown),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Maple.orange,
      foregroundColor: Colors.white,
      shape: CircleBorder(side: BorderSide(color: Maple.brown, width: 3)),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: Maple.brown,
      iconColor: Maple.brownMid,
      titleTextStyle: TextStyle(fontFamily: Maple.font, fontSize: 17, color: Maple.brown),
      subtitleTextStyle: TextStyle(fontFamily: Maple.font, fontSize: 13, color: Maple.brownMid),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Maple.creamLight,
      labelStyle: TextStyle(fontFamily: Maple.font, fontSize: 12, color: Maple.brown),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Maple.navy,
      indicatorColor: Maple.navyLight,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Maple.gold, width: 1.5),
      ),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? Maple.gold : Colors.white70,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: Maple.font,
            fontSize: 13,
            color: s.contains(WidgetState.selected) ? Maple.gold : Colors.white70,
          )),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Maple.navy,
      indicatorColor: Maple.navyLight,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Maple.gold, width: 1.5),
      ),
      selectedIconTheme: const IconThemeData(color: Maple.gold),
      unselectedIconTheme: const IconThemeData(color: Colors.white70),
      selectedLabelTextStyle: const TextStyle(fontFamily: Maple.font, color: Maple.gold),
      unselectedLabelTextStyle: const TextStyle(fontFamily: Maple.font, color: Colors.white70),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Maple.navy,
      contentTextStyle: TextStyle(fontFamily: Maple.font, color: Colors.white),
    ),
  );
}

/// 맑은 하늘 + 구름 + 언덕 배경.
class MapleBackground extends StatelessWidget {
  const MapleBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _SkyPainter(),
        child: child,
      );
}

class _SkyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Maple.skyTop, Maple.skyBottom],
        ).createShader(rect),
    );

    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.85);
    void drawCloud(double x, double y, double s) {
      for (final (dx, dy, r) in const [
        (0.0, 0.0, 1.0),
        (0.9, -0.35, 1.2),
        (1.9, 0.0, 0.95),
        (0.95, 0.25, 1.1),
      ]) {
        canvas.drawCircle(Offset(x + dx * 22 * s, y + dy * 22 * s), r * 22 * s, cloud);
      }
    }

    final w = size.width;
    drawCloud(w * 0.08, 70, 1.0);
    drawCloud(w * 0.62, 40, 0.8);
    drawCloud(w * 0.80, 150, 1.1);
    drawCloud(w * 0.30, 230, 0.7);

    // 언덕
    final h = size.height;
    final hill = Path()
      ..moveTo(0, h)
      ..lineTo(0, h - 70)
      ..quadraticBezierTo(w * 0.25, h - 120, w * 0.5, h - 80)
      ..quadraticBezierTo(w * 0.78, h - 40, w, h - 95)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFF9CCC65));
    canvas.drawPath(
      hill,
      Paint()
        ..color = const Color(0xFF689F38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 게임 창 모양 패널: 주황 타이틀바 + 크림색 본문 + 갈색 테두리.
class MaplePanel extends StatelessWidget {
  const MaplePanel({
    super.key,
    this.title,
    this.icon,
    this.trailing,
    required this.child,
    this.accent,
    this.margin = const EdgeInsets.fromLTRB(12, 6, 12, 10),
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  final String? title;
  final String? icon;
  final Widget? trailing;
  final Widget child;

  /// 타이틀바 색 (기본 주황)
  final Color? accent;
  final EdgeInsets margin;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final a = accent ?? Maple.orange;
    final light = Color.lerp(a, Colors.white, 0.45)!;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Maple.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Maple.brown, width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x554E3426), offset: Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [light, a],
                  ),
                  border: const Border(bottom: BorderSide(color: Maple.brown, width: 2)),
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Text(icon!, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                    ],
                    Expanded(child: Text(title!, style: Maple.titleText(18))),
                    ?trailing,
                  ],
                ),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// 타이틀바 오른쪽에 붙는 작은 숫자 배지.
class MapleBadge extends StatelessWidget {
  const MapleBadge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: Maple.brown,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: const TextStyle(fontFamily: Maple.font, color: Maple.gold, fontSize: 13)),
      );
}

/// 타이틀바용 둥근 + 버튼.
class MapleAddButton extends StatelessWidget {
  const MapleAddButton({super.key, required this.onPressed, this.tooltip = '추가'});

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onPressed,
          radius: 18,
          child: Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFB9F6CA), Maple.leaf],
              ),
              border: Border.all(color: Maple.brown, width: 2),
            ),
            child: const Icon(Icons.add, size: 18, color: Colors.white),
          ),
        ),
      );
}

enum GaugeKind { exp, hp, mp }

/// EXP / HP / MP 게이지.
class GaugeBar extends StatelessWidget {
  const GaugeBar({
    super.key,
    required this.value,
    this.kind = GaugeKind.exp,
    this.label,
    this.height = 18,
  });

  final double value;
  final GaugeKind kind;
  final String? label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = switch (kind) {
      GaugeKind.exp => Maple.exp,
      GaugeKind.hp => Maple.hp,
      GaugeKind.mp => Maple.mp,
    };
    final tag = switch (kind) {
      GaugeKind.exp => 'EXP',
      GaugeKind.hp => 'HP',
      GaugeKind.mp => 'MP',
    };
    final v = value.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF3B2A20),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: Maple.brown, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: colors,
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                label ?? '$tag ${(v * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontFamily: Maple.font,
                  fontSize: height * 0.62,
                  height: 1,
                  color: Colors.white,
                  shadows: Maple.outline(const Color(0xFF2B1D15), 1.1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 퀘스트 표시: 미완료는 노란 느낌표, 완료는 초록 체크.
class QuestMark extends StatelessWidget {
  const QuestMark({super.key, required this.done, this.onTap});

  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: done
                  ? const [Color(0xFFC5E1A5), Maple.leaf]
                  : const [Color(0xFFFFF59D), Color(0xFFFFB300)],
            ),
            border: Border.all(color: Maple.brown, width: 2),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check, size: 18, color: Colors.white, weight: 900)
                : Text('!', style: TextStyle(fontFamily: Maple.font, fontSize: 20, height: 1.1, color: Colors.white, shadows: Maple.outline(Maple.brown, 1.4))),
          ),
        ),
      );
}

/// 아이템 슬롯 모양 체크박스.
class SlotCheck extends StatelessWidget {
  const SlotCheck({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: value ? Maple.orangeLight : Maple.creamLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Maple.brownMid, width: 2),
            boxShadow: const [BoxShadow(color: Color(0x334E3426), offset: Offset(0, 2))],
          ),
          child: value
              ? Icon(Icons.check_rounded, size: 22, color: Colors.white, shadows: Maple.outline(Maple.brown, 1))
              : null,
        ),
      );
}

/// 패널 안 빈 상태 안내.
class MapleEmpty extends StatelessWidget {
  const MapleEmpty(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(text, style: const TextStyle(color: Maple.brownMid, fontSize: 15)),
      );
}

/// 패널 안 항목 사이 점선 느낌 구분선.
class MapleDivider extends StatelessWidget {
  const MapleDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, indent: 12, endIndent: 12, color: Maple.brownSoft);
}

/// 위젯 목록 사이사이에 구분선을 넣는다.
List<Widget> withDividers(Iterable<Widget> items) {
  final out = <Widget>[];
  for (final w in items) {
    if (out.isNotEmpty) out.add(const MapleDivider());
    out.add(w);
  }
  return out;
}

/// 화면 공통 틀: 하늘 배경 위에 투명 Scaffold.
class MapleScaffold extends StatelessWidget {
  const MapleScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) => MapleBackground(
        child: Scaffold(
          appBar: AppBar(title: Text(title), actions: actions),
          floatingActionButton: floatingActionButton,
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: body,
            ),
          ),
        ),
      );
}
