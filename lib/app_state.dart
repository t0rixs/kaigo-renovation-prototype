import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'storage/app_data_repository.dart';

typedef WallSnap = ({
  PlanObject wall,
  WallEdge edge,
  int xMm,
  int yMm,
  double distance,
});

typedef LayoutWallOcclusion = ({WallEdge edge, int startMm, int endMm});

typedef _JointPointEntry = ({
  WorkLine line,
  HandrailProduct product,
  bool endpoint,
  String pointKey,
  int xMm,
  int yMm,
});

enum OpeningAddResult { added, noWall, overlaps }

enum CanvasResizeEdge { top, right, bottom, left }

class AppState extends ChangeNotifier {
  static const gridMm = 250;
  static const majorGridMm = 500;
  static const defaultReinforcementPlatePrice = 5000;
  static const defaultCanvasWidthMm = RenovationProject.defaultCanvasWidthMm;
  static const defaultCanvasHeightMm = RenovationProject.defaultCanvasHeightMm;

  AppState({AppDataRepository? dataRepository})
    : _dataRepository = dataRepository ?? createAppDataRepository() {
    _replaceWithFreshProject();
  }

  final AppDataRepository _dataRepository;

  List<HandrailProduct> products = defaultHandrailProducts();
  List<JointProduct> jointProducts = defaultJointProducts();
  String? indoorDefaultProductId = 'demo-indoor-35';
  String? outdoorDefaultProductId = 'demo-outdoor-34';
  List<RenovationProject> projects = [];
  String? activeProjectId;
  String? selectedId;
  bool isReady = false;

  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  Timer? _saveTimer;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  RenovationProject get activeProject {
    final selected = projects
        .where((project) => project.id == activeProjectId)
        .firstOrNull;
    return selected ?? projects.first;
  }

  CustomerInfo get customer => activeProject.customer;
  set customer(CustomerInfo value) => activeProject.customer = value;

  List<PlanObject> get objects => activeProject.objects;
  set objects(List<PlanObject> value) => activeProject.objects = value;

  List<WorkLine> get lines => activeProject.lines;
  set lines(List<WorkLine> value) => activeProject.lines = value;

  ProjectDocuments get documents => activeProject.documents;
  List<RenovationPhotoLocation> get photoLocations =>
      activeProject.photoLocations;
  List<SharedWallSegment> get sharedWallOverrides =>
      activeProject.sharedWallOverrides;
  int get canvasWidthMm => activeProject.canvasWidthMm;
  int get canvasHeightMm => activeProject.canvasHeightMm;

  Future<void> load() async {
    final raw = await _dataRepository.read();
    if (raw == null) {
      addSample(notify: false);
    } else {
      try {
        _restore(raw);
      } catch (_) {
        _resetData();
        addSample(notify: false);
      }
    }
    await saveNow();
    isReady = true;
    notifyListeners();
  }

  void _resetData() {
    products = defaultHandrailProducts();
    jointProducts = defaultJointProducts();
    indoorDefaultProductId = 'demo-indoor-35';
    outdoorDefaultProductId = 'demo-outdoor-34';
    _replaceWithFreshProject();
    selectedId = null;
  }

  void _replaceWithFreshProject() {
    final project = RenovationProject(
      id: newId('project'),
      customer: CustomerInfo(),
      objects: [],
      lines: [],
      updatedAt: DateTime.now(),
    );
    projects = [project];
    activeProjectId = project.id;
  }

  RenovationProject createProject() {
    final project = RenovationProject(
      id: newId('project'),
      customer: CustomerInfo(
        name: '',
        kana: '',
        address: '',
        phone: '',
        insuredNumber: '',
        surveyDate: '',
        birthDate: '',
        familyAddressee: '',
        projectName: '新規案件',
        constructionPlace: '',
      ),
      objects: [],
      lines: [],
      updatedAt: DateTime.now(),
    );
    projects.add(project);
    activeProjectId = project.id;
    selectedId = null;
    _undoStack.clear();
    _redoStack.clear();
    changed();
    return project;
  }

  void selectProject(String id) {
    if (!projects.any((project) => project.id == id)) return;
    activeProjectId = id;
    selectedId = null;
    _undoStack.clear();
    _redoStack.clear();
    changed(projectChanged: false);
  }

  bool movePhotoLocation(
    RenovationPhotoLocation location, {
    required int xMm,
    required int yMm,
  }) {
    if (!photoLocations.any((item) => item.id == location.id)) return false;
    final nextX = snapMm(xMm).clamp(0, canvasWidthMm);
    final nextY = snapMm(yMm).clamp(0, canvasHeightMm);
    if (location.xMm == nextX && location.yMm == nextY) return false;
    location
      ..xMm = nextX
      ..yMm = nextY
      ..positionCustomized = true;
    changed();
    return true;
  }

  bool setProjectPhoto({
    required String projectId,
    required String locationId,
    required ProjectPhotoSlot slot,
    required CapturedProjectPhoto photo,
  }) {
    final project = projects.where((item) => item.id == projectId).firstOrNull;
    final location = project?.photoLocations
        .where((item) => item.id == locationId)
        .firstOrNull;
    if (project == null || location == null) return false;

    location.setPhoto(slot, photo);
    project.updatedAt = DateTime.now();
    _undoStack.clear();
    _redoStack.clear();
    changed(projectChanged: false);
    return true;
  }

  bool clearProjectPhoto({
    required String projectId,
    required String locationId,
    required ProjectPhotoSlot slot,
  }) {
    final project = projects.where((item) => item.id == projectId).firstOrNull;
    final location = project?.photoLocations
        .where((item) => item.id == locationId)
        .firstOrNull;
    if (project == null ||
        location == null ||
        location.photoFor(slot) == null) {
      return false;
    }

    location.clearPhoto(slot);
    project.updatedAt = DateTime.now();
    _undoStack.clear();
    _redoStack.clear();
    changed(projectChanged: false);
    return true;
  }

  bool setProjectPhotoMemo({
    required String projectId,
    required String locationId,
    required ProjectPhotoSlot slot,
    required String value,
  }) {
    final project = projects.where((item) => item.id == projectId).firstOrNull;
    final location = project?.photoLocations
        .where((item) => item.id == locationId)
        .firstOrNull;
    if (project == null ||
        location == null ||
        location.memoFor(slot) == value) {
      return false;
    }

    location.setMemo(slot, value);
    project.updatedAt = DateTime.now();
    changed(projectChanged: false);
    return true;
  }

  Map<String, dynamic> toJson() {
    _prepareDerivedProjectData();
    return {
      'schemaVersion': 1,
      'productMaster': {
        'products': products.map((item) => item.toJson()).toList(),
        'jointProducts': jointProducts.map((item) => item.toJson()).toList(),
        'defaults': {
          'indoorProductId': indoorDefaultProductId,
          'outdoorProductId': outdoorDefaultProductId,
        },
      },
      'projects': projects.map(_projectToJson).toList(),
      'activeProjectId': activeProjectId,
    };
  }

  Map<String, dynamic> _projectToJson(RenovationProject project) {
    final json = project.toJson();
    final estimateRows =
        handrailEstimateGroups(
          projectLines: project.lines,
          projectObjects: project.objects,
        ).map((group) {
          final line = group.primary;
          final product = productById(line.productId);
          final cost = costForGroup(group, projectObjects: project.objects);
          return {
            'handrailId': group.id,
            'componentHandrailIds': group.lines
                .map((component) => component.id)
                .toList(),
            'place': line.place,
            'productId': line.productId,
            'productName': product?.name,
            'environment': line.environment.name,
            'installationType': line.installationType.name,
            'lengthMm': group.lengthMm,
            'jointCount': cost.jointCount,
            'endBracketCount': cost.endBracketCount,
            'intermediateBracketCount': cost.intermediateBracketCount,
            'connectionJointCount': cost.connectionJointCount,
            'postCount': cost.postCount,
            'railCost': cost.railCost,
            'jointCost': cost.jointCost,
            'endBracketCost': cost.endBracketCost,
            'intermediateBracketCost': cost.intermediateBracketCost,
            'connectionJointCost': cost.connectionJointCost,
            'postCost': cost.postCost,
            'reinforcementPlateCount': cost.reinforcementPlateCount,
            'reinforcementPlateCost': cost.reinforcementPlateCost,
            'materialCostTotal': cost.total,
          };
        }).toList();
    json['estimate'] = {
      'handrails': estimateRows,
      'materialCostTotal': estimateRows.fold<int>(
        0,
        (total, row) => total + (row['materialCostTotal'] as int),
      ),
    };
    return json;
  }

  void _restore(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final schemaVersion = (json['schemaVersion'] as num?)?.toInt();
    if (schemaVersion != 1) {
      throw const FormatException('Unsupported data schema version');
    }
    final productMaster = json['productMaster'] as Map<String, dynamic>;
    final defaults = productMaster['defaults'] as Map<String, dynamic>;
    products = (productMaster['products'] as List<dynamic>)
        .map((item) => HandrailProduct.fromJson(item as Map<String, dynamic>))
        .toList();
    jointProducts = (productMaster['jointProducts'] as List<dynamic>)
        .map((item) => JointProduct.fromJson(item as Map<String, dynamic>))
        .toList();
    indoorDefaultProductId = defaults['indoorProductId'] as String?;
    outdoorDefaultProductId = defaults['outdoorProductId'] as String?;
    _ensureDefaultProductsValid();

    projects = (json['projects'] as List<dynamic>)
        .map((item) => RenovationProject.fromJson(item as Map<String, dynamic>))
        .toList();
    if (projects.isEmpty) {
      throw const FormatException('At least one project is required');
    }
    final storedActiveProjectId = json['activeProjectId'] as String;
    if (!projects.any((project) => project.id == storedActiveProjectId)) {
      throw const FormatException('Active project does not exist');
    }
    activeProjectId = storedActiveProjectId;

    for (final project in projects) {
      for (final line in project.lines) {
        final product = productById(line.productId);
        if (product == null || !product.supports(line.environment)) {
          line.productId = defaultProductIdFor(line.environment);
        }
      }
    }
    selectedId = null;
  }

