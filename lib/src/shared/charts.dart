import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/financial_models.dart';
class _ChartTooltipEntry {
  const _ChartTooltipEntry({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}

TextPainter _chartTextPainter(
  String text,
  TextStyle style, {
  double? maxWidth,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    ellipsis: '...',
    textDirection: TextDirection.ltr,
  );

  painter.layout(maxWidth: maxWidth ?? double.infinity);
  return painter;
}

void _drawChartTooltip(
  Canvas canvas,
  Size size, {
  required Offset anchor,
  required String title,
  required List<_ChartTooltipEntry> entries,
  required bool isDarkMode,
}) {
  if (entries.isEmpty) {
    return;
  }

  const padding = 10.0;
  const dotSpace = 14.0;
  const gap = 7.0;
  final maxBoxWidth = math.max(120.0, size.width - 8);
  final maxTextWidth = math.max(80.0, maxBoxWidth - padding * 2 - dotSpace);
  final titlePainter = _chartTextPainter(
    title,
    TextStyle(
      color: isDarkMode ? FlorgPalette.offWhite : AppColors.teal900,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
    maxWidth: maxTextWidth,
  );
  final entryPainters = entries
      .map(
        (entry) => _chartTextPainter(
          '${entry.label}: ${entry.value}',
          TextStyle(
            color: isDarkMode ? FlorgPalette.mist : AppColors.teal700,
            fontSize: 12,
          ),
          maxWidth: maxTextWidth,
        ),
      )
      .toList();

  var contentWidth = titlePainter.width;
  var contentHeight = titlePainter.height;
  for (final painter in entryPainters) {
    contentWidth = math.max(contentWidth, dotSpace + painter.width);
    contentHeight += gap + painter.height;
  }

  final boxWidth = math.min(contentWidth + padding * 2, maxBoxWidth);
  final boxHeight = contentHeight + padding * 2;
  var left = anchor.dx + 14;
  if (left + boxWidth > size.width - 4) {
    left = anchor.dx - boxWidth - 14;
  }
  left = left.clamp(4.0, math.max(4.0, size.width - boxWidth - 4)).toDouble();

  var top = anchor.dy - boxHeight - 14;
  if (top < 4) {
    top = anchor.dy + 14;
  }
  top = top.clamp(4.0, math.max(4.0, size.height - boxHeight - 4)).toDouble();

  final rect = RRect.fromRectAndRadius(
    Rect.fromLTWH(left, top, boxWidth, boxHeight),
    const Radius.circular(10),
  );
  canvas.drawRRect(
    rect,
    Paint()
      ..color = isDarkMode
          ? FlorgPalette.surfaceSunken.withValues(alpha: 0.96)
          : Colors.white.withValues(alpha: 0.98),
  );
  canvas.drawRRect(
    rect,
    Paint()
      ..color = isDarkMode ? FlorgPalette.surfaceRaised : AppColors.teal100
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );

  var y = top + padding;
  titlePainter.paint(canvas, Offset(left + padding, y));
  y += titlePainter.height + gap;

  for (var i = 0; i < entries.length; i++) {
    final painter = entryPainters[i];
    final rowCenterY = y + painter.height / 2;
    canvas.drawCircle(
      Offset(left + padding + 4, rowCenterY),
      4,
      Paint()..color = entries[i].color,
    );
    painter.paint(canvas, Offset(left + padding + dotSpace, y));
    y += painter.height + gap;
  }
}

class LegendItem {
  const LegendItem(this.label, this.color);

  final String label;
  final Color color;
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items});

  final List<LegendItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.label,
                style: const TextStyle(color: AppColors.teal700, fontSize: 14),
              ),
            ],
          ),
      ],
    );
  }
}

class ChartSeries {
  const ChartSeries({
    required this.name,
    required this.color,
    required this.values,
    this.fill = false,
  });

  final String name;
  final Color color;
  final List<double> values;
  final bool fill;
}

class LineAreaChart extends StatefulWidget {
  const LineAreaChart({super.key, required this.labels, required this.series});

  final List<String> labels;
  final List<ChartSeries> series;

  @override
  State<LineAreaChart> createState() => _LineAreaChartState();
}

