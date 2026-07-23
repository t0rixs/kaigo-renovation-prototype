import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';

enum DraftKind { layout, rail }

const editorSelectionColor = Color(0xFF1769AA);

class EditorDraft {
  const EditorDraft({
    required this.kind,
    required this.start,
    required this.end,
  });

  final DraftKind kind;
  final Offset start;
  final Offset end;
}

class GridPainter extends CustomPainter {
  const GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    const minorSize = 40.0;
    for (double x = 0; x <= size.width; x += minorSize) {
      final index = (x / minorSize).round();
      final paint = Paint()
        ..color = index % 4 == 0
            ? const Color(0xFF9FB4C2)
            : index % 2 == 0
            ? const Color(0xFFC3D1DA)
            : const Color(0xFFE1E8EC)
        ..strokeWidth = index % 4 == 0 ? 1.4 : 1;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += minorSize) {
      final index = (y / minorSize).round();
      final paint = Paint()
        ..color = index % 4 == 0
            ? const Color(0xFF9FB4C2)
            : index % 2 == 0
            ? const Color(0xFFC3D1DA)
            : const Color(0xFFE1E8EC)
        ..strokeWidth = index % 4 == 0 ? 1.4 : 1;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) => false;
}

class PlanPainter extends CustomPainter {
  PlanPainter({
    required this.lines,
    required this.selectedId,
    required this.mmToPixels,
    required this.pathFor,
    required this.connectionPoints,
    required this.constructionNumberFor,
    this.selectionColor = editorSelectionColor,
    this.focusedHandrailIds = const {},
    this.showConnectionNumbers = false,
    this.connectionPointNumbers = const {},
    this.selectedConnectionPointId,
    this.draft,
  });

  final List<WorkLine> lines;
  final String? selectedId;
  final double Function(int) mmToPixels;
  final HandrailPath Function(WorkLine) pathFor;
  final List<HandrailConnectionPoint> connectionPoints;
  final String Function(WorkLine) constructionNumberFor;
  final Color selectionColor;
  final Set<String> focusedHandrailIds;
  final bool showConnectionNumbers;
  final Map<String, int> connectionPointNumbers;
  final String? selectedConnectionPointId;
  final EditorDraft? draft;

  @override
  void paint(Canvas canvas, Size size) {
    _drawDraft(canvas);
    for (final line in lines) {
      _drawHandrail(canvas, line);
    }
    _drawConnectionPoints(canvas);
  }

  void _drawDraft(Canvas canvas) {
    final value = draft;
    if (value == null) return;
    if (value.kind == DraftKind.layout) {
      final rect = Rect.fromPoints(value.start, value.end);
      canvas.drawRect(
        rect,
        Paint()..color = const Color(0xFF1769AA).withValues(alpha: .12),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0xFF1769AA)
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke,
      );
      final width = ((rect.width / 40) * 250).round();
      final height = ((rect.height / 40) * 250).round();
      _label(canvas, '$width × ${height}mm', rect.center);
      return;
    }
    final end = value.end;
    canvas.drawLine(
      value.start,
      end,
      Paint()
        ..color = const Color(0xFFC9372C).withValues(alpha: .72)
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    final length = (((end - value.start).distance / 40) * 250).round();
    _label(
      canvas,
      '${length}mm',
      Offset.lerp(value.start, end, .5)! - const Offset(0, 20),
    );
  }