  String _snapshot() => jsonEncode(toJson());

  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  Future<void> importJson(String jsonText) async {
    final previous = _snapshot();
    try {
      _restore(jsonText);
    } catch (_) {
      _restore(previous);
      rethrow;
    }
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
    await saveNow();
  }

  void checkpoint() {
    final current = _snapshot();
    if (_undoStack.lastOrNull != current) {
      _undoStack.add(current);
      if (_undoStack.length > 40) _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void undo() {
    if (!canUndo) return;
    _redoStack.add(_snapshot());
    _restore(_undoStack.removeLast());
    changed();
  }

  void redo() {
    if (!canRedo) return;
    _undoStack.add(_snapshot());
    _restore(_redoStack.removeLast());
    changed();
  }

  void changed({bool projectChanged = true}) {
    _prepareDerivedProjectData();
    if (projectChanged && projects.isNotEmpty) {
      activeProject.updatedAt = DateTime.now();
    }
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), saveNow);
  }

  Future<void> saveNow() async {
    await _dataRepository.write(_snapshot());
  }

  String newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  int snapMm(num value) => (value / gridMm).round() * gridMm;

  int get minimumCanvasWidthMm {
    var required = gridMm;
    for (final item in objects) {
      final right = item.isWallAttached && !item.isHorizontalWall
          ? item.xMm
          : item.xMm + item.widthMm;
      required = math.max(required, right);
    }
    for (final line in lines) {
      required = math.max(required, math.max(line.x1Mm, line.x2Mm));
    }
    return snapMm(required);
  }

  int get minimumCanvasHeightMm {
    var required = gridMm;
    for (final item in objects) {
      final bottom = item.isWallAttached && item.isHorizontalWall
          ? item.yMm
          : item.yMm + item.heightMm;
      required = math.max(required, bottom);
    }
    for (final line in lines) {
      required = math.max(required, math.max(line.y1Mm, line.y2Mm));
    }
    return snapMm(required);
  }

  bool setCanvasSize(int widthMm, int heightMm) {
    final width = math.max(gridMm, snapMm(widthMm));
    final height = math.max(gridMm, snapMm(heightMm));
    if (width < minimumCanvasWidthMm || height < minimumCanvasHeightMm) {
      return false;
    }
    if (width == canvasWidthMm && height == canvasHeightMm) return true;
    checkpoint();
    activeProject.canvasWidthMm = width;
    activeProject.canvasHeightMm = height;
    changed();
    return true;
  }

  int get minimumCanvasWidthFromLeftMm {
    var minimumX = canvasWidthMm;
    for (final item in objects) {
      minimumX = math.min(minimumX, item.xMm);
    }
    for (final line in lines) {
      minimumX = math.min(minimumX, math.min(line.x1Mm, line.x2Mm));
    }
    return math.max(gridMm, snapMm(canvasWidthMm - minimumX));
  }

  int get minimumCanvasHeightFromTopMm {
    var minimumY = canvasHeightMm;
    for (final item in objects) {
      minimumY = math.min(minimumY, item.yMm);
    }
    for (final line in lines) {
      minimumY = math.min(minimumY, math.min(line.y1Mm, line.y2Mm));
    }
    return math.max(gridMm, snapMm(canvasHeightMm - minimumY));
  }

  bool resizeCanvasFromEdge(
    CanvasResizeEdge edge,
    int dimensionMm, {
    bool recordUndo = true,
  }) {
    final dimension = math.max(gridMm, snapMm(dimensionMm));
    final currentDimension = switch (edge) {
      CanvasResizeEdge.left || CanvasResizeEdge.right => canvasWidthMm,
      CanvasResizeEdge.top || CanvasResizeEdge.bottom => canvasHeightMm,
    };
    final minimumDimension = switch (edge) {
      CanvasResizeEdge.left => minimumCanvasWidthFromLeftMm,
      CanvasResizeEdge.right => minimumCanvasWidthMm,
      CanvasResizeEdge.top => minimumCanvasHeightFromTopMm,
      CanvasResizeEdge.bottom => minimumCanvasHeightMm,
    };
    if (dimension < minimumDimension) return false;
    if (dimension == currentDimension) return true;
    if (recordUndo) checkpoint();

    final shift = dimension - currentDimension;
    switch (edge) {
      case CanvasResizeEdge.left:
        for (final item in objects) {
          item.xMm += shift;
        }
        for (final line in lines) {
          line.x1Mm += shift;
          line.x2Mm += shift;
        }
        _shiftSharedWallOverrides(dxMm: shift);
        activeProject.canvasWidthMm = dimension;
      case CanvasResizeEdge.right:
        activeProject.canvasWidthMm = dimension;
      case CanvasResizeEdge.top:
        for (final item in objects) {
          item.yMm += shift;
        }
        for (final line in lines) {
          line.y1Mm += shift;
          line.y2Mm += shift;
        }
        _shiftSharedWallOverrides(dyMm: shift);
        activeProject.canvasHeightMm = dimension;
      case CanvasResizeEdge.bottom:
        activeProject.canvasHeightMm = dimension;
    }
    changed();
    return true;
  }

  void _shiftSharedWallOverrides({int dxMm = 0, int dyMm = 0}) {
    for (var index = 0; index < sharedWallOverrides.length; index++) {
      final segment = sharedWallOverrides[index];
      sharedWallOverrides[index] = SharedWallSegment(
        roomAId: segment.roomAId,
        roomBId: segment.roomBId,
        horizontal: segment.horizontal,
        coordinateMm: segment.coordinateMm + (segment.horizontal ? dyMm : dxMm),
        startMm: segment.startMm + (segment.horizontal ? dxMm : dyMm),
        endMm: segment.endMm + (segment.horizontal ? dxMm : dyMm),
        visible: segment.visible,
      );
    }
  }

  Object? get selected =>
      objects.where((item) => item.id == selectedId).firstOrNull ??
      lines.where((item) => item.id == selectedId).firstOrNull;

  void select(String? id) {
    selectedId = id;
    notifyListeners();
  }

  void deleteSelected() {
    if (selectedId == null) return;
    checkpoint();
    final removedHandrailId = lines
        .where((line) => line.id == selectedId)
        .firstOrNull
        ?.id;
    final removedWallId = objects
        .where(
          (item) => item.id == selectedId && item.kind == PlanObjectKind.layout,
        )
        .firstOrNull
        ?.id;
    objects.removeWhere(
      (item) =>
          item.id == selectedId ||
          (removedWallId != null && item.wallId == removedWallId),
    );
    if (removedWallId != null) {
      sharedWallOverrides.removeWhere(
        (segment) =>
            segment.roomAId == removedWallId ||
            segment.roomBId == removedWallId,
      );
    }
    lines.removeWhere((item) => item.id == selectedId);
    if (removedHandrailId != null) {
      documents.handrailFields.remove(removedHandrailId);
    }
    selectedId = null;
    changed();
  }

  PlanObject? layoutAt(int xMm, int yMm) {
    final matches = objects
        .where(
          (object) =>
              object.kind == PlanObjectKind.layout &&
              layoutContainsPoint(object, xMm, yMm),
        )
        .toList();
    if (matches.isEmpty) return null;
    matches.sort(
      (a, b) => (a.widthMm * a.heightMm).compareTo(b.widthMm * b.heightMm),
    );
    return matches.first;
  }

  String placeNameAt(int xMm, int yMm) =>
      layoutAt(xMm, yMm)?.place.trim() ?? '';

  String handrailPlace(WorkLine line) {
    final configured = line.place.trim();
    if (configured.isNotEmpty) return configured;
    final detected = placeNameAt(
      (line.x1Mm + line.x2Mm) ~/ 2,
      (line.y1Mm + line.y2Mm) ~/ 2,
    );
    return detected.isEmpty ? '場所未設定' : detected;
  }

  void addLayout(int xMm, int yMm, int widthMm, int heightMm) {
    checkpoint();
    final item = PlanObject(
      id: newId('layout'),
      kind: PlanObjectKind.layout,
      place: '間取り',
      xMm: snapMm(xMm),
      yMm: snapMm(yMm),
      widthMm: math.max(gridMm, snapMm(widthMm)),
      heightMm: math.max(gridMm, snapMm(heightMm)),
    );
    objects.add(item);
    selectedId = item.id;
    changed();
  }

  List<PlanObject> containedLayouts(PlanObject outer) {
    if (outer.kind != PlanObjectKind.layout) return const [];
    final outerRight = outer.xMm + outer.widthMm;
    final outerBottom = outer.yMm + outer.heightMm;
    final outerArea = outer.widthMm * outer.heightMm;
    return objects.where((candidate) {
      if (candidate.id == outer.id ||
          candidate.kind != PlanObjectKind.layout ||
          candidate.widthMm * candidate.heightMm >= outerArea) {
        return false;
      }
      return candidate.xMm >= outer.xMm &&
          candidate.yMm >= outer.yMm &&
          candidate.xMm + candidate.widthMm <= outerRight &&
          candidate.yMm + candidate.heightMm <= outerBottom;
    }).toList();
  }