class _LineAreaChartState extends State<LineAreaChart> {
  Offset? _hoverPosition;

  void _setHoverPosition(Offset position) {
    setState(() => _hoverPosition = position);
  }

  void _clearHoverPosition() {
    if (_hoverPosition != null) {
      setState(() => _hoverPosition = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) => _setHoverPosition(event.localPosition),
      onExit: (_) => _clearHoverPosition(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _setHoverPosition(details.localPosition),
        onPanUpdate: (details) => _setHoverPosition(details.localPosition),
        onTapCancel: _clearHoverPosition,
        child: CustomPaint(
          painter: LineAreaChartPainter(
            labels: widget.labels,
            series: widget.series,
            hoverPosition: _hoverPosition,
            isDarkMode: AppColors.isDark(context),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class LineAreaChartPainter extends CustomPainter {
  LineAreaChartPainter({
    required this.labels,
    required this.series,
    required this.hoverPosition,
    required this.isDarkMode,
  });

  final List<String> labels;
  final List<ChartSeries> series;
  final Offset? hoverPosition;
  final bool isDarkMode;

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty || series.isEmpty) {
      return;
    }

    const leftPadding = 52.0;
    const rightPadding = 18.0;
    const topPadding = 18.0;
    const bottomPadding = 36.0;
    final chartRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );
    if (chartRect.width <= 0 || chartRect.height <= 0) {
      return;
    }

    final maxValue = _niceMax(
      series.expand((line) => line.values).fold(0.0, math.max),
    );
    final gridPaint = Paint()
      ..color = FlorgPalette.lightSurfaceRaised
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = chartRect.bottom - chartRect.height * i / 4;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
      _drawText(
        canvas,
        formatCurrency(maxValue * i / 4, decimals: 0),
        Offset(0, y - 8),
        color: AppColors.gray400,
        size: 11,
      );
    }

    for (var i = 0; i < labels.length; i++) {
      final x = labels.length == 1
          ? chartRect.center.dx
          : chartRect.left + chartRect.width * i / (labels.length - 1);
      _drawText(
        canvas,
        labels[i],
        Offset(x - 14, chartRect.bottom + 12),
        color: AppColors.gray400,
        size: 11,
      );
    }

    for (final line in series) {
      final points = <Offset>[];
      for (var i = 0; i < line.values.length; i++) {
        final x = line.values.length == 1
            ? chartRect.center.dx
            : chartRect.left + chartRect.width * i / (line.values.length - 1);
        final y =
            chartRect.bottom - (line.values[i] / maxValue) * chartRect.height;
        points.add(Offset(x, y));
      }

      if (points.isEmpty) {
        continue;
      }

      final path = _smoothPath(points);
      if (line.fill) {
        final fillPath = Path.from(path)
          ..lineTo(points.last.dx, chartRect.bottom)
          ..lineTo(points.first.dx, chartRect.bottom)
          ..close();
        final fillPaint = Paint()
          ..shader = LinearGradient(
            colors: [
              line.color.withValues(alpha: 0.28),
              line.color.withValues(alpha: 0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(chartRect)
          ..style = PaintingStyle.fill;
        canvas.drawPath(fillPath, fillPaint);
      }

      final linePaint = Paint()
        ..color = line.color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, linePaint);

      final dotPaint = Paint()..color = line.color;
      for (final point in points) {
        canvas.drawCircle(point, 3.5, dotPaint);
      }
    }

    final hoverIndex = _hoveredIndex(chartRect);
    if (hoverIndex != null) {
      _drawHoverState(canvas, size, chartRect, hoverIndex, maxValue);
    }
  }

  int? _hoveredIndex(Rect chartRect) {
    final position = hoverPosition;
    if (position == null || labels.isEmpty) {
      return null;
    }

    if (!chartRect.inflate(10).contains(position)) {
      return null;
    }

    if (labels.length == 1) {
      return 0;
    }

    final rawIndex =
        ((position.dx - chartRect.left) / chartRect.width * (labels.length - 1))
            .round();
    return rawIndex.clamp(0, labels.length - 1).toInt();
  }

  void _drawHoverState(
    Canvas canvas,
    Size size,
    Rect chartRect,
    int index,
    double maxValue,
  ) {
    final x = labels.length == 1
        ? chartRect.center.dx
        : chartRect.left + chartRect.width * index / (labels.length - 1);
    final crosshairPaint = Paint()
      ..color = isDarkMode
          ? FlorgPalette.mist.withValues(alpha: 0.35)
          : FlorgPalette.lightSurfaceRaised
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(x, chartRect.top),
      Offset(x, chartRect.bottom),
      crosshairPaint,
    );

    final entries = <_ChartTooltipEntry>[];
    for (final line in series) {
      if (index >= line.values.length) {
        continue;
      }

      final value = line.values[index];
      final y = chartRect.bottom - (value / maxValue) * chartRect.height;
      final point = Offset(x, y);
      canvas.drawCircle(
        point,
        7,
        Paint()
          ..color = isDarkMode
              ? FlorgPalette.surface.withValues(alpha: 0.96)
              : Colors.white,
      );
      canvas.drawCircle(point, 4.5, Paint()..color = line.color);
      entries.add(
        _ChartTooltipEntry(
          label: line.name,
          value: formatCurrency(value),
          color: line.color,
        ),
      );
    }

    _drawChartTooltip(
      canvas,
      size,
      anchor: hoverPosition ?? Offset(x, chartRect.top),
      title: labels[index],
      entries: entries,
      isDarkMode: isDarkMode,
    );
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) {
      return path;
    }

    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final controlX = current.dx + (next.dx - current.dx) / 2;
      path.cubicTo(controlX, current.dy, controlX, next.dy, next.dx, next.dy);
    }
    return path;
  }

  double _niceMax(double value) {
    if (value <= 0) {
      return 1;
    }
    final exponent = math
        .pow(10, value.toStringAsFixed(0).length - 1)
        .toDouble();
    return (value / exponent).ceil() * exponent;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required Color color,
    required double size,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant LineAreaChartPainter oldDelegate) {
    return oldDelegate.labels != labels ||
        oldDelegate.series != series ||
        oldDelegate.hoverPosition != hoverPosition ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}

class GroupedBarChart extends StatefulWidget {
  const GroupedBarChart({
    super.key,
    required this.labels,
    required this.series,
  });

  final List<String> labels;
  final List<ChartSeries> series;

  @override
  State<GroupedBarChart> createState() => _GroupedBarChartState();
}

class _GroupedBarChartState extends State<GroupedBarChart> {
  Offset? _hoverPosition;

  void _setHoverPosition(Offset position) {
    setState(() => _hoverPosition = position);
  }

  void _clearHoverPosition() {
    if (_hoverPosition != null) {
      setState(() => _hoverPosition = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) => _setHoverPosition(event.localPosition),
      onExit: (_) => _clearHoverPosition(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _setHoverPosition(details.localPosition),
        onPanUpdate: (details) => _setHoverPosition(details.localPosition),
        onTapCancel: _clearHoverPosition,
        child: CustomPaint(
          painter: GroupedBarChartPainter(
            labels: widget.labels,
            series: widget.series,
            hoverPosition: _hoverPosition,
            isDarkMode: AppColors.isDark(context),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class GroupedBarChartPainter extends CustomPainter {
  GroupedBarChartPainter({
    required this.labels,
    required this.series,
    required this.hoverPosition,
    required this.isDarkMode,
  });

  final List<String> labels;
  final List<ChartSeries> series;
  final Offset? hoverPosition;
  final bool isDarkMode;

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty || series.isEmpty) {
      return;
    }

    const leftPadding = 52.0;
    const rightPadding = 18.0;
    const topPadding = 18.0;
    const bottomPadding = 48.0;
    final chartRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );
    if (chartRect.width <= 0 || chartRect.height <= 0) {
      return;
    }

    final maxValue = _niceMax(
      series.expand((line) => line.values).fold(0.0, math.max),
    );
    final gridPaint = Paint()
      ..color = FlorgPalette.lightSurfaceRaised
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = chartRect.bottom - chartRect.height * i / 4;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
      _drawText(
        canvas,
        formatCurrency(maxValue * i / 4, decimals: 0),
        Offset(0, y - 8),
        color: AppColors.gray400,
        size: 11,
      );
    }

    final groupWidth = chartRect.width / labels.length;
    final hoveredGroupIndex = _hoveredGroupIndex(chartRect, groupWidth);
    if (hoveredGroupIndex != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            chartRect.left + groupWidth * hoveredGroupIndex,
            chartRect.top,
            groupWidth,
            chartRect.height,
          ),
          const Radius.circular(10),
        ),
        Paint()
          ..color = isDarkMode
              ? FlorgPalette.surfaceRaised.withValues(alpha: 0.55)
              : AppColors.teal50.withValues(alpha: 0.9),
      );
    }

    final barWidth = math.min(22.0, groupWidth / (series.length + 1.7));

    for (var groupIndex = 0; groupIndex < labels.length; groupIndex++) {
      final groupLeft = chartRect.left + groupWidth * groupIndex;
      final groupCenter = groupLeft + groupWidth / 2;
      final totalBarsWidth = barWidth * series.length;
      final firstBarX = groupCenter - totalBarsWidth / 2;

      for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
        if (groupIndex >= series[seriesIndex].values.length) {
          continue;
        }

        final value = series[seriesIndex].values[groupIndex];
        final barHeight = (value / maxValue) * chartRect.height;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            firstBarX + seriesIndex * barWidth,
            chartRect.bottom - barHeight,
            barWidth * 0.78,
            barHeight,
          ),
          const Radius.circular(6),
        );
        canvas.drawRRect(rect, Paint()..color = series[seriesIndex].color);
        if (hoveredGroupIndex == groupIndex) {
          canvas.drawRRect(
            rect,
            Paint()
              ..color = isDarkMode ? FlorgPalette.offWhite : Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }

      _drawText(
        canvas,
        _shortLabel(labels[groupIndex]),
        Offset(groupCenter - 18, chartRect.bottom + 14),
        color: AppColors.gray400,
        size: 10,
      );
    }

    if (hoveredGroupIndex != null) {
      _drawGroupTooltip(canvas, size, chartRect, groupWidth, hoveredGroupIndex);
    }
  }

