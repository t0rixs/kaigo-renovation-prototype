import 'dart:math' as math;

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

enum HandrailOrientation { horizontal, vertical, diagonal }

extension HandrailOrientationLabel on HandrailOrientation {
  String get label => switch (this) {
    HandrailOrientation.horizontal => '横',
    HandrailOrientation.vertical => '縦',
    HandrailOrientation.diagonal => '斜め',
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

enum ProjectPhotoSlot { before, after }

class CapturedProjectPhoto {
  CapturedProjectPhoto({
    required this.base64Data,
    required this.mimeType,
    required this.fileName,
    required this.capturedAt,
  });

  String base64Data;
  String mimeType;
  String fileName;
  DateTime capturedAt;

  Map<String, dynamic> toJson() => {
    'base64Data': base64Data,
    'mimeType': mimeType,
    'fileName': fileName,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
  };

  factory CapturedProjectPhoto.fromJson(Map<String, dynamic> json) =>
      CapturedProjectPhoto(
        base64Data: json['base64Data'] as String? ?? '',
        mimeType: json['mimeType'] as String? ?? 'image/jpeg',
        fileName: json['fileName'] as String? ?? 'photo.jpg',
        capturedAt:
            DateTime.tryParse(json['capturedAt'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

class RenovationPhotoLocation {
  RenovationPhotoLocation({
    required this.id,
    required this.locationName,
    required this.xMm,
    required this.yMm,
    List<String>? handrailIds,
    this.handrailNumber = '',
    this.positionCustomized = false,
    this.beforeMemo = '',
    this.afterMemo = '',
    this.beforePhoto,
    this.afterPhoto,
  }) : handrailIds = handrailIds ?? [];

  String id;
  String locationName;
  int xMm;
  int yMm;
  List<String> handrailIds;
  String handrailNumber;
  bool positionCustomized;
  String beforeMemo;
  String afterMemo;
  CapturedProjectPhoto? beforePhoto;
  CapturedProjectPhoto? afterPhoto;

  CapturedProjectPhoto? photoFor(ProjectPhotoSlot slot) => switch (slot) {
    ProjectPhotoSlot.before => beforePhoto,
    ProjectPhotoSlot.after => afterPhoto,
  };

  String memoFor(ProjectPhotoSlot slot) => switch (slot) {
    ProjectPhotoSlot.before => beforeMemo,
    ProjectPhotoSlot.after => afterMemo,
  };

  void setPhoto(ProjectPhotoSlot slot, CapturedProjectPhoto photo) {
    switch (slot) {
      case ProjectPhotoSlot.before:
        beforePhoto = photo;
      case ProjectPhotoSlot.after:
        afterPhoto = photo;
    }
  }

  void clearPhoto(ProjectPhotoSlot slot) {
    switch (slot) {
      case ProjectPhotoSlot.before:
        beforePhoto = null;
      case ProjectPhotoSlot.after:
        afterPhoto = null;
    }
  }

  void setMemo(ProjectPhotoSlot slot, String value) {
    switch (slot) {
      case ProjectPhotoSlot.before:
        beforeMemo = value;
      case ProjectPhotoSlot.after:
        afterMemo = value;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'locationName': locationName,
    'xMm': xMm,
    'yMm': yMm,
    'handrailIds': handrailIds,
    'handrailNumber': handrailNumber,
    'positionCustomized': positionCustomized,
    'beforeMemo': beforeMemo,
    'afterMemo': afterMemo,
    'beforePhoto': beforePhoto?.toJson(),
    'afterPhoto': afterPhoto?.toJson(),
  };

  factory RenovationPhotoLocation.fromJson(
    Map<String, dynamic> json,
  ) => RenovationPhotoLocation(
    id: json['id'] as String? ?? '',
    locationName: json['locationName'] as String? ?? '',
    xMm: (json['xMm'] as num).round(),
    yMm: (json['yMm'] as num).round(),
    handrailIds: ((json['handrailIds'] as List<dynamic>?) ?? const [])
        .whereType<String>()
        .toList(),
    handrailNumber: json['handrailNumber'] as String? ?? '',
    positionCustomized: json['positionCustomized'] as bool? ?? false,
    beforeMemo: json['beforeMemo'] as String? ?? '',
    afterMemo: json['afterMemo'] as String? ?? '',
    beforePhoto: switch (json['beforePhoto']) {
      final Map<String, dynamic> value => CapturedProjectPhoto.fromJson(value),
      _ => null,
    },
    afterPhoto: switch (json['afterPhoto']) {
      final Map<String, dynamic> value => CapturedProjectPhoto.fromJson(value),
      _ => null,
    },
  );
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
    List<RenovationPhotoLocation>? photoLocations,
    List<SharedWallSegment>? sharedWallOverrides,
  }) : documents = documents ?? ProjectDocuments(),
       photoLocations = photoLocations ?? [],
       sharedWallOverrides = sharedWallOverrides ?? [];

  String id;
  CustomerInfo customer;
  List<PlanObject> objects;
  List<WorkLine> lines;
  DateTime updatedAt;
  int canvasWidthMm;
  int canvasHeightMm;
  ProjectDocuments documents;
  List<RenovationPhotoLocation> photoLocations;
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
    'photos': photoLocations.map((item) => item.toJson()).toList(),
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
    final drawing = json['drawing'] as Map<String, dynamic>;
    final canvas = drawing['canvas'] as Map<String, dynamic>;
    final storedWidth = _canvasDimension(
      canvas['widthMm'],
      defaultCanvasWidthMm,
    );
    final storedHeight = _canvasDimension(
      canvas['heightMm'],
      defaultCanvasHeightMm,
    );
    return RenovationProject(
      id: json['id'] as String,
      customer: CustomerInfo.fromJson(
        json['basicInfo'] as Map<String, dynamic>,
      ),
      objects: (drawing['objects'] as List<dynamic>)
          .map((item) => PlanObject.fromJson(item as Map<String, dynamic>))
          .toList(),
      lines: (drawing['handrails'] as List<dynamic>)
          .map((item) => WorkLine.fromJson(item as Map<String, dynamic>))
          .toList(),
      canvasWidthMm: storedWidth,
      canvasHeightMm: storedHeight,
      sharedWallOverrides: (drawing['sharedWalls'] as List<dynamic>)
          .map(
            (item) => SharedWallSegment.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      documents: ProjectDocuments.fromJson(
        json['documents'] as Map<String, dynamic>,
      ),
      photoLocations: (json['photos'] as List<dynamic>)
          .map(
            (item) =>
                RenovationPhotoLocation.fromJson(item as Map<String, dynamic>),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
    );
  }
}

enum JointProductType {
  endBracket,
  intermediateBracket,
  lShapeConnection,
  twoDimensionalConnection,
  threeDimensionalConnection,
}

extension JointProductTypeLabel on JointProductType {
  String get label => switch (this) {
    JointProductType.endBracket => '端部ブラケット',
    JointProductType.intermediateBracket => '中受ブラケット',
    JointProductType.lShapeConnection => 'L字接続ジョイント',
    JointProductType.twoDimensionalConnection => '2次元接続ジョイント',
    JointProductType.threeDimensionalConnection => '3次元接続ジョイント',
  };

  String get groupLabel => switch (this) {
    JointProductType.endBracket => '端部ブラケット',
    JointProductType.intermediateBracket => '中受ブラケット',
    JointProductType.lShapeConnection ||
    JointProductType.twoDimensionalConnection ||
    JointProductType.threeDimensionalConnection => '接続ジョイント',
  };

  String get shortLabel => switch (this) {
    JointProductType.endBracket => '端部',
    JointProductType.intermediateBracket => '中受',
    JointProductType.lShapeConnection => 'L字',
    JointProductType.twoDimensionalConnection => '2次元',
    JointProductType.threeDimensionalConnection => '3次元',
  };

  int get sortOrder => switch (this) {
    JointProductType.endBracket => 0,
    JointProductType.intermediateBracket => 1,
    JointProductType.lShapeConnection => 2,
    JointProductType.twoDimensionalConnection => 3,
    JointProductType.threeDimensionalConnection => 4,
  };

  bool get isConnection => switch (this) {
    JointProductType.endBracket ||
    JointProductType.intermediateBracket => false,
    JointProductType.lShapeConnection ||
    JointProductType.twoDimensionalConnection ||
    JointProductType.threeDimensionalConnection => true,
  };
}

class JointProduct {
  JointProduct({
    required this.id,
    required this.name,
    required this.type,
    required this.unitPrice,
  });

  String id;
  String name;
  JointProductType type;
  int unitPrice;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'unitPrice': unitPrice,
  };

  factory JointProduct.fromJson(Map<String, dynamic> json) => JointProduct(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    type: JointProductType.values.firstWhere(
      (type) => type.name == json['type'],
      orElse: () => JointProductType.endBracket,
    ),
    unitPrice: (json['unitPrice'] as num?)?.round() ?? 0,
  );
}

class HandrailProduct {
  HandrailProduct({
    required this.id,
    required this.name,
    required this.environmentTags,
    required this.diameterMm,
    required this.railPricePerMeter,
    required this.postPrice,
    required this.maxJointIntervalMm,
    this.defaultEndBracketId,
    this.defaultIntermediateBracketId,
    this.defaultLJointId,
  });

  String id;
  String name;
  Set<HandrailEnvironment> environmentTags;
  int diameterMm;
  int railPricePerMeter;
  int postPrice;
  int maxJointIntervalMm;
  String? defaultEndBracketId;
  String? defaultIntermediateBracketId;
  String? defaultLJointId;

  bool supports(HandrailEnvironment environment) =>
      environmentTags.contains(environment);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'environmentTags': environmentTags.map((tag) => tag.name).toList(),
    'diameterMm': diameterMm,
    'railPricePerMeter': railPricePerMeter,
    'postPrice': postPrice,
    'maxJointIntervalMm': maxJointIntervalMm,
    'defaultEndBracketId': defaultEndBracketId,
    'defaultIntermediateBracketId': defaultIntermediateBracketId,
    'defaultLJointId': defaultLJointId,
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
        postPrice: (json['postPrice'] as num?)?.round() ?? 0,
        maxJointIntervalMm:
            (json['maxJointIntervalMm'] as num?)?.round() ?? 1000,
        defaultEndBracketId: json['defaultEndBracketId'] as String?,
        defaultIntermediateBracketId:
            json['defaultIntermediateBracketId'] as String?,
        defaultLJointId: json['defaultLJointId'] as String?,
      );
}

enum FixtureType {
  toilet,
  diningTable,
  kitchen,
  refrigerator,
  wardrobe,
  bathtub,
}

extension FixtureTypeDetails on FixtureType {
  String get label => switch (this) {
    FixtureType.toilet => 'トイレ',
    FixtureType.diningTable => 'ダイニングテーブル',
    FixtureType.kitchen => 'キッチン',
    FixtureType.refrigerator => '冷蔵庫',
    FixtureType.wardrobe => 'タンス',
    FixtureType.bathtub => '浴槽',
  };

  String get menuLabel => switch (this) {
    FixtureType.diningTable => 'テーブル',
    _ => label,
  };

  int get defaultWidthMm => switch (this) {
    FixtureType.toilet => 500,
    FixtureType.diningTable => 1500,
    FixtureType.kitchen => 2500,
    FixtureType.refrigerator => 750,
    FixtureType.wardrobe => 2000,
    FixtureType.bathtub => 1500,
  };

  int get defaultHeightMm => switch (this) {
    FixtureType.toilet => 1000,
    FixtureType.diningTable => 1250,
    FixtureType.kitchen => 750,
    FixtureType.refrigerator => 1000,
    FixtureType.wardrobe => 1000,
    FixtureType.bathtub => 750,
  };

  static FixtureType? fromName(String? value) =>
      FixtureType.values.where((type) => type.name == value).firstOrNull;
}

enum PlanObjectKind { layout, fixture, door }

extension PlanObjectKindLabel on PlanObjectKind {
  String get label => switch (this) {
    PlanObjectKind.layout => '間取り',
    PlanObjectKind.fixture => '設備',
    PlanObjectKind.door => 'ドア',
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

  FixtureType? get fixtureType => FixtureTypeDetails.fromName(fixture);

  bool get isWallAttached => kind == PlanObjectKind.door;

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
      orElse: () => throw FormatException(
        'Unsupported plan object kind: ${json['kind']}',
      ),
    ),
    place: json['place'] as String? ?? '',
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
    this.manualIntermediatePointCount,
    Map<String, String>? connectionProductOverrides,
    Map<String, int>? reinforcementPlatePrices,
  }) : connectionProductOverrides = connectionProductOverrides ?? {},
       reinforcementPlatePrices = reinforcementPlatePrices ?? {};

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
  int? manualIntermediatePointCount;
  Map<String, String> connectionProductOverrides;
  Map<String, int> reinforcementPlatePrices;

  bool get isHorizontal => y1Mm == y2Mm;
  bool get isVertical => x1Mm == x2Mm;
  int get lengthMm {
    final dx = x2Mm - x1Mm;
    final dy = y2Mm - y1Mm;
    return math.sqrt(dx * dx + dy * dy).round();
  }

  HandrailOrientation get orientation => isHorizontal
      ? HandrailOrientation.horizontal
      : isVertical
      ? HandrailOrientation.vertical
      : HandrailOrientation.diagonal;

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
    'manualIntermediatePointCount': manualIntermediatePointCount,
    'connectionProductOverrides': connectionProductOverrides,
    'reinforcementPlatePrices': reinforcementPlatePrices,
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
    manualIntermediatePointCount: (json['manualIntermediatePointCount'] as num?)
        ?.round(),
    connectionProductOverrides:
        ((json['connectionProductOverrides'] as Map<String, dynamic>?) ?? {})
            .map((key, value) => MapEntry(key, value as String)),
    reinforcementPlatePrices:
        ((json['reinforcementPlatePrices'] as Map<String, dynamic>?) ?? {}).map(
          (key, value) => MapEntry(key, (value as num).round()),
        ),
  );
}

class HandrailPoint {
  const HandrailPoint(this.xMm, this.yMm);