  void _drawHandrail(Canvas canvas, WorkLine line) {
    final handrailPath = pathFor(line);
    final points = handrailPath.points
        .map((point) => Offset(mmToPixels(point.xMm), mmToPixels(point.yMm)))
        .toList();
    if (points.length < 2) return;
    final freestanding =
        line.installationType == HandrailInstallationType.freestanding;
    final lineColor = freestanding
        ? const Color(0xFF13805B)
        : const Color(0xFFC9372C);
    for (var index = 0; index < points.length - 1; index++) {
      final start = points[index];
      final end = points[index + 1];
      if (line.id == selectedId || focusedHandrailIds.contains(line.id)) {
        canvas.drawLine(
          start,
          end,
          Paint()
            ..color = selectionColor.withValues(alpha: .3)
            ..strokeWidth = 20
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = lineColor
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round,
      );
    }
    _label(
      canvas,
      'No.${constructionNumberFor(line)}  ${line.lengthMm}mm',
      _pathMidpoint(points) - const Offset(0, 20),
    );
  }

  Offset _pathMidpoint(List<Offset> points) {
    final lengths = <double>[];
    var total = 0.0;
    for (var index = 0; index < points.length - 1; index++) {
      final length = (points[index + 1] - points[index]).distance;
      lengths.add(length);
      total += length;
    }
    var remaining = total / 2;
    for (var index = 0; index < lengths.length; index++) {
      if (remaining <= lengths[index]) {
        return Offset.lerp(
          points[index],
          points[index + 1],
          lengths[index] == 0 ? 0 : remaining / lengths[index],
        )!;
      }
      remaining -= lengths[index];
    }
    return points.last;
  }

  void _drawConnectionPoints(Canvas canvas) {
    for (final connection in connectionPoints) {
      final center = Offset(
        mmToPixels(connection.point.xMm),
        mmToPixels(connection.point.yMm),
      );
      if (connection.id == selectedConnectionPointId) {
        canvas.drawCircle(
          center,
          12,
          Paint()..color = const Color(0xFFFFC928).withValues(alpha: .45),
        );
      }
      _drawConnectionSymbol(canvas, connection, center);
      final number = connectionPointNumbers[connection.id];
      if (showConnectionNumbers && number != null) {
        _numberBadge(canvas, '$number', center + const Offset(14, -14));
      }
    }
  }

  void _drawConnectionSymbol(
    Canvas canvas,
    HandrailConnectionPoint connection,
    Offset center,
  ) {
    final markerPaint = Paint()
      ..color = connection.freestanding
          ? const Color(0xFF075C40)
          : const Color(0xFF7E221B)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..color = Colors.white;
    final direction = Offset(
      math.cos(connection.angleRadians),
      math.sin(connection.angleRadians),
    );
    final perpendicular = Offset(-direction.dy, direction.dx);
    final crossAxis = perpendicular * 7;
    if (connection.freestanding) {
      final postAxis = perpendicular * 13;
      final baseAxis = direction * 5;
      final postEnd = center + postAxis;
      canvas.drawLine(center, postEnd, markerPaint);
      canvas.drawLine(postEnd - baseAxis, postEnd + baseAxis, markerPaint);
    }

    switch (connection.kind) {
      case HandrailConnectionKind.endBracket:
        canvas.drawLine(center - crossAxis, center + crossAxis, markerPaint);
        canvas.drawRect(
          Rect.fromCenter(center: center, width: 6, height: 6),
          markerPaint,
        );
      case HandrailConnectionKind.intermediateBracket:
        canvas.drawLine(center - crossAxis, center + crossAxis, markerPaint);
        canvas.drawCircle(center, 3.5, fillPaint);
        canvas.drawCircle(
          center,
          3.5,
          markerPaint..style = PaintingStyle.stroke,
        );
      case HandrailConnectionKind.connectionJoint:
        switch (connection.displayType) {
          case JointProductType.lShapeConnection:
            final diamond = Path()
              ..moveTo(center.dx, center.dy - 7)
              ..lineTo(center.dx + 7, center.dy)
              ..lineTo(center.dx, center.dy + 7)
              ..lineTo(center.dx - 7, center.dy)
              ..close();
            canvas.drawPath(diamond, fillPaint);
            canvas.drawPath(diamond, markerPaint..style = PaintingStyle.stroke);
          case JointProductType.twoDimensionalConnection:
            canvas.drawCircle(center, 7, fillPaint);
            canvas.drawCircle(
              center,
              7,
              markerPaint..style = PaintingStyle.stroke,
            );
            canvas.drawLine(
              center - const Offset(5, 0),
              center + const Offset(5, 0),
              markerPaint,
            );
          case JointProductType.threeDimensionalConnection:
            canvas.drawCircle(center, 8, fillPaint);
            canvas.drawCircle(
              center,
              8,
              markerPaint..style = PaintingStyle.stroke,
            );
            canvas.drawLine(
              center - const Offset(5, 0),
              center + const Offset(5, 0),
              markerPaint,
            );
            canvas.drawLine(
              center - const Offset(0, 5),
              center + const Offset(0, 5),
              markerPaint,
            );
          case JointProductType.endBracket:
          case JointProductType.intermediateBracket:
            break;
        }
    }
    markerPaint.style = PaintingStyle.fill;
  }

  void _numberBadge(Canvas canvas, String text, Offset center) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF20262C),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final radius = math.max(10.0, painter.width / 2 + 5);
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFFFE69A));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF8A6810)
        ..style = PaintingStyle.stroke,
    );
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _label(Canvas canvas, String text, Offset center) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF20262C),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(
      center: center,
      width: painter.width + 12,
      height: painter.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = Colors.white.withValues(alpha: .95),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()
        ..color = const Color(0xFFCDD4DA)
        ..style = PaintingStyle.stroke,
    );
    painter.paint(canvas, Offset(rect.left + 6, rect.top + 3));
  }

  @override
  bool shouldRepaint(covariant PlanPainter oldDelegate) => true;
}