  bool layoutContainsPoint(PlanObject room, int xMm, int yMm) {
    if (room.kind != PlanObjectKind.layout ||
        xMm < room.xMm ||
        xMm > room.xMm + room.widthMm ||
        yMm < room.yMm ||
        yMm > room.yMm + room.heightMm) {
      return false;
    }
    return !containedLayouts(room).any(
      (inner) =>
          xMm >= inner.xMm &&
          xMm <= inner.xMm + inner.widthMm &&
          yMm >= inner.yMm &&
          yMm <= inner.yMm + inner.heightMm,
    );
  }

  List<LayoutWallOcclusion> layoutWallOcclusionsFor(PlanObject room) {
    if (room.kind != PlanObjectKind.layout) return const [];
    final roomIndex = objects.indexWhere((object) => object.id == room.id);
    if (roomIndex < 0) return const [];

    final roomRight = room.xMm + room.widthMm;
    final roomBottom = room.yMm + room.heightMm;
    final occlusions = <LayoutWallOcclusion>[];
    for (final other
        in objects
            .skip(roomIndex + 1)
            .where((object) => object.kind == PlanObjectKind.layout)) {
      final otherRight = other.xMm + other.widthMm;
      final otherBottom = other.yMm + other.heightMm;
      final overlapLeft = math.max(room.xMm, other.xMm);
      final overlapTop = math.max(room.yMm, other.yMm);
      final overlapRight = math.min(roomRight, otherRight);
      final overlapBottom = math.min(roomBottom, otherBottom);
      if (overlapLeft >= overlapRight || overlapTop >= overlapBottom) continue;

      final sameBounds =
          room.xMm == other.xMm &&
          room.yMm == other.yMm &&
          roomRight == otherRight &&
          roomBottom == otherBottom;
      final roomContainsOther =
          room.xMm <= other.xMm &&
          room.yMm <= other.yMm &&
          roomRight >= otherRight &&
          roomBottom >= otherBottom;
      final otherContainsRoom =
          other.xMm <= room.xMm &&
          other.yMm <= room.yMm &&
          otherRight >= roomRight &&
          otherBottom >= roomBottom;
      if (!sameBounds && (roomContainsOther || otherContainsRoom)) continue;

      if (other.yMm <= room.yMm && otherBottom >= room.yMm) {
        occlusions.add((
          edge: WallEdge.top,
          startMm: overlapLeft,
          endMm: overlapRight,
        ));
      }
      if (other.yMm <= roomBottom && otherBottom >= roomBottom) {
        occlusions.add((
          edge: WallEdge.bottom,
          startMm: overlapLeft,
          endMm: overlapRight,
        ));
      }
      if (other.xMm <= room.xMm && otherRight >= room.xMm) {
        occlusions.add((
          edge: WallEdge.left,
          startMm: overlapTop,
          endMm: overlapBottom,
        ));
      }
      if (other.xMm <= roomRight && otherRight >= roomRight) {
        occlusions.add((
          edge: WallEdge.right,
          startMm: overlapTop,
          endMm: overlapBottom,
        ));
      }
    }
    return occlusions;
  }

  List<LayoutWallContact> sharedWallContactsFor(PlanObject room) {
    if (room.kind != PlanObjectKind.layout) return const [];
    final contacts = <LayoutWallContact>[];
    final roomRight = room.xMm + room.widthMm;
    final roomBottom = room.yMm + room.heightMm;
    for (final other in objects.where(
      (object) => object.kind == PlanObjectKind.layout && object.id != room.id,
    )) {
      final otherRight = other.xMm + other.widthMm;
      final otherBottom = other.yMm + other.heightMm;
      if (roomRight == other.xMm) {
        _addSharedWallContact(
          contacts,
          room: room,
          other: other,
          roomEdge: WallEdge.right,
          otherEdge: WallEdge.left,
          horizontal: false,
          coordinateMm: roomRight,
          startMm: math.max(room.yMm, other.yMm),
          endMm: math.min(roomBottom, otherBottom),
        );
      }
      if (room.xMm == otherRight) {
        _addSharedWallContact(
          contacts,
          room: room,
          other: other,
          roomEdge: WallEdge.left,
          otherEdge: WallEdge.right,
          horizontal: false,
          coordinateMm: room.xMm,
          startMm: math.max(room.yMm, other.yMm),
          endMm: math.min(roomBottom, otherBottom),
        );
      }
      if (roomBottom == other.yMm) {
        _addSharedWallContact(
          contacts,
          room: room,
          other: other,
          roomEdge: WallEdge.bottom,
          otherEdge: WallEdge.top,
          horizontal: true,
          coordinateMm: roomBottom,
          startMm: math.max(room.xMm, other.xMm),
          endMm: math.min(roomRight, otherRight),
        );
      }
      if (room.yMm == otherBottom) {
        _addSharedWallContact(
          contacts,
          room: room,
          other: other,
          roomEdge: WallEdge.top,
          otherEdge: WallEdge.bottom,
          horizontal: true,
          coordinateMm: room.yMm,
          startMm: math.max(room.xMm, other.xMm),
          endMm: math.min(roomRight, otherRight),
        );
      }
    }
    return contacts;
  }

  void _addSharedWallContact(
    List<LayoutWallContact> contacts, {
    required PlanObject room,
    required PlanObject other,
    required WallEdge roomEdge,
    required WallEdge otherEdge,
    required bool horizontal,
    required int coordinateMm,
    required int startMm,
    required int endMm,
  }) {
    if (endMm <= startMm) return;
    final candidate = SharedWallSegment(
      roomAId: room.id,
      roomBId: other.id,
      horizontal: horizontal,
      coordinateMm: coordinateMm,
      startMm: startMm,
      endMm: endMm,
      visible: true,
    );
    final override = sharedWallOverrides
        .where((segment) => segment.key == candidate.key)
        .firstOrNull;
    contacts.add(
      LayoutWallContact(
        room: room,
        otherRoom: other,
        roomEdge: roomEdge,
        otherEdge: otherEdge,
        segment: candidate.copyWith(visible: override?.visible ?? true),
      ),
    );
  }

  void setSharedWallVisible(LayoutWallContact contact, bool visible) {
    if (contact.visible == visible) return;
    checkpoint();
    sharedWallOverrides.removeWhere(
      (segment) => segment.key == contact.segment.key,
    );
    if (!visible) {
      sharedWallOverrides.add(contact.segment.copyWith(visible: false));
    }
    changed();
  }

  void _pruneSharedWallOverrides() {
    if (sharedWallOverrides.isEmpty) return;
    final validKeys = <String>{};
    for (final room in objects.where(
      (object) => object.kind == PlanObjectKind.layout,
    )) {
      validKeys.addAll(
        sharedWallContactsFor(room).map((contact) => contact.segment.key),
      );
    }
    sharedWallOverrides.removeWhere(
      (segment) => !validKeys.contains(segment.key),
    );
  }

  void addFixture(FixtureType type, int centerXMm, int centerYMm) {
    checkpoint();
    final width = math.min(type.defaultWidthMm, canvasWidthMm);
    final height = math.min(type.defaultHeightMm, canvasHeightMm);
    final item = PlanObject(
      id: newId(type.name),
      kind: PlanObjectKind.fixture,
      fixture: type.name,
      place: placeNameAt(centerXMm, centerYMm),
      xMm: snapMm(centerXMm - width / 2).clamp(0, canvasWidthMm - width),
      yMm: snapMm(centerYMm - height / 2).clamp(0, canvasHeightMm - height),
      widthMm: width,
      heightMm: height,
    );
    objects.add(item);
    selectedId = item.id;
    changed();
  }

  void addToilet(int centerXMm, int centerYMm) =>
      addFixture(FixtureType.toilet, centerXMm, centerYMm);

  WallSnap? nearestWall(int xMm, int yMm, {int maxDistanceMm = 500}) {
    WallSnap? best;
    for (final wall in objects.where(
      (item) => item.kind == PlanObjectKind.layout,
    )) {
      final left = wall.xMm;
      final right = wall.xMm + wall.widthMm;
      final top = wall.yMm;
      final bottom = wall.yMm + wall.heightMm;
      final candidates = <WallSnap>[
        _wallCandidate(
          wall,
          WallEdge.top,
          xMm.clamp(left, right),
          top,
          xMm,
          yMm,
        ),
        _wallCandidate(
          wall,
          WallEdge.bottom,
          xMm.clamp(left, right),
          bottom,
          xMm,
          yMm,
        ),
        _wallCandidate(
          wall,
          WallEdge.left,
          left,
          yMm.clamp(top, bottom),
          xMm,
          yMm,
        ),
        _wallCandidate(
          wall,
          WallEdge.right,
          right,
          yMm.clamp(top, bottom),
          xMm,
          yMm,
        ),
      ];
      for (final candidate in candidates) {
        if ((best == null || candidate.distance < best.distance) &&
            candidate.distance <= maxDistanceMm) {
          best = candidate;
        }
      }
    }
    return best;
  }

  WallSnap _wallCandidate(
    PlanObject wall,
    WallEdge edge,
    int wallX,
    int wallY,
    int tapX,
    int tapY,
  ) => (
    wall: wall,
    edge: edge,
    xMm: wallX,
    yMm: wallY,
    distance: math.sqrt(math.pow(tapX - wallX, 2) + math.pow(tapY - wallY, 2)),
  );

