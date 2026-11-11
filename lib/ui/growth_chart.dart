import 'package:flutter/material.dart';

import 'maple.dart';

/// 날짜별 값 꺾은선 그래프.
class GrowthChart extends StatelessWidget {
  const GrowthChart({
    super.key,
    required this.dates,
    required this.values,
    required this.format,
    this.color = Maple.orange,
    this.height = 180,
  });

  /// 'yyyy-MM-dd'
  final List<String> dates;
  final List<double> values;
  final String Function(double) format;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            values.isEmpty ? '기록이 없어요' : '기록이 하루치뿐이에요. 갱신하거나 지난 기록을 불러오세요.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Maple.brownMid),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _ChartPainter(dates, values, format, color),
        size: Size.infinite,
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.dates, this.values, this.format, this.color);

  final List<String> dates;
  final List<double> values;
  final String Function(double) format;
  final Color color;

  TextPainter _text(String s, double size, Color c) => TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(fontFamily: Maple.font, fontSize: size, color: c),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    const left = 8.0, right = 8.0, top = 22.0, bottom = 22.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (hi == lo) {
      hi += 1;
      lo -= 1;
    }
    final pad = (hi - lo) * 0.12;
    lo -= pad;
    hi += pad;

    Offset pt(int i) => Offset(
          left + (values.length == 1 ? w / 2 : w * i / (values.length - 1)),
          top + h * (1 - (values[i] - lo) / (hi - lo)),
        );

    // 가이드 선
    final grid = Paint()
      ..color = Maple.brownSoft
      ..strokeWidth = 1;
    for (var k = 0; k <= 3; k++) {
      final y = top + h * k / 3;
      canvas.drawLine(Offset(left, y), Offset(left + w, y), grid);
    }

    // 아래 채우기
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    final fill = Path.from(path)
      ..lineTo(pt(values.length - 1).dx, top + h)
      ..lineTo(pt(0).dx, top + h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.02)],
        ).createShader(Rect.fromLTWH(left, top, w, h)),
    );

    // 선 (갈색 테두리 + 색)
    canvas.drawPath(
      path,
      Paint()
        ..color = Maple.brown
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // 점 (많으면 생략)
    if (values.length <= 31) {
      for (var i = 0; i < values.length; i++) {
        canvas.drawCircle(pt(i), 4, Paint()..color = Maple.brown);
        canvas.drawCircle(pt(i), 2.6, Paint()..color = Colors.white);
      }
    }

    // 처음·마지막 값
    final first = _text(format(values.first), 12, Maple.brownMid);
    first.paint(canvas, Offset(left, (pt(0).dy - 18).clamp(0, size.height - 14)));
    final last = _text(format(values.last), 13, Maple.brown);
    last.paint(canvas, Offset(left + w - last.width, (pt(values.length - 1).dy - 20).clamp(0, size.height - 14)));

    // 날짜
    String md(String d) => '${int.parse(d.substring(5, 7))}/${int.parse(d.substring(8, 10))}';
    final d0 = _text(md(dates.first), 11, Maple.brownMid);
    d0.paint(canvas, Offset(left, size.height - 15));
    final d1 = _text(md(dates.last), 11, Maple.brownMid);
    d1.paint(canvas, Offset(left + w - d1.width, size.height - 15));
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.values != values || old.dates != dates || old.color != color;
}
