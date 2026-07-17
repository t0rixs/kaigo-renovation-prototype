enum HandrailEnvironment { indoor, outdoor }

extension HandrailEnvironmentLabel on HandrailEnvironment {
  String get label => switch (this) {
    HandrailEnvironment.indoor => '屋内',
    HandrailEnvironment.outdoor => '屋外',
  };

  static HandrailEnvironment fromName(String? value) =>
      HandrailEnvironment.values.firstWhere(
        (environment) => environment.name == value,
        orElse: () => HandrailEnvironment.indoor,
      );
}

enum HandrailInstallationType { wallMounted, freestanding }

extension HandrailInstallationTypeLabel on HandrailInstallationType {
  String get label => switch (this) {
    HandrailInstallationType.wallMounted => '壁取付型',
    HandrailInstallationType.freestanding => '独立型',
  };

  static HandrailInstallationType fromName(String? value) =>
      HandrailInstallationType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => HandrailInstallationType.wallMounted,
      );
}

enum HandrailOrientation { horizontal, vertical }

extension HandrailOrientationLabel on HandrailOrientation {
  String get label => switch (this) {
    HandrailOrientation.horizontal => '横',
    HandrailOrientation.vertical => '縦',
  };
}

class CustomerInfo {
  CustomerInfo({
    this.name = '山田 太郎',
    this.kana = 'ヤマダ タロウ',
    this.address = '福岡市西区小戸1丁目',
    this.phone = '092-000-0000',
    this.insuredNumber = '0000123456',
    this.surveyDate = '',
    this.birthDate = '',
    this.familyAddressee = '山田 花子 様',
    this.projectName = '山田 太郎様邸 住宅改修工事',
    this.constructionPlace = '福岡市西区小戸1丁目',
    this.estimateValid = '発行日より30日',
    this.paymentTerms = '完了後一括',
  });

  String name;
  String kana;
  String address;
  String phone;
  String insuredNumber;
  String surveyDate;
  String birthDate;
  String familyAddressee;
  String projectName;
  String constructionPlace;
  String estimateValid;
  String paymentTerms;

  Map<String, dynamic> toJson() => {
    'name': name,
    'kana': kana,
    'address': address,
    'phone': phone,
    'insuredNumber': insuredNumber,
    'surveyDate': surveyDate,
    'birthDate': birthDate,
    'familyAddressee': familyAddressee,
    'projectName': projectName,
    'constructionPlace': constructionPlace,
    'estimateValid': estimateValid,
    'paymentTerms': paymentTerms,
  };

  factory CustomerInfo.fromJson(Map<String, dynamic> json) => CustomerInfo(
    name: json['name'] as String? ?? '',
    kana: json['kana'] as String? ?? '',
    address: json['address'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    insuredNumber: json['insuredNumber'] as String? ?? '',
    surveyDate: json['surveyDate'] as String? ?? '',
    birthDate: json['birthDate'] as String? ?? '',
    familyAddressee: json['familyAddressee'] as String? ?? '',
    projectName: json['projectName'] as String? ?? '',
    constructionPlace: json['constructionPlace'] as String? ?? '',
    estimateValid: json['estimateValid'] as String? ?? '',
    paymentTerms: json['paymentTerms'] as String? ?? '',
  );
}

class HandrailDocumentFields {
  HandrailDocumentFields({
    required this.handrailId,
    this.location = '',
    this.workContent = '',
    this.specification = '',
    this.remarks = '',
  });

  String handrailId;
  String location;
  String workContent;
  String specification;
  String remarks;

  Map<String, dynamic> toJson() => {
    'handrailId': handrailId,
    'location': location,
    'workContent': workContent,
    'specification': specification,
    'remarks': remarks,
  };

  factory HandrailDocumentFields.fromJson(Map<String, dynamic> json) =>
      HandrailDocumentFields(
        handrailId: json['handrailId'] as String? ?? '',
        location: json['location'] as String? ?? '',
        workContent: json['workContent'] as String? ?? '',
        specification: json['specification'] as String? ?? '',
        remarks: json['remarks'] as String? ?? '',
      );
}

class ProjectDocuments {
  ProjectDocuments({
    this.costItemName = '',
    this.quotePaymentTerms = '',
    this.grossMarginPercent = 50,
    Map<String, HandrailDocumentFields>? handrailFields,
  }) : handrailFields = handrailFields ?? {};