  bool? _doorOpensOutwardAt(WallSnap snap, int xMm, int yMm) {
    final wall = snap.wall;
    switch (snap.edge) {
      case WallEdge.top:
        if (yMm == wall.yMm) return null;
        return yMm < wall.yMm;
      case WallEdge.bottom:
        final wallY = wall.yMm + wall.heightMm;
        if (yMm == wallY) return null;
        return yMm > wallY;
      case WallEdge.left:
        if (xMm == wall.xMm) return null;
        return xMm < wall.xMm;
      case WallEdge.right:
        final wallX = wall.xMm + wall.widthMm;
        if (xMm == wallX) return null;
        return xMm > wallX;
    }
  }

  OpeningAddResult addDoor(
    int tapXMm,
    int tapYMm, {
    DoorType doorType = DoorType.swing,
  }) {
    final snap = nearestWall(tapXMm, tapYMm);
    if (snap == null) return OpeningAddResult.noWall;
    const opening = 500;
    const depth = 500;
    final horizontal =
        snap.edge == WallEdge.top || snap.edge == WallEdge.bottom;
    late final int x;
    late final int y;
    late final int width;
    late final int height;
    if (horizontal) {
      x = snapMm(
        snap.xMm - opening / 2,
      ).clamp(snap.wall.xMm, snap.wall.xMm + snap.wall.widthMm - opening);
      y = snap.edge == WallEdge.top
          ? snap.wall.yMm
          : snap.wall.yMm + snap.wall.heightMm;
      width = opening;
      height = depth;
    } else {
      x = snap.edge == WallEdge.left
          ? snap.wall.xMm
          : snap.wall.xMm + snap.wall.widthMm;
      y = snapMm(
        snap.yMm - opening / 2,
      ).clamp(snap.wall.yMm, snap.wall.yMm + snap.wall.heightMm - opening);
      width = depth;
      height = opening;
    }
    final item = PlanObject(
      id: newId('door'),
      kind: PlanObjectKind.door,
      place: snap.wall.place.trim(),
      xMm: x,
      yMm: y,
      widthMm: width,
      heightMm: height,
      wallId: snap.wall.id,
      wallEdge: snap.edge,
      doorType: doorType,
    );
    if (_openingOverlaps(item)) {
      return OpeningAddResult.overlaps;
    }
    checkpoint();
    objects.add(item);
    selectedId = item.id;
    changed();
    return OpeningAddResult.added;
  }

  bool _openingOverlaps(PlanObject candidate) {
    if (!candidate.isWallAttached) return false;
    final candidateStart = candidate.isHorizontalWall
        ? candidate.xMm
        : candidate.yMm;
    final candidateEnd =
        candidateStart +
        (candidate.isHorizontalWall ? candidate.widthMm : candidate.heightMm);
    return objects.any((item) {
      if (item.id == candidate.id ||
          !item.isWallAttached ||
          item.wallId != candidate.wallId ||
          item.wallEdge != candidate.wallEdge) {
        return false;
      }
      final itemStart = item.isHorizontalWall ? item.xMm : item.yMm;
      final itemEnd =
          itemStart + (item.isHorizontalWall ? item.widthMm : item.heightMm);
      return candidateStart < itemEnd && candidateEnd > itemStart;
    });
  }

  PlanObject? wallFor(PlanObject item) =>
      objects.where((wall) => wall.id == item.wallId).firstOrNull;

  bool moveOpeningTo(
    PlanObject item,
    int centerXMm,
    int centerYMm, {
    int maxDistanceMm = 750,
  }) {
    if (!item.isWallAttached) return false;
    final snap = nearestWall(
      centerXMm,
      centerYMm,
      maxDistanceMm: maxDistanceMm,
    );
    if (snap == null) return false;

    final length = item.isHorizontalWall ? item.widthMm : item.heightMm;
    final wallLength = snap.edge == WallEdge.top || snap.edge == WallEdge.bottom
        ? snap.wall.widthMm
        : snap.wall.heightMm;
    if (length > wallLength) return false;

    final oldWallId = item.wallId;
    final oldWallEdge = item.wallEdge;
    final oldX = item.xMm;
    final oldY = item.yMm;
    final oldWidth = item.widthMm;
    final oldHeight = item.heightMm;
    final oldOpensOutward = item.opensOutward;
    final depth = item.isHorizontalWall ? item.heightMm : item.widthMm;
    final horizontal =
        snap.edge == WallEdge.top || snap.edge == WallEdge.bottom;

    item.wallId = snap.wall.id;
    item.wallEdge = snap.edge;
    if (item.kind == PlanObjectKind.door && item.doorType == DoorType.swing) {
      item.opensOutward =
          _doorOpensOutwardAt(snap, centerXMm, centerYMm) ?? item.opensOutward;
    } else if (item.kind == PlanObjectKind.door) {
      item.opensOutward = false;
    }
    if (horizontal) {
      item.widthMm = length;
      item.heightMm = item.kind == PlanObjectKind.door ? length : depth;
      item.xMm = snapMm(
        snap.xMm - length / 2,
      ).clamp(snap.wall.xMm, snap.wall.xMm + snap.wall.widthMm - length);
      item.yMm = snap.edge == WallEdge.top
          ? snap.wall.yMm
          : snap.wall.yMm + snap.wall.heightMm;
    } else {
      item.widthMm = item.kind == PlanObjectKind.door ? length : depth;
      item.heightMm = length;
      item.xMm = snap.edge == WallEdge.left
          ? snap.wall.xMm
          : snap.wall.xMm + snap.wall.widthMm;
      item.yMm = snapMm(
        snap.yMm - length / 2,
      ).clamp(snap.wall.yMm, snap.wall.yMm + snap.wall.heightMm - length);
    }

    if (_openingOverlaps(item)) {
      item.wallId = oldWallId;
      item.wallEdge = oldWallEdge;
      item.xMm = oldX;
      item.yMm = oldY;
      item.widthMm = oldWidth;
      item.heightMm = oldHeight;
      item.opensOutward = oldOpensOutward;
      return false;
    }
    return true;
  }

  void flipDoor(PlanObject item) {
    if (item.kind != PlanObjectKind.door) return;
    checkpoint();
    item.flipped = !item.flipped;
    changed();
  }

  void toggleDoorOpeningSide(PlanObject item) {
    if (item.kind != PlanObjectKind.door || item.doorType != DoorType.swing) {
      return;
    }
    checkpoint();
    item.opensOutward = !item.opensOutward;
    changed();
  }

  void setDoorType(PlanObject item, DoorType type) {
    if (item.kind != PlanObjectKind.door || item.doorType == type) return;
    checkpoint();
    item.doorType = type;
    if (type == DoorType.sliding) item.opensOutward = false;
    changed();
  }

  void rotateFixture(PlanObject item) {
    if (item.kind != PlanObjectKind.fixture) return;
    checkpoint();
    applyFixtureRotation(item, item.rotationQuarterTurns + 1);
    changed();
  }

  void applyFixtureRotation(PlanObject item, int quarterTurns) {
    if (item.kind != PlanObjectKind.fixture) return;
    final target = quarterTurns % 4;
    final current = item.rotationQuarterTurns % 4;
    if (target == current) return;
    final swapsDimensions = (target - current).abs().isOdd;
    item.rotationQuarterTurns = target;
    if (!swapsDimensions) return;

    final centerX = item.xMm + item.widthMm / 2;
    final centerY = item.yMm + item.heightMm / 2;
    final newWidth = item.heightMm;
    final newHeight = item.widthMm;
    item.widthMm = newWidth;
    item.heightMm = newHeight;
    item.xMm = snapMm(
      centerX - newWidth / 2,
    ).clamp(0, canvasWidthMm - newWidth);
    item.yMm = snapMm(
      centerY - newHeight / 2,
    ).clamp(0, canvasHeightMm - newHeight);
  }

  void moveObjectBy(PlanObject item, int dxMm, int dyMm) {
    if (item.isWallAttached) {
      final wall = wallFor(item);
      if (wall == null) return;
      final oldX = item.xMm;
      final oldY = item.yMm;
      if (item.isHorizontalWall) {
        item.xMm = snapMm(
          item.xMm + dxMm,
        ).clamp(wall.xMm, wall.xMm + wall.widthMm - item.widthMm);
        item.yMm = item.wallEdge == WallEdge.top
            ? wall.yMm
            : wall.yMm + wall.heightMm;
      } else {
        item.yMm = snapMm(
          item.yMm + dyMm,
        ).clamp(wall.yMm, wall.yMm + wall.heightMm - item.heightMm);
        item.xMm = item.wallEdge == WallEdge.left
            ? wall.xMm
            : wall.xMm + wall.widthMm;
      }
      if (_openingOverlaps(item)) {
        item.xMm = oldX;
        item.yMm = oldY;
      }
      return;
    }
    final oldX = item.xMm;
    final oldY = item.yMm;
    item.xMm = snapMm(item.xMm + dxMm).clamp(0, canvasWidthMm - item.widthMm);
    item.yMm = snapMm(item.yMm + dyMm).clamp(0, canvasHeightMm - item.heightMm);
    if (item.kind == PlanObjectKind.layout) {
      final movedX = item.xMm - oldX;
      final movedY = item.yMm - oldY;
      for (final opening in objects.where(
        (object) => object.wallId == item.id,
      )) {
        opening.xMm += movedX;
        opening.yMm += movedY;
      }
      syncAttachedOpenings(item);
      _pruneSharedWallOverrides();
      if (movedX != 0 || movedY != 0) _bringLayoutToFront(item);
    }
  }

  void _bringLayoutToFront(PlanObject item) {
    final index = objects.indexWhere((object) => object.id == item.id);
    if (index < 0 ||
        !objects
            .skip(index + 1)
            .any((object) => object.kind == PlanObjectKind.layout)) {
      return;
    }
    objects.removeAt(index);
    objects.add(item);
  }

