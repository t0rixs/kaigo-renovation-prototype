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
    required this.jointPointsFor,
    required this.constructionNumberFor,
    this.selectionColor = editorSelectionColor,
    this.draft,
  });

  final List<WorkLine> lines;
  final String? selectedId;
  final double Function(int) mmToPixels;
  final HandrailPath Function(WorkLine) pathFor;
  final List<HandrailPoint> Function(WorkLine) jointPointsFor;
  final String Function(WorkLine) constructionNumberFor;
  final Color selectionColor;
  final EditorDraft? draft;

  @override
  void paint(Canvas canvas, Size size) {
    _drawDraft(canvas);
    for (final line in lines) {
      _drawHandrail(canvas, line);
    }
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
    final end = _lockedEnd(value.start, value.end);
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

  Offset _lockedEnd(Offset start, Offset end) =>
      (end.dx - start.dx).abs() > (end.dy - start.dy).abs()
      ? Offset(end.dx, start.dy)
      : Offset(start.dx, end.dy);

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
      if (line.id == selectedId) {
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
    _drawHandrailJoints(canvas, line);
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

  void _drawHandrailJoints(Canvas canvas, WorkLine line) {
    if (line.lengthMm <= 0) return;
    final joints = jointPointsFor(line);
    if (joints.isEmpty) return;
    final freestanding =
        line.installationType == HandrailInstallationType.freestanding;
    final markerPaint = Paint()
      ..color = freestanding ? const Color(0xFF075C40) : const Color(0xFF7E221B)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..color = Colors.white;
    final path = pathFor(line).points;
    for (final joint in joints) {
      final center = Offset(mmToPixels(joint.xMm), mmToPixels(joint.yMm));
      final horizontal = _jointSegmentIsHorizontal(
        joint,
        path,
        line.isHorizontal,
      );
      final axis = horizontal ? const Offset(0, 7) : const Offset(7, 0);
      if (freestanding) {
        final postAxis = horizontal ? const Offset(0, 13) : const Offset(13, 0);
        final baseAxis = horizontal ? const Offset(5, 0) : const Offset(0, 5);
        final postEnd = center + postAxis;
        canvas.drawLine(center, postEnd, markerPaint);
        canvas.drawLine(postEnd - baseAxis, postEnd + baseAxis, markerPaint);
      }
      canvas.drawLine(center - axis, center + axis, markerPaint);
      canvas.drawCircle(center, 3.5, fillPaint);
      canvas.drawCircle(center, 3.5, markerPaint..style = PaintingStyle.stroke);
      markerPaint.style = PaintingStyle.fill;
    }
  }

  bool _jointSegmentIsHorizontal(
    HandrailPoint joint,
    List<HandrailPoint> path,
    bool fallback,
  ) {
    for (var index = 0; index < path.length - 1; index++) {
      final start = path[index];
      final end = path[index + 1];
      final minX = math.min(start.xMm, end.xMm);
      final maxX = math.max(start.xMm, end.xMm);
      final minY = math.min(start.yMm, end.yMm);
      final maxY = math.max(start.yMm, end.yMm);
      if (joint.xMm >= minX &&
          joint.xMm <= maxX &&
          joint.yMm >= minY &&
          joint.yMm <= maxY) {
        return start.yMm == end.yMm;
      }
    }
    return fallback;
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

class ToiletPainter extends CustomPainter {
  const ToiletPainter({
    required this.selected,
    required this.rotationQuarterTurns,
    this.selectionColor = editorSelectionColor,
  });

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
    _drawToilet(canvas, logicalSize);
    canvas.restore();
  }

  void _drawToilet(Canvas canvas, Size size) {
    final shortestSide = math.min(size.width, size.height);
    final inset = math.max(4.0, shortestSide * .08);
    final strokeWidth =
        (shortestSide * .045).clamp(1.4, 4.0).toDouble() + (selected ? .7 : 0);
    final left = inset;
    final right = size.width - inset;
    final top = inset;
    final bottom = size.height - inset;
    final path = Path()
      ..moveTo(left + size.width * .06, bottom)
      ..cubicTo(
        left,
        top + size.height * .38,
        left + size.width * .14,
        top + size.height * .08,
        size.width / 2,
        top,
      )
      ..cubicTo(
        right - size.width * .14,
        top + size.height * .08,
        right,
        top + size.height * .38,
        right - size.width * .06,
        bottom,
      )
      ..lineTo(left + size.width * .06, bottom)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: .92));
    canvas.drawPath(
      path,
      Paint()
        ..color = selected ? selectionColor : const Color(0xFF263238)
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant ToiletPainter oldDelegate) =>
      selected != oldDelegate.selected ||
      rotationQuarterTurns != oldDelegate.rotationQuarterTurns ||
      selectionColor != oldDelegate.selectionColor;
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