  final int xMm;
  final int yMm;
}

enum HandrailConnectionKind { endBracket, intermediateBracket, connectionJoint }

extension HandrailConnectionKindLabel on HandrailConnectionKind {
  String get label => switch (this) {
    HandrailConnectionKind.endBracket => '端部ブラケット',
    HandrailConnectionKind.intermediateBracket => '中受ブラケット',
    HandrailConnectionKind.connectionJoint => '接続ジョイント',
  };

  bool accepts(JointProductType type) => switch (this) {
    HandrailConnectionKind.endBracket => type == JointProductType.endBracket,
    HandrailConnectionKind.intermediateBracket =>
      type == JointProductType.intermediateBracket,
    HandrailConnectionKind.connectionJoint => type.isConnection,
  };
}

class HandrailConnectionReference {
  const HandrailConnectionReference({
    required this.lineId,
    required this.pointKey,
  });

  final String lineId;
  final String pointKey;
}

class HandrailConnectionPoint {
  const HandrailConnectionPoint({
    required this.id,
    required this.point,
    required this.kind,
    required this.jointProduct,
    required this.references,
    required this.angleRadians,
    required this.freestanding,
    required this.postPrice,
    required this.hasReinforcementPlate,
    required this.reinforcementPlatePrice,
  });

  final String id;
  final HandrailPoint point;
  final HandrailConnectionKind kind;
  final JointProduct? jointProduct;
  final List<HandrailConnectionReference> references;
  final double angleRadians;
  final bool freestanding;
  final int postPrice;
  final bool hasReinforcementPlate;
  final int reinforcementPlatePrice;

