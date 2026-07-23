import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'drawing_painters.dart';

class PhotoDrawingController {
  _PhotoDrawingCanvasState? _state;

  void centerOn(
    RenovationPhotoLocation location, {
    double rightInset = 0,
    double bottomInset = 0,
  }) => _state?._centerOn(
    location,
    rightInset: rightInset,
    bottomInset: bottomInset,
  );
}

class PhotoDrawingCanvas extends StatefulWidget {
  const PhotoDrawingCanvas({
    super.key,
    required this.state,
    required this.controller,
    required this.activeLocationId,
    required this.moveMode,
    required this.onMarkerTap,
    required this.onMarkerMoveStart,
    required this.onMarkerMove,
    required this.onMarkerMoveEnd,
  });

  final AppState state;
  final PhotoDrawingController controller;
  final String? activeLocationId;
  final bool moveMode;
  final ValueChanged<RenovationPhotoLocation> onMarkerTap;
  final ValueChanged<RenovationPhotoLocation> onMarkerMoveStart;
  final void Function(RenovationPhotoLocation location, Offset pointMm)
  onMarkerMove;
  final ValueChanged<RenovationPhotoLocation> onMarkerMoveEnd;

  @override
  State<PhotoDrawingCanvas> createState() => _PhotoDrawingCanvasState();
}

