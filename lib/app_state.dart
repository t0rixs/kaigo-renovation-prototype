import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

enum OpeningAddResult { added, noWall, overlaps }

class AppState extends ChangeNotifier {
  static const _legacyStorageKey = 'kaigo_renovation_project_v4_handrail';
  static const gridMm = 250;
  static const majorGridMm = 500;
  static const defaultCanvasWidthMm = RenovationProject.defaultCanvasWidthMm;
  static const defaultCanvasHeightMm = RenovationProject.defaultCanvasHeightMm;

  AppState({AppDataRepository? dataRepository})
    : _dataRepository = dataRepository ?? createAppDataRepository() {
    _replaceWithFreshProject();
  }

  final AppDataRepository _dataRepository;

  List<HandrailProduct> products = defaultHandrailProducts();
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
  List<SharedWallSegment> get sharedWallOverrides =>
      activeProject.sharedWallOverrides;
  int get canvasWidthMm => activeProject.canvasWidthMm;
  int get canvasHeightMm => activeProject.canvasHeightMm;

  Future<void> load() async {
    var raw = await _dataRepository.read();
    if (raw == null) {
      final preferences = await SharedPreferences.getInstance();
      raw = preferences.getString(_legacyStorageKey);
    }
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

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'productMaster': {
      'products': products.map((item) => item.toJson()).toList(),
      'defaults': {
        'indoorProductId': indoorDefaultProductId,
        'outdoorProductId': outdoorDefaultProductId,
      },
    },
    'projects': projects.map(_projectToJson).toList(),
    'activeProjectId': activeProjectId,
  };

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
            'postCount': cost.postCount,
            'railCost': cost.railCost,
            'jointCost': cost.jointCost,
            'postCost': cost.postCost,
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
    final schemaVersion = (json['schemaVersion'] as num?)?.toInt() ?? 0;
    if (schemaVersion > 1) {
      throw const FormatException('Unsupported data schema version');
    }
    final productMaster = json['productMaster'] as Map<String, dynamic>?;
    final productSource = productMaster ?? json;
    final defaults = productMaster?['defaults'] as Map<String, dynamic>?;
    products = ((productSource['products'] as List<dynamic>?) ?? const [])
        .map((item) => HandrailProduct.fromJson(item as Map<String, dynamic>))
        .toList();
    indoorDefaultProductId =
        defaults?['indoorProductId'] as String? ??
        json['indoorDefaultProductId'] as String?;
    outdoorDefaultProductId =
        defaults?['outdoorProductId'] as String? ??
        json['outdoorDefaultProductId'] as String?;
    _ensureDefaultProductsValid();