  JointProductType get displayType =>
      jointProduct?.type ??
      switch (kind) {
        HandrailConnectionKind.endBracket => JointProductType.endBracket,
        HandrailConnectionKind.intermediateBracket =>
          JointProductType.intermediateBracket,
        HandrailConnectionKind.connectionJoint =>
          JointProductType.lShapeConnection,
      };
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
    return HandrailOrientation.diagonal;
  }
}

class HandrailEstimateGroup {
  const HandrailEstimateGroup(this.lines);

  final List<WorkLine> lines;

  WorkLine get primary => lines.first;
  String get id => primary.id;
  int get lengthMm => lines.fold(0, (total, line) => total + line.lengthMm);
  bool get isConnected => lines.length > 1;
  bool get hasDirectionChange => lines.indexed.any((entry) {
    final (index, line) = entry;
    final dx = line.x2Mm - line.x1Mm;
    final dy = line.y2Mm - line.y1Mm;
    return lines.skip(index + 1).any((other) {
      final otherDx = other.x2Mm - other.x1Mm;
      final otherDy = other.y2Mm - other.y1Mm;
      return dx * otherDy - dy * otherDx != 0;
    });
  });

  bool get hasOnlyRightAngleChanges {
    var foundChange = false;
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final dx = line.x2Mm - line.x1Mm;
      final dy = line.y2Mm - line.y1Mm;
      for (final other in lines.skip(index + 1)) {
        final otherDx = other.x2Mm - other.x1Mm;
        final otherDy = other.y2Mm - other.y1Mm;
        if (dx * otherDy - dy * otherDx == 0) continue;
        foundChange = true;
        if (dx * otherDx + dy * otherDy != 0) return false;
      }
    }
    return foundChange;
  }

  String get shapeLabel => !hasDirectionChange
      ? ''
      : hasOnlyRightAngleChanges
      ? 'L字'
      : '角度付き';
}