class _PhotoDrawingCanvasState extends State<PhotoDrawingCanvas>
    with SingleTickerProviderStateMixin {
  static const pixelsPerGrid = 40.0;
  static const minimumScale = .08;
  static const workspaceMargin = 320.0;
  static const viewAnimationDuration = Duration(milliseconds: 300);

  final TransformationController _transform = TransformationController();
  late final AnimationController _viewAnimationController;
  Animation<Matrix4>? _viewAnimation;
  Size _viewportSize = Size.zero;

  AppState get state => widget.state;
  double get _scale {
    final matrix = _transform.value;
    final scaleX = matrix.entry(0, 0);
    final scaleY = matrix.entry(1, 0);
    return math.sqrt(scaleX * scaleX + scaleY * scaleY);
  }

  Size get _canvasSize =>
      Size(_px(state.canvasWidthMm), _px(state.canvasHeightMm));

  double _px(int millimeters) => millimeters / AppState.gridMm * pixelsPerGrid;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    _viewAnimationController = AnimationController(
      vsync: this,
      duration: viewAnimationDuration,
    )..addListener(_handleViewAnimationTick);
    _transform.addListener(_handleTransformChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetView());
  }

  @override
  void didUpdateWidget(covariant PhotoDrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._state = null;
      widget.controller._state = this;
    }
    if (oldWidget.state.canvasWidthMm != state.canvasWidthMm ||
        oldWidget.state.canvasHeightMm != state.canvasHeightMm) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resetView());
    }
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    _viewAnimationController.dispose();
    _transform.removeListener(_handleTransformChanged);
    _transform.dispose();
    super.dispose();
  }

  void _handleTransformChanged() {
    if (mounted && state.photoLocations.isNotEmpty) setState(() {});
  }

  void _handleViewAnimationTick() {
    final animation = _viewAnimation;
    if (animation != null) _transform.value = animation.value;
  }

  void _stopViewAnimation() {
    _viewAnimationController.stop();
    _viewAnimation = null;
  }

  void _resetView() {
    if (!mounted || _viewportSize.isEmpty || _canvasSize.isEmpty) return;
    _stopViewAnimation();
    final fitScale = math
        .min(
          (_viewportSize.width - 32) / _canvasSize.width,
          (_viewportSize.height - 32) / _canvasSize.height,
        )
        .clamp(minimumScale, 1.0);
    final translation = Offset(
      (_viewportSize.width - _canvasSize.width * fitScale) / 2 -
          workspaceMargin * fitScale,
      (_viewportSize.height - _canvasSize.height * fitScale) / 2 -
          workspaceMargin * fitScale,
    );
    _transform.value = Matrix4.identity()
      ..translateByDouble(translation.dx, translation.dy, 0, 1)
      ..scaleByDouble(fitScale, fitScale, 1, 1);
  }

  void _centerOn(
    RenovationPhotoLocation location, {
    required double rightInset,
    required double bottomInset,
  }) {
    if (!mounted || _viewportSize.isEmpty) return;
    final visibleWidth = math.max(1.0, _viewportSize.width - rightInset);
    final visibleHeight = math.max(1.0, _viewportSize.height - bottomInset);
    final target = Offset(visibleWidth / 2, visibleHeight / 2);
    final point = Offset(
      workspaceMargin + _px(location.xMm),
      workspaceMargin + _px(location.yMm),
    );
    final currentScale = _scale.clamp(minimumScale, 2.5);
    final translation = target - point * currentScale;
    final targetTransform = Matrix4.identity()
      ..translateByDouble(translation.dx, translation.dy, 0, 1)
      ..scaleByDouble(currentScale, currentScale, 1, 1);
    _viewAnimationController.stop();
    _viewAnimation =
        Matrix4Tween(
          begin: _transform.value.clone(),
          end: targetTransform,
        ).animate(
          CurvedAnimation(
            parent: _viewAnimationController,
            curve: Curves.easeInOutCubic,
          ),
        );
    _viewAnimationController.forward(from: 0);
  }

  void _handleInteractionStart(ScaleStartDetails details) {
    _stopViewAnimation();
  }

  Offset? _pointMmAtGlobal(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final viewportPoint = box.globalToLocal(globalPosition);
    final scenePoint =
        _transform.toScene(viewportPoint) -
        const Offset(workspaceMargin, workspaceMargin);
    return Offset(
      state
          .snapMm(
            scenePoint.dx.clamp(0, _canvasSize.width) /
                pixelsPerGrid *
                AppState.gridMm,
          )
          .toDouble(),
      state
          .snapMm(
            scenePoint.dy.clamp(0, _canvasSize.height) /
                pixelsPerGrid *
                AppState.gridMm,
          )
          .toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = constraints.biggest;
        final markerScale = 1 / _scale.clamp(minimumScale, 2.5);
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: GestureDetector(
            key: const ValueKey('photo-drawing-canvas'),
            behavior: HitTestBehavior.opaque,
            child: InteractiveViewer(
              transformationController: _transform,
              constrained: false,
              minScale: minimumScale,
              maxScale: 2.5,
              boundaryMargin: const EdgeInsets.all(workspaceMargin),
              panEnabled: !widget.moveMode,
              scaleEnabled: true,
              onInteractionStart: _handleInteractionStart,
              child: SizedBox(
                key: const ValueKey('photo-drawing-workspace'),
                width: _canvasSize.width + workspaceMargin * 2,
                height: _canvasSize.height + workspaceMargin * 2,
                child: Center(
                  child: SizedBox.fromSize(
                    key: const ValueKey('photo-plan-canvas'),
                    size: _canvasSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: PhotoPlanPainter(state: state),
                            ),
                          ),
                        ),
                        for (
                          var index = 0;
                          index < state.photoLocations.length;
                          index++
                        )
                          _marker(
                            state.photoLocations[index],
                            state.photoLocations[index].handrailNumber,
                            markerScale,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _marker(
    RenovationPhotoLocation location,
    String number,
    double markerScale,
  ) {
    final active = location.id == widget.activeLocationId;
    final hitSize = 48 * markerScale;
    final markerSize = (active ? 34.0 : 30.0) * markerScale;
    return Positioned(
      left: _px(location.xMm) - hitSize / 2,
      top: _px(location.yMm) - hitSize / 2,
      width: hitSize,
      height: hitSize,
      child: Semantics(
        button: true,
        selected: active,
        label: '改修場所 $number',
        child: GestureDetector(
          key: ValueKey('photo-marker-${location.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onMarkerTap(location),
          onPanStart: widget.moveMode
              ? (_) => widget.onMarkerMoveStart(location)
              : null,
          onPanUpdate: widget.moveMode
              ? (details) {
                  final point = _pointMmAtGlobal(details.globalPosition);
                  if (point != null) widget.onMarkerMove(location, point);
                }
              : null,
          onPanEnd: widget.moveMode
              ? (_) => widget.onMarkerMoveEnd(location)
              : null,
          onPanCancel: widget.moveMode
              ? () => widget.onMarkerMoveEnd(location)
              : null,
          child: Center(
            child: Container(
              key: active
                  ? ValueKey('active-photo-marker-${location.id}')
                  : null,
              width: markerSize,
              height: markerSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF1769AA)
                    : const Color(0xFF263238),
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? const Color(0xFFFFC928) : Colors.white,
                  width: (active ? 3 : 2) * markerScale,
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 4),
                ],
              ),
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14 * markerScale,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PhotoPlanPainter extends CustomPainter {
  PhotoPlanPainter({required this.state});

  static const pixelsPerGrid = 40.0;

  final AppState state;

  double _px(int millimeters) => millimeters / AppState.gridMm * pixelsPerGrid;

  @override
  void paint(Canvas canvas, Size size) {
    const GridPainter().paint(canvas, size);
    final layouts = state.objects
        .where((item) => item.kind == PlanObjectKind.layout)
        .toList();
    final fixtures = state.objects
        .where((item) => item.kind == PlanObjectKind.fixture)
        .toList();
    final doors = state.objects
        .where((item) => item.kind == PlanObjectKind.door)
        .toList();

    for (final layout in layouts) {
      final rect = _objectRect(layout);
      final wallGaps =
          state
              .sharedWallContactsFor(layout)
              .where((contact) => !contact.visible)
              .map(
                (contact) => LayoutWallGap(
                  edge: contact.roomEdge,
                  start: _px(
                    contact.segment.startMm -
                        (contact.segment.horizontal ? layout.xMm : layout.yMm),
                  ),
                  end: _px(
                    contact.segment.endMm -
                        (contact.segment.horizontal ? layout.xMm : layout.yMm),
                  ),
                ),
              )
              .toList()
            ..addAll(
              state
                  .layoutWallOcclusionsFor(layout)
                  .map(
                    (occlusion) => LayoutWallGap(
                      edge: occlusion.edge,
                      start: _px(
                        occlusion.startMm -
                            (occlusion.edge == WallEdge.top ||
                                    occlusion.edge == WallEdge.bottom
                                ? layout.xMm
                                : layout.yMm),
                      ),
                      end: _px(
                        occlusion.endMm -
                            (occlusion.edge == WallEdge.top ||
                                    occlusion.edge == WallEdge.bottom
                                ? layout.xMm
                                : layout.yMm),
                      ),
                    ),
                  ),
            );
      final cutouts = state
          .containedLayouts(layout)
          .map(
            (inner) => Rect.fromLTWH(
              _px(inner.xMm - layout.xMm),
              _px(inner.yMm - layout.yMm),
              _px(inner.widthMm),
              _px(inner.heightMm),
            ),
          )
          .toList();
      canvas.save();
      canvas.translate(rect.left, rect.top);
      LayoutPainter(
        selected: false,
        selectionColor: editorSelectionColor,
        cutouts: cutouts,
        wallGaps: wallGaps,
      ).paint(canvas, rect.size);
      canvas.restore();
    }

    for (final fixture in fixtures) {
      final rect = _objectRect(fixture);
      canvas.save();
      canvas.translate(rect.left, rect.top);
      FixturePainter(
        type: fixture.fixtureType ?? FixtureType.toilet,
        selected: false,
        rotationQuarterTurns: fixture.rotationQuarterTurns,
      ).paint(canvas, rect.size);
      canvas.restore();
    }

    for (final layout in layouts) {
      _paintLayoutLabel(canvas, layout);
    }

    for (final door in doors) {
      final rect = _objectRect(door);
      canvas.save();
      canvas.translate(rect.left, rect.top);
      DoorPainter(
        edge: _renderedWallEdge(door) ?? WallEdge.top,
        selected: false,
        flipped: door.flipped,
        doorType: door.doorType,
      ).paint(canvas, rect.size);
      canvas.restore();
    }

    final connectionPoints = state
        .handrailEstimateGroups()
        .expand(state.connectionPointsForGroup)
        .toList();
    PlanPainter(
      lines: state.lines,
      selectedId: null,
      mmToPixels: _px,
      pathFor: state.handrailPath,
      connectionPoints: connectionPoints,
      constructionNumberFor: state.constructionNumberFor,
    ).paint(canvas, size);
  }

  Rect _objectRect(PlanObject item) {
    var left = _px(item.xMm);
    var top = _px(item.yMm);
    final width = _px(item.widthMm);
    final height = _px(item.heightMm);
    final edge = _renderedWallEdge(item);
    if (edge == WallEdge.bottom) top -= height;
    if (edge == WallEdge.right) left -= width;
    return Rect.fromLTWH(left, top, width, height);
  }

  WallEdge? _renderedWallEdge(PlanObject item) {
    final edge = item.wallEdge;
    if (edge == null ||
        item.kind != PlanObjectKind.door ||
        item.doorType != DoorType.swing ||
        !item.opensOutward) {
      return edge;
    }
    return switch (edge) {
      WallEdge.top => WallEdge.bottom,
      WallEdge.right => WallEdge.left,
      WallEdge.bottom => WallEdge.top,
      WallEdge.left => WallEdge.right,
    };
  }

  void _paintLayoutLabel(Canvas canvas, PlanObject item) {
    const horizontalInset = 6.0;
    const verticalInset = 4.0;
    const style = TextStyle(fontSize: 13, fontWeight: FontWeight.w800);
    final roomRect = _objectRect(item);
    final maximumWidth = math.max(1.0, roomRect.width - horizontalInset * 2);
    final measure = TextPainter(
      text: TextSpan(text: _placeName(item), style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: math.max(1, maximumWidth - 8));
    final labelWidth = math.min(maximumWidth, measure.width + 8);
    final roomIndex = state.objects.indexWhere((entry) => entry.id == item.id);
    final containedIds = state.containedLayouts(item).map((e) => e.id).toSet();
    final blockers = <Rect>[];
    for (var index = 0; index < state.objects.length; index++) {
      final other = state.objects[index];
      if (other.id == item.id || other.kind != PlanObjectKind.layout) continue;
      if (index <= roomIndex && !containedIds.contains(other.id)) continue;
      final localRect = Rect.fromLTWH(
        _px(other.xMm - item.xMm),
        _px(other.yMm - item.yMm),
        _px(other.widthMm),
        _px(other.heightMm),
      ).intersect(Offset.zero & roomRect.size);
      if (!localRect.isEmpty) blockers.add(localRect);
    }
    final maxX = math.max(
      horizontalInset,
      roomRect.width - labelWidth - horizontalInset,
    );
    final maxY = math.max(verticalInset, roomRect.height - 44 - verticalInset);
    final candidates = <({Offset offset, TextAlign align})>[
      (
        offset: const Offset(horizontalInset, verticalInset),
        align: TextAlign.left,
      ),
      (offset: Offset(maxX, verticalInset), align: TextAlign.right),
      (offset: Offset(horizontalInset, maxY), align: TextAlign.left),
      (offset: Offset(maxX, maxY), align: TextAlign.right),
    ];
    for (var y = verticalInset; y <= maxY; y += 20) {
      for (var x = horizontalInset; x <= maxX; x += 20) {
        candidates.add((
          offset: Offset(x, y),
          align: x > (horizontalInset + maxX) / 2
              ? TextAlign.right
              : TextAlign.left,
        ));
      }
    }
    final candidate = candidates.where((entry) {
      final rect = entry.offset & Size(labelWidth, 44);
      return blockers.every((blocker) => !rect.overlaps(blocker));
    }).firstOrNull;
    if (candidate == null) return;
    final displayWidth = math.max(
      1.0,
      roomRect.width - candidate.offset.dx - horizontalInset,
    );
    final painter = TextPainter(
      text: TextSpan(text: _placeName(item), style: style),
      textDirection: TextDirection.ltr,
      textAlign: candidate.align,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(1, displayWidth - 4));
    painter.paint(
      canvas,
      roomRect.topLeft + candidate.offset + const Offset(2, 6),
    );
  }

  String _placeName(PlanObject item) =>
      item.place.trim().isEmpty ? '間取り' : item.place.trim();

  @override
  bool shouldRepaint(covariant PhotoPlanPainter oldDelegate) => true;
}