  int? _hoveredGroupIndex(Rect chartRect, double groupWidth) {
    final position = hoverPosition;
    if (position == null || labels.isEmpty) {
      return null;
    }

    if (!chartRect.inflate(4).contains(position)) {
      return null;
    }

    final rawIndex = ((position.dx - chartRect.left) / groupWidth).floor();
    return rawIndex.clamp(0, labels.length - 1).toInt();
  }

  void _drawGroupTooltip(
    Canvas canvas,
    Size size,
    Rect chartRect,
    double groupWidth,
    int groupIndex,
  ) {
    final entries = <_ChartTooltipEntry>[];
    for (final item in series) {
      if (groupIndex >= item.values.length) {
        continue;
      }

      entries.add(
        _ChartTooltipEntry(
          label: item.name,
          value: formatCurrency(item.values[groupIndex]),
          color: item.color,
        ),
      );
    }

    _drawChartTooltip(
      canvas,
      size,
      anchor:
          hoverPosition ??
          Offset(
            chartRect.left + groupWidth * groupIndex + groupWidth / 2,
            chartRect.top,
          ),
      title: labels[groupIndex],
      entries: entries,
      isDarkMode: isDarkMode,
    );
  }

  String _shortLabel(String label) {
    return label.length <= 6 ? label : label.substring(0, 6);
  }