class LayoutWallGap {
  const LayoutWallGap({
    required this.edge,
    required this.start,
    required this.end,
  });

  final WallEdge edge;
  final double start;
  final double end;
}

class LayoutPainter extends CustomPainter {
  const LayoutPainter({
    required this.selected,
    required this.selectionColor,
    required this.cutouts,
    required this.wallGaps,
  });

  final bool selected;
  final Color selectionColor;
  final List<Rect> cutouts;
  final List<LayoutWallGap> wallGaps;

  @override
  void paint(Canvas canvas, Size size) {
    var region = Path()..addRect(Offset.zero & size);
    for (final cutout in cutouts) {
      region = Path.combine(
        PathOperation.difference,
        region,
        Path()..addRect(cutout),
      );
    }
    canvas.drawPath(
      region,
      Paint()
        ..color = Colors.white.withValues(alpha: .06)
        ..style = PaintingStyle.fill,
    );

    if (selected) {
      _drawWalls(
        canvas,
        size,
        Paint()
          ..color = selectionColor.withValues(alpha: .22)
          ..strokeWidth = 13
          ..strokeCap = StrokeCap.square,
      );
    }
    _drawWalls(
      canvas,
      size,
      Paint()
        ..color = selected ? selectionColor : const Color(0xFF20262C)
        ..strokeWidth = selected ? 5 : 4
        ..strokeCap = StrokeCap.square,
    );
  }

  void _drawWalls(Canvas canvas, Size size, Paint paint) {
    _drawEdge(
      canvas,
      edge: WallEdge.top,
      length: size.width,
      pointFor: (value) => Offset(value, 0),
      paint: paint,
    );
    _drawEdge(
      canvas,
      edge: WallEdge.bottom,
      length: size.width,
      pointFor: (value) => Offset(value, size.height),
      paint: paint,
    );
    _drawEdge(
      canvas,
      edge: WallEdge.left,
      length: size.height,
      pointFor: (value) => Offset(0, value),
      paint: paint,
    );
    _drawEdge(
      canvas,
      edge: WallEdge.right,
      length: size.height,
      pointFor: (value) => Offset(size.width, value),
      paint: paint,
    );
  }