  String costItemName;
  String quotePaymentTerms;
  double grossMarginPercent;
  final Map<String, HandrailDocumentFields> handrailFields;

  HandrailDocumentFields fieldsFor(String handrailId) =>
      handrailFields.putIfAbsent(
        handrailId,
        () => HandrailDocumentFields(handrailId: handrailId),
      );

  Map<String, dynamic> toJson() => {
    'costItemName': costItemName,
    'quotePaymentTerms': quotePaymentTerms,
    'grossMarginPercent': grossMarginPercent,
    'handrailFields': handrailFields.values
        .map((fields) => fields.toJson())
        .toList(),
  };

  factory ProjectDocuments.fromJson(Map<String, dynamic> json) {
    final entries = ((json['handrailFields'] as List<dynamic>?) ?? const [])
        .map(
          (item) =>
              HandrailDocumentFields.fromJson(item as Map<String, dynamic>),
        )
        .where((fields) => fields.handrailId.isNotEmpty);
    return ProjectDocuments(
      costItemName: json['costItemName'] as String? ?? '',
      quotePaymentTerms: json['quotePaymentTerms'] as String? ?? '',
      grossMarginPercent:
          (json['grossMarginPercent'] as num?)?.toDouble() ?? 50,
      handrailFields: {for (final fields in entries) fields.handrailId: fields},
    );
  }
}

class RenovationProject {
  static const defaultCanvasWidthMm = 10000;
  static const defaultCanvasHeightMm = 7500;

  RenovationProject({
    required this.id,
    required this.customer,
    required this.objects,
    required this.lines,
    required this.updatedAt,
    this.canvasWidthMm = defaultCanvasWidthMm,
    this.canvasHeightMm = defaultCanvasHeightMm,
    ProjectDocuments? documents,
    List<SharedWallSegment>? sharedWallOverrides,
  }) : documents = documents ?? ProjectDocuments(),
       sharedWallOverrides = sharedWallOverrides ?? [];

  String id;
  CustomerInfo customer;
  List<PlanObject> objects;
  List<WorkLine> lines;
  DateTime updatedAt;
  int canvasWidthMm;
  int canvasHeightMm;
  ProjectDocuments documents;
  List<SharedWallSegment> sharedWallOverrides;