class HandrailCostBreakdown {
  const HandrailCostBreakdown({
    required this.endBracketCount,
    required this.intermediateBracketCount,
    required this.connectionJointCount,
    required this.postCount,
    required this.railCost,
    required this.endBracketCost,
    required this.intermediateBracketCost,
    required this.connectionJointCost,
    required this.postCost,
    required this.reinforcementPlateCount,
    required this.reinforcementPlateCost,
  });

  final int endBracketCount;
  final int intermediateBracketCount;
  final int connectionJointCount;
  final int postCount;
  final int railCost;
  final int endBracketCost;
  final int intermediateBracketCost;
  final int connectionJointCost;
  final int postCost;
  final int reinforcementPlateCount;
  final int reinforcementPlateCost;

  int get jointCount =>
      endBracketCount + intermediateBracketCount + connectionJointCount;
  int get jointCost =>
      endBracketCost + intermediateBracketCost + connectionJointCost;
  int get total => railCost + jointCost + postCost + reinforcementPlateCost;
}

List<JointProduct> defaultJointProducts() => [
  JointProduct(
    id: 'EB-35-WH',
    name: '樹脂被覆端部ブラケット',
    type: JointProductType.endBracket,
    unitPrice: 1250,
  ),
  JointProduct(
    id: 'EB-35-BR',
    name: '木製手すり用端部ブラケット',
    type: JointProductType.endBracket,
    unitPrice: 1450,
  ),
  JointProduct(
    id: 'EB-34-OD',
    name: '屋外用端部ブラケット',
    type: JointProductType.endBracket,
    unitPrice: 1800,
  ),
  JointProduct(
    id: 'MB-35-WH',
    name: '樹脂被覆中受ブラケット',
    type: JointProductType.intermediateBracket,
    unitPrice: 1250,
  ),
  JointProduct(
    id: 'MB-35-BR',
    name: '木製手すり用中受ブラケット',
    type: JointProductType.intermediateBracket,
    unitPrice: 1450,
  ),
  JointProduct(
    id: 'MB-34-OD',
    name: '屋外用中受ブラケット',
    type: JointProductType.intermediateBracket,
    unitPrice: 1800,
  ),
  JointProduct(
    id: 'CJ-L-35',
    name: 'L字接続ジョイント',
    type: JointProductType.lShapeConnection,
    unitPrice: 1250,
  ),
  JointProduct(
    id: 'CJ-2D-35',
    name: '2次元自在ジョイント',
    type: JointProductType.twoDimensionalConnection,
    unitPrice: 2200,
  ),
  JointProduct(
    id: 'CJ-3D-35',
    name: '3次元自在ジョイント',
    type: JointProductType.threeDimensionalConnection,
    unitPrice: 2800,
  ),
];

List<HandrailProduct> defaultHandrailProducts() => [
  HandrailProduct(
    id: 'demo-indoor-35',
    name: '室内用木製手すり φ35',
    environmentTags: {HandrailEnvironment.indoor},
    diameterMm: 35,
    railPricePerMeter: 4400,
    postPrice: 3800,
    maxJointIntervalMm: 1000,
    defaultEndBracketId: 'EB-35-WH',
    defaultIntermediateBracketId: 'MB-35-WH',
    defaultLJointId: 'CJ-L-35',
  ),
  HandrailProduct(
    id: 'demo-outdoor-34',
    name: '屋外用アルミ手すり φ34',
    environmentTags: {HandrailEnvironment.outdoor},
    diameterMm: 34,
    railPricePerMeter: 7200,
    postPrice: 6500,
    maxJointIntervalMm: 1000,
    defaultEndBracketId: 'EB-34-OD',
    defaultIntermediateBracketId: 'MB-34-OD',
    defaultLJointId: 'CJ-L-35',
  ),
];