    final storedProjects = json['projects'] as List<dynamic>?;
    if (storedProjects == null) {
      projects = [
        RenovationProject(
          id: newId('project'),
          customer: CustomerInfo.fromJson(
            json['customer'] as Map<String, dynamic>? ?? const {},
          ),
          objects: ((json['objects'] as List<dynamic>?) ?? const [])
              .map((item) => PlanObject.fromJson(item as Map<String, dynamic>))
              .toList(),
          lines: ((json['lines'] as List<dynamic>?) ?? const [])
              .map((item) => WorkLine.fromJson(item as Map<String, dynamic>))
              .toList(),
          updatedAt: DateTime.now(),
        ),
      ];
    } else {
      projects = storedProjects
          .map(
            (item) => RenovationProject.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      if (projects.isEmpty) _replaceWithFreshProject();
    }
    final storedActiveProjectId = json['activeProjectId'] as String?;
    activeProjectId =
        projects.any((project) => project.id == storedActiveProjectId)
        ? storedActiveProjectId
        : projects.first.id;

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

  void addToilet(int centerXMm, int centerYMm) {
    checkpoint();
    const width = 500;
    const height = 1000;
    final item = PlanObject(
      id: newId('toilet'),
      kind: PlanObjectKind.fixture,
      fixture: 'toilet',
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

  OpeningAddResult addOpening(
    PlanObjectKind kind,
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
      id: newId(kind.name),
      kind: kind,
      place: snap.wall.place.trim(),
      xMm: x,
      yMm: y,
      widthMm: width,
      heightMm: height,
      wallId: snap.wall.id,
      wallEdge: snap.edge,
      doorType: kind == PlanObjectKind.door ? doorType : DoorType.swing,
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

  void rotateToilet(PlanObject item) {
    if (item.kind != PlanObjectKind.fixture || item.fixture != 'toilet') return;
    checkpoint();
    applyToiletRotation(item, item.rotationQuarterTurns + 1);
    changed();
  }

  void applyToiletRotation(PlanObject item, int quarterTurns) {
    if (item.kind != PlanObjectKind.fixture || item.fixture != 'toilet') return;
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
    var endX = snapMm(x2Mm);
    var endY = snapMm(y2Mm);
    final horizontal = (endX - startX).abs() > (endY - startY).abs();
    if (horizontal) {
      endY = startY;
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

    endX = startX;
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
    if ((endX - startX).abs() > (endY - startY).abs()) {
      endY = startY;
      if (endX == startX) endX += gridMm;
    } else {
      endX = startX;
      if (endY == startY) endY += gridMm;
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
    final movingX = start ? line.x1Mm : line.x2Mm;
    final movingY = start ? line.y1Mm : line.y2Mm;
    final wasHorizontal = line.isHorizontal;
    var targetX = snapMm(xMm).clamp(0, canvasWidthMm);
    var targetY = snapMm(yMm).clamp(0, canvasHeightMm);
    final dragX = (targetX - movingX).abs();
    final dragY = (targetY - movingY).abs();
    final horizontal = math.max(dragX, dragY) < gridMm / 2
        ? wasHorizontal
        : dragX > dragY;
    if (horizontal) {
      targetY = fixedY;
      if (targetX == fixedX) {
        targetX = (fixedX + (start ? -gridMm : gridMm)).clamp(0, canvasWidthMm);
      }
    } else {
      targetX = fixedX;
      if (targetY == fixedY) {
        targetY = (fixedY + (start ? -gridMm : gridMm)).clamp(
          0,
          canvasHeightMm,
        );
      }
    }
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
    } else {
      final direction = line.y2Mm >= line.y1Mm ? 1 : -1;
      line.y2Mm = (line.y1Mm + direction * snapped).clamp(0, canvasHeightMm);
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
    if (products.isEmpty) products = defaultHandrailProducts();
    indoorDefaultProductId = defaultProductIdFor(HandrailEnvironment.indoor);
    outdoorDefaultProductId = defaultProductIdFor(HandrailEnvironment.outdoor);
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

  HandrailEstimateGroup estimateGroupFor(WorkLine line) =>
      handrailEstimateGroups().firstWhere(
        (group) => group.lines.any((component) => component.id == line.id),
        orElse: () => HandrailEstimateGroup([line]),
      );

  String constructionNumberFor(WorkLine line) =>
      estimateGroupFor(line).primary.constructionNumber;

  void setConstructionNumberForGroup(WorkLine line, String value) {
    for (final component in estimateGroupFor(line).lines) {
      component.constructionNumber = value;
    }
  }

  List<HandrailPoint> jointPointsFor(
    WorkLine line, {
    List<PlanObject>? projectObjects,
  }) {
    final product = productById(line.productId);
    if (product == null || !product.supports(line.environment)) return const [];
    final interval = math.max(1, product.maxJointIntervalMm);
    final path = handrailPath(line).points;
    if (path.length < 2) return const [];
    final joints = <HandrailPoint>[path.first];
    for (var index = 0; index < path.length - 1; index++) {
      final start = path[index];
      final end = path[index + 1];
      final dx = end.xMm - start.xMm;
      final dy = end.yMm - start.yMm;
      final length = dx.abs() + dy.abs();
      if (length == 0) continue;
      final sectionCount = (length / interval).ceil();
      for (var section = 1; section <= sectionCount; section++) {
        final distance = (length * section / sectionCount).round();
        joints.add(
          HandrailPoint(
            start.xMm + dx.sign * distance,
            start.yMm + dy.sign * distance,
          ),
        );
      }
    }
    return joints;
  }

  HandrailCostBreakdown costFor(
    WorkLine line, {
    List<PlanObject>? projectObjects,
  }) {
    final product = productById(line.productId);
    if (product == null || !product.supports(line.environment)) {
      return const HandrailCostBreakdown(
        jointCount: 0,
        postCount: 0,
        railCost: 0,
        jointCost: 0,
        postCost: 0,
      );
    }
    final jointCount = jointPointsFor(
      line,
      projectObjects: projectObjects,
    ).length;
    final postCount =
        line.installationType == HandrailInstallationType.freestanding
        ? jointCount
        : 0;
    return HandrailCostBreakdown(
      jointCount: jointCount,
      postCount: postCount,
      railCost: (line.lengthMm / 1000 * product.railPricePerMeter).round(),
      jointCost: jointCount * product.jointPrice,
      postCost: postCount * product.postPrice,
    );
  }

  HandrailCostBreakdown costForGroup(
    HandrailEstimateGroup group, {
    List<PlanObject>? projectObjects,
  }) {
    var railCost = 0;
    final jointPrices = <(int, int), int>{};
    final postPrices = <(int, int), int>{};
    for (final line in group.lines) {
      final product = productById(line.productId);
      if (product == null || !product.supports(line.environment)) continue;
      railCost += (line.lengthMm / 1000 * product.railPricePerMeter).round();
      for (final point in jointPointsFor(
        line,
        projectObjects: projectObjects,
      )) {
        final key = (point.xMm, point.yMm);
        jointPrices[key] = math.max(jointPrices[key] ?? 0, product.jointPrice);
        if (line.installationType == HandrailInstallationType.freestanding) {
          postPrices[key] = math.max(postPrices[key] ?? 0, product.postPrice);
        }
      }
    }
    return HandrailCostBreakdown(
      jointCount: jointPrices.length,
      postCount: postPrices.length,
      railCost: railCost,
      jointCost: jointPrices.values.fold(0, (total, price) => total + price),
      postCost: postPrices.values.fold(0, (total, price) => total + price),
    );
  }

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
      PlanObject(
        id: newId('window'),
        kind: PlanObjectKind.window,
        place: 'トイレ',
        xMm: 1500,
        yMm: 750,
        widthMm: 750,
        heightMm: 500,
        wallId: room.id,
        wallEdge: WallEdge.top,
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
    if (notify) changed();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
