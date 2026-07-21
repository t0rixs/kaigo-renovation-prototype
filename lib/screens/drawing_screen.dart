import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../controller_disposal_scope.dart';
import '../formatters.dart';
import '../models.dart';
import 'drawing_painters.dart';
import 'estimate_screen.dart';

enum DrawingTool { layout, rail, equipment, door, window }

enum _EquipmentTool { toilet }

enum _LineDragMode { body, start, end }

class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key, required this.state});

  final AppState state;

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  static const pixelsPerGrid = 40.0;
  static const workspaceMargin = 320.0;
  static const minimumScale = .08;

  final TransformationController transform = TransformationController();
  final GlobalKey canvasKey = GlobalKey();
  final GlobalKey viewerKey = GlobalKey();
  DrawingTool? tool;
  _EquipmentTool? equipmentTool;
  DoorType doorTool = DoorType.swing;
  Offset? draftStartMm;
  Offset? draftCurrentMm;
  int? draftPointer;
  final Set<int> canvasPointers = {};
  bool pointerEditingExisting = false;
  bool multiTouchGestureActive = false;

  List<int>? objectOrigin;
  final Map<String, List<int>> attachedObjectOrigins = {};
  Offset objectDeltaPixels = Offset.zero;
  bool objectResize = false;
  bool objectChanged = false;
  PlanObject? objectDragItem;
  Offset? objectDragStartCanvas;
  String? objectOriginWallId;
  WallEdge? objectOriginWallEdge;
  bool objectOriginOpensOutward = false;

  List<int>? lineOrigin;
  Offset lineDeltaPixels = Offset.zero;
  Offset? lineDragStartCanvas;
  _LineDragMode? lineDragMode;
  bool lineChanged = false;

  AppState get state => widget.state;
  double get scale {
    final matrix = transform.value;
    final scaleX = matrix.entry(0, 0);
    final scaleY = matrix.entry(1, 0);
    return math.sqrt(scaleX * scaleX + scaleY * scaleY);
  }

  Color get selectionColor => editorSelectionColor;
  Size get canvasSize =>
      Size(_px(state.canvasWidthMm), _px(state.canvasHeightMm));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetView());
  }

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  double _px(int mm) => mm / AppState.gridMm * pixelsPerGrid;
  int _mm(double pixels) =>
      state.snapMm(pixels / pixelsPerGrid * AppState.gridMm);
  Offset _pointMm(Offset local) => Offset(
    _mm(local.dx.clamp(0, canvasSize.width)).toDouble(),
    _mm(local.dy.clamp(0, canvasSize.height)).toDouble(),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _toolbar(),
        if (tool == DrawingTool.equipment) _equipmentMenu(),
        if (tool == DrawingTool.door) _doorMenu(),
        _statusBar(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              if (wide) {
                return Row(
                  children: [
                    Expanded(child: _canvas()),
                    SizedBox(width: 320, child: _propertiesPanel()),
                  ],
                );
              }
              return _canvas();
            },
          ),
        ),
      ],
    );
  }

  double _toolBarHeight(double base) {
    final scaledLabel = MediaQuery.textScalerOf(context).scale(11);
    return (base + math.max(0, scaledLabel - 11) * 2).clamp(base, 94);
  }

  Widget _toolbar() => Container(
    height: _toolBarHeight(68),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: ListView(
      key: const ValueKey('drawing-toolbar'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      children: [
        _ToolButton(
          key: const ValueKey('tool-layout'),
          icon: CupertinoIcons.square,
          label: '間取り',
          selected: tool == DrawingTool.layout,
          onTap: () => _setTool(DrawingTool.layout),
        ),
        _ToolButton(
          key: const ValueKey('tool-rail'),
          icon: CupertinoIcons.minus,
          label: '手すり',
          selected: tool == DrawingTool.rail,
          color: Theme.of(context).colorScheme.error,
          onTap: () => _setTool(DrawingTool.rail),
        ),
        _ToolButton(
          key: const ValueKey('tool-equipment'),
          icon: CupertinoIcons.square_grid_2x2,
          label: '設備',
          selected: tool == DrawingTool.equipment,
          onTap: () => _setTool(DrawingTool.equipment),
        ),
        _ToolButton(
          key: const ValueKey('tool-door'),
          icon: Icons.door_front_door_outlined,
          label: 'ドア',
          selected: tool == DrawingTool.door,
          onTap: () => _setTool(DrawingTool.door),
        ),
        _ToolButton(
          key: const ValueKey('tool-window'),
          icon: Icons.window_outlined,
          label: '窓',
          selected: tool == DrawingTool.window,
          onTap: () => _setTool(DrawingTool.window),
        ),
        const VerticalDivider(width: 12, indent: 4, endIndent: 4),
        _ToolButton(
          icon: CupertinoIcons.arrow_uturn_left,
          label: '元に戻す',
          selected: false,
          enabled: state.canUndo,
          onTap: state.undo,
        ),
        _ToolButton(
          icon: CupertinoIcons.arrow_uturn_right,
          label: 'やり直し',
          selected: false,
          enabled: state.canRedo,
          onTap: state.redo,
        ),
        _ToolButton(
          icon: CupertinoIcons.trash,
          label: '削除',
          selected: false,
          enabled: state.selected != null,
          color: Theme.of(context).colorScheme.error,
          onTap: state.deleteSelected,
        ),
        _ToolButton(
          key: const ValueKey('drawing-settings'),
          icon: CupertinoIcons.gear,
          label: '図面設定',
          selected: false,
          onTap: _showCanvasSettings,
        ),
      ],
    ),
  );

  Widget _equipmentMenu() => Container(
    key: const ValueKey('equipment-menu'),
    height: _toolBarHeight(60),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      border: Border(
        bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      children: [
        _ToolButton(
          key: const ValueKey('equipment-toilet'),
          iconWidget: _ToiletToolIcon(
            selected: equipmentTool == _EquipmentTool.toilet,
          ),
          label: 'トイレ',
          selected: equipmentTool == _EquipmentTool.toilet,
          onTap: () => _setEquipmentTool(_EquipmentTool.toilet),
        ),
      ],
    ),
  );

  Widget _doorMenu() => Container(
    key: const ValueKey('door-menu'),
    height: _toolBarHeight(60),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      border: Border(
        bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      children: [
        _ToolButton(
          key: const ValueKey('door-swing'),
          icon: Icons.door_front_door_outlined,
          label: DoorType.swing.label,
          selected: doorTool == DoorType.swing,
          onTap: () => _setDoorTool(DoorType.swing),
        ),
        _ToolButton(
          key: const ValueKey('door-sliding'),
          icon: Icons.door_sliding_outlined,
          label: DoorType.sliding.label,
          selected: doorTool == DoorType.sliding,
          onTap: () => _setDoorTool(DoorType.sliding),
        ),
      ],
    ),
  );

  Widget _statusBar() {
    final text = switch (tool) {
      DrawingTool.layout => '間取り：空白をドラッグして長方形を作成（250mm単位）',
      DrawingTool.rail => '手すり：空白をドラッグして縦または横に作成',
      DrawingTool.equipment => switch (equipmentTool) {
        _EquipmentTool.toilet => 'トイレ：配置する中心グリッドをタップ',
        null => '配置する設備を選択',
      },
      DrawingTool.door => '${doorTool.label}：間取りの辺付近をタップして配置',
      DrawingTool.window => '間取りの辺付近をタップして窓を配置',
      null => 'ツール未選択：ドラッグで画面移動',
    };
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _canvas() => Stack(
    children: [
      Positioned.fill(
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: InteractiveViewer(
            key: viewerKey,
            transformationController: transform,
            constrained: false,
            minScale: minimumScale,
            maxScale: 2.5,
            boundaryMargin: const EdgeInsets.all(workspaceMargin),
            panEnabled: !_isDragTool,
            scaleEnabled: true,
            onInteractionUpdate: _handleViewerInteractionUpdate,
            onInteractionEnd: _handleViewerInteractionEnd,
            child: SizedBox(
              width: canvasSize.width + workspaceMargin * 2,
              height: canvasSize.height + workspaceMargin * 2,
              child: Center(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _handleCanvasPointerDown,
                  onPointerMove: _handleCanvasPointerMove,
                  onPointerUp: _handleCanvasPointerUp,
                  onPointerCancel: _handleCanvasPointerUp,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: _handleCanvasTap,
                    child: SizedBox.fromSize(
                      key: canvasKey,
                      size: canvasSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: PlanPainter(
                                lines: state.lines,
                                selectedId: state.selectedId,
                                mmToPixels: _px,
                                pathFor: state.handrailPath,
                                jointPointsFor: state.jointPointsFor,
                                constructionNumberFor:
                                    state.constructionNumberFor,
                                selectionColor: selectionColor,
                                draft: _draft,
                              ),
                            ),
                          ),
                          ...state.objects
                              .where(
                                (item) => item.kind == PlanObjectKind.layout,
                              )
                              .expand(_expandedLayoutHitTargets),
                          ..._selectedExpandedHitTargets(),
                          ...state.objects.map(_planObject),
                          ...state.lines.expand(_lineHitTargets),
                          if (state.selected is WorkLine)
                            ..._lineControls(state.selected! as WorkLine),
                          ..._selectedSharedWallButtons(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        right: 10,
        bottom: state.selected == null ? 12 : 72,
        child: Column(
          children: [
            _canvasButton(CupertinoIcons.plus, '拡大', () => _zoom(.18)),
            const SizedBox(height: 6),
            _canvasButton(CupertinoIcons.minus, '縮小', () => _zoom(-.18)),
            const SizedBox(height: 6),
            _canvasButton(CupertinoIcons.scope, '全体表示', _resetView),
          ],
        ),
      ),
      if (state.selected != null && MediaQuery.sizeOf(context).width < 900)
        _selectionBar(),
    ],
  );

  bool get _isDragTool =>
      tool == DrawingTool.layout || tool == DrawingTool.rail;

  EditorDraft? get _draft {
    final start = draftStartMm;
    final end = draftCurrentMm;
    if (start == null || end == null) return null;
    return EditorDraft(
      kind: tool == DrawingTool.rail ? DraftKind.rail : DraftKind.layout,
      start: Offset(_px(start.dx.round()), _px(start.dy.round())),
      end: Offset(_px(end.dx.round()), _px(end.dy.round())),
    );
  }

  void _setTool(DrawingTool value) {
    setState(() {
      tool = tool == value ? null : value;
      if (tool != DrawingTool.equipment) equipmentTool = null;
      draftStartMm = null;
      draftCurrentMm = null;
      draftPointer = null;
      canvasPointers.clear();
      multiTouchGestureActive = false;
    });
    if (state.selectedId != null) state.select(null);
  }

  void _setEquipmentTool(_EquipmentTool value) {
    setState(() => equipmentTool = value);
    if (state.selectedId != null) state.select(null);
  }

  void _setDoorTool(DoorType value) {
    setState(() => doorTool = value);
    if (state.selectedId != null) state.select(null);
  }

  void _handleCanvasPointerDown(PointerDownEvent event) {
    canvasPointers.add(event.pointer);
    if (canvasPointers.length > 1) {
      _suppressToolsForMultiTouch();
      return;
    }
    if (multiTouchGestureActive) return;
    if (!_isDragTool || pointerEditingExisting) return;
    draftPointer = event.pointer;
    _startDraft(event.localPosition);
  }

  void _handleCanvasPointerMove(PointerMoveEvent event) {
    if (multiTouchGestureActive ||
        event.pointer != draftPointer ||
        canvasPointers.length != 1) {
      return;
    }
    _updateDraft(event.localPosition);
  }

  void _handleViewerInteractionUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount > 1 || details.scale != 1) {
      _suppressToolsForMultiTouch();
    }
  }

  void _handleViewerInteractionEnd(ScaleEndDetails details) {
    if (!multiTouchGestureActive) return;
    _releaseMultiTouchWhenIdle();
  }

  void _suppressToolsForMultiTouch() {
    multiTouchGestureActive = true;
    draftPointer = null;
    if (draftStartMm != null || draftCurrentMm != null) _cancelDraft();
    if (objectOrigin != null) _endObjectDrag();
    if (lineOrigin != null) _endLineDrag();
  }

  void _releaseMultiTouchWhenIdle() {
    if (canvasPointers.isNotEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || canvasPointers.isNotEmpty) return;
      setState(() => multiTouchGestureActive = false);
    });
  }

  void _handleCanvasPointerUp(PointerEvent event) {
    canvasPointers.remove(event.pointer);
    if (multiTouchGestureActive) {
      draftPointer = null;
      _releaseMultiTouchWhenIdle();
      return;
    }
    if (event.pointer != draftPointer) return;
    draftPointer = null;
    if (pointerEditingExisting) {
      _cancelDraft();
    } else {
      _finishDraft();
    }
  }

  void _startDraft(Offset local) {
    final point = _pointMm(local);
    setState(() {
      draftStartMm = point;
      draftCurrentMm = point;
    });
  }

  void _updateDraft(Offset local) {
    setState(() => draftCurrentMm = _pointMm(local));
  }

  void _finishDraft() {
    if (multiTouchGestureActive) {
      _cancelDraft();
      return;
    }
    final start = draftStartMm;
    final end = draftCurrentMm;
    _cancelDraft();
    if (start == null || end == null) return;
    final dx = (end.dx - start.dx).round();
    final dy = (end.dy - start.dy).round();
    if (tool == DrawingTool.layout) {
      if (dx.abs() < AppState.gridMm || dy.abs() < AppState.gridMm) return;
      state.addLayout(
        math.min(start.dx, end.dx).round(),
        math.min(start.dy, end.dy).round(),
        dx.abs(),
        dy.abs(),
      );
    } else if (tool == DrawingTool.rail) {
      if (math.max(dx.abs(), dy.abs()) < AppState.gridMm) return;
      if (state.handrailCompletelyOverlapsLayoutEdge(
        start.dx.round(),
        start.dy.round(),
        end.dx.round(),
        end.dy.round(),
      )) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('手すりは間取りの縁と完全に重ならない位置へ配置してください')),
          );
        }
        return;
      }
      state.addHandrail(
        start.dx.round(),
        start.dy.round(),
        end.dx.round(),
        end.dy.round(),
      );
    }
  }

  void _cancelDraft() {
    setState(() {
      draftStartMm = null;
      draftCurrentMm = null;
    });
  }

  void _handleCanvasTap(TapUpDetails details) {
    if (multiTouchGestureActive) return;
    if (state.selectedId != null) {
      state.select(null);
      return;
    }
    final point = _pointMm(details.localPosition);
    switch (tool) {
      case DrawingTool.equipment:
        if (equipmentTool == _EquipmentTool.toilet) {
          state.addToilet(point.dx.round(), point.dy.round());
        }
      case DrawingTool.door:
        _addOpening(PlanObjectKind.door, point, doorType: doorTool);
      case DrawingTool.window:
        _addOpening(PlanObjectKind.window, point);
      case DrawingTool.layout || DrawingTool.rail:
      case null:
        state.select(null);
        return;
    }
  }

  void _addOpening(
    PlanObjectKind kind,
    Offset point, {
    DoorType doorType = DoorType.swing,
  }) {
    if (state.selectedId != null) state.select(null);
    final result = state.addOpening(
      kind,
      point.dx.round(),
      point.dy.round(),
      doorType: doorType,
    );
    if (result != OpeningAddResult.added && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (result) {
            OpeningAddResult.noWall =>
              '${kind == PlanObjectKind.door ? 'ドア' : '窓'}は間取りの辺付近に配置してください',
            OpeningAddResult.overlaps => 'その位置には既にドアまたは窓があります',
            OpeningAddResult.added => '',
          }),
        ),
      );
    }
  }

  Rect _objectRect(PlanObject item) {
    var left = _px(item.xMm);
    var top = _px(item.yMm);
    final width = _px(item.widthMm);
    final height = _px(item.heightMm);
    final renderedEdge = _renderedWallEdge(item);
    if (renderedEdge == WallEdge.bottom) top -= height;
    if (renderedEdge == WallEdge.right) left -= width;
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

  List<Widget> _selectedExpandedHitTargets() {
    final selected = state.selected;
    if (selected is PlanObject && selected.kind != PlanObjectKind.layout) {
      return _expandedObjectHitTargets(selected);
    }
    if (selected is WorkLine) {
      return _expandedLineHitTargets(selected);
    }
    return const [];
  }

  List<Widget> _expandedObjectHitTargets(PlanObject item) {
    final objectRect = _objectRect(item);
    final padding = _px(AppState.gridMm);
    final hitRect = objectRect.inflate(padding);
    return [
      Positioned.fromRect(
        key: ValueKey('selected-hit-${item.id}'),
        rect: hitRect,
        child: _objectGestureTarget(
          item: item,
          selected: true,
          objectSize: objectRect.size,
          canvasOrigin: hitRect.topLeft,
          forceResize: false,
          child: const SizedBox.expand(),
        ),
      ),
    ];
  }

  List<Widget> _expandedLayoutHitTargets(PlanObject item) {
    final objectRect = _objectRect(item);
    final selected = state.selectedId == item.id;
    final padding = _px(AppState.gridMm);
    final edgeHit = math.min(
      44.0,
      math.min(objectRect.width, objectRect.height) / 2,
    );
    final edgeRects = <(String, Rect)>[
      (
        'top',
        Rect.fromLTWH(
          objectRect.left,
          objectRect.top,
          objectRect.width,
          edgeHit,
        ).inflate(padding),
      ),
      (
        'bottom',
        Rect.fromLTWH(
          objectRect.left,
          objectRect.bottom - edgeHit,
          objectRect.width,
          edgeHit,
        ).inflate(padding),
      ),
      (
        'left',
        Rect.fromLTWH(
          objectRect.left,
          objectRect.top,
          edgeHit,
          objectRect.height,
        ).inflate(padding),
      ),
      (
        'right',
        Rect.fromLTWH(
          objectRect.right - edgeHit,
          objectRect.top,
          edgeHit,
          objectRect.height,
        ).inflate(padding),
      ),
    ];
    return [
      for (final edge in edgeRects)
        Positioned.fromRect(
          key: ValueKey('layout-expanded-hit-${item.id}-${edge.$1}'),
          rect: edge.$2,
          child: _objectGestureTarget(
            item: item,
            selected: selected,
            objectSize: objectRect.size,
            canvasOrigin: edge.$2.topLeft,
            forceResize: false,
            child: const SizedBox.expand(),
          ),
        ),
    ];
  }

  List<Widget> _expandedLineHitTargets(WorkLine line) {
    final points = state.handrailPath(line).points;
    final padding = _px(AppState.gridMm);
    return [
      for (var index = 0; index < points.length - 1; index++)
        Positioned.fromRect(
          key: ValueKey('selected-hit-${line.id}-segment-$index'),
          rect: _lineSegmentRect(
            Offset(_px(points[index].xMm), _px(points[index].yMm)),
            Offset(_px(points[index + 1].xMm), _px(points[index + 1].yMm)),
          ).inflate(padding),
          child: _lineDragTarget(
            line,
            _LineDragMode.body,
            const SizedBox.expand(),
          ),
        ),
    ];
  }

  Widget _planObject(PlanObject item) {
    final rect = _objectRect(item);
    final selected = state.selectedId == item.id;
    if (item.kind == PlanObjectKind.layout) {
      return _layoutObject(item, rect, selected);
    }
    return Positioned.fromRect(
      rect: rect,
      child: Stack(
        key: ValueKey('object-${item.id}'),
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: _objectGestureTarget(
              item: item,
              selected: selected,
              objectSize: rect.size,
              canvasOrigin: rect.topLeft,
              child: _objectVisual(item, selected),
            ),
          ),
          if (selected)
            Positioned(
              right: 3,
              bottom: 3,
              width: 32,
              height: 32,
              child: _objectGestureTarget(
                item: item,
                selected: selected,
                objectSize: rect.size,
                canvasOrigin: rect.bottomRight - const Offset(35, 35),
                forceResize: true,
                child: _resizeDot(item),
              ),
            ),
        ],
      ),
    );
  }

  Widget _layoutObject(PlanObject item, Rect rect, bool selected) {
    final size = rect.size;
    final contacts = state.sharedWallContactsFor(item);
    final wallGaps =
        contacts
            .where((contact) => !contact.visible)
            .map(
              (contact) => LayoutWallGap(
                edge: contact.roomEdge,
                start: _px(
                  contact.segment.startMm -
                      (contact.segment.horizontal ? item.xMm : item.yMm),
                ),
                end: _px(
                  contact.segment.endMm -
                      (contact.segment.horizontal ? item.xMm : item.yMm),
                ),
              ),
            )
            .toList()
          ..addAll(
            state
                .layoutWallOcclusionsFor(item)
                .map(
                  (occlusion) => LayoutWallGap(
                    edge: occlusion.edge,
                    start: _px(
                      occlusion.startMm -
                          (occlusion.edge == WallEdge.top ||
                                  occlusion.edge == WallEdge.bottom
                              ? item.xMm
                              : item.yMm),
                    ),
                    end: _px(
                      occlusion.endMm -
                          (occlusion.edge == WallEdge.top ||
                                  occlusion.edge == WallEdge.bottom
                              ? item.xMm
                              : item.yMm),
                    ),
                  ),
                ),
          );
    final cutouts = state
        .containedLayouts(item)
        .map(
          (inner) => Rect.fromLTWH(
            _px(inner.xMm - item.xMm),
            _px(inner.yMm - item.yMm),
            _px(inner.widthMm),
            _px(inner.heightMm),
          ),
        )
        .toList();
    final hit = math.min(44.0, math.min(size.width, size.height) / 2);
    final verticalLength = math.max(0.0, size.height - hit * 2);
    final zones = <(String, Rect)>[
      ('top', Rect.fromLTWH(0, 0, size.width, hit)),
      ('bottom', Rect.fromLTWH(0, size.height - hit, size.width, hit)),
      ('left', Rect.fromLTWH(0, hit, hit, verticalLength)),
      ('right', Rect.fromLTWH(size.width - hit, hit, hit, verticalLength)),
    ];
    return Positioned.fromRect(
      rect: rect,
      child: Stack(
        key: ValueKey('object-${item.id}'),
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: LayoutPainter(
                  selected: selected,
                  selectionColor: selectionColor,
                  cutouts: cutouts,
                  wallGaps: wallGaps,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      _objectPlaceName(item),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          for (final zone in zones)
            Positioned.fromRect(
              rect: zone.$2,
              child: _objectGestureTarget(
                key: ValueKey('layout-edge-${item.id}-${zone.$1}'),
                item: item,
                selected: selected,
                objectSize: size,
                canvasOrigin: rect.topLeft + zone.$2.topLeft,
                forceResize: false,
                child: const SizedBox.expand(),
              ),
            ),
          if (selected)
            Positioned(
              right: 3,
              bottom: 3,
              width: 32,
              height: 32,
              child: _objectGestureTarget(
                item: item,
                selected: selected,
                objectSize: size,
                canvasOrigin: rect.bottomRight - const Offset(35, 35),
                forceResize: true,
                child: _resizeDot(item),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _selectedSharedWallButtons() {
    final selected = state.selected;
    if (selected is! PlanObject || selected.kind != PlanObjectKind.layout) {
      return const [];
    }
    return state
        .sharedWallContactsFor(selected)
        .map(_sharedWallButton)
        .toList();
  }

  Widget _sharedWallButton(LayoutWallContact contact) {
    const buttonSize = 32.0;
    final midpointMm = (contact.segment.startMm + contact.segment.endMm) / 2;
    final center = switch (contact.roomEdge) {
      WallEdge.top || WallEdge.bottom => Offset(
        _px(midpointMm.round()),
        _px(contact.segment.coordinateMm),
      ),
      WallEdge.left || WallEdge.right => Offset(
        _px(contact.segment.coordinateMm),
        _px(midpointMm.round()),
      ),
    };
    return Positioned(
      key: ValueKey('shared-wall-button-${contact.segment.key}'),
      left: center.dx - buttonSize / 2,
      top: center.dy - buttonSize / 2,
      width: buttonSize,
      height: buttonSize,
      child: Material(
        elevation: 3,
        color: contact.visible ? Colors.white : const Color(0xFFFFF3C4),
        shape: const CircleBorder(side: BorderSide(color: Color(0xFF98A2AB))),
        child: IconButton(
          tooltip: '共有壁を編集',
          padding: EdgeInsets.zero,
          iconSize: 18,
          onPressed: () => _showSharedWallOptions(contact),
          icon: Icon(
            contact.visible ? Icons.wallpaper_outlined : Icons.space_bar,
            color: contact.visible
                ? const Color(0xFF20262C)
                : const Color(0xFF9A6700),
          ),
        ),
      ),
    );
  }

  Future<void> _showSharedWallOptions(LayoutWallContact contact) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Text(
                '共有壁',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              key: const ValueKey('shared-wall-hide'),
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('壁を消す'),
              trailing: contact.visible ? null : const Icon(Icons.check),
              onTap: () {
                state.setSharedWallVisible(contact, false);
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              key: const ValueKey('shared-wall-show'),
              leading: const Icon(Icons.wallpaper_outlined),
              title: const Text('壁を表示'),
              trailing: contact.visible ? const Icon(Icons.check) : null,
              onTap: () {
                state.setSharedWallVisible(contact, true);
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _objectGestureTarget({
    Key? key,
    required PlanObject item,
    required bool selected,
    required Size objectSize,
    required Offset canvasOrigin,
    required Widget child,
    bool? forceResize,
  }) {
    final prioritizeCreation = _isDragTool && !selected && forceResize != true;
    return Listener(
      key: key,
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        if (!prioritizeCreation) _suppressCanvasInteraction();
      },
      onPointerUp: (_) {
        if (!prioritizeCreation) _releaseCanvasInteraction();
      },
      onPointerCancel: (_) {
        if (!prioritizeCreation) _releaseCanvasInteraction();
      },
      child: forceResize == true || selected
          ? RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                EagerGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      EagerGestureRecognizer
                    >(EagerGestureRecognizer.new, (_) {}),
              },
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) => _beginObjectDrag(
                  item,
                  selected,
                  objectSize,
                  event.localPosition,
                  forceResize: forceResize == true,
                  dragStartCanvas: _globalToCanvas(event.position),
                ),
                onPointerMove: (event) =>
                    _updateObjectAtGlobal(item, event.position),
                onPointerUp: (_) => _endObjectDrag(),
                onPointerCancel: (_) => _endObjectDrag(),
                child: child,
              ),
            )
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) =>
                  _handleObjectTap(item, canvasOrigin + details.localPosition),
              child: child,
            ),
    );
  }

  void _handleObjectTap(PlanObject item, Offset canvasPoint) {
    if (multiTouchGestureActive) return;
    if (item.kind == PlanObjectKind.layout &&
        tool == DrawingTool.equipment &&
        equipmentTool == _EquipmentTool.toilet) {
      final point = _pointMm(canvasPoint);
      state.addToilet(point.dx.round(), point.dy.round());
      return;
    }
    if (item.kind == PlanObjectKind.layout &&
        (tool == DrawingTool.door || tool == DrawingTool.window)) {
      _addOpening(
        tool == DrawingTool.door ? PlanObjectKind.door : PlanObjectKind.window,
        _pointMm(canvasPoint),
        doorType: doorTool,
      );
      return;
    }
    state.select(item.id);
  }

  void _suppressCanvasInteraction() {
    pointerEditingExisting = true;
    draftPointer = null;
    if (draftStartMm != null || draftCurrentMm != null) _cancelDraft();
  }

  void _releaseCanvasInteraction() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (objectOrigin == null && lineOrigin == null) {
        pointerEditingExisting = false;
      }
    });
  }

  Offset _globalToCanvas(Offset globalPosition) {
    final box = canvasKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(globalPosition) ?? Offset.zero;
  }

  Widget _resizeDot(PlanObject item) => Container(
    key: ValueKey('resize-${item.id}'),
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      color: selectionColor,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
    ),
  );

  Widget _objectVisual(PlanObject item, bool selected) => switch (item.kind) {
    PlanObjectKind.layout => Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        border: Border.all(
          color: selected ? selectionColor : const Color(0xFF20262C),
          width: selected ? 5 : 4,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: selectionColor.withValues(alpha: .24),
                  blurRadius: 9,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(10),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          _objectPlaceName(item),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    ),
    PlanObjectKind.fixture => CustomPaint(
      key: ValueKey('toilet-symbol-${item.id}'),
      painter: ToiletPainter(
        selected: selected,
        rotationQuarterTurns: item.rotationQuarterTurns,
        selectionColor: selectionColor,
      ),
    ),
    PlanObjectKind.door => CustomPaint(
      painter: DoorPainter(
        edge: _renderedWallEdge(item) ?? WallEdge.top,
        selected: selected,
        flipped: item.flipped,
        doorType: item.doorType,
        selectionColor: selectionColor,
      ),
    ),
    PlanObjectKind.window => CustomPaint(
      painter: WindowPainter(
        edge: item.wallEdge ?? WallEdge.top,
        selected: selected,
        selectionColor: selectionColor,
      ),
    ),
  };

  void _beginObjectDrag(
    PlanObject item,
    bool selected,
    Size size,
    Offset local, {
    bool? forceResize,
    Offset? dragStartCanvas,
  }) {
    if (multiTouchGestureActive) return;
    _suppressCanvasInteraction();
    objectResize =
        forceResize ??
        (selected &&
            local.dx >= size.width - 44 &&
            local.dy >= size.height - 44);
    objectDragItem = item;
    objectDragStartCanvas = dragStartCanvas;
    objectOriginWallId = item.wallId;
    objectOriginWallEdge = item.wallEdge;
    objectOriginOpensOutward = item.opensOutward;
    objectOrigin = [item.xMm, item.yMm, item.widthMm, item.heightMm];
    attachedObjectOrigins.clear();
    if (item.kind == PlanObjectKind.layout) {
      for (final opening in state.objects.where(
        (object) => object.wallId == item.id,
      )) {
        attachedObjectOrigins[opening.id] = [
          opening.xMm,
          opening.yMm,
          opening.widthMm,
          opening.heightMm,
        ];
      }
    }
    objectDeltaPixels = Offset.zero;
    objectChanged = false;
    state.select(item.id);
  }

  void _updateObjectAtGlobal(PlanObject item, Offset globalPosition) {
    if (multiTouchGestureActive) return;
    final start = objectDragStartCanvas;
    if (start == null) return;
    objectDeltaPixels = _globalToCanvas(globalPosition) - start;
    _applyObjectDelta(item);
  }

  void _applyObjectDelta(PlanObject item) {
    final origin = objectOrigin;
    if (origin == null) return;
    if (!objectChanged) state.checkpoint();
    objectChanged = true;
    _restoreObjectOrigin(item);
    final dx = _mm(objectDeltaPixels.dx);
    final dy = _mm(objectDeltaPixels.dy);
    if (objectResize) {
      state.resizeObjectBy(item, dx, dy);
    } else if (item.isWallAttached) {
      final horizontal =
          objectOriginWallEdge == WallEdge.top ||
          objectOriginWallEdge == WallEdge.bottom;
      final centerX = horizontal ? origin[0] + origin[2] ~/ 2 : origin[0];
      final centerY = horizontal ? origin[1] : origin[1] + origin[3] ~/ 2;
      state.moveOpeningTo(item, centerX + dx, centerY + dy);
    } else {
      state.moveObjectBy(item, dx, dy);
    }
    setState(() {});
  }

  void _restoreObjectOrigin(PlanObject item) {
    final origin = objectOrigin;
    if (origin == null) return;
    item.xMm = origin[0];
    item.yMm = origin[1];
    item.widthMm = origin[2];
    item.heightMm = origin[3];
    item.wallId = objectOriginWallId;
    item.wallEdge = objectOriginWallEdge;
    item.opensOutward = objectOriginOpensOutward;
    for (final entry in attachedObjectOrigins.entries) {
      final opening = state.objects
          .where((object) => object.id == entry.key)
          .firstOrNull;
      if (opening == null) continue;
      opening.xMm = entry.value[0];
      opening.yMm = entry.value[1];
      opening.widthMm = entry.value[2];
      opening.heightMm = entry.value[3];
    }
  }

  void _endObjectDrag() {
    objectOrigin = null;
    attachedObjectOrigins.clear();
    objectDeltaPixels = Offset.zero;
    objectDragItem = null;
    objectDragStartCanvas = null;
    objectOriginWallId = null;
    objectOriginWallEdge = null;
    objectOriginOpensOutward = false;
    objectResize = false;
    if (objectChanged) {
      objectChanged = false;
      state.changed();
    }
    pointerEditingExisting = false;
  }

  List<Widget> _lineHitTargets(WorkLine line) {
    final points = state.handrailPath(line).points;
    return [
      for (var index = 0; index < points.length - 1; index++)
        Positioned.fromRect(
          key: ValueKey(
            index == 0
                ? 'line-body-${line.id}'
                : 'line-body-${line.id}-segment-$index',
          ),
          rect: _lineSegmentRect(
            Offset(_px(points[index].xMm), _px(points[index].yMm)),
            Offset(_px(points[index + 1].xMm), _px(points[index + 1].yMm)),
          ),
          child: _lineDragTarget(
            line,
            _LineDragMode.body,
            const SizedBox.expand(),
          ),
        ),
    ];
  }

  Rect _lineSegmentRect(Offset start, Offset end) {
    final left = math.min(start.dx, end.dx);
    final top = math.min(start.dy, end.dy);
    return start.dy == end.dy
        ? Rect.fromLTWH(
            left,
            start.dy - 20,
            math.max(40, (end.dx - start.dx).abs()),
            40,
          )
        : Rect.fromLTWH(
            start.dx - 20,
            top,
            40,
            math.max(40, (end.dy - start.dy).abs()),
          );
  }

  List<Widget> _lineControls(WorkLine line) {
    final points = state.handrailPath(line).points;
    final start = Offset(_px(points.first.xMm), _px(points.first.yMm));
    final end = Offset(_px(points.last.xMm), _px(points.last.yMm));
    return [
      for (var index = 0; index < points.length - 1; index++)
        Positioned.fromRect(
          rect: _lineSegmentRect(
            Offset(_px(points[index].xMm), _px(points[index].yMm)),
            Offset(_px(points[index + 1].xMm), _px(points[index + 1].yMm)),
          ),
          child: _lineDragTarget(
            line,
            _LineDragMode.body,
            const SizedBox.expand(),
          ),
        ),
      _lineHandle(line, true, start),
      _lineHandle(line, false, end),
    ];
  }

  Widget _lineHandle(WorkLine line, bool start, Offset center) => Positioned(
    key: ValueKey('line-${line.id}-${start ? 'start' : 'end'}'),
    left: center.dx - 14,
    top: center.dy - 14,
    width: 28,
    height: 28,
    child: _lineDragTarget(
      line,
      start ? _LineDragMode.start : _LineDragMode.end,
      Container(
        decoration: BoxDecoration(
          color: selectionColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
    ),
  );

  Widget _lineDragTarget(WorkLine line, _LineDragMode mode, Widget child) {
    final body = mode == _LineDragMode.body;
    final selected = state.selectedId == line.id;
    final prioritizeCreation = body && !selected && _isDragTool;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        if (!prioritizeCreation) _suppressCanvasInteraction();
      },
      onPointerUp: (_) {
        if (!prioritizeCreation) _releaseCanvasInteraction();
      },
      onPointerCancel: (_) {
        if (!prioritizeCreation) _releaseCanvasInteraction();
      },
      child: body && !selected
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!multiTouchGestureActive) state.select(line.id);
              },
              child: child,
            )
          : RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                EagerGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      EagerGestureRecognizer
                    >(EagerGestureRecognizer.new, (_) {}),
              },
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) => _beginLineDrag(
                  line,
                  mode,
                  dragStartCanvas: _globalToCanvas(event.position),
                ),
                onPointerMove: (event) =>
                    _updateLineAtGlobal(line, event.position),
                onPointerUp: (_) => _endLineDrag(),
                onPointerCancel: (_) => _endLineDrag(),
                child: child,
              ),
            ),
    );
  }

  void _beginLineDrag(
    WorkLine line,
    _LineDragMode mode, {
    required Offset dragStartCanvas,
  }) {
    if (multiTouchGestureActive) return;
    _suppressCanvasInteraction();
    state.select(line.id);
    lineOrigin = [line.x1Mm, line.y1Mm, line.x2Mm, line.y2Mm];
    lineDeltaPixels = Offset.zero;
    lineDragStartCanvas = dragStartCanvas;
    lineDragMode = mode;
    lineChanged = false;
  }

  void _updateLineAtGlobal(WorkLine line, Offset globalPosition) {
    if (multiTouchGestureActive) return;
    final start = lineDragStartCanvas;
    if (start == null) return;
    lineDeltaPixels = _globalToCanvas(globalPosition) - start;
    _applyLineDelta(line);
  }

  void _applyLineDelta(WorkLine line) {
    final origin = lineOrigin;
    if (origin == null || lineDragMode == null) return;
    if (!lineChanged) state.checkpoint();
    lineChanged = true;
    line.x1Mm = origin[0];
    line.y1Mm = origin[1];
    line.x2Mm = origin[2];
    line.y2Mm = origin[3];
    final dx = _mm(lineDeltaPixels.dx);
    final dy = _mm(lineDeltaPixels.dy);
    switch (lineDragMode!) {
      case _LineDragMode.body:
        state.moveLineBy(line, dx, dy);
      case _LineDragMode.start:
        state.moveLineEnd(line, true, origin[0] + dx, origin[1] + dy);
      case _LineDragMode.end:
        state.moveLineEnd(line, false, origin[2] + dx, origin[3] + dy);
    }
    setState(() {});
  }

  void _endLineDrag() {
    lineOrigin = null;
    lineDeltaPixels = Offset.zero;
    lineDragStartCanvas = null;
    lineDragMode = null;
    if (lineChanged) {
      lineChanged = false;
      state.changed();
    }
    pointerEditingExisting = false;
  }

  Widget _selectionBar() {
    final selected = state.selected;
    return Positioned(
      left: 10,
      right: 10,
      bottom: 10,
      child: CupertinoPopupSurface(
        child: SizedBox(
          height: 54,
          child: Material(
            color: Colors.transparent,
            child: Row(
              children: [
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _selectedLabel(selected),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (selected is PlanObject &&
                    selected.kind == PlanObjectKind.door &&
                    selected.doorType == DoorType.swing)
                  IconButton(
                    tooltip: selected.opensOutward ? '内開きに変更' : '外開きに変更',
                    onPressed: () => state.toggleDoorOpeningSide(selected),
                    icon: const Icon(CupertinoIcons.arrow_2_squarepath),
                  ),
                if (selected is PlanObject &&
                    selected.kind == PlanObjectKind.door)
                  IconButton(
                    tooltip: selected.doorType == DoorType.swing
                        ? 'ドアを左右反転'
                        : '引き方向を反転',
                    onPressed: () => state.flipDoor(selected),
                    icon: const Icon(CupertinoIcons.arrow_left_right),
                  ),
                if (selected is PlanObject && selected.fixture == 'toilet')
                  IconButton(
                    tooltip: 'トイレを90度回転',
                    onPressed: () => state.rotateToilet(selected),
                    icon: const Icon(CupertinoIcons.rotate_right),
                  ),
                IconButton(
                  tooltip: '属性を編集',
                  onPressed: _editSelected,
                  icon: const Icon(CupertinoIcons.slider_horizontal_3),
                ),
                IconButton(
                  tooltip: '削除',
                  color: Theme.of(context).colorScheme.error,
                  onPressed: state.deleteSelected,
                  icon: const Icon(CupertinoIcons.trash),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _selectedLabel(Object? selected) => switch (selected) {
    PlanObject item => _planObjectSelectedLabel(item),
    WorkLine line => _handrailSelectedLabel(line),
    _ => '',
  };

  String _planObjectSelectedLabel(PlanObject item) {
    final doorState = item.kind == PlanObjectKind.door
        ? ' / ${_doorStateLabel(item)}'
        : '';
    final rotation = item.fixture == 'toilet'
        ? ' / ${item.rotationDegrees}°'
        : '';
    return '${_objectTypeName(item)}  ${_objectPlaceName(item)}  '
        '${item.widthMm} × ${item.heightMm}mm$doorState$rotation';
  }

  String _doorStateLabel(PlanObject item) {
    if (item.doorType == DoorType.swing) {
      return item.opensOutward ? '外開き' : '内開き';
    }
    final horizontal = item.isHorizontalWall;
    if (item.flipped) return horizontal ? '左引き' : '上引き';
    return horizontal ? '右引き' : '下引き';
  }

  String _objectTypeName(PlanObject item) => item.fixture == 'toilet'
      ? 'トイレ'
      : item.kind == PlanObjectKind.door
      ? item.doorType.label
      : item.kind.label;

  String _objectPlaceName(PlanObject item) => item.place.trim().isEmpty
      ? (item.kind == PlanObjectKind.layout ? '間取り' : '場所未設定')
      : item.place.trim();

  String _handrailSelectedLabel(WorkLine line) {
    final cost = state.costFor(line);
    return 'No.${state.constructionNumberFor(line)} 手すり  ${line.lengthMm}mm / '
        '${line.installationType.label} / ジョイント${cost.jointCount}個'
        '${cost.postCount > 0 ? '・柱${cost.postCount}本' : ''}  '
        '${formatYen(cost.total)}';
  }

  Widget _propertiesPanel() {
    final selected = state.selected;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '属性',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (selected == null)
            Text(
              '図面上のオブジェクトを選択してください',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Text(
              _selectedLabel(selected),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _editSelected,
              icon: const Icon(Icons.tune),
              label: const Text('属性を編集'),
            ),
            if (selected is PlanObject &&
                selected.kind == PlanObjectKind.door) ...[
              const SizedBox(height: 8),
              if (selected.doorType == DoorType.swing) ...[
                OutlinedButton.icon(
                  onPressed: () => state.toggleDoorOpeningSide(selected),
                  icon: const Icon(Icons.compare_arrows),
                  label: Text(selected.opensOutward ? '内開きに変更' : '外開きに変更'),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: () => state.flipDoor(selected),
                icon: Icon(
                  selected.doorType == DoorType.swing
                      ? Icons.flip
                      : Icons.swap_horiz,
                ),
                label: Text(
                  selected.doorType == DoorType.swing ? '左右反転' : '引き方向反転',
                ),
              ),
            ],
            if (selected is PlanObject && selected.fixture == 'toilet') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => state.rotateToilet(selected),
                icon: const Icon(Icons.rotate_right),
                label: const Text('90度回転'),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: state.deleteSelected,
              icon: const Icon(Icons.delete_outline),
              label: const Text('削除'),
            ),
          ],
          const Divider(height: 32),
          Text(
            '施工箇所 ${state.handrailEstimateGroups().length}件',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...state.lines.map(
            (line) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'No.${state.constructionNumberFor(line)} ${state.handrailPlace(line)}',
              ),
              subtitle: Text(
                '${line.lengthMm}mm / ${line.environment.label} / '
                '${line.installationType.label}',
              ),
              onTap: () => state.select(line.id),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSelected() async {
    final selected = state.selected;
    if (selected is WorkLine) {
      await showWorkLineEditor(context, state, selected);
    } else if (selected is PlanObject) {
      await _showObjectEditor(selected);
    }
  }

  Future<void> _showObjectEditor(PlanObject item) async {
    final place = TextEditingController(text: item.place);
    final width = TextEditingController(text: '${item.widthMm}');
    final height = TextEditingController(text: '${item.heightMm}');
    final openingLength = TextEditingController(
      text: '${item.isHorizontalWall ? item.widthMm : item.heightMm}',
    );
    var doorType = item.doorType;
    var doorFlipped = item.flipped;
    var doorOpensOutward = item.opensOutward;
    var toiletRotation = item.rotationQuarterTurns;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ControllerDisposalScope(
        controllers: [place, width, height, openingLength],
        builder: (_) => StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${item.kind.label}を編集',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: place,
                    decoration: const InputDecoration(labelText: '場所名'),
                  ),
                  const SizedBox(height: 12),
                  if (item.isWallAttached)
                    TextField(
                      controller: openingLength,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '開口幅',
                        suffixText: 'mm',
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: width,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '幅',
                              suffixText: 'mm',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: height,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '奥行',
                              suffixText: 'mm',
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (item.fixture == 'toilet') ...[
                    const SizedBox(height: 16),
                    const Text(
                      '回転角度',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment<int>(value: 0, label: Text('0°')),
                        ButtonSegment<int>(value: 1, label: Text('90°')),
                        ButtonSegment<int>(value: 2, label: Text('180°')),
                        ButtonSegment<int>(value: 3, label: Text('270°')),
                      ],
                      selected: {toiletRotation},
                      onSelectionChanged: (values) {
                        final next = values.first;
                        if ((next - toiletRotation).abs().isOdd) {
                          final oldWidth = width.text;
                          width.text = height.text;
                          height.text = oldWidth;
                        }
                        setSheetState(() => toiletRotation = next);
                      },
                    ),
                  ],
                  if (item.kind == PlanObjectKind.door) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '戸種',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<DoorType>(
                      segments: const [
                        ButtonSegment<DoorType>(
                          value: DoorType.swing,
                          icon: Icon(Icons.door_front_door_outlined),
                          label: Text('開き戸'),
                        ),
                        ButtonSegment<DoorType>(
                          value: DoorType.sliding,
                          icon: Icon(Icons.door_sliding_outlined),
                          label: Text('スライド戸'),
                        ),
                      ],
                      selected: {doorType},
                      onSelectionChanged: (values) => setSheetState(() {
                        doorType = values.first;
                        if (doorType == DoorType.sliding) {
                          doorOpensOutward = false;
                        }
                      }),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      doorType == DoorType.swing ? '開き方向' : '引き方向',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (doorType == DoorType.swing)
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(
                            value: false,
                            icon: Icon(Icons.login),
                            label: Text('内開き'),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            icon: Icon(Icons.logout),
                            label: Text('外開き'),
                          ),
                        ],
                        selected: {doorOpensOutward},
                        onSelectionChanged: (values) => setSheetState(
                          () => doorOpensOutward = values.first,
                        ),
                      )
                    else
                      SegmentedButton<bool>(
                        segments: [
                          ButtonSegment<bool>(
                            value: false,
                            icon: const Icon(Icons.arrow_forward),
                            label: Text(item.isHorizontalWall ? '右へ' : '下へ'),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            icon: const Icon(Icons.arrow_back),
                            label: Text(item.isHorizontalWall ? '左へ' : '上へ'),
                          ),
                        ],
                        selected: {doorFlipped},
                        onSelectionChanged: (values) =>
                            setSheetState(() => doorFlipped = values.first),
                      ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      state.checkpoint();
                      item.place = place.text.trim();
                      item.doorType = doorType;
                      item.flipped = doorFlipped;
                      item.opensOutward =
                          doorType == DoorType.swing && doorOpensOutward;
                      if (item.fixture == 'toilet') {
                        state.applyToiletRotation(item, toiletRotation);
                      }
                      if (item.isWallAttached) {
                        final desired = math.max(
                          AppState.gridMm,
                          state.snapMm(parseInt(openingLength.text)),
                        );
                        final current = item.isHorizontalWall
                            ? item.widthMm
                            : item.heightMm;
                        state.resizeObjectBy(
                          item,
                          desired - current,
                          desired - current,
                        );
                      } else {
                        final desiredWidth = math
                            .max(
                              AppState.gridMm,
                              state.snapMm(parseInt(width.text)),
                            )
                            .clamp(
                              AppState.gridMm,
                              state.canvasWidthMm - item.xMm,
                            );
                        final desiredHeight = math
                            .max(
                              AppState.gridMm,
                              state.snapMm(parseInt(height.text)),
                            )
                            .clamp(
                              AppState.gridMm,
                              state.canvasHeightMm - item.yMm,
                            );
                        state.resizeObjectBy(
                          item,
                          desiredWidth - item.widthMm,
                          desiredHeight - item.heightMm,
                        );
                      }
                      state.changed();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('反映する'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCanvasSettings() async {
    final width = TextEditingController(text: '${state.canvasWidthMm}');
    final height = TextEditingController(text: '${state.canvasHeightMm}');
    var updated = false;
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ControllerDisposalScope(
        controllers: [width, height],
        builder: (_) => StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '図面設定',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _dimensionInput(
                    key: const ValueKey('canvas-width-field'),
                    label: '横幅',
                    controller: width,
                  ),
                  const SizedBox(height: 12),
                  _dimensionInput(
                    key: const ValueKey('canvas-height-field'),
                    label: '縦幅',
                    controller: height,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const ValueKey('apply-canvas-settings'),
                    onPressed: () {
                      final targetWidth = math.max(
                        AppState.gridMm,
                        state.snapMm(parseInt(width.text)),
                      );
                      final targetHeight = math.max(
                        AppState.gridMm,
                        state.snapMm(parseInt(height.text)),
                      );
                      width.text = '$targetWidth';
                      height.text = '$targetHeight';
                      if (!state.setCanvasSize(targetWidth, targetHeight)) {
                        setSheetState(() {
                          error =
                              '配置済み要素を収めるには ${state.minimumCanvasWidthMm} × '
                              '${state.minimumCanvasHeightMm}mm 以上が必要です';
                        });
                        return;
                      }
                      updated = true;
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('反映する'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    if (updated && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resetView());
    }
  }

  Widget _dimensionInput({
    required Key key,
    required String label,
    required TextEditingController controller,
  }) {
    void step(int amount) {
      final current = parseInt(controller.text);
      controller.text = '${math.max(AppState.gridMm, current + amount)}';
    }

    return Row(
      children: [
        IconButton.outlined(
          tooltip: '$labelを250mm小さくする',
          onPressed: () => step(-AppState.gridMm),
          icon: const Icon(CupertinoIcons.minus),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            key: key,
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.end,
            decoration: InputDecoration(labelText: label, suffixText: 'mm'),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: '$labelを250mm大きくする',
          onPressed: () => step(AppState.gridMm),
          icon: const Icon(CupertinoIcons.plus),
        ),
      ],
    );
  }

  Widget _canvasButton(IconData icon, String tooltip, VoidCallback onPressed) =>
      Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: IconButton(
          tooltip: tooltip,
          icon: Icon(icon),
          onPressed: onPressed,
        ),
      );

  void _zoom(double amount) {
    final next = (scale + amount).clamp(minimumScale, 2.5);
    final translation = transform.value.getTranslation();
    final viewport =
        (viewerKey.currentContext?.findRenderObject() as RenderBox?)?.size;
    final focalPoint = viewport == null
        ? Offset.zero
        : Offset(viewport.width / 2, viewport.height / 2);
    final ratio = next / scale;
    final nextTranslation =
        focalPoint -
        (focalPoint - Offset(translation.x, translation.y)) * ratio;
    transform.value = Matrix4.diagonal3Values(next, next, 1)
      ..setTranslationRaw(nextTranslation.dx, nextTranslation.dy, 0);
  }

  void _resetView() {
    if (!mounted) return;
    final viewport =
        (viewerKey.currentContext?.findRenderObject() as RenderBox?)?.size;
    final fit = viewport == null
        ? .5
        : math
              .min(
                (viewport.width - 24) / canvasSize.width,
                (viewport.height - 24) / canvasSize.height,
              )
              .clamp(minimumScale, .75);
    final translationX = viewport == null
        ? 12.0
        : (viewport.width - canvasSize.width * fit) / 2 - workspaceMargin * fit;
    final translationY = viewport == null
        ? 12.0
        : (viewport.height - canvasSize.height * fit) / 2 -
              workspaceMargin * fit;
    transform.value = Matrix4.diagonal3Values(fit, fit, 1)
      ..setTranslationRaw(translationX, translationY, 0);
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    this.icon,
    this.iconWidget,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.color,
  });

  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Theme.of(context).colorScheme.primary;
    final scheme = Theme.of(context).colorScheme;
    final scaledLabel = MediaQuery.textScalerOf(context).scale(11);
    final extraWidth = math.max(0, scaledLabel - 11) * 4;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        button: true,
        selected: selected,
        enabled: enabled,
        label: label,
        child: Tooltip(
          message: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: enabled ? onTap : null,
            child: Opacity(
              opacity: enabled ? 1 : .35,
              child: Container(
                width: (66 + extraWidth).toDouble(),
                decoration: BoxDecoration(
                  color: selected
                      ? foreground.withValues(alpha: .12)
                      : Colors.transparent,
                  border: Border.all(
                    width: selected ? 1.5 : 1,
                    color: selected ? foreground : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    iconWidget ??
                        Icon(
                          icon,
                          size: 22,
                          color: selected || color != null
                              ? foreground
                              : scheme.onSurfaceVariant,
                        ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: selected ? foreground : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToiletToolIcon extends StatelessWidget {
  const _ToiletToolIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 23,
    child: CustomPaint(
      painter: ToiletPainter(
        selected: selected,
        rotationQuarterTurns: 0,
        selectionColor: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