  double _niceMax(double value) {
    if (value <= 0) {
      return 1;
    }
    final exponent = math
        .pow(10, value.toStringAsFixed(0).length - 1)
        .toDouble();
    return (value / exponent).ceil() * exponent;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required Color color,
    required double size,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant GroupedBarChartPainter oldDelegate) {
    return oldDelegate.labels != labels ||
        oldDelegate.series != series ||
        oldDelegate.hoverPosition != hoverPosition ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}

class CategoryPieChart extends StatefulWidget {
  const CategoryPieChart({super.key, required this.slices});

  final List<CategorySlice> slices;

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  Offset? _hoverPosition;

  void _setHoverPosition(Offset position) {
    setState(() => _hoverPosition = position);
  }

  void _clearHoverPosition() {
    if (_hoverPosition != null) {
      setState(() => _hoverPosition = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) => _setHoverPosition(event.localPosition),
      onExit: (_) => _clearHoverPosition(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _setHoverPosition(details.localPosition),
        onPanUpdate: (details) => _setHoverPosition(details.localPosition),
        onTapCancel: _clearHoverPosition,
        child: CustomPaint(
          painter: PieChartPainter(
            widget.slices,
            hoverPosition: _hoverPosition,
            isDarkMode: AppColors.isDark(context),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class PieChartPainter extends CustomPainter {
  PieChartPainter(
    this.slices, {
    required this.hoverPosition,
    required this.isDarkMode,
  });

  final List<CategorySlice> slices;
  final Offset? hoverPosition;
  final bool isDarkMode;

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty) {
      return;
    }

    final total = slices.fold(0.0, (sum, slice) => sum + slice.value);
    if (total <= 0) {
      return;
    }

    final radius = math.min(size.width, size.height) * 0.42;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final hoveredIndex = _hoveredSliceIndex(size, radius);
    var start = -math.pi / 2;
    final starts = <double>[];
    final sweeps = <double>[];

    for (var i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final sweep = (slice.value / total) * math.pi * 2;
      starts.add(start);
      sweeps.add(sweep);
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, start, sweep, true, paint);
      start += sweep;
    }

    canvas.drawCircle(
      center,
      radius * 0.48,
      Paint()
        ..color = isDarkMode
            ? FlorgPalette.surface.withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.94),
    );
    _drawText(
      canvas,
      'Abril',
      Offset(size.width / 2 - 20, size.height / 2 - 18),
      color: AppColors.teal600,
      size: 13,
    );
    _drawText(
      canvas,
      formatCurrency(total, decimals: 0),
      Offset(size.width / 2 - 40, size.height / 2 + 2),
      color: AppColors.teal900,
      size: 18,
      weight: FontWeight.w700,
    );

    if (hoveredIndex != null) {
      final slice = slices[hoveredIndex];
      canvas.drawArc(
        rect,
        starts[hoveredIndex],
        sweeps[hoveredIndex],
        false,
        Paint()
          ..color = isDarkMode ? FlorgPalette.offWhite : Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawArc(
        rect,
        starts[hoveredIndex],
        sweeps[hoveredIndex],
        false,
        Paint()
          ..color = slice.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );

      _drawChartTooltip(
        canvas,
        size,
        anchor: hoverPosition ?? center,
        title: slice.name,
        entries: [
          _ChartTooltipEntry(
            label: 'Valor',
            value: formatCurrency(slice.value),
            color: slice.color,
          ),
          _ChartTooltipEntry(
            label: 'Participacao',
            value: '${(slice.value / total * 100).toStringAsFixed(1)}%',
            color: slice.color,
          ),
        ],
        isDarkMode: isDarkMode,
      );
    }
  }

  int? _hoveredSliceIndex(Size size, double radius) {
    final position = hoverPosition;
    if (position == null) {
      return null;
    }

    final center = size.center(Offset.zero);
    final vector = position - center;
    final distance = vector.distance;
    if (distance > radius || distance < radius * 0.48) {
      return null;
    }

    final total = slices.fold(0.0, (sum, slice) => sum + slice.value);
    if (total <= 0) {
      return null;
    }

    var relativeAngle = math.atan2(vector.dy, vector.dx) + math.pi / 2;
    while (relativeAngle < 0) {
      relativeAngle += math.pi * 2;
    }
    while (relativeAngle >= math.pi * 2) {
      relativeAngle -= math.pi * 2;
    }

    var accumulated = 0.0;
    for (var i = 0; i < slices.length; i++) {
      final sweep = (slices[i].value / total) * math.pi * 2;
      if (relativeAngle <= accumulated + sweep) {
        return i;
      }
      accumulated += sweep;
    }

    return null;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required Color color,
    required double size,
    FontWeight weight = FontWeight.w400,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) =>
      oldDelegate.slices != slices ||
      oldDelegate.hoverPosition != hoverPosition ||
      oldDelegate.isDarkMode != isDarkMode;
}