  void resizeObjectBy(PlanObject item, int dxMm, int dyMm) {
    if (item.isWallAttached) {
      final wall = wallFor(item);
      if (wall == null) return;
      final oldWidth = item.widthMm;
      final oldHeight = item.heightMm;
      if (item.isHorizontalWall) {
        item.widthMm = snapMm(
          item.widthMm + dxMm,
        ).clamp(gridMm, wall.xMm + wall.widthMm - item.xMm);
        if (item.kind == PlanObjectKind.door) item.heightMm = item.widthMm;
      } else {
        item.heightMm = snapMm(
          item.heightMm + dyMm,
        ).clamp(gridMm, wall.yMm + wall.heightMm - item.yMm);
        if (item.kind == PlanObjectKind.door) item.widthMm = item.heightMm;
      }
      if (_openingOverlaps(item)) {
        item.widthMm = oldWidth;
        item.heightMm = oldHeight;
      }
      return;
    }
    final oldWidth = item.widthMm;
    final oldHeight = item.heightMm;
    final attachedSnapshot = item.kind == PlanObjectKind.layout
        ? objects
              .where((object) => object.wallId == item.id)
              .map(
                (object) => (
                  object: object,
                  xMm: object.xMm,
                  yMm: object.yMm,
                  widthMm: object.widthMm,
                  heightMm: object.heightMm,
                ),
              )
              .toList()
        : const [];
    item.widthMm = snapMm(
      item.widthMm + dxMm,
    ).clamp(gridMm, canvasWidthMm - item.xMm);
    item.heightMm = snapMm(
      item.heightMm + dyMm,
    ).clamp(gridMm, canvasHeightMm - item.yMm);
    if (item.kind == PlanObjectKind.layout) {
      syncAttachedOpenings(item);
      if (objects
          .where((object) => object.wallId == item.id)
          .any(_openingOverlaps)) {
        item.widthMm = oldWidth;
        item.heightMm = oldHeight;
        for (final snapshot in attachedSnapshot) {
          snapshot.object.xMm = snapshot.xMm;
          snapshot.object.yMm = snapshot.yMm;
          snapshot.object.widthMm = snapshot.widthMm;
          snapshot.object.heightMm = snapshot.heightMm;
        }
      }
      _pruneSharedWallOverrides();
    }
  }

  void syncAttachedOpenings(PlanObject wall) {
    if (wall.kind != PlanObjectKind.layout) return;
    for (final opening in objects.where((object) => object.wallId == wall.id)) {
      final edge = opening.wallEdge;
      if (edge == null) continue;
      if (edge == WallEdge.top || edge == WallEdge.bottom) {
        opening.widthMm = opening.widthMm.clamp(gridMm, wall.widthMm);
        if (opening.kind == PlanObjectKind.door) {
          opening.heightMm = opening.widthMm;
        }
        opening.xMm = opening.xMm.clamp(
          wall.xMm,
          wall.xMm + wall.widthMm - opening.widthMm,
        );
        opening.yMm = edge == WallEdge.top
            ? wall.yMm
            : wall.yMm + wall.heightMm;
      } else {
        opening.heightMm = opening.heightMm.clamp(gridMm, wall.heightMm);
        if (opening.kind == PlanObjectKind.door) {
          opening.widthMm = opening.heightMm;
        }
        opening.yMm = opening.yMm.clamp(
          wall.yMm,
          wall.yMm + wall.heightMm - opening.heightMm,
        );
        opening.xMm = edge == WallEdge.left
            ? wall.xMm
            : wall.xMm + wall.widthMm;
      }
    }
  }

  bool handrailCompletelyOverlapsLayoutEdge(
    int x1Mm,
    int y1Mm,
    int x2Mm,
    int y2Mm,
  ) {
    final startX = snapMm(x1Mm);
    final startY = snapMm(y1Mm);
    final endX = snapMm(x2Mm);
    final endY = snapMm(y2Mm);
    if (startY == endY) {
      final left = math.min(startX, endX);
      final right = math.max(startX, endX);
      return objects.where((item) => item.kind == PlanObjectKind.layout).any((
        room,
      ) {
        final roomRight = room.xMm + room.widthMm;
        final onHorizontalEdge =
            startY == room.yMm || startY == room.yMm + room.heightMm;
        return onHorizontalEdge && left >= room.xMm && right <= roomRight;
      });
    }

    if (startX != endX) return false;
    final top = math.min(startY, endY);
    final bottom = math.max(startY, endY);
    return objects.where((item) => item.kind == PlanObjectKind.layout).any((
      room,
    ) {
      final roomBottom = room.yMm + room.heightMm;
      final onVerticalEdge =
          startX == room.xMm || startX == room.xMm + room.widthMm;
      return onVerticalEdge && top >= room.yMm && bottom <= roomBottom;
    });
  }

  void addHandrail(int x1Mm, int y1Mm, int x2Mm, int y2Mm) {
    var endX = snapMm(x2Mm);
    var endY = snapMm(y2Mm);
    final startX = snapMm(x1Mm);
    final startY = snapMm(y1Mm);
    if (endX == startX && endY == startY) {
      endX = startX + gridMm <= canvasWidthMm
          ? startX + gridMm
          : startX - gridMm;
    }
    final line = WorkLine(
      id: newId('rail'),
      place: placeNameAt((startX + endX) ~/ 2, (startY + endY) ~/ 2),
      x1Mm: startX,
      y1Mm: startY,
      x2Mm: endX.clamp(0, canvasWidthMm),
      y2Mm: endY.clamp(0, canvasHeightMm),
      productId: defaultProductIdFor(HandrailEnvironment.indoor),
      constructionNumber: '${handrailEstimateGroups().length + 1}',
    );
    checkpoint();
    lines.add(line);
    selectedId = line.id;
    changed();
  }

  void moveLineBy(WorkLine line, int dxMm, int dyMm) {
    final minX = math.min(line.x1Mm, line.x2Mm);
    final maxX = math.max(line.x1Mm, line.x2Mm);
    final minY = math.min(line.y1Mm, line.y2Mm);
    final maxY = math.max(line.y1Mm, line.y2Mm);
    final safeDx = snapMm(dxMm).clamp(-minX, canvasWidthMm - maxX);
    final safeDy = snapMm(dyMm).clamp(-minY, canvasHeightMm - maxY);
    line.x1Mm += safeDx;
    line.x2Mm += safeDx;
    line.y1Mm += safeDy;
    line.y2Mm += safeDy;
  }

  void moveLineEnd(WorkLine line, bool start, int xMm, int yMm) {
    final targetX = snapMm(xMm).clamp(0, canvasWidthMm);
    final targetY = snapMm(yMm).clamp(0, canvasHeightMm);
    _moveLineEndUnconstrained(line, start, targetX, targetY);
  }

  void _moveLineEndUnconstrained(WorkLine line, bool start, int xMm, int yMm) {
    final fixedX = start ? line.x2Mm : line.x1Mm;
    final fixedY = start ? line.y2Mm : line.y1Mm;
    final targetX = snapMm(xMm).clamp(0, canvasWidthMm);
    final targetY = snapMm(yMm).clamp(0, canvasHeightMm);
    if (targetX == fixedX && targetY == fixedY) return;
    if (start) {
      line.x1Mm = targetX;
      line.y1Mm = targetY;
    } else {
      line.x2Mm = targetX;
      line.y2Mm = targetY;
    }
  }

  void setLineLength(WorkLine line, int lengthMm) {
    final targetLength = math.max(gridMm, snapMm(lengthMm));
    _setLineLengthUnconstrained(line, targetLength);
  }

  void _setLineLengthUnconstrained(WorkLine line, int lengthMm) {
    final snapped = math.max(gridMm, snapMm(lengthMm));
    if (line.isHorizontal) {
      final direction = line.x2Mm >= line.x1Mm ? 1 : -1;
      line.x2Mm = (line.x1Mm + direction * snapped).clamp(0, canvasWidthMm);
    } else if (line.isVertical) {
      final direction = line.y2Mm >= line.y1Mm ? 1 : -1;
      line.y2Mm = (line.y1Mm + direction * snapped).clamp(0, canvasHeightMm);
    } else {
      final dx = line.x2Mm - line.x1Mm;
      final dy = line.y2Mm - line.y1Mm;
      final currentLength = math.sqrt(dx * dx + dy * dy);
      final targetX = snapMm(
        line.x1Mm + dx / currentLength * snapped,
      ).clamp(0, canvasWidthMm);
      final targetY = snapMm(
        line.y1Mm + dy / currentLength * snapped,
      ).clamp(0, canvasHeightMm);
      if (targetX != line.x1Mm || targetY != line.y1Mm) {
        line.x2Mm = targetX;
        line.y2Mm = targetY;
      }
    }
  }

  void selectNearestLine(int xMm, int yMm) {
    WorkLine? nearest;
    var nearestDistance = gridMm.toDouble();
    for (final line in lines) {
      final distance = _pointToSegmentDistance(xMm, yMm, line);
      if (distance < nearestDistance) {
        nearest = line;
        nearestDistance = distance;
      }
    }
    select(nearest?.id);
  }

  double _pointToSegmentDistance(int x, int y, WorkLine line) {
    final points = handrailPath(line).points;
    var nearest = double.infinity;
    for (var index = 0; index < points.length - 1; index++) {
      nearest = math.min(
        nearest,
        _pointToPathSegmentDistance(x, y, points[index], points[index + 1]),
      );
    }
    return nearest;
  }