  Map<String, dynamic> toJson() => {
    'id': id,
    'basicInfo': customer.toJson(),
    'drawing': {
      'canvas': {'widthMm': canvasWidthMm, 'heightMm': canvasHeightMm},
      'objects': objects.map((item) => item.toJson()).toList(),
      'handrails': lines.map((item) => item.toJson()).toList(),
      'sharedWalls': sharedWallOverrides.map((item) => item.toJson()).toList(),
    },
    'documents': documents.toJson(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static int _canvasDimension(Object? value, int fallback) {
    final millimeters = (value as num?)?.round() ?? fallback;
    if (millimeters <= 0) return fallback;
    final snapped = ((millimeters + 125) ~/ 250) * 250;
    return snapped < 250 ? 250 : snapped;
  }

  factory RenovationProject.fromJson(Map<String, dynamic> json) {
    final drawing = json['drawing'] as Map<String, dynamic>? ?? json;
    final canvas = drawing['canvas'] as Map<String, dynamic>? ?? const {};
    final storedWidth = _canvasDimension(
      canvas['widthMm'],
      defaultCanvasWidthMm,
    );
    final storedHeight = _canvasDimension(
      canvas['heightMm'],
      defaultCanvasHeightMm,
    );
    return RenovationProject(
      id: json['id'] as String? ?? '',
      customer: CustomerInfo.fromJson(
        json['basicInfo'] as Map<String, dynamic>? ??
            json['customer'] as Map<String, dynamic>? ??
            const {},
      ),
      objects: ((drawing['objects'] as List<dynamic>?) ?? const [])
          .map((item) => PlanObject.fromJson(item as Map<String, dynamic>))
          .toList(),
      lines:
          ((drawing['handrails'] as List<dynamic>?) ??
                  (drawing['lines'] as List<dynamic>?) ??
                  const [])
              .map((item) => WorkLine.fromJson(item as Map<String, dynamic>))
              .toList(),
      canvasWidthMm: storedWidth,
      canvasHeightMm: storedHeight,
      sharedWallOverrides:
          ((drawing['sharedWalls'] as List<dynamic>?) ?? const [])
              .map(
                (item) =>
                    SharedWallSegment.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      documents: ProjectDocuments.fromJson(
        json['documents'] as Map<String, dynamic>? ?? const {},
      ),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

class HandrailProduct {
  HandrailProduct({
    required this.id,
    required this.name,
    required this.environmentTags,
    required this.diameterMm,
    required this.railPricePerMeter,
    required this.jointPrice,
    required this.postPrice,
    required this.maxJointIntervalMm,
  });

  String id;
  String name;
  Set<HandrailEnvironment> environmentTags;
  int diameterMm;
  int railPricePerMeter;
  int jointPrice;
  int postPrice;
  int maxJointIntervalMm;

  bool supports(HandrailEnvironment environment) =>
      environmentTags.contains(environment);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'environmentTags': environmentTags.map((tag) => tag.name).toList(),
    'diameterMm': diameterMm,
    'railPricePerMeter': railPricePerMeter,
    'jointPrice': jointPrice,
    'postPrice': postPrice,
    'maxJointIntervalMm': maxJointIntervalMm,
  };

  factory HandrailProduct.fromJson(Map<String, dynamic> json) =>
      HandrailProduct(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        environmentTags: ((json['environmentTags'] as List<dynamic>?) ?? [])
            .map((tag) => HandrailEnvironmentLabel.fromName(tag as String?))
            .toSet(),
        diameterMm: (json['diameterMm'] as num?)?.round() ?? 35,
        railPricePerMeter: (json['railPricePerMeter'] as num?)?.round() ?? 0,
        jointPrice: (json['jointPrice'] as num?)?.round() ?? 0,
        postPrice: (json['postPrice'] as num?)?.round() ?? 0,
        maxJointIntervalMm:
            (json['maxJointIntervalMm'] as num?)?.round() ?? 1000,
      );
}

enum PlanObjectKind { layout, fixture, door, window }

extension PlanObjectKindLabel on PlanObjectKind {
  String get label => switch (this) {
    PlanObjectKind.layout => '間取り',
    PlanObjectKind.fixture => '設備',
    PlanObjectKind.door => 'ドア',
    PlanObjectKind.window => '窓',
  };
}

enum WallEdge { top, right, bottom, left }

enum DoorType { swing, sliding }

extension DoorTypeLabel on DoorType {
  String get label => switch (this) {
    DoorType.swing => '開き戸',
    DoorType.sliding => 'スライド戸',
  };
}

class SharedWallSegment {
  const SharedWallSegment({
    required this.roomAId,
    required this.roomBId,
    required this.horizontal,
    required this.coordinateMm,
    required this.startMm,
    required this.endMm,
    required this.visible,
  });

  final String roomAId;
  final String roomBId;
  final bool horizontal;
  final int coordinateMm;
  final int startMm;
  final int endMm;
  final bool visible;

  String get key {
    final first = roomAId.compareTo(roomBId) <= 0 ? roomAId : roomBId;
    final second = first == roomAId ? roomBId : roomAId;
    return '$first|$second|${horizontal ? 'h' : 'v'}|$coordinateMm|$startMm|$endMm';
  }

  SharedWallSegment copyWith({bool? visible}) => SharedWallSegment(
    roomAId: roomAId,
    roomBId: roomBId,
    horizontal: horizontal,
    coordinateMm: coordinateMm,
    startMm: startMm,
    endMm: endMm,
    visible: visible ?? this.visible,
  );

  Map<String, dynamic> toJson() => {
    'roomAId': roomAId,
    'roomBId': roomBId,
    'orientation': horizontal ? 'horizontal' : 'vertical',
    'coordinateMm': coordinateMm,
    'startMm': startMm,
    'endMm': endMm,
    'visible': visible,
  };

  factory SharedWallSegment.fromJson(Map<String, dynamic> json) =>
      SharedWallSegment(
        roomAId: json['roomAId'] as String? ?? '',
        roomBId: json['roomBId'] as String? ?? '',
        horizontal: json['orientation'] != 'vertical',
        coordinateMm: (json['coordinateMm'] as num?)?.round() ?? 0,
        startMm: (json['startMm'] as num?)?.round() ?? 0,
        endMm: (json['endMm'] as num?)?.round() ?? 0,
        visible: json['visible'] as bool? ?? true,
      );
}

class LayoutWallContact {
  const LayoutWallContact({
    required this.room,
    required this.otherRoom,
    required this.roomEdge,
    required this.otherEdge,
    required this.segment,
  });

  final PlanObject room;
  final PlanObject otherRoom;
  final WallEdge roomEdge;
  final WallEdge otherEdge;
  final SharedWallSegment segment;

  bool get visible => segment.visible;
}

class PlanObject {
  PlanObject({
    required this.id,
    required this.kind,
    required this.place,
    required this.xMm,
    required this.yMm,
    required this.widthMm,
    required this.heightMm,
    this.fixture = '',
    this.wallId,
    this.wallEdge,
    this.doorType = DoorType.swing,
    this.flipped = false,
    this.opensOutward = false,
    this.rotationQuarterTurns = 0,
  });

  String id;
  PlanObjectKind kind;
  String place;
  int xMm;
  int yMm;
  int widthMm;
  int heightMm;
  String fixture;
  String? wallId;
  WallEdge? wallEdge;
  DoorType doorType;
  bool flipped;
  bool opensOutward;
  int rotationQuarterTurns;

  int get rotationDegrees => (rotationQuarterTurns % 4) * 90;

  bool get isWallAttached =>
      kind == PlanObjectKind.door || kind == PlanObjectKind.window;

  bool get isHorizontalWall =>
      wallEdge == WallEdge.top || wallEdge == WallEdge.bottom;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'place': place,
    'xMm': xMm,
    'yMm': yMm,
    'widthMm': widthMm,
    'heightMm': heightMm,
    'fixture': fixture,
    'wallId': wallId,
    'wallEdge': wallEdge?.name,
    'doorType': doorType.name,
    'flipped': flipped,
    'opensOutward': opensOutward,
    'rotationQuarterTurns': rotationQuarterTurns,
  };

  factory PlanObject.fromJson(Map<String, dynamic> json) => PlanObject(
    id: json['id'] as String? ?? '',
    kind: PlanObjectKind.values.firstWhere(
      (kind) => kind.name == json['kind'],
      orElse: () => PlanObjectKind.layout,
    ),
    place: ((json['place'] as String?)?.trim().isNotEmpty ?? false)
        ? json['place'] as String
        : json['label'] as String? ?? '',
    xMm: (json['xMm'] as num?)?.round() ?? 0,
    yMm: (json['yMm'] as num?)?.round() ?? 0,
    widthMm: (json['widthMm'] as num?)?.round() ?? 500,
    heightMm: (json['heightMm'] as num?)?.round() ?? 500,
    fixture: json['fixture'] as String? ?? '',
    wallId: json['wallId'] as String?,
    wallEdge: WallEdge.values
        .where((edge) => edge.name == json['wallEdge'])
        .firstOrNull,
    doorType: DoorType.values.firstWhere(
      (type) => type.name == json['doorType'],
      orElse: () => DoorType.swing,
    ),
    flipped: json['flipped'] as bool? ?? false,
    opensOutward: json['opensOutward'] as bool? ?? false,
    rotationQuarterTurns:
        ((json['rotationQuarterTurns'] as num?)?.round() ?? 0) % 4,
  );
}

class WorkLine {
  WorkLine({
    required this.id,
    required this.place,
    required this.x1Mm,
    required this.y1Mm,
    required this.x2Mm,
    required this.y2Mm,
    this.productId,
    this.note = '',
    this.constructionNumber = '1',
    this.environment = HandrailEnvironment.indoor,
    this.installationType = HandrailInstallationType.wallMounted,
  });

  String id;
  String place;
  int x1Mm;
  int y1Mm;
  int x2Mm;
  int y2Mm;
  String? productId;
  String note;
  String constructionNumber;
  HandrailEnvironment environment;
  HandrailInstallationType installationType;

  bool get isHorizontal => y1Mm == y2Mm;
  int get lengthMm => isHorizontal ? (x2Mm - x1Mm).abs() : (y2Mm - y1Mm).abs();
  HandrailOrientation get orientation => isHorizontal
      ? HandrailOrientation.horizontal
      : HandrailOrientation.vertical;

  Map<String, dynamic> toJson() => {
    'id': id,
    'place': place,
    'x1Mm': x1Mm,
    'y1Mm': y1Mm,
    'x2Mm': x2Mm,
    'y2Mm': y2Mm,
    'productId': productId,
    'note': note,
    'constructionNumber': constructionNumber,
    'environment': environment.name,
    'installationType': installationType.name,
  };

  factory WorkLine.fromJson(Map<String, dynamic> json) => WorkLine(
    id: json['id'] as String? ?? '',
    place: json['place'] as String? ?? '',
    x1Mm: (json['x1Mm'] as num?)?.round() ?? 0,
    y1Mm: (json['y1Mm'] as num?)?.round() ?? 0,
    x2Mm: (json['x2Mm'] as num?)?.round() ?? 250,
    y2Mm: (json['y2Mm'] as num?)?.round() ?? 0,
    productId: json['productId'] as String?,
    note: json['note'] as String? ?? '',
    constructionNumber: json['constructionNumber'] as String? ?? '1',
    environment: HandrailEnvironmentLabel.fromName(
      json['environment'] as String?,
    ),
    installationType: HandrailInstallationTypeLabel.fromName(
      json['installationType'] as String?,
    ),
  );
}

class HandrailPoint {
  const HandrailPoint(this.xMm, this.yMm);

  final int xMm;
  final int yMm;
}

class HandrailPath {
  const HandrailPath(this.points);

  final List<HandrailPoint> points;

  HandrailOrientation? get orientation {
    if (points.length < 2) return null;
    final first = points.first;
    if (points.every((point) => point.yMm == first.yMm)) {
      return HandrailOrientation.horizontal;
    }
    if (points.every((point) => point.xMm == first.xMm)) {
      return HandrailOrientation.vertical;
    }
    return null;
  }
}

class HandrailEstimateGroup {
  const HandrailEstimateGroup(this.lines);

  final List<WorkLine> lines;

  WorkLine get primary => lines.first;
  String get id => primary.id;
  int get lengthMm => lines.fold(0, (total, line) => total + line.lengthMm);
  bool get isConnected => lines.length > 1;
}

class HandrailCostBreakdown {
  const HandrailCostBreakdown({
    required this.jointCount,
    required this.postCount,
    required this.railCost,
    required this.jointCost,
    required this.postCost,
  });

  final int jointCount;
  final int postCount;
  final int railCost;
  final int jointCost;
  final int postCost;

  int get total => railCost + jointCost + postCost;
}

List<HandrailProduct> defaultHandrailProducts() => [
  HandrailProduct(
    id: 'demo-indoor-35',
    name: '室内用木製手すり φ35',
    environmentTags: {HandrailEnvironment.indoor},
    diameterMm: 35,
    railPricePerMeter: 4400,
    jointPrice: 1250,
    postPrice: 3800,
    maxJointIntervalMm: 1000,
  ),
  HandrailProduct(
    id: 'demo-outdoor-34',
    name: '屋外用アルミ手すり φ34',
    environmentTags: {HandrailEnvironment.outdoor},
    diameterMm: 34,
    railPricePerMeter: 7200,
    jointPrice: 1800,
    postPrice: 6500,
    maxJointIntervalMm: 1000,
  ),
];