  void _drawEdge(
    Canvas canvas, {
    required WallEdge edge,
    required double length,
    required Offset Function(double value) pointFor,
    required Paint paint,
  }) {
    final gaps =
        wallGaps
            .where((gap) => gap.edge == edge)
            .map(
              (gap) => (
                start: gap.start.clamp(0.0, length),
                end: gap.end.clamp(0.0, length),
              ),
            )
            .where((gap) => gap.end > gap.start)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    var cursor = 0.0;
    for (final gap in gaps) {
      if (gap.start > cursor) {
        canvas.drawLine(pointFor(cursor), pointFor(gap.start), paint);
      }
      cursor = math.max(cursor, gap.end);
    }
    if (cursor < length) {
      canvas.drawLine(pointFor(cursor), pointFor(length), paint);
    }
  }

  @override
  bool shouldRepaint(covariant LayoutPainter oldDelegate) => true;
}

class FixturePainter extends CustomPainter {
  const FixturePainter({
    required this.type,
    required this.selected,
    required this.rotationQuarterTurns,
    this.selectionColor = editorSelectionColor,
  });

  final FixtureType type;
  final bool selected;
  final int rotationQuarterTurns;
  final Color selectionColor;

  @override
  void paint(Canvas canvas, Size size) {
    final turns = rotationQuarterTurns % 4;
    final logicalSize = turns.isOdd ? Size(size.height, size.width) : size;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(turns * math.pi / 2);
    canvas.translate(-logicalSize.width / 2, -logicalSize.height / 2);
    final shortestSide = math.min(logicalSize.width, logicalSize.height);
    final stroke = Paint()
      ..color = selected ? selectionColor : const Color(0xFF263238)
      ..strokeWidth =
          (shortestSide * .035).clamp(1.1, 2.6).toDouble() +
          (selected ? .45 : 0)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = Colors.white.withValues(alpha: .94);
    switch (type) {
      case FixtureType.toilet:
        _drawToilet(canvas, logicalSize, stroke, fill);
      case FixtureType.diningTable:
        _drawDiningTable(canvas, logicalSize, stroke, fill);
      case FixtureType.kitchen:
        _drawKitchen(canvas, logicalSize, stroke, fill);
      case FixtureType.refrigerator:
        _drawRefrigerator(canvas, logicalSize, stroke, fill);
      case FixtureType.wardrobe:
        _drawWardrobe(canvas, logicalSize, stroke, fill);
      case FixtureType.bathtub:
        _drawBathtub(canvas, logicalSize, stroke, fill);
    }
    canvas.restore();
  }

  Rect _insetRect(Size size, [double factor = .06]) {
    final inset = math.max(1.5, math.min(size.width, size.height) * factor);
    return Rect.fromLTWH(
      inset,
      inset,
      math.max(1, size.width - inset * 2),
      math.max(1, size.height - inset * 2),
    );
  }