  double _pointToPathSegmentDistance(
    int x,
    int y,
    HandrailPoint start,
    HandrailPoint end,
  ) {
    final dx = end.xMm - start.xMm;
    final dy = end.yMm - start.yMm;
    if (dx == 0 && dy == 0) return double.infinity;
    final t =
        (((x - start.xMm) * dx + (y - start.yMm) * dy) / (dx * dx + dy * dy))
            .clamp(0.0, 1.0);
    final px = start.xMm + t * dx;
    final py = start.yMm + t * dy;
    return math.sqrt(math.pow(x - px, 2) + math.pow(y - py, 2));
  }

  HandrailProduct? productById(String? id) =>
      products.where((product) => product.id == id).firstOrNull;

  JointProduct? jointProductById(String? id) =>
      jointProducts.where((product) => product.id == id).firstOrNull;

  List<JointProduct> jointProductsForType(JointProductType type) =>
      jointProducts.where((product) => product.type == type).toList()
        ..sort((a, b) => a.id.compareTo(b.id));

  List<JointProduct> jointProductsForKind(HandrailConnectionKind kind) =>
      jointProducts.where((product) => kind.accepts(product.type)).toList()
        ..sort((a, b) {
          final typeComparison = a.type.sortOrder.compareTo(b.type.sortOrder);
          return typeComparison != 0 ? typeComparison : a.id.compareTo(b.id);
        });

  List<JointProduct> get sortedJointProducts =>
      jointProducts.toList()..sort((a, b) {
        final typeComparison = a.type.sortOrder.compareTo(b.type.sortOrder);
        return typeComparison != 0 ? typeComparison : a.id.compareTo(b.id);
      });

  List<HandrailProduct> productsFor(HandrailEnvironment environment) =>
      products.where((product) => product.supports(environment)).toList();

  String? defaultProductIdFor(HandrailEnvironment environment) {
    final configured = environment == HandrailEnvironment.indoor
        ? indoorDefaultProductId
        : outdoorDefaultProductId;
    final compatible = productsFor(environment);
    if (compatible.any((product) => product.id == configured)) {
      return configured;
    }
    return compatible.firstOrNull?.id;
  }

  void _ensureDefaultProductsValid() {
    if (jointProducts.isEmpty) jointProducts = defaultJointProducts();
    if (products.isEmpty) products = defaultHandrailProducts();
    for (final product in products) {
      final outdoorOnly =
          product.supports(HandrailEnvironment.outdoor) &&
          !product.supports(HandrailEnvironment.indoor);
      product.defaultEndBracketId = _validJointDefault(
        product.defaultEndBracketId,
        JointProductType.endBracket,
        preferredId: outdoorOnly ? 'EB-34-OD' : 'EB-35-WH',
      );
      product.defaultIntermediateBracketId = _validJointDefault(
        product.defaultIntermediateBracketId,
        JointProductType.intermediateBracket,
        preferredId: outdoorOnly ? 'MB-34-OD' : 'MB-35-WH',
      );
      product.defaultLJointId = _validJointDefault(
        product.defaultLJointId,
        JointProductType.lShapeConnection,
        preferredId: 'CJ-L-35',
      );
    }
    indoorDefaultProductId = defaultProductIdFor(HandrailEnvironment.indoor);
    outdoorDefaultProductId = defaultProductIdFor(HandrailEnvironment.outdoor);
  }

  String? _validJointDefault(
    String? id,
    JointProductType type, {
    required String preferredId,
  }) {
    final configured = jointProductById(id);
    if (configured?.type == type) return configured?.id;
    final preferred = jointProductById(preferredId);
    if (preferred?.type == type) return preferred?.id;
    return jointProductsForType(type).firstOrNull?.id;
  }

  void setDefaultProduct(HandrailEnvironment environment, String? productId) {
    final product = productById(productId);
    if (product == null || !product.supports(environment)) return;
    checkpoint();
    if (environment == HandrailEnvironment.indoor) {
      indoorDefaultProductId = product.id;
    } else {
      outdoorDefaultProductId = product.id;
    }
    changed(projectChanged: false);
  }

  bool addProduct(HandrailProduct product) {
    if (products.any((item) => item.id == product.id)) return false;
    checkpoint();
    products.add(product);
    _ensureDefaultProductsValid();
    changed(projectChanged: false);
    return true;
  }

  bool addJointProduct(JointProduct product) {
    if (jointProducts.any((item) => item.id == product.id)) return false;
    checkpoint();
    jointProducts.add(product);
    _ensureDefaultProductsValid();
    changed(projectChanged: false);
    return true;
  }

  bool isJointProductInUse(JointProduct jointProduct) =>
      products.any(
        (product) =>
            product.defaultEndBracketId == jointProduct.id ||
            product.defaultIntermediateBracketId == jointProduct.id ||
            product.defaultLJointId == jointProduct.id,
      ) ||
      projects.any(
        (project) => project.lines.any(
          (line) =>
              line.connectionProductOverrides.values.contains(jointProduct.id),
        ),
      );

  bool deleteJointProduct(JointProduct jointProduct) {
    if (isJointProductInUse(jointProduct)) return false;
    checkpoint();
    jointProducts.remove(jointProduct);
    _ensureDefaultProductsValid();
    changed(projectChanged: false);
    return true;
  }

  void updateJointProduct(JointProduct current, JointProduct replacement) {
    final index = jointProducts.indexWhere((item) => item.id == current.id);
    if (index < 0) return;
    checkpoint();
    replacement.id = current.id;
    jointProducts[index] = replacement;
    _ensureDefaultProductsValid();
    changed(projectChanged: false);
  }

  void setProductDefaultJoint(
    HandrailProduct product,
    JointProductType type,
    String? jointProductId,
  ) {
    final jointProduct = jointProductById(jointProductId);
    if (jointProduct == null || jointProduct.type != type) return;
    checkpoint();
    switch (type) {
      case JointProductType.endBracket:
        product.defaultEndBracketId = jointProduct.id;
      case JointProductType.intermediateBracket:
        product.defaultIntermediateBracketId = jointProduct.id;
      case JointProductType.lShapeConnection:
        product.defaultLJointId = jointProduct.id;
      case JointProductType.twoDimensionalConnection:
      case JointProductType.threeDimensionalConnection:
        return;
    }
    changed(projectChanged: false);
  }

  bool isProductInUse(HandrailProduct product) => projects.any(
    (project) => project.lines.any((line) => line.productId == product.id),
  );

  bool deleteProduct(HandrailProduct product) {
    if (isProductInUse(product)) return false;
    checkpoint();
    products.remove(product);
    _ensureDefaultProductsValid();
    changed(projectChanged: false);
    return true;
  }

  void updateProduct(HandrailProduct current, HandrailProduct replacement) {
    final index = products.indexWhere((product) => product.id == current.id);
    if (index < 0) return;
    checkpoint();
    replacement.id = current.id;
    products[index] = replacement;
    _ensureDefaultProductsValid();
    for (final project in projects) {
      for (final line in project.lines.where(
        (line) => line.productId == current.id,
      )) {
        if (!replacement.supports(line.environment)) {
          line.productId = defaultProductIdFor(line.environment);
        }
      }
    }
    changed(projectChanged: false);
  }

  void applyHandrailSettings(
    WorkLine line, {
    required HandrailEnvironment environment,
    required HandrailInstallationType installationType,
    String? productId,
  }) {
    line.environment = environment;
    line.installationType = installationType;
    final product = productById(productId);
    line.productId = product != null && product.supports(environment)
        ? product.id
        : defaultProductIdFor(environment);
  }

  bool applyHandrailDocumentSettings(
    HandrailEstimateGroup group, {
    required String place,
    required String productId,
    required String workContent,
    required String specification,
    required String remarks,
  }) {
    final product = productById(productId);
    if (product == null ||
        group.lines.any((line) => !product.supports(line.environment))) {
      return false;
    }
    checkpoint();
    final normalizedPlace = place.trim();
    for (final line in group.lines) {
      line.place = normalizedPlace;
      line.productId = product.id;
    }
    final fields = documents.fieldsFor(group.id);
    fields.location = '';
    fields.workContent = workContent.trim();
    fields.specification = specification.trim();
    fields.remarks = remarks.trim();
    changed();
    return true;
  }

  HandrailPath handrailPath(WorkLine line) => HandrailPath([
    HandrailPoint(line.x1Mm, line.y1Mm),
    HandrailPoint(line.x2Mm, line.y2Mm),
  ]);

  List<HandrailEstimateGroup> handrailEstimateGroups({
    List<WorkLine>? projectLines,
    List<PlanObject>? projectObjects,
  }) {
    final source = projectLines ?? lines;
    final remaining = source.map((line) => line.id).toSet();
    final groups = <HandrailEstimateGroup>[];
    for (final seed in source) {
      if (!remaining.remove(seed.id)) continue;
      final component = <WorkLine>[seed];
      final queue = <WorkLine>[seed];
      while (queue.isNotEmpty) {
        final current = queue.removeLast();
        for (final candidate in source) {
          if (!remaining.contains(candidate.id) ||
              !_handrailEndpointsConnect(current, candidate)) {
            continue;
          }
          remaining.remove(candidate.id);
          component.add(candidate);
          queue.add(candidate);
        }
      }
      component.sort((a, b) => source.indexOf(a).compareTo(source.indexOf(b)));
      groups.add(HandrailEstimateGroup(component));
    }
    return groups;
  }

  bool _handrailEndpointsConnect(WorkLine first, WorkLine second) {
    final firstPath = handrailPath(first).points;
    final secondPath = handrailPath(second).points;
    if (firstPath.length < 2 || secondPath.length < 2) return false;
    final firstEnds = [firstPath.first, firstPath.last];
    final secondEnds = [secondPath.first, secondPath.last];
    return firstEnds.any(
      (a) => secondEnds.any((b) => a.xMm == b.xMm && a.yMm == b.yMm),
    );
  }

