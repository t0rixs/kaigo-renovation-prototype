import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../controller_disposal_scope.dart';
import '../formatters.dart';
import '../models.dart';
import 'drawing_painters.dart';
import 'editor_tool_button.dart';
import 'estimate_screen.dart';

enum DrawingTool { layout, rail, equipment, door }

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
  late final TextEditingController canvasWidthController;
  late final TextEditingController canvasHeightController;
  DrawingTool? tool;
  FixtureType? equipmentTool;
  DoorType doorTool = DoorType.swing;
  bool canvasSettingsActive = false;
  CanvasResizeEdge? canvasResizeEdge;
  Offset? canvasResizeStartGlobal;
  int canvasResizeOriginWidthMm = 0;
  int canvasResizeOriginHeightMm = 0;
  bool canvasResizeChanged = false;
  Offset? draftStartMm;
  Offset? draftCurrentMm;
  int? draftPointer;
  final Set<int> canvasPointers = {};
  bool pointerEditingExisting = false;
  bool multiTouchGestureActive = false;
  String? connectionEditorGroupId;
  String? selectedConnectionPointId;
  final Map<String, String> reinforcementPriceDrafts = {};

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
  double lastTransformScale = 1;

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
  HandrailEstimateGroup? get _connectionEditorGroup => state
      .handrailEstimateGroups()
      .where((group) => group.id == connectionEditorGroupId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    canvasWidthController = TextEditingController(
      text: '${state.canvasWidthMm}',
    );
    canvasHeightController = TextEditingController(
      text: '${state.canvasHeightMm}',
    );
    transform.addListener(_handleTransformChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetView());
  }

  @override
  void dispose() {
    transform.removeListener(_handleTransformChange);
    canvasWidthController.dispose();
    canvasHeightController.dispose();
    transform.dispose();
    super.dispose();
  }

  void _handleTransformChange() {
    final nextScale = scale;
    final scaleChanged = (nextScale - lastTransformScale).abs() > .001;
    lastTransformScale = nextScale;
    if (mounted &&
        (canvasSettingsActive || (state.selected != null && scaleChanged))) {
      setState(() {});
    }
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
        _statusBar(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final connectionGroup = _connectionEditorGroup;
              if (wide && connectionGroup != null) {
                return Row(
                  children: [
                    Expanded(child: _canvas()),
                    SizedBox(
                      width: 360,
                      child: _connectionEditorPanel(connectionGroup),
                    ),
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

  double _mobileConnectionEditorHeight() =>
      math.min(360, MediaQuery.sizeOf(context).height * .42);

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
        EditorToolButton(
          key: const ValueKey('tool-layout'),
          icon: CupertinoIcons.square,
          label: '間取り',
          selected: tool == DrawingTool.layout,
          onTap: () => _setTool(DrawingTool.layout),
        ),
        EditorToolButton(
          key: const ValueKey('tool-rail'),
          icon: CupertinoIcons.minus,
          label: '手すり',
          selected: tool == DrawingTool.rail,
          color: Theme.of(context).colorScheme.error,
          onTap: () => _setTool(DrawingTool.rail),
        ),
        EditorToolButton(
          key: const ValueKey('tool-equipment'),
          icon: CupertinoIcons.square_grid_2x2,
          label: '設備',
          selected: tool == DrawingTool.equipment,
          onTap: () => _setTool(DrawingTool.equipment),
        ),
        EditorToolButton(
          key: const ValueKey('tool-door'),
          icon: Icons.door_front_door_outlined,
          label: 'ドア',
          selected: tool == DrawingTool.door,
          onTap: () => _setTool(DrawingTool.door),
        ),
        const VerticalDivider(width: 12, indent: 4, endIndent: 4),
        EditorToolButton(
          icon: CupertinoIcons.arrow_uturn_left,
          label: '元に戻す',
          selected: false,
          enabled: state.canUndo,
          onTap: state.undo,
        ),
        EditorToolButton(
          icon: CupertinoIcons.arrow_uturn_right,
          label: 'やり直し',
          selected: false,
          enabled: state.canRedo,
          onTap: state.redo,
        ),
        EditorToolButton(
          icon: CupertinoIcons.trash,
          label: '削除',
          selected: false,
          enabled: state.selected != null,
          color: Theme.of(context).colorScheme.error,
          onTap: state.deleteSelected,
        ),
        EditorToolButton(
          key: const ValueKey('drawing-settings'),
          icon: CupertinoIcons.gear,
          label: '図面設定',
          selected: canvasSettingsActive,
          onTap: _toggleCanvasSettings,
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
        for (final type in FixtureType.values)
          EditorToolButton(
            key: ValueKey('equipment-${type.name}'),
            iconWidget: _FixtureToolIcon(
              type: type,
              selected: equipmentTool == type,
            ),
            label: type.menuLabel,
            selected: equipmentTool == type,
            onTap: () => _setEquipmentTool(type),
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
        EditorToolButton(
          key: const ValueKey('door-swing'),
          icon: Icons.door_front_door_outlined,
          label: DoorType.swing.label,
          selected: doorTool == DoorType.swing,
          onTap: () => _setDoorTool(DoorType.swing),
        ),
        EditorToolButton(
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
    final text = canvasSettingsActive
        ? '図面サイズ：外周ハンドルをドラッグ、または数値を入力（250mm単位）'
        : switch (tool) {
            DrawingTool.layout => '間取り：空白をドラッグして長方形を作成（250mm単位）',
            DrawingTool.rail => '手すり：空白をドラッグして直線を作成',
            DrawingTool.equipment => switch (equipmentTool) {
              FixtureType type => '${type.label}：配置する中心グリッドをタップ',
              null => '配置する設備を選択',
            },
            DrawingTool.door => '${doorTool.label}：間取りの辺付近をタップして配置',
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

  Widget _canvas() {
    final connectionGroup = _connectionEditorGroup;
    final connectionPoints = state
        .handrailEstimateGroups()
        .expand(state.connectionPointsForGroup)
        .toList();
    final focusedConnectionPoints = connectionGroup == null
        ? const <HandrailConnectionPoint>[]
        : state.connectionPointsForGroup(connectionGroup);
    final connectionPointNumbers = {
      for (var index = 0; index < focusedConnectionPoints.length; index++)
        focusedConnectionPoints[index].id: index + 1,
    };
    final focusedIds = connectionGroup?.lines.map((line) => line.id).toSet();
    return Stack(
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
                            const Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(painter: GridPainter()),
                              ),
                            ),
                            ...state.objects
                                .where(
                                  (item) => item.kind == PlanObjectKind.layout,
                                )
                                .expand(_expandedLayoutHitTargets),
                            ...state.objects
                                .where(
                                  (item) => item.kind == PlanObjectKind.layout,
                                )
                                .map(_planObject),
                            ...state.objects
                                .where(
                                  (item) => item.kind == PlanObjectKind.fixture,
                                )
                                .map(_planObject),
                            ...state.objects
                                .where(
                                  (item) => item.kind == PlanObjectKind.layout,
                                )
                                .expand(_layoutLabelLayer),
                            ...state.objects
                                .where(
                                  (item) => item.kind == PlanObjectKind.door,
                                )
                                .map(_planObject),
                            ..._selectedExpandedHitTargets(),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: PlanPainter(
                                    lines: state.lines,
                                    selectedId: state.selectedId,
                                    mmToPixels: _px,
                                    pathFor: state.handrailPath,
                                    connectionPoints: connectionPoints,
                                    constructionNumberFor:
                                        state.constructionNumberFor,
                                    selectionColor: selectionColor,
                                    focusedHandrailIds: focusedIds ?? const {},
                                    showConnectionNumbers:
                                        connectionGroup != null,
                                    connectionPointNumbers:
                                        connectionPointNumbers,
                                    selectedConnectionPointId:
                                        selectedConnectionPointId,
                                    draft: _draft,
                                  ),
                                ),
                              ),
                            ),
                            if (connectionGroup == null)
                              ...state.lines.expand(_lineHitTargets),
                            if (connectionGroup != null)
                              const Positioned.fill(
                                child: AbsorbPointer(
                                  child: ColoredBox(color: Colors.transparent),
                                ),
                              ),
                            if (connectionGroup != null)
                              ..._connectionPointHitTargets(connectionGroup),
                            if (state.selected is WorkLine &&
                                connectionGroup == null)
                              ..._lineControls(state.selected! as WorkLine),
                            ..._selectedSharedWallButtons(),
                            ..._selectedLayoutResizeHandle(),
                            ..._selectedObjectResizeHandle(),
                            if (canvasSettingsActive) ..._canvasResizeHandles(),
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
        if (tool == DrawingTool.equipment)
          Positioned(top: 0, left: 0, right: 0, child: _equipmentMenu()),
        if (tool == DrawingTool.door)
          Positioned(top: 0, left: 0, right: 0, child: _doorMenu()),
        if (canvasSettingsActive)
          Positioned(top: 10, left: 10, right: 10, child: _canvasSizePanel()),
        if (!canvasSettingsActive)
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
        if (state.selected != null && connectionGroup == null) _selectionBar(),
        if (connectionGroup != null && MediaQuery.sizeOf(context).width < 900)
          Positioned(
            left: 8,
            right: 8,
            bottom: 0,
            height: _mobileConnectionEditorHeight(),
            child: Material(
              elevation: 10,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              color: Theme.of(context).colorScheme.surface,
              child: _connectionEditorPanel(connectionGroup),
            ),
          ),
      ],
    );
  }

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
      canvasSettingsActive = false;
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

  void _toggleCanvasSettings() {
    FocusManager.instance.primaryFocus?.unfocus();
    final willOpen = !canvasSettingsActive;
    setState(() {
      canvasSettingsActive = willOpen;
      tool = null;
      equipmentTool = null;
      draftStartMm = null;
      draftCurrentMm = null;
      draftPointer = null;
      canvasPointers.clear();
      multiTouchGestureActive = false;
      _syncCanvasDimensionFields();
    });
    if (state.selectedId != null) state.select(null);
    if (willOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resetView());
    }
  }

  void _setEquipmentTool(FixtureType value) {
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
    if (_isDragTool &&
        (_selectedLayoutResizeRect()?.contains(event.localPosition) ?? false)) {
      _suppressCanvasInteraction();
      return;
    }
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
    if (multiTouchGestureActive || canvasSettingsActive) return;
    if (state.selectedId != null) {
      state.select(null);
      return;
    }
    final point = _pointMm(details.localPosition);
    switch (tool) {
      case DrawingTool.equipment:
        final type = equipmentTool;
        if (type != null) {
          state.addFixture(type, point.dx.round(), point.dy.round());
        }
      case DrawingTool.door:
        _addDoor(point, doorType: doorTool);
      case DrawingTool.layout || DrawingTool.rail:
      case null:
        state.select(null);
        return;
    }
  }

  void _addDoor(Offset point, {DoorType doorType = DoorType.swing}) {
    if (state.selectedId != null) state.select(null);
    final result = state.addDoor(
      point.dx.round(),
      point.dy.round(),
      doorType: doorType,
    );
    if (result != OpeningAddResult.added && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (result) {
            OpeningAddResult.noWall => 'ドアは間取りの辺付近に配置してください',
            OpeningAddResult.overlaps => 'その位置には既にドアがあります',
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
        _positionedLineSegment(
          key: ValueKey('selected-hit-${line.id}-segment-$index'),
          start: Offset(_px(points[index].xMm), _px(points[index].yMm)),
          end: Offset(_px(points[index + 1].xMm), _px(points[index + 1].yMm)),
          padding: padding,
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
          if (selected && item.kind == PlanObjectKind.door)
            Positioned(
              right: 3,
              bottom: 3,
              width: 32,
              height: 32,
              child: _objectGestureTarget(
                item: item,
                selected: true,
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
        ],
      ),
    );
  }

  List<Widget> _layoutLabelLayer(PlanObject item) {
    final roomRect = _objectRect(item);
    final placement = _layoutLabelPlacement(item, roomRect.size);
    if (placement == null) return const [];
    return [
      Positioned(
        left: roomRect.left + placement.offset.dx,
        top: roomRect.top + placement.offset.dy,
        child: _layoutLabelTarget(item, placement.hitSize),
      ),
      Positioned(
        left: roomRect.left + placement.offset.dx,
        top: roomRect.top + placement.offset.dy,
        child: IgnorePointer(
          child: _layoutLabelVisual(item, placement.size, placement.textAlign),
        ),
      ),
    ];
  }

  ({Offset offset, Size size, Size hitSize, TextAlign textAlign})?
  _layoutLabelPlacement(PlanObject item, Size roomSize) {
    const horizontalInset = 6.0;
    const verticalInset = 4.0;
    const minimumTarget = 44.0;
    final textPainter = TextPainter(
      text: TextSpan(
        text: _objectPlaceName(item),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout(maxWidth: math.max(1, roomSize.width - horizontalInset * 2 - 8));
    final maximumWidth = math.max(1.0, roomSize.width - horizontalInset * 2);
    final labelSize = Size(
      math.min(maximumWidth, textPainter.width + 8),
      minimumTarget,
    );
    final roomIndex = state.objects.indexWhere(
      (object) => object.id == item.id,
    );
    final containedIds = state
        .containedLayouts(item)
        .map((room) => room.id)
        .toSet();
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
      ).intersect(Offset.zero & roomSize);
      if (!localRect.isEmpty) blockers.add(localRect);
    }

    final maxX = math.max(
      horizontalInset,
      roomSize.width - labelSize.width - horizontalInset,
    );
    final maxY = math.max(
      verticalInset,
      roomSize.height - labelSize.height - verticalInset,
    );
    final candidates = <({Offset offset, TextAlign textAlign})>[
      (
        offset: const Offset(horizontalInset, verticalInset),
        textAlign: TextAlign.left,
      ),
      (offset: Offset(maxX, verticalInset), textAlign: TextAlign.right),
      (offset: Offset(horizontalInset, maxY), textAlign: TextAlign.left),
      (offset: Offset(maxX, maxY), textAlign: TextAlign.right),
    ];
    const searchStep = 20.0;
    for (var y = verticalInset; y <= maxY; y += searchStep) {
      for (var x = horizontalInset; x <= maxX; x += searchStep) {
        candidates.add((
          offset: Offset(x, y),
          textAlign: x > (horizontalInset + maxX) / 2
              ? TextAlign.right
              : TextAlign.left,
        ));
      }
    }
    for (final candidate in candidates) {
      final offset = candidate.offset;
      final labelRect = offset & labelSize;
      if (blockers.every((blocker) => !labelRect.overlaps(blocker))) {
        return (
          offset: offset,
          size: Size(
            math.max(1, roomSize.width - offset.dx - horizontalInset),
            labelSize.height,
          ),
          hitSize: labelSize,
          textAlign: candidate.textAlign,
        );
      }
    }
    return null;
  }

  Widget _layoutLabelTarget(PlanObject item, Size size) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: (_) => _suppressCanvasInteraction(),
    onPointerUp: (_) => _releaseCanvasInteraction(),
    onPointerCancel: (_) => _releaseCanvasInteraction(),
    child: GestureDetector(
      key: ValueKey('layout-label-${item.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => state.select(item.id),
      child: SizedBox.fromSize(size: size),
    ),
  );

  Widget _layoutLabelVisual(PlanObject item, Size size, TextAlign textAlign) =>
      SizedBox.fromSize(
        key: ValueKey('layout-label-visual-${item.id}'),
        size: size,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Text(
            _objectPlaceName(item),
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
      );

  double get _resizeControlScale => scale.clamp(minimumScale, 2.5);
  double get _resizeHandleHitSize => 48 / _resizeControlScale;
  double get _resizeDotSize => 18 / _resizeControlScale;

  Rect _resizeHandleRectFor(PlanObject item) {
    final objectRect = _objectRect(item);
    final outsideOffset = 8 / _resizeControlScale;
    return Rect.fromCenter(
      center: objectRect.bottomRight + Offset(outsideOffset, outsideOffset),
      width: _resizeHandleHitSize,
      height: _resizeHandleHitSize,
    );
  }

  Rect? _selectedLayoutResizeRect() {
    final selected = state.selected;
    if (selected is! PlanObject || selected.kind != PlanObjectKind.layout) {
      return null;
    }
    return _resizeHandleRectFor(selected);
  }

  List<Widget> _selectedLayoutResizeHandle() {
    final selected = state.selected;
    final handleRect = _selectedLayoutResizeRect();
    if (selected is! PlanObject || handleRect == null) return const [];
    return [
      Positioned.fromRect(
        rect: handleRect,
        child: _objectGestureTarget(
          item: selected,
          selected: true,
          objectSize: _objectRect(selected).size,
          canvasOrigin: handleRect.topLeft,
          forceResize: true,
          child: Center(child: _resizeDot(selected, size: _resizeDotSize)),
        ),
      ),
    ];
  }

  List<Widget> _selectedObjectResizeHandle() {
    final selected = state.selected;
    if (selected is! PlanObject || selected.kind != PlanObjectKind.fixture) {
      return const [];
    }
    final handleRect = _resizeHandleRectFor(selected);
    return [
      Positioned.fromRect(
        key: ValueKey('resize-hit-${selected.id}'),
        rect: handleRect,
        child: _objectGestureTarget(
          item: selected,
          selected: true,
          objectSize: _objectRect(selected).size,
          canvasOrigin: handleRect.topLeft,
          forceResize: true,
          child: Center(child: _resizeDot(selected, size: _resizeDotSize)),
        ),
      ),
    ];
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
        equipmentTool != null) {
      final point = _pointMm(canvasPoint);
      state.addFixture(equipmentTool!, point.dx.round(), point.dy.round());
      return;
    }
    if (item.kind == PlanObjectKind.layout && tool == DrawingTool.door) {
      _addDoor(_pointMm(canvasPoint), doorType: doorTool);
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

  Widget _resizeDot(PlanObject item, {double? size}) => Container(
    key: ValueKey('resize-${item.id}'),
    width: size ?? 28,
    height: size ?? 28,
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
      key: ValueKey('${item.fixture}-symbol-${item.id}'),
      painter: FixturePainter(
        type: item.fixtureType ?? FixtureType.toilet,
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
        _positionedLineSegment(
          key: ValueKey(
            index == 0
                ? 'line-body-${line.id}'
                : 'line-body-${line.id}-segment-$index',
          ),
          start: Offset(_px(points[index].xMm), _px(points[index].yMm)),
          end: Offset(_px(points[index + 1].xMm), _px(points[index + 1].yMm)),
          child: _lineDragTarget(
            line,
            _LineDragMode.body,
            const SizedBox.expand(),
          ),
        ),
    ];
  }

  Widget _positionedLineSegment({
    Key? key,
    required Offset start,
    required Offset end,
    required Widget child,
    double padding = 0,
  }) {
    final center = Offset.lerp(start, end, .5)!;
    final length = math.max(40.0, (end - start).distance) + padding * 2;
    final height = 40.0 + padding * 2;
    return Positioned(
      key: key,
      left: center.dx - length / 2,
      top: center.dy - height / 2,
      width: length,
      height: height,
      child: Transform.rotate(
        angle: math.atan2(end.dy - start.dy, end.dx - start.dx),
        child: child,
      ),
    );
  }

  Iterable<Widget> _connectionPointHitTargets(
    HandrailEstimateGroup group,
  ) sync* {
    for (final point in state.connectionPointsForGroup(group)) {
      final center = Offset(_px(point.point.xMm), _px(point.point.yMm));
      yield Positioned(
        key: ValueKey('connection-point-hit-${point.id}'),
        left: center.dx - 22,
        top: center.dy - 22,
        width: 44,
        height: 44,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => selectedConnectionPointId = point.id),
        ),
      );
    }
  }

  List<Widget> _lineControls(WorkLine line) {
    final points = state.handrailPath(line).points;
    final start = Offset(_px(points.first.xMm), _px(points.first.yMm));
    final end = Offset(_px(points.last.xMm), _px(points.last.yMm));
    return [
      for (var index = 0; index < points.length - 1; index++)
        _positionedLineSegment(
          start: Offset(_px(points[index].xMm), _px(points[index].yMm)),
          end: Offset(_px(points[index + 1].xMm), _px(points[index + 1].yMm)),
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
                if (selected is PlanObject &&
                    selected.kind == PlanObjectKind.fixture)
                  IconButton(
                    tooltip: '設備を90度回転',
                    onPressed: () => state.rotateFixture(selected),
                    icon: const Icon(CupertinoIcons.rotate_right),
                  ),
                if (selected is WorkLine)
                  IconButton(
                    key: const ValueKey('open-connection-editor-compact'),
                    tooltip: '接続点を編集',
                    onPressed: () => _openConnectionEditor(selected),
                    icon: const Icon(Icons.hub_outlined),
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
    final rotation = item.kind == PlanObjectKind.fixture
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

  String _objectTypeName(PlanObject item) =>
      item.fixtureType?.label ??
      (item.kind == PlanObjectKind.door
          ? item.doorType.label
          : item.kind.label);

  String _objectPlaceName(PlanObject item) => item.place.trim().isEmpty
      ? (item.kind == PlanObjectKind.layout ? '間取り' : '場所未設定')
      : item.place.trim();

  String _handrailSelectedLabel(WorkLine line) {
    final group = state.estimateGroupFor(line);
    final cost = state.costForGroup(group);
    return 'No.${state.constructionNumberFor(line)} 手すり  ${group.lengthMm}mm / '
        '${line.installationType.label} / '
        '端部${cost.endBracketCount}個・中受${cost.intermediateBracketCount}個'
        '${cost.connectionJointCount > 0 ? '・接続${cost.connectionJointCount}個' : ''}'
        '${cost.postCount > 0 ? '・柱${cost.postCount}本' : ''}  '
        '${cost.reinforcementPlateCount > 0 ? '・補強板${cost.reinforcementPlateCount}枚' : ''}  '
        '${formatYen(cost.total)}';
  }

  void _openConnectionEditor(WorkLine line) {
    final group = state.estimateGroupFor(line);
    setState(() {
      tool = null;
      equipmentTool = null;
      canvasSettingsActive = false;
      connectionEditorGroupId = group.id;
      selectedConnectionPointId = null;
      reinforcementPriceDrafts.clear();
    });
    state.select(group.primary.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && connectionEditorGroupId == group.id) {
        _focusConnectionGroup(group);
      }
    });
  }

  void _focusConnectionGroup(HandrailEstimateGroup group) {
    final viewport =
        (viewerKey.currentContext?.findRenderObject() as RenderBox?)?.size;
    if (viewport == null) return;
    final points = group.lines
        .expand((line) => state.handrailPath(line).points)
        .toList();
    if (points.isEmpty) return;

    final minX = points.map((point) => point.xMm).reduce(math.min);
    final maxX = points.map((point) => point.xMm).reduce(math.max);
    final minY = points.map((point) => point.yMm).reduce(math.min);
    final maxY = points.map((point) => point.yMm).reduce(math.max);
    final mobile = MediaQuery.sizeOf(context).width < 900;
    final visibleHeight = math.max(
      140.0,
      viewport.height - (mobile ? _mobileConnectionEditorHeight() : 0),
    );
    final contentWidth = math.max(80.0, _px(maxX - minX) + 80);
    final contentHeight = math.max(80.0, _px(maxY - minY) + 80);
    final targetScale = math
        .min(
          (viewport.width - 32) / contentWidth,
          (visibleHeight - 24) / contentHeight,
        )
        .clamp(minimumScale, 1.1);
    final contentCenter = Offset(
      workspaceMargin + _px((minX + maxX) ~/ 2),
      workspaceMargin + _px((minY + maxY) ~/ 2),
    );
    final visibleCenter = Offset(viewport.width / 2, visibleHeight / 2);
    final translation = visibleCenter - contentCenter * targetScale;
    transform.value = Matrix4.diagonal3Values(targetScale, targetScale, 1)
      ..setTranslationRaw(translation.dx, translation.dy, 0);
  }

  void _closeConnectionEditor() {
    setState(() {
      connectionEditorGroupId = null;
      selectedConnectionPointId = null;
      reinforcementPriceDrafts.clear();
    });
  }

  Widget _connectionEditorPanel(HandrailEstimateGroup group) {
    final points = state.connectionPointsForGroup(group);
    final intermediateCount = state.intermediatePointCountForGroup(group);
    final manual = group.lines.any(
      (line) => line.manualIntermediatePointCount != null,
    );
    return Material(
      key: const ValueKey('connection-editor-panel'),
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '接続点編集',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('close-connection-editor'),
                  tooltip: '閉じる',
                  onPressed: _closeConnectionEditor,
                  icon: const Icon(CupertinoIcons.xmark),
                ),
              ],
            ),
            Text(
              'No.${state.constructionNumberFor(group.primary)}  '
              '${state.handrailPlace(group.primary)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${group.lines.length}本の手すりをまとめて選択中  /  '
              '接続点 ${points.length}個',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '中受接続点数',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('decrease-connection-points'),
                    tooltip: '中受接続点を1つ減らす',
                    onPressed: intermediateCount <= 0
                        ? null
                        : () {
                            state.setIntermediatePointCountForGroup(
                              group,
                              intermediateCount - 1,
                            );
                            reinforcementPriceDrafts.clear();
                            setState(() => selectedConnectionPointId = null);
                          },
                    icon: const Icon(CupertinoIcons.minus_circle),
                  ),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '$intermediateCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('increase-connection-points'),
                    tooltip: '中受接続点を1つ追加',
                    onPressed: intermediateCount >= 99
                        ? null
                        : () {
                            state.setIntermediatePointCountForGroup(
                              group,
                              intermediateCount + 1,
                            );
                            reinforcementPriceDrafts.clear();
                            setState(() => selectedConnectionPointId = null);
                          },
                    icon: const Icon(CupertinoIcons.plus_circle),
                  ),
                ],
              ),
            ),
            if (manual)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey('reset-connection-points'),
                  onPressed: () {
                    state.resetIntermediatePointsForGroup(group);
                    reinforcementPriceDrafts.clear();
                    setState(() => selectedConnectionPointId = null);
                  },
                  icon: const Icon(CupertinoIcons.refresh),
                  label: const Text('自動配置に戻す'),
                ),
              ),
            const Divider(height: 26),
            Text(
              '接続点ごとの使用部品',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < points.length; index++)
              _connectionPointEditorCard(group, points[index], index),
          ],
        ),
      ),
    );
  }

  Widget _connectionPointEditorCard(
    HandrailEstimateGroup group,
    HandrailConnectionPoint point,
    int index,
  ) {
    final products = state.jointProductsForKind(point.kind);
    final productId = point.jointProduct?.id;
    final selected = selectedConnectionPointId == point.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        key: ValueKey('connection-point-card-${index + 1}'),
        color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => selectedConnectionPointId = point.id),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: selected
                              ? Theme.of(context).colorScheme.onPrimary
                              : null,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            point.kind.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'x ${point.point.xMm} / y ${point.point.yMm}mm',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatYen(point.jointProduct?.unitPrice ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'connection-product-${point.id}-${productId ?? 'none'}',
                  ),
                  initialValue:
                      products.any((product) => product.id == productId)
                      ? productId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '使用部品'),
                  items: products
                      .map(
                        (product) => DropdownMenuItem(
                          value: product.id,
                          child: Text(
                            '${product.type.shortLabel}  ${product.id}  '
                            '${product.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: products.isEmpty
                      ? null
                      : (value) {
                          if (value == null) return;
                          state.setConnectionPointProduct(group, point, value);
                          setState(() => selectedConnectionPointId = point.id);
                        },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  key: ValueKey('reinforcement-plate-${point.id}'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: point.hasReinforcementPlate,
                  title: const Text(
                    '補強板',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    point.hasReinforcementPlate
                        ? 'この接続点へ補強板を追加'
                        : 'チェックすると5,000円で追加',
                  ),
                  onChanged: (value) {
                    if (value == null) return;
                    state.setConnectionPointReinforcementPlate(
                      group,
                      point,
                      value,
                    );
                    if (value) {
                      reinforcementPriceDrafts[point.id] =
                          '${AppState.defaultReinforcementPlatePrice}';
                    } else {
                      reinforcementPriceDrafts.remove(point.id);
                    }
                    setState(() => selectedConnectionPointId = point.id);
                  },
                ),
                if (point.hasReinforcementPlate)
                  TextFormField(
                    key: ValueKey('reinforcement-price-${point.id}'),
                    initialValue:
                        reinforcementPriceDrafts[point.id] ??
                        '${point.reinforcementPlatePrice}',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: '補強板単価',
                      suffixText: '円',
                    ),
                    onChanged: (value) =>
                        reinforcementPriceDrafts[point.id] = value,
                    onFieldSubmitted: (_) =>
                        _commitReinforcementPrice(group, point),
                    onTapOutside: (_) {
                      _commitReinforcementPrice(group, point);
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _commitReinforcementPrice(
    HandrailEstimateGroup group,
    HandrailConnectionPoint point,
  ) {
    final current = state
        .connectionPointsForGroup(group)
        .where((candidate) => candidate.id == point.id)
        .firstOrNull;
    if (current == null || !current.hasReinforcementPlate) return;
    final parsed = int.tryParse(
      reinforcementPriceDrafts[point.id] ??
          '${current.reinforcementPlatePrice}',
    );
    final price = parsed ?? AppState.defaultReinforcementPlatePrice;
    reinforcementPriceDrafts[point.id] = '$price';
    if (price != current.reinforcementPlatePrice) {
      state.setConnectionPointReinforcementPlatePrice(group, current, price);
    }
  }

  Future<void> _editSelected() async {
    final selected = state.selected;
    if (selected is WorkLine) {
      await showWorkLineEditor(
        context,
        state,
        selected,
        onEditConnectionPoints: () => _openConnectionEditor(selected),
      );
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
    var fixtureRotation = item.rotationQuarterTurns;
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
                    '${item.fixtureType?.label ?? item.kind.label}を編集',
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
                  if (item.kind == PlanObjectKind.fixture) ...[
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
                      selected: {fixtureRotation},
                      onSelectionChanged: (values) {
                        final next = values.first;
                        if ((next - fixtureRotation).abs().isOdd) {
                          final oldWidth = width.text;
                          width.text = height.text;
                          height.text = oldWidth;
                        }
                        setSheetState(() => fixtureRotation = next);
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
                      if (item.kind == PlanObjectKind.fixture) {
                        state.applyFixtureRotation(item, fixtureRotation);
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

  void _syncCanvasDimensionFields() {
    canvasWidthController.text = '${state.canvasWidthMm}';
    canvasHeightController.text = '${state.canvasHeightMm}';
  }

  Widget _canvasSizePanel() => CupertinoPopupSurface(
    child: Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '図面サイズ',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '250mm単位',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  key: const ValueKey('apply-canvas-settings'),
                  tooltip: '図面サイズを反映して閉じる',
                  onPressed: _applyCanvasDimensionFields,
                  icon: const Icon(
                    CupertinoIcons.check_mark,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _canvasDimensionField(
                    key: const ValueKey('canvas-width-field'),
                    label: '横幅',
                    controller: canvasWidthController,
                    submit: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _canvasDimensionField(
                    key: const ValueKey('canvas-height-field'),
                    label: '縦幅',
                    controller: canvasHeightController,
                    submit: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _canvasDimensionField({
    required Key key,
    required String label,
    required TextEditingController controller,
    required bool submit,
  }) => TextField(
    key: key,
    controller: controller,
    keyboardType: TextInputType.number,
    textInputAction: submit ? TextInputAction.done : TextInputAction.next,
    textAlign: TextAlign.end,
    onSubmitted: submit ? (_) => _applyCanvasDimensionFields() : null,
    decoration: InputDecoration(
      isDense: true,
      labelText: label,
      suffixText: 'mm',
    ),
  );

  void _applyCanvasDimensionFields() {
    final targetWidth = math.max(
      AppState.gridMm,
      state.snapMm(parseInt(canvasWidthController.text)),
    );
    final targetHeight = math.max(
      AppState.gridMm,
      state.snapMm(parseInt(canvasHeightController.text)),
    );
    _syncCanvasDimensionFields();
    if (!state.setCanvasSize(targetWidth, targetHeight)) {
      _syncCanvasDimensionFields();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '配置済み要素を収めるには ${state.minimumCanvasWidthMm} × '
            '${state.minimumCanvasHeightMm}mm 以上が必要です',
          ),
        ),
      );
      return;
    }
    _syncCanvasDimensionFields();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => canvasSettingsActive = false);
  }

  List<Widget> _canvasResizeHandles() => [
    _canvasResizeHandle(CanvasResizeEdge.top),
    _canvasResizeHandle(CanvasResizeEdge.right),
    _canvasResizeHandle(CanvasResizeEdge.bottom),
    _canvasResizeHandle(CanvasResizeEdge.left),
  ];

  Widget _canvasResizeHandle(CanvasResizeEdge edge) {
    final currentScale = math.max(scale, .01);
    final hitSize = 48.0 / currentScale;
    final visualSize = 30.0 / currentScale;
    final position = switch (edge) {
      CanvasResizeEdge.top => (
        left: canvasSize.width / 2 - hitSize / 2,
        top: 0.0,
      ),
      CanvasResizeEdge.right => (
        left: canvasSize.width - hitSize,
        top: canvasSize.height / 2 - hitSize / 2,
      ),
      CanvasResizeEdge.bottom => (
        left: canvasSize.width / 2 - hitSize / 2,
        top: canvasSize.height - hitSize,
      ),
      CanvasResizeEdge.left => (
        left: 0.0,
        top: canvasSize.height / 2 - hitSize / 2,
      ),
    };
    final icon = switch (edge) {
      CanvasResizeEdge.top => CupertinoIcons.chevron_up,
      CanvasResizeEdge.right => CupertinoIcons.chevron_right,
      CanvasResizeEdge.bottom => CupertinoIcons.chevron_down,
      CanvasResizeEdge.left => CupertinoIcons.chevron_left,
    };
    final label = switch (edge) {
      CanvasResizeEdge.top => '上辺で縦幅を変更',
      CanvasResizeEdge.right => '右辺で横幅を変更',
      CanvasResizeEdge.bottom => '下辺で縦幅を変更',
      CanvasResizeEdge.left => '左辺で横幅を変更',
    };
    return Positioned(
      key: ValueKey('canvas-resize-${edge.name}'),
      left: position.left,
      top: position.top,
      width: hitSize,
      height: hitSize,
      child: Semantics(
        button: true,
        label: label,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            EagerGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                  EagerGestureRecognizer.new,
                  (_) {},
                ),
          },
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => _beginCanvasResize(edge, event.position),
            onPointerMove: (event) => _updateCanvasResize(event.position),
            onPointerUp: (_) => _endCanvasResize(),
            onPointerCancel: (_) => _endCanvasResize(),
            child: Center(
              child: Container(
                width: visualSize,
                height: visualSize,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2 / currentScale,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .18),
                      blurRadius: 5 / currentScale,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 17 / currentScale,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _beginCanvasResize(CanvasResizeEdge edge, Offset globalPosition) {
    FocusManager.instance.primaryFocus?.unfocus();
    _suppressCanvasInteraction();
    canvasResizeEdge = edge;
    canvasResizeStartGlobal = globalPosition;
    canvasResizeOriginWidthMm = state.canvasWidthMm;
    canvasResizeOriginHeightMm = state.canvasHeightMm;
    canvasResizeChanged = false;
  }

  void _updateCanvasResize(Offset globalPosition) {
    final edge = canvasResizeEdge;
    final start = canvasResizeStartGlobal;
    if (edge == null || start == null) return;
    final delta = (globalPosition - start) / scale;
    final deltaX = _mm(delta.dx);
    final deltaY = _mm(delta.dy);
    final target = switch (edge) {
      CanvasResizeEdge.left => canvasResizeOriginWidthMm - deltaX,
      CanvasResizeEdge.right => canvasResizeOriginWidthMm + deltaX,
      CanvasResizeEdge.top => canvasResizeOriginHeightMm - deltaY,
      CanvasResizeEdge.bottom => canvasResizeOriginHeightMm + deltaY,
    };
    final previousWidth = state.canvasWidthMm;
    final previousHeight = state.canvasHeightMm;
    final resized = state.resizeCanvasFromEdge(
      edge,
      target,
      recordUndo: !canvasResizeChanged,
    );
    if (!resized ||
        (state.canvasWidthMm == previousWidth &&
            state.canvasHeightMm == previousHeight)) {
      return;
    }
    canvasResizeChanged = true;
    if (edge == CanvasResizeEdge.left || edge == CanvasResizeEdge.top) {
      final matrix = transform.value.clone();
      final translation = matrix.getTranslation();
      final widthDeltaPixels = _px(state.canvasWidthMm - previousWidth) * scale;
      final heightDeltaPixels =
          _px(state.canvasHeightMm - previousHeight) * scale;
      matrix.setTranslationRaw(
        translation.x - widthDeltaPixels,
        translation.y - heightDeltaPixels,
        0,
      );
      transform.value = matrix;
    }
    _syncCanvasDimensionFields();
    setState(() {});
  }

  void _endCanvasResize() {
    canvasResizeEdge = null;
    canvasResizeStartGlobal = null;
    canvasResizeChanged = false;
    _syncCanvasDimensionFields();
    _releaseCanvasInteraction();
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
    final visiblePadding = canvasSettingsActive ? 72.0 : 24.0;
    final fit = viewport == null
        ? .5
        : math
              .min(
                (viewport.width - visiblePadding) / canvasSize.width,
                (viewport.height - visiblePadding) / canvasSize.height,
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

class _FixtureToolIcon extends StatelessWidget {
  const _FixtureToolIcon({required this.type, required this.selected});

  final FixtureType type;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final aspect = type.defaultWidthMm / type.defaultHeightMm;
    final width = math.min(30.0, 23.0 * aspect);
    final height = math.min(23.0, 30.0 / aspect);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: FixturePainter(
          type: type,
          selected: selected,
          rotationQuarterTurns: 0,
          selectionColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