  void _drawToilet(Canvas canvas, Size size, Paint stroke, Paint fill) {
    if (size.height > size.width) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.rotate(math.pi / 2);
      _drawHorizontalToilet(
        canvas,
        Size(size.height, size.width),
        stroke,
        fill,
      );
      canvas.restore();
      return;
    }
    _drawHorizontalToilet(canvas, size, stroke, fill);
  }

  void _drawHorizontalToilet(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fill,
  ) {
    final bounds = _insetRect(size, .045);
    final tankWidth = bounds.width * .3;
    final tankRect = Rect.fromLTWH(
      bounds.left,
      bounds.top,
      tankWidth,
      bounds.height,
    );
    final tank = RRect.fromRectAndRadius(
      tankRect,
      Radius.circular(math.min(4, bounds.height * .08)),
    );
    canvas.drawRRect(tank, fill);
    canvas.drawRRect(tank, stroke);
    final tankInset = Rect.fromCenter(
      center: tankRect.center,
      width: tankRect.width * .5,
      height: tankRect.height * .65,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        tankInset,
        Radius.circular(tankInset.width * .34),
      ),
      stroke,
    );
    canvas.drawLine(
      Offset(tankRect.left, tankRect.center.dy),
      Offset(tankRect.left + tankRect.width * .28, tankRect.center.dy),
      Paint()
        ..color = stroke.color
        ..strokeWidth = math.max(stroke.strokeWidth, bounds.height * .055)
        ..strokeCap = StrokeCap.square,
    );

    final joinX = tankRect.right - stroke.strokeWidth / 2;
    final radius = bounds.height / 2;
    final bowl = Path()
      ..moveTo(joinX, bounds.top)
      ..lineTo(bounds.right - radius, bounds.top)
      ..cubicTo(
        bounds.right - radius * .25,
        bounds.top,
        bounds.right,
        bounds.top + radius * .45,
        bounds.right,
        bounds.center.dy,
      )
      ..cubicTo(
        bounds.right,
        bounds.bottom - radius * .45,
        bounds.right - radius * .25,
        bounds.bottom,
        bounds.right - radius,
        bounds.bottom,
      )
      ..lineTo(joinX, bounds.bottom)
      ..close();
    canvas.drawPath(bowl, fill);
    canvas.drawPath(bowl, stroke);
  }

  void _drawDiningTable(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final bounds = _insetRect(size, .04);
    final chairWidth = bounds.width * .23;
    final chairHeight = bounds.height * .24;
    for (var index = 0; index < 3; index++) {
      final x = bounds.left + bounds.width * (.05 + index * .335);
      for (final y in [bounds.top, bounds.bottom - chairHeight]) {
        final chair = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, chairWidth, chairHeight),
          Radius.circular(math.min(chairWidth, chairHeight) * .18),
        );
        canvas.drawRRect(chair, fill);
        canvas.drawRRect(chair, stroke);
      }
    }
    final tableRect = Rect.fromLTRB(
      bounds.left,
      bounds.top + bounds.height * .19,
      bounds.right,
      bounds.bottom - bounds.height * .19,
    );
    final table = RRect.fromRectAndRadius(
      tableRect,
      Radius.circular(math.min(tableRect.width, tableRect.height) * .1),
    );
    canvas.drawRRect(table, fill);
    canvas.drawRRect(table, stroke);
  }

  void _drawKitchen(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final bounds = _insetRect(size, .04);
    canvas.drawRect(bounds, fill);
    canvas.drawRect(bounds, stroke);
    final sink = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        bounds.left + bounds.width * .08,
        bounds.top + bounds.height * .2,
        bounds.width * .24,
        bounds.height * .6,
      ),
      Radius.circular(bounds.height * .08),
    );
    canvas.drawRRect(sink, stroke);
    canvas.drawLine(
      Offset(sink.center.dx, sink.top),
      Offset(sink.center.dx, sink.top + sink.height * .28),
      stroke,
    );
    final hobCenter = Offset(
      bounds.right - bounds.width * .17,
      bounds.center.dy,
    );
    final radius = math.min(bounds.width * .035, bounds.height * .15);
    for (final offset in [
      const Offset(-1, -1),
      const Offset(1, -1),
      const Offset(-1, 1),
      const Offset(1, 1),
    ]) {
      canvas.drawCircle(
        hobCenter +
            Offset(offset.dx * radius * 1.45, offset.dy * radius * 1.45),
        radius,
        stroke,
      );
    }
  }

  void _drawRefrigerator(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final bounds = _insetRect(size);
    canvas.drawRect(bounds, fill);
    canvas.drawRect(bounds, stroke);
    canvas.drawLine(
      Offset(bounds.left + bounds.width * .38, bounds.center.dy),
      Offset(bounds.right, bounds.center.dy),
      stroke,
    );
  }

  void _drawWardrobe(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final bounds = _insetRect(size, .04);
    canvas.drawRect(bounds, fill);
    canvas.drawRect(bounds, stroke);
    final side = bounds.left + bounds.width * .14;
    canvas.drawLine(
      Offset(side, bounds.top),
      Offset(side, bounds.bottom),
      stroke,
    );
    if (bounds.width >= 42 && bounds.height >= 24) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'タ\nン\nス',
          style: TextStyle(
            color: stroke.color,
            fontSize: math.min(bounds.height * .2, bounds.width * .09),
            height: .85,
            fontWeight: FontWeight.w500,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          side + (bounds.right - side - textPainter.width) / 2,
          bounds.center.dy - textPainter.height / 2,
        ),
      );
    }
  }

  void _drawBathtub(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final bounds = _insetRect(size, .04);
    canvas.drawRect(bounds, fill);
    canvas.drawRect(bounds, stroke);
    final tubRect = bounds.deflate(
      math.max(2, math.min(bounds.width, bounds.height) * .14),
    );
    final tub = RRect.fromRectAndRadius(
      tubRect,
      Radius.circular(math.min(tubRect.width, tubRect.height) * .38),
    );
    canvas.drawRRect(tub, stroke);
  }

  @override
  bool shouldRepaint(covariant FixturePainter oldDelegate) =>
      type != oldDelegate.type ||
      selected != oldDelegate.selected ||
      rotationQuarterTurns != oldDelegate.rotationQuarterTurns ||
      selectionColor != oldDelegate.selectionColor;
}