  Map<String, String> _constructionNumbersForGroups(
    List<HandrailEstimateGroup> groups,
  ) {
    final used = <String>{};
    final numbers = <String, String>{};
    var nextAutomaticNumber = 1;
    for (final group in groups) {
      var number = group.primary.constructionNumber.trim();
      if (number.isEmpty || used.contains(number)) {
        while (used.contains('$nextAutomaticNumber')) {
          nextAutomaticNumber++;
        }
        number = '$nextAutomaticNumber';
      }
      used.add(number);
      numbers[group.id] = number;
      while (used.contains('$nextAutomaticNumber')) {
        nextAutomaticNumber++;
      }
    }
    return numbers;
  }

  void _prepareDerivedProjectData() {
    for (final project in projects) {
      final groups = handrailEstimateGroups(
        projectLines: project.lines,
        projectObjects: project.objects,
      );
      final numbers = _constructionNumbersForGroups(groups);
      for (final group in groups) {
        final number = numbers[group.id]!;
        for (final line in group.lines) {
          line.constructionNumber = number;
        }
      }
      _syncPhotoLocations(project, groups, numbers);
    }
  }

  void _syncPhotoLocations(
    RenovationProject project,
    List<HandrailEstimateGroup> groups,
    Map<String, String> numbers,
  ) {
    final available = [...project.photoLocations];
    final synchronized = <RenovationPhotoLocation>[];
    for (final group in groups) {
      final handrailIds = group.lines.map((line) => line.id).toSet();
      RenovationPhotoLocation? location = available
          .where(
            (item) =>
                item.handrailIds.length == handrailIds.length &&
                item.handrailIds.toSet().containsAll(handrailIds),
          )
          .firstOrNull;
      location ??= available
          .where((item) => item.handrailIds.any(handrailIds.contains))
          .firstOrNull;
      if (location != null) available.remove(location);

      final anchor = _photoAnchorForGroup(group);
      location ??= RenovationPhotoLocation(
        id: 'photo-${group.primary.id}',
        locationName: '',
        xMm: anchor.xMm,
        yMm: anchor.yMm,
      );
      location
        ..handrailIds = handrailIds.toList()
        ..handrailNumber = numbers[group.id]!;
      if (!location.positionCustomized) {
        location
          ..xMm = anchor.xMm.clamp(0, project.canvasWidthMm)
          ..yMm = anchor.yMm.clamp(0, project.canvasHeightMm);
      }
      final detectedPlace = _projectPlaceNameAt(
        project,
        location.xMm,
        location.yMm,
      );
      location.locationName = detectedPlace.isNotEmpty
          ? detectedPlace
          : group.primary.place.trim().isEmpty
          ? '場所未設定'
          : group.primary.place.trim();
      synchronized.add(location);
    }
    synchronized.sort((a, b) {
      final aNumber = int.tryParse(a.handrailNumber.trim());
      final bNumber = int.tryParse(b.handrailNumber.trim());
      if (aNumber != null && bNumber != null) {
        return aNumber.compareTo(bNumber);
      }
      if (aNumber != null) return -1;
      if (bNumber != null) return 1;
      return a.handrailNumber.compareTo(b.handrailNumber);
    });
    project.photoLocations
      ..clear()
      ..addAll(synchronized);
  }

  HandrailPoint _photoAnchorForGroup(HandrailEstimateGroup group) {
    var weightedX = 0.0;
    var weightedY = 0.0;
    var totalLength = 0;
    for (final line in group.lines) {
      final length = math.max(1, line.lengthMm);
      weightedX += (line.x1Mm + line.x2Mm) / 2 * length;
      weightedY += (line.y1Mm + line.y2Mm) / 2 * length;
      totalLength += length;
    }
    return HandrailPoint(
      snapMm(weightedX / totalLength),
      snapMm(weightedY / totalLength),
    );
  }

  String _projectPlaceNameAt(RenovationProject project, int xMm, int yMm) {
    final matches =
        project.objects
            .where(
              (object) =>
                  object.kind == PlanObjectKind.layout &&
                  xMm >= object.xMm &&
                  xMm <= object.xMm + object.widthMm &&
                  yMm >= object.yMm &&
                  yMm <= object.yMm + object.heightMm,
            )
            .toList()
          ..sort(
            (a, b) =>
                (a.widthMm * a.heightMm).compareTo(b.widthMm * b.heightMm),
          );
    return matches.firstOrNull?.place.trim() ?? '';
  }

  HandrailEstimateGroup estimateGroupFor(WorkLine line) =>
      handrailEstimateGroups().firstWhere(
        (group) => group.lines.any((component) => component.id == line.id),
        orElse: () => HandrailEstimateGroup([line]),
      );

  String constructionNumberFor(WorkLine line) {
    final groups = handrailEstimateGroups();
    final group = groups.firstWhere(
      (candidate) =>
          candidate.lines.any((component) => component.id == line.id),
      orElse: () => HandrailEstimateGroup([line]),
    );
    return _constructionNumbersForGroups(groups)[group.id] ??
        line.constructionNumber;
  }

  void setConstructionNumberForGroup(WorkLine line, String value) {
    for (final component in estimateGroupFor(line).lines) {
      component.constructionNumber = value;
    }
  }

  List<HandrailPoint> jointPointsFor(
    WorkLine line, {
    List<PlanObject>? projectObjects,
  }) => _lineConnectionEntries(
    line,
  ).map((entry) => HandrailPoint(entry.xMm, entry.yMm)).toList();

