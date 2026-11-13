import 'package:flutter/material.dart';

/// 디자인 토큰: 밝은 바탕 + 흰 카드, 주황 포인트 (A안)
abstract final class Ui {
  static const bg = Color(0xFFF6F5F2);
  static const card = Color(0xFFFFFFFF);
  static const field = Color(0xFFF3F1EC);
  static const text = Color(0xFF1C1B19);
  static const subtext = Color(0xFF6B6862);
  static const line = Color(0xFFE7E4DE);
  static const ring = Color(0xFFC9C5BD);
  static const accent = Color(0xFFEA7317);
  static const accentSoft = Color(0xFFFDEBDC);
  static const maple = Color(0xFFB45309); // 메이플 관련 글자 (흰 바탕 대비 4.5:1 이상)
  static const blue = Color(0xFF2563EB);
  static const red = Color(0xFFB91C1C);
  static const green = Color(0xFF15803D);
  static const purple = Color(0xFF7C3AED);

  static TextStyle title([double size = 22]) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: text,
      );
}

ThemeData appTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Ui.accent,
    primary: Ui.text,
    onPrimary: Colors.white,
    secondary: Ui.accent,
    surface: Ui.card,
    onSurface: Ui.text,
    error: Ui.red,
  );
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Ui.bg,
    canvasColor: Ui.card,
    dividerColor: Ui.line,
    hintColor: Ui.subtext,
    appBarTheme: AppBarTheme(
      backgroundColor: Ui.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Ui.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: Ui.title(22),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Ui.card,
      surfaceTintColor: Colors.transparent,
      shape: rounded,
      titleTextStyle: Ui.title(20),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Ui.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    datePickerTheme: DatePickerThemeData(backgroundColor: Ui.card, shape: rounded),
    timePickerTheme: TimePickerThemeData(backgroundColor: Ui.card, shape: rounded),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Ui.field,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: const TextStyle(color: Ui.subtext),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Ui.text, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Ui.text,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Ui.text,
        minimumSize: const Size(0, 44),
        side: const BorderSide(color: Ui.line, width: 1.5),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Ui.text,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Ui.card,
        foregroundColor: Ui.subtext,
        selectedBackgroundColor: Ui.text,
        selectedForegroundColor: Colors.white,
        side: const BorderSide(color: Ui.line),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Ui.card,
      selectedColor: Ui.text,
      side: const BorderSide(color: Ui.line),
      shape: StadiumBorder(side: const BorderSide(color: Ui.line)),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Ui.text),
      secondaryLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
      checkmarkColor: Colors.white,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Ui.accent : Ui.ring),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Ui.text,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: CircleBorder(),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: Ui.text,
      iconColor: Ui.subtext,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Ui.text),
      subtitleTextStyle: TextStyle(fontSize: 12.5, color: Ui.subtext),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Ui.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Ui.accentSoft,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? Ui.text : Ui.subtext,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 11.5,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? Ui.text : Ui.subtext,
          )),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Ui.card,
      indicatorColor: Ui.accentSoft,
      selectedIconTheme: IconThemeData(color: Ui.text),
      unselectedIconTheme: IconThemeData(color: Ui.subtext),
      selectedLabelTextStyle: TextStyle(fontWeight: FontWeight.w700, color: Ui.text),
      unselectedLabelTextStyle: TextStyle(color: Ui.subtext),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Ui.text,
      behavior: SnackBarBehavior.floating,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Ui.accent),
  );
}

/// 흰 카드 섹션. 제목은 작은 회색 글씨.
class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.accent,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12),
    this.padding = const EdgeInsets.only(bottom: 6),
  });

  final String? title;
  final Widget? trailing;
  final Widget child;

  /// 제목 앞 작은 점 색 (분류 표시)
  final Color? accent;
  final EdgeInsets margin;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // 그림자는 바깥 상자, 배경은 Material (목록 터치 효과가 보이도록)
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Material(
        color: Ui.card,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 2),
              child: SizedBox(
                height: 32,
                child: Row(
                  children: [
                    if (accent != null) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        title!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Ui.subtext),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
        ),
      ),
    );
  }
}