class ToiletPainter extends FixturePainter {
  const ToiletPainter({
    required super.selected,
    required super.rotationQuarterTurns,
    super.selectionColor,
  }) : super(type: FixtureType.toilet);
}

class DoorPainter extends CustomPainter {
  const DoorPainter({
    required this.edge,
    required this.selected,
    required this.flipped,
    this.doorType = DoorType.swing,
    this.selectionColor = editorSelectionColor,
  });

  final WallEdge edge;
  final bool selected;
  final bool flipped;
  final DoorType doorType;
  final Color selectionColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (flipped) {
      if (edge == WallEdge.top || edge == WallEdge.bottom) {
        canvas
          ..translate(size.width, 0)
          ..scale(-1, 1);
      } else {
        canvas
          ..translate(0, size.height)
          ..scale(1, -1);
      }
    }
    final stroke = Paint()
      ..color = selected ? selectionColor : const Color(0xFF263238)
      ..strokeWidth = selected ? 4 : 3
      ..style = PaintingStyle.stroke;
    final erase = Paint()
      ..color = Colors.white
      ..strokeWidth = 9;
    if (doorType == DoorType.sliding) {
      _paintSlidingDoor(canvas, size, stroke, erase);
      canvas.restore();
      return;
    }
    final radius = math.min(size.width, size.height);
    switch (edge) {
      case WallEdge.top:
        canvas.drawLine(Offset.zero, Offset(size.width, 0), erase);
        const hinge = Offset.zero;
        canvas.drawLine(hinge, Offset(0, radius), stroke);
        canvas.drawArc(
          Rect.fromCircle(center: hinge, radius: radius),
          0,
          math.pi / 2,
          false,
          stroke,
        );
      case WallEdge.bottom:
        canvas.drawLine(
          Offset(0, size.height),
          Offset(size.width, size.height),
          erase,
        );
        final hinge = Offset(0, size.height);
        canvas.drawLine(hinge, Offset(0, size.height - radius), stroke);
        canvas.drawArc(
          Rect.fromCircle(center: hinge, radius: radius),
          0,
          -math.pi / 2,
          false,
          stroke,
        );
      case WallEdge.left:
        canvas.drawLine(Offset.zero, Offset(0, size.height), erase);
        const hinge = Offset.zero;
        canvas.drawLine(hinge, Offset(radius, 0), stroke);
        canvas.drawArc(
          Rect.fromCircle(center: hinge, radius: radius),
          math.pi / 2,
          -math.pi / 2,
          false,
          stroke,
        );
      case WallEdge.right:
        canvas.drawLine(
          Offset(size.width, 0),
          Offset(size.width, size.height),
          erase,
        );
        final hinge = Offset(size.width, 0);
        canvas.drawLine(hinge, Offset(size.width - radius, 0), stroke);
        canvas.drawArc(
          Rect.fromCircle(center: hinge, radius: radius),
          math.pi / 2,
          math.pi / 2,
          false,
          stroke,
        );
    }
    canvas.restore();
  }

  void _paintSlidingDoor(Canvas canvas, Size size, Paint stroke, Paint erase) {
    final horizontal = edge == WallEdge.top || edge == WallEdge.bottom;
    final edgeAtStart = edge == WallEdge.top || edge == WallEdge.left;
    final direction = edgeAtStart ? 1.0 : -1.0;
    final depth = horizontal ? size.height : size.width;
    final panelGap = math.min(4.0, depth * .08);
    final trackGap = math.min(10.0, depth * .16);
    final arrowGap = math.min(22.0, trackGap + 8.0);

    if (horizontal) {
      final wallY = edge == WallEdge.top ? 0.0 : size.height;
      canvas.drawLine(Offset(0, wallY), Offset(size.width, wallY), erase);
      final firstY = wallY + direction * panelGap;
      final secondY = wallY + direction * trackGap;
      canvas.drawLine(
        Offset(0, firstY),
        Offset(size.width * .58, firstY),
        stroke,
      );
      canvas.drawLine(
        Offset(size.width * .42, secondY),
        Offset(size.width, secondY),
        stroke,
      );
      canvas.drawLine(Offset(0, wallY), Offset(0, firstY), stroke);
      canvas.drawLine(
        Offset(size.width, wallY),
        Offset(size.width, secondY),
        stroke,
      );
      final arrowY = wallY + direction * arrowGap;
      final arrowStart = Offset(size.width * .30, arrowY);
      final arrowEnd = Offset(size.width * .72, arrowY);
      canvas.drawLine(arrowStart, arrowEnd, stroke);
      canvas.drawLine(
        arrowEnd,
        Offset(size.width * .63, arrowY - direction * 6),
        stroke,
      );
      canvas.drawLine(
        arrowEnd,
        Offset(size.width * .63, arrowY + direction * 6),
        stroke,
      );
      return;
    }

    final wallX = edge == WallEdge.left ? 0.0 : size.width;
    canvas.drawLine(Offset(wallX, 0), Offset(wallX, size.height), erase);
    final firstX = wallX + direction * panelGap;
    final secondX = wallX + direction * trackGap;
    canvas.drawLine(
      Offset(firstX, 0),
      Offset(firstX, size.height * .58),
      stroke,
    );
    canvas.drawLine(
      Offset(secondX, size.height * .42),
      Offset(secondX, size.height),
      stroke,
    );
    canvas.drawLine(Offset(wallX, 0), Offset(firstX, 0), stroke);
    canvas.drawLine(
      Offset(wallX, size.height),
      Offset(secondX, size.height),
      stroke,
    );
    final arrowX = wallX + direction * arrowGap;
    final arrowStart = Offset(arrowX, size.height * .30);
    final arrowEnd = Offset(arrowX, size.height * .72);
    canvas.drawLine(arrowStart, arrowEnd, stroke);
    canvas.drawLine(
      arrowEnd,
      Offset(arrowX - direction * 6, size.height * .63),
      stroke,
    );
    canvas.drawLine(
      arrowEnd,
      Offset(arrowX + direction * 6, size.height * .63),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant DoorPainter oldDelegate) =>
      edge != oldDelegate.edge ||
      selected != oldDelegate.selected ||
      flipped != oldDelegate.flipped ||
      doorType != oldDelegate.doorType ||
      selectionColor != oldDelegate.selectionColor;
}