  List<_JointPointEntry> _lineConnectionEntries(WorkLine line) {
    final product = productById(line.productId);
    if (product == null || !product.supports(line.environment)) return const [];
    final path = handrailPath(line).points;
    if (path.length < 2) return const [];
    final start = path.first;
    final end = path.last;
    final dx = end.xMm - start.xMm;
    final dy = end.yMm - start.yMm;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0) return const [];
    final automaticCount = math.max(
      0,
      (length / math.max(1, product.maxJointIntervalMm)).ceil() - 1,
    );
    final intermediateCount =
        line.manualIntermediatePointCount?.clamp(0, 99) ?? automaticCount;
    return [
      (
        line: line,
        product: product,
        endpoint: true,
        pointKey: 'start',
        xMm: start.xMm,
        yMm: start.yMm,
      ),
      for (var index = 0; index < intermediateCount; index++)
        (
          line: line,
          product: product,
          endpoint: false,
          pointKey: 'middle:$index',
          xMm: (start.xMm + dx * (index + 1) / (intermediateCount + 1)).round(),
          yMm: (start.yMm + dy * (index + 1) / (intermediateCount + 1)).round(),
        ),
      (
        line: line,
        product: product,
        endpoint: true,
        pointKey: 'end',
        xMm: end.xMm,
        yMm: end.yMm,
      ),
    ];
  }

  List<HandrailConnectionPoint> connectionPointsForGroup(
    HandrailEstimateGroup group,
  ) {
    final entriesByPosition = <(int, int), List<_JointPointEntry>>{};
    final orderedPositions = <(int, int)>[];
    for (final line in group.lines) {
      for (final entry in _lineConnectionEntries(line)) {
        final key = (entry.xMm, entry.yMm);
        if (!entriesByPosition.containsKey(key)) orderedPositions.add(key);
        entriesByPosition.putIfAbsent(key, () => []).add(entry);
      }
    }

    return orderedPositions.map((position) {
      final entries = entriesByPosition[position]!;
      final endpointEntries = entries.where((entry) => entry.endpoint).toList();
      final endpointLineIds = endpointEntries
          .map((entry) => entry.line.id)
          .toSet();
      final kind =
          endpointLineIds.length >= 2 &&
              _connectionEntriesChangeDirection(endpointEntries)
          ? HandrailConnectionKind.connectionJoint
          : entries.length == 1 && entries.single.endpoint == true
          ? HandrailConnectionKind.endBracket
          : HandrailConnectionKind.intermediateBracket;

      JointProduct? selectedProduct;
      for (final entry in entries) {
        final line = entry.line;
        final overrideId = line.connectionProductOverrides[entry.pointKey];
        final override = jointProductById(overrideId);
        if (override != null && kind.accepts(override.type)) {
          selectedProduct = override;
          break;
        }
      }
      if (selectedProduct == null) {
        final connectionType = kind == HandrailConnectionKind.connectionJoint
            ? _connectionEntriesMeetAtRightAngle(endpointEntries)
                  ? JointProductType.lShapeConnection
                  : JointProductType.twoDimensionalConnection
            : null;
        for (final entry in entries) {
          final candidate = _defaultJointForKind(
            entry.product,
            kind,
            connectionType: connectionType,
          );
          if (candidate != null &&
              (selectedProduct == null ||
                  candidate.unitPrice > selectedProduct.unitPrice)) {
            selectedProduct = candidate;
          }
        }
      }

      final freestandingEntries = entries.where(
        (entry) =>
            entry.line.installationType ==
            HandrailInstallationType.freestanding,
      );
      final reinforcementPrices = entries
          .where(
            (entry) =>
                entry.line.reinforcementPlatePrices.containsKey(entry.pointKey),
          )
          .map(
            (entry) => entry.line.reinforcementPlatePrices[entry.pointKey] ?? 0,
          )
          .toList();
      return HandrailConnectionPoint(
        id: '${position.$1}:${position.$2}',
        point: HandrailPoint(position.$1, position.$2),
        kind: kind,
        jointProduct: selectedProduct,
        references: entries
            .map(
              (entry) => HandrailConnectionReference(
                lineId: entry.line.id,
                pointKey: entry.pointKey,
              ),
            )
            .toList(),
        angleRadians: math.atan2(
          entries.first.line.y2Mm - entries.first.line.y1Mm,
          entries.first.line.x2Mm - entries.first.line.x1Mm,
        ),
        freestanding: freestandingEntries.isNotEmpty,
        postPrice: freestandingEntries.fold<int>(
          0,
          (highest, entry) => math.max(highest, entry.product.postPrice),
        ),
        hasReinforcementPlate: reinforcementPrices.isNotEmpty,
        reinforcementPlatePrice: reinforcementPrices.fold<int>(0, math.max),
      );
    }).toList();
  }

  bool _connectionEntriesChangeDirection(List<_JointPointEntry> entries) {
    for (var index = 0; index < entries.length; index++) {
      final line = entries[index].line;
      final dx = line.x2Mm - line.x1Mm;
      final dy = line.y2Mm - line.y1Mm;
      for (final other in entries.skip(index + 1)) {
        final otherDx = other.line.x2Mm - other.line.x1Mm;
        final otherDy = other.line.y2Mm - other.line.y1Mm;
        if (dx * otherDy - dy * otherDx != 0) return true;
      }
    }
    return false;
  }

  bool _connectionEntriesMeetAtRightAngle(List<_JointPointEntry> entries) {
    for (var index = 0; index < entries.length; index++) {
      final line = entries[index].line;
      final dx = line.x2Mm - line.x1Mm;
      final dy = line.y2Mm - line.y1Mm;
      for (final other in entries.skip(index + 1)) {
        final otherDx = other.line.x2Mm - other.line.x1Mm;
        final otherDy = other.line.y2Mm - other.line.y1Mm;
        if (dx * otherDy - dy * otherDx != 0 &&
            dx * otherDx + dy * otherDy == 0) {
          return true;
        }
      }
    }
    return false;
  }

  int intermediatePointCountForGroup(HandrailEstimateGroup group) =>
      group.lines.fold(
        0,
        (total, line) =>
            total +
            _lineConnectionEntries(
              line,
            ).where((entry) => !entry.endpoint).length,
      );

  void setIntermediatePointCountForGroup(
    HandrailEstimateGroup group,
    int count,
  ) {
    final desired = count.clamp(0, 99);
    final allocations = <String, int>{
      for (final line in group.lines) line.id: 0,
    };
    for (var index = 0; index < desired; index++) {
      final target = group.lines.reduce((current, candidate) {
        final currentSpacing =
            current.lengthMm / ((allocations[current.id] ?? 0) + 1);
        final candidateSpacing =
            candidate.lengthMm / ((allocations[candidate.id] ?? 0) + 1);
        return candidateSpacing > currentSpacing ? candidate : current;
      });
      allocations[target.id] = (allocations[target.id] ?? 0) + 1;
    }
    checkpoint();
    for (final line in group.lines) {
      line.manualIntermediatePointCount = allocations[line.id] ?? 0;
      line.connectionProductOverrides.removeWhere(
        (key, _) => key.startsWith('middle:'),
      );
      line.reinforcementPlatePrices.removeWhere(
        (key, _) => key.startsWith('middle:'),
      );
    }
    changed();
  }

  void resetIntermediatePointsForGroup(HandrailEstimateGroup group) {
    checkpoint();
    for (final line in group.lines) {
      line.manualIntermediatePointCount = null;
      line.connectionProductOverrides.removeWhere(
        (key, _) => key.startsWith('middle:'),
      );
      line.reinforcementPlatePrices.removeWhere(
        (key, _) => key.startsWith('middle:'),
      );
    }
    changed();
  }

  void setConnectionPointReinforcementPlate(
    HandrailEstimateGroup group,
    HandrailConnectionPoint point,
    bool enabled,
  ) {
    checkpoint();
    final references = {
      for (final reference in point.references) reference.lineId: reference,
    };
    for (final line in group.lines) {
      final reference = references[line.id];
      if (reference == null) continue;
      if (enabled) {
        line.reinforcementPlatePrices.putIfAbsent(
          reference.pointKey,
          () => defaultReinforcementPlatePrice,
        );
      } else {
        line.reinforcementPlatePrices.remove(reference.pointKey);
      }
    }
    changed();
  }

  void setConnectionPointReinforcementPlatePrice(
    HandrailEstimateGroup group,
    HandrailConnectionPoint point,
    int price,
  ) {
    if (!point.hasReinforcementPlate) return;
    checkpoint();
    final normalizedPrice = price.clamp(0, 999999999);
    final references = {
      for (final reference in point.references) reference.lineId: reference,
    };
    for (final line in group.lines) {
      final reference = references[line.id];
      if (reference == null) continue;
      line.reinforcementPlatePrices[reference.pointKey] = normalizedPrice;
    }
    changed();
  }

  void setConnectionPointProduct(
    HandrailEstimateGroup group,
    HandrailConnectionPoint point,
    String productId,
  ) {
    final product = jointProductById(productId);
    if (product == null || !point.kind.accepts(product.type)) return;
    checkpoint();
    final references = {
      for (final reference in point.references) reference.lineId: reference,
    };
    for (final line in group.lines) {
      final reference = references[line.id];
      if (reference != null) {
        line.connectionProductOverrides[reference.pointKey] = product.id;
      }
    }
    changed();
  }

  HandrailCostBreakdown costFor(
    WorkLine line, {
    List<PlanObject>? projectObjects,
  }) => costForGroup(
    HandrailEstimateGroup([line]),
    projectObjects: projectObjects,
  );

  HandrailCostBreakdown costForGroup(
    HandrailEstimateGroup group, {
    List<PlanObject>? projectObjects,
  }) {
    var railCost = 0;
    for (final line in group.lines) {
      final product = productById(line.productId);
      if (product == null || !product.supports(line.environment)) continue;
      railCost += (line.lengthMm / 1000 * product.railPricePerMeter).round();
    }

    final points = connectionPointsForGroup(group);
    var endBracketCount = 0;
    var intermediateBracketCount = 0;
    var connectionJointCount = 0;
    var endBracketCost = 0;
    var intermediateBracketCost = 0;
    var connectionJointCost = 0;
    var postCount = 0;
    var postCost = 0;
    var reinforcementPlateCount = 0;
    var reinforcementPlateCost = 0;

    for (final point in points) {
      final price = point.jointProduct?.unitPrice ?? 0;
      switch (point.kind) {
        case HandrailConnectionKind.endBracket:
          endBracketCount++;
          endBracketCost += price;
        case HandrailConnectionKind.intermediateBracket:
          intermediateBracketCount++;
          intermediateBracketCost += price;
        case HandrailConnectionKind.connectionJoint:
          connectionJointCount++;
          connectionJointCost += price;
      }
      if (point.freestanding) {
        postCount++;
        postCost += point.postPrice;
      }
      if (point.hasReinforcementPlate) {
        reinforcementPlateCount++;
        reinforcementPlateCost += point.reinforcementPlatePrice;
      }
    }
    return HandrailCostBreakdown(
      endBracketCount: endBracketCount,
      intermediateBracketCount: intermediateBracketCount,
      connectionJointCount: connectionJointCount,
      postCount: postCount,
      railCost: railCost,
      endBracketCost: endBracketCost,
      intermediateBracketCost: intermediateBracketCost,
      connectionJointCost: connectionJointCost,
      postCost: postCost,
      reinforcementPlateCount: reinforcementPlateCount,
      reinforcementPlateCost: reinforcementPlateCost,
    );
  }

  JointProduct? _defaultJointForKind(
    HandrailProduct product,
    HandrailConnectionKind kind, {
    JointProductType? connectionType,
  }) => switch (kind) {
    HandrailConnectionKind.endBracket => jointProductById(
      product.defaultEndBracketId,
    ),
    HandrailConnectionKind.intermediateBracket => jointProductById(
      product.defaultIntermediateBracketId,
    ),
    HandrailConnectionKind.connectionJoint =>
      connectionType == JointProductType.lShapeConnection
          ? jointProductById(product.defaultLJointId)
          : jointProductsForType(
              connectionType ?? JointProductType.twoDimensionalConnection,
            ).firstOrNull,
  };

  int get materialCostTotal => handrailEstimateGroups().fold(
    0,
    (sum, group) => sum + costForGroup(group).total,
  );

  void addSample({bool notify = true}) {
    final room = PlanObject(
      id: newId('layout'),
      kind: PlanObjectKind.layout,
      place: 'トイレ',
      xMm: 1000,
      yMm: 750,
      widthMm: 2000,
      heightMm: 2500,
    );
    objects = [
      room,
      PlanObject(
        id: newId('toilet'),
        kind: PlanObjectKind.fixture,
        fixture: 'toilet',
        place: 'トイレ',
        xMm: 1750,
        yMm: 1500,
        widthMm: 500,
        heightMm: 1000,
      ),
      PlanObject(
        id: newId('door'),
        kind: PlanObjectKind.door,
        place: 'トイレ入口',
        xMm: 3000,
        yMm: 2500,
        widthMm: 500,
        heightMm: 500,
        wallId: room.id,
        wallEdge: WallEdge.right,
      ),
    ];
    lines = [
      WorkLine(
        id: newId('rail'),
        place: 'トイレ',
        x1Mm: 1250,
        y1Mm: 1250,
        x2Mm: 2000,
        y2Mm: 1250,
        productId: defaultProductIdFor(HandrailEnvironment.indoor),
        constructionNumber: '1',
      ),
    ];
    selectedId = null;
    _prepareDerivedProjectData();
    if (notify) changed();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