/// 섹션 제목 오른쪽의 작은 숫자.
class CountBadge extends StatelessWidget {
  const CountBadge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Ui.subtext)),
      );
}

/// 섹션 제목 오른쪽 + 버튼.
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.onPressed, this.tooltip = '추가'});

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: const Icon(Icons.add, size: 22, color: Ui.text),
      );
}

enum GaugeKind { exp, hp, mp }

/// 얇은 진행 막대 (+ 아래 작은 설명)
class GaugeBar extends StatelessWidget {
  const GaugeBar({
    super.key,
    required this.value,
    this.kind = GaugeKind.exp,
    this.label,
    this.height = 8,
  });

  final double value;
  final GaugeKind kind;
  final String? label;

  /// 예전 호출 호환용 (두꺼운 게이지 값은 무시하고 8~10px로)
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      GaugeKind.exp => Ui.accent,
      GaugeKind.hp => Ui.red,
      GaugeKind.mp => Ui.blue,
    };
    final v = value.clamp(0.0, 1.0);
    final h = height.clamp(6.0, 10.0);
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(h / 2),
      child: SizedBox(
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Ui.line),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v,
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
    if (label == null) return bar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        bar,
        const SizedBox(height: 4),
        Text(label!, style: const TextStyle(fontSize: 12, color: Ui.subtext)),
      ],
    );
  }
}

/// 완료 체크 원 (할 일·일정·숙제 공통)
class CheckCircle extends StatelessWidget {
  const CheckCircle({super.key, required this.value, required this.onChanged, this.color});

  final bool value;
  final ValueChanged<bool> onChanged;

  /// 미완료일 때 테두리 색 (메이플 숙제는 주황 등)
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
        checked: value,
        button: true,
        child: InkResponse(
          onTap: () => onChanged(!value),
          radius: 22,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? Ui.text : Colors.transparent,
                  border: value ? null : Border.all(color: color ?? Ui.ring, width: 2),
                ),
                child: value ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
              ),
            ),
          ),
        ),
      );
}

/// 숙제용 체크 (CheckCircle에 주황 테두리)
class QuestMark extends StatelessWidget {
  const QuestMark({super.key, required this.done, this.onTap});

  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) =>
      CheckCircle(value: done, onChanged: (_) => onTap?.call(), color: Ui.accent);
}

/// 빈 상태 안내 문구.
class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Text(text, style: const TextStyle(color: Ui.subtext, fontSize: 14, height: 1.45)),
      );
}

class ListDivider extends StatelessWidget {
  const ListDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: Ui.line);
}

/// 위젯 목록 사이에 구분선 (A안은 구분선 없이 여백만)
List<Widget> withDividers(Iterable<Widget> items) => items.toList();

/// 공통 화면 틀: 앱바 + 가운데 정렬된 본문(PC에서 너무 넓어지지 않게)
class AppScaffold extends StatelessWidget {
  const AppScaffold({
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        floatingActionButton: floatingActionButton,
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: body,
          ),
        ),
      );
}

/// 작은 숫자 위젯 카드 (홈 하단 2칸 등)
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.valueSuffix,
    this.progress,
    this.color = Ui.accent,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final String? valueSuffix;
  final double? progress;
  final Color color;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Ui.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Ui.subtext)),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: value),
                    if (valueSuffix != null)
                      TextSpan(text: ' $valueSuffix', style: TextStyle(fontSize: 14, color: color)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress!.clamp(0, 1),
                      minHeight: 6,
                      color: color,
                      backgroundColor: Ui.line,
                    ),
                  ),
                ],
                if (caption != null) ...[
                  const SizedBox(height: 6),
                  Text(caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Ui.subtext)),
                ],
              ],
            ),
          ),
        ),
      );
}
