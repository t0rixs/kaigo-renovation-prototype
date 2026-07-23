import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as image;
import 'package:xml/xml.dart';

import 'document_export_data.dart';

class KaigoEstimateTemplateWriter {
  static const _photoSheetName = '写真貼付台紙';
  static const _photoRowsPerLocation = 54;
  static const _templatePhotoLocations = 10;

  static const targetSheetNames = [
    '基本情報',
    '原価',
    '原価内訳書',
    'お客様提示用見積書表紙',
    'お客様提示用内訳書',
    _photoSheetName,
  ];

  static const _targetRelationshipIds = {
    'rId1',
    'rId2',
    'rId3',
    'rId5',
    'rId6',
    'rId7',
  };

  Uint8List build(Uint8List templateBytes, DocumentExportData data) {
    if (data.lines.length > 38) {
      throw StateError('原価内訳書に出力できる手すりは38件までです');
    }
    final archive = ZipDecoder().decodeBytes(templateBytes);
    final photoPageCount = data.photos.isEmpty ? 1 : data.photos.length;
    _writeWorkbook(archive, photoPageCount: photoPageCount);
    _writeAppProperties(archive);

    final basicInfo = _xmlFile(archive, 'xl/worksheets/sheet1.xml');
    final cost = _xmlFile(archive, 'xl/worksheets/sheet2.xml');
    final costDetails = _xmlFile(archive, 'xl/worksheets/sheet3.xml');
    final quoteCover = _xmlFile(archive, 'xl/worksheets/sheet5.xml');
    final quoteDetails = _xmlFile(archive, 'xl/worksheets/sheet6.xml');
    final photos = _xmlFile(archive, 'xl/worksheets/sheet7.xml');

    for (final document in [
      basicInfo,
      cost,
      costDetails,
      quoteCover,
      quoteDetails,
      photos,
    ]) {
      _removeFormulas(document);
    }

    _populateBasicInfo(basicInfo, data);
    _populateCost(cost, data);
    _populateCostDetails(costDetails, data);
    _populateQuoteCover(quoteCover, data);
    _populateQuoteDetails(quoteDetails, data);
    final photoMemoStyle = _createPhotoMemoStyle(archive);
    _populatePhotos(
      photos,
      data,
      photoPageCount: photoPageCount,
      memoStyle: photoMemoStyle,
    );
    _writePhotoDrawings(archive, data.photos);

    _replaceXmlFile(archive, 'xl/worksheets/sheet1.xml', basicInfo);
    _replaceXmlFile(archive, 'xl/worksheets/sheet2.xml', cost);
    _replaceXmlFile(archive, 'xl/worksheets/sheet3.xml', costDetails);
    _replaceXmlFile(archive, 'xl/worksheets/sheet5.xml', quoteCover);
    _replaceXmlFile(archive, 'xl/worksheets/sheet6.xml', quoteDetails);
    _replaceXmlFile(archive, 'xl/worksheets/sheet7.xml', photos);

    return ZipEncoder().encodeBytes(archive);
  }

  void _populateBasicInfo(XmlDocument sheet, DocumentExportData data) {
    _setText(sheet, 'B3', data.customerName);
    _setText(sheet, 'B4', data.customerKana);
    _setText(sheet, 'B5', data.customerAddress);
    _setText(sheet, 'B6', data.customerPhone);
    _setText(sheet, 'B7', data.insuredNumber);
    _setText(sheet, 'B8', _displayDate(data.surveyDate));

    final birthday = _japaneseDate(data.birthDate);
    _setText(sheet, 'B9', birthday.era);
    _setText(sheet, 'C9', birthday.year);
    _setText(sheet, 'E9', birthday.month);
    _setText(sheet, 'G9', birthday.day);
  }

  void _populateCost(XmlDocument sheet, DocumentExportData data) {
    _clearRange(sheet, 'B9', 'H19');
    _setNumber(sheet, 'C2', data.materialTotal);
    _setText(sheet, 'C3', data.paymentTerms);
    _setText(sheet, 'C4', data.estimateValid);
    _setText(sheet, 'B9', data.costItemName);
    _setNumber(sheet, 'D9', 1);
    _setText(sheet, 'E9', '式');
    _setNumber(sheet, 'F9', data.materialSubtotal);
    _setNumber(sheet, 'G9', data.materialSubtotal);
    _setNumber(sheet, 'K16', data.materialSubtotal);
    _setNumber(sheet, 'K17', 0.1);
    _setNumber(sheet, 'K18', data.materialTax);
    _setNumber(sheet, 'K19', data.materialTotal);
    _configurePrintLayout(sheet, fitToHeight: 1);
  }

  void _populateCostDetails(XmlDocument sheet, DocumentExportData data) {
    _setText(sheet, 'A3', data.customerName);
    _setText(sheet, 'D4', data.insuredNumber);
    _setText(sheet, 'B5', data.constructionPlace);
    _clearRange(sheet, 'A9', 'N84');

    for (var index = 0; index < data.lines.length; index++) {
      final row = index + 9;
      final line = data.lines[index];
      _setText(sheet, 'A$row', line.workContent);
      _setText(sheet, 'B$row', line.location);
      _setText(sheet, 'C$row', line.productId);
      _setText(sheet, 'D$row', line.specification);
      _setNumber(sheet, 'E$row', line.quantity);
      _setText(sheet, 'F$row', line.unit);
      _setNumber(sheet, 'G$row', line.costUnitPrice);
      _setNumber(sheet, 'H$row', line.costAmount);
      _setText(sheet, 'N$row', line.remarks);
    }

    _setNumber(sheet, 'H85', data.materialSubtotal);
    _setNumber(sheet, 'L85', 0);
    _setNumber(sheet, 'H86', 0);
    _setNumber(sheet, 'L86', 0);
    _setNumber(sheet, 'H87', data.materialTax);
    _setNumber(sheet, 'L87', 0);
    _setNumber(sheet, 'H88', data.materialTotal);
    _setNumber(sheet, 'L88', 0);
    _compactDetailPrintLayout(
      sheet,
      firstUnusedRow: 9 + data.lines.length,
      lastDetailRow: 84,
    );
  }

  void _populateQuoteCover(XmlDocument sheet, DocumentExportData data) {
    _setText(sheet, 'K1', _japaneseExportDate(data.exportedAt));
    _setText(sheet, 'A7', data.customerName);
    _setNumber(sheet, 'D14', data.coverQuoteAmount);
    _setText(sheet, 'D19', data.projectName);
    _setText(sheet, 'G19', '');
    _setText(sheet, 'D21', data.constructionPlace);
    _setText(sheet, 'D25', data.estimateValid);
    _setText(sheet, 'D27', data.paymentTerms);
    _configurePrintLayout(sheet, fitToHeight: 1);
  }

  void _populateQuoteDetails(XmlDocument sheet, DocumentExportData data) {
    _setText(sheet, 'M1', _slashDate(data.exportedAt));
    _setNumber(sheet, 'Q3', data.grossMarginPercent);
    _setText(sheet, 'A3', data.customerName);
    _setText(sheet, 'D4', data.insuredNumber);
    _setText(sheet, 'B5', data.constructionPlace);
    _clearRange(sheet, 'A9', 'O46');

    for (var index = 0; index < data.lines.length; index++) {
      final row = index + 9;
      final line = data.lines[index];
      _setText(sheet, 'A$row', line.workContent);
      _setText(sheet, 'B$row', line.location);
      _setText(sheet, 'C$row', line.productId);
      _setText(sheet, 'D$row', line.specification);
      _setNumber(sheet, 'E$row', line.quantity);
      _setText(sheet, 'F$row', line.unit);
      _setNumber(sheet, 'G$row', line.customerUnitPrice);
      _setNumber(sheet, 'H$row', line.customerAmount);
      _setText(sheet, 'N$row', line.remarks);
      _setNumber(sheet, 'O$row', data.grossMarginPercent / 100);
    }

    _setNumber(sheet, 'H47', data.quoteSubtotal);
    _setNumber(sheet, 'L47', 0);
    _setNumber(sheet, 'H48', 0);
    _setNumber(sheet, 'L48', 0);
    _setNumber(sheet, 'H49', data.quoteTax);
    _setNumber(sheet, 'L49', 0);
    _setNumber(sheet, 'M49', 0);
    _setNumber(sheet, 'H50', data.quoteTotal);
    _setNumber(sheet, 'L50', 0);
    _setNumber(sheet, 'M50', 0);
    _setNumber(sheet, 'O50', data.grossMarginPercent / 100);
    _compactDetailPrintLayout(
      sheet,
      firstUnusedRow: 9 + data.lines.length,
      lastDetailRow: 46,
    );
  }

  void _populatePhotos(
    XmlDocument sheet,
    DocumentExportData data, {
    required int photoPageCount,
    required int memoStyle,
  }) {
    _ensurePhotoTemplatePages(sheet, photoPageCount);
    for (var index = 0; index < photoPageCount; index++) {
      final rowOffset = index * _photoRowsPerLocation;
      final photo = index < data.photos.length ? data.photos[index] : null;
      _setText(sheet, 'C${rowOffset + 3}', data.customerName);
      _setText(sheet, 'H${rowOffset + 3}', data.insuredNumber);
      _setText(sheet, 'C${rowOffset + 4}', photo?.location ?? '');
      _setText(
        sheet,
        'H${rowOffset + 4}',
        photo == null ? '' : _photoNumber(photo.number),
      );
      _setText(sheet, 'C${rowOffset + 6}', '');
      _setText(sheet, 'A${rowOffset + 9}', photo?.beforeMemo ?? '');
      _setText(sheet, 'A${rowOffset + 32}', photo?.afterMemo ?? '');
      _setAttribute(_cell(sheet, 'A${rowOffset + 9}'), 's', '$memoStyle');
      _setAttribute(_cell(sheet, 'A${rowOffset + 32}'), 's', '$memoStyle');
      _ensureMergedRange(sheet, 'A${rowOffset + 9}:B${rowOffset + 30}');
      _ensureMergedRange(sheet, 'A${rowOffset + 32}:B${rowOffset + 53}');
    }

    _configurePhotoPrintLayout(sheet, photoPageCount);
  }

  void _ensurePhotoTemplatePages(XmlDocument sheet, int pageCount) {
    if (pageCount <= _templatePhotoLocations) return;
    final sheetData = sheet.findAllElements('sheetData').first;
    final sourceStartRow =
        (_templatePhotoLocations - 1) * _photoRowsPerLocation + 1;
    final sourceEndRow = _templatePhotoLocations * _photoRowsPerLocation;
    final sourceRows = sheetData.findElements('row').where((row) {
      final rowNumber = int.tryParse(row.getAttribute('r') ?? '');
      return rowNumber != null &&
          rowNumber >= sourceStartRow &&
          rowNumber <= sourceEndRow;
    }).toList();
    final sourceMerges = sheet
        .findAllElements('mergeCell')
        .map((cell) => cell.getAttribute('ref'))
        .whereType<String>()
        .where((reference) {
          final match = RegExp(
            r'^([A-Z]+)(\d+):([A-Z]+)(\d+)$',
          ).firstMatch(reference);
          if (match == null) return false;
          final startRow = int.parse(match.group(2)!);
          final endRow = int.parse(match.group(4)!);
          return startRow >= sourceStartRow && endRow <= sourceEndRow;
        })
        .toList();

    for (
      var pageIndex = _templatePhotoLocations;
      pageIndex < pageCount;
      pageIndex++
    ) {
      final rowShift =
          (pageIndex - (_templatePhotoLocations - 1)) * _photoRowsPerLocation;
      for (final sourceRow in sourceRows) {
        final clone = sourceRow.copy();
        final sourceRowNumber = int.parse(sourceRow.getAttribute('r')!);
        _setAttribute(clone, 'r', '${sourceRowNumber + rowShift}');
        for (final cell in clone.findAllElements('c')) {
          final reference = cell.getAttribute('r');
          if (reference == null) continue;
          _setAttribute(cell, 'r', _shiftCellRow(reference, rowShift));
        }
        sheetData.children.add(clone);
      }
      for (final reference in sourceMerges) {
        _ensureMergedRange(sheet, _shiftRangeRows(reference, rowShift));
      }
    }

    final dimension = sheet.findAllElements('dimension').firstOrNull;
    if (dimension != null) {
      _setAttribute(
        dimension,
        'ref',
        'A1:IQ${pageCount * _photoRowsPerLocation}',
      );
    }
  }

  String _shiftRangeRows(String reference, int rowShift) {
    final match = RegExp(
      r'^([A-Z]+)(\d+):([A-Z]+)(\d+)$',
    ).firstMatch(reference);
    if (match == null) return reference;
    return '${match.group(1)}${int.parse(match.group(2)!) + rowShift}:'
        '${match.group(3)}${int.parse(match.group(4)!) + rowShift}';
  }

  String _shiftCellRow(String reference, int rowShift) {
    final match = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(reference);
    if (match == null) return reference;
    return '${match.group(1)}${int.parse(match.group(2)!) + rowShift}';
  }

  String _photoNumber(String value) {
    final number = int.tryParse(value);
    if (number != null && number >= 1 && number <= 20) {
      return String.fromCharCode(0x2460 + number - 1);
    }
    return value;
  }

  void _compactDetailPrintLayout(
    XmlDocument sheet, {
    required int firstUnusedRow,
    required int lastDetailRow,
  }) {
    for (final row in sheet.findAllElements('row')) {
      final rowNumber = int.tryParse(row.getAttribute('r') ?? '');
      if (rowNumber == null ||
          rowNumber < firstUnusedRow ||
          rowNumber > lastDetailRow) {
        continue;
      }
      _setAttribute(row, 'hidden', '1');
    }

    _configurePrintLayout(sheet, fitToHeight: 0);
  }

  void _configurePhotoPrintLayout(XmlDocument sheet, int pageCount) {
    final sheetProperties = sheet.findAllElements('sheetPr').firstOrNull;
    if (sheetProperties != null) {
      for (final pageSetupProperties
          in sheetProperties.findElements('pageSetUpPr').toList()) {
        sheetProperties.children.remove(pageSetupProperties);
      }
    }

    final pageSetup = sheet.findAllElements('pageSetup').firstOrNull;
    if (pageSetup != null) {
      pageSetup.attributes.removeWhere(
        (attribute) =>
            const {'fitToWidth', 'fitToHeight'}.contains(attribute.name.local),
      );
      _setAttribute(pageSetup, 'scale', '90');
    }

    for (final breaks in [
      ...sheet.findAllElements('rowBreaks'),
      ...sheet.findAllElements('colBreaks'),
    ]) {
      breaks.parent?.children.remove(breaks);
    }

    if (pageCount <= 1) return;
    final drawing = sheet.findAllElements('drawing').firstOrNull;
    final parent = drawing?.parent;
    if (drawing == null || parent == null) return;
    final rowBreaks = XmlElement(
      XmlName('rowBreaks'),
      [
        XmlAttribute(XmlName('count'), '${pageCount - 1}'),
        XmlAttribute(XmlName('manualBreakCount'), '${pageCount - 1}'),
      ],
      [
        for (var index = 1; index < pageCount; index++)
          XmlElement(XmlName('brk'), [
            XmlAttribute(XmlName('id'), '${index * _photoRowsPerLocation}'),
            XmlAttribute(XmlName('max'), '8'),
            XmlAttribute(XmlName('man'), '1'),
          ]),
      ],
    );
    parent.children.insert(parent.children.indexOf(drawing), rowBreaks);
  }

  void _configurePrintLayout(XmlDocument sheet, {required int fitToHeight}) {
    final sheetProperties = sheet.findAllElements('sheetPr').firstOrNull;
    if (sheetProperties != null) {
      var pageSetupProperties = sheetProperties
          .findElements('pageSetUpPr')
          .firstOrNull;
      if (pageSetupProperties == null) {
        pageSetupProperties = XmlElement(XmlName('pageSetUpPr'));
        sheetProperties.children.add(pageSetupProperties);
      }
      _setAttribute(pageSetupProperties, 'fitToPage', '1');
    }

    final pageSetup = sheet.findAllElements('pageSetup').firstOrNull;
    if (pageSetup != null) {
      pageSetup.attributes.removeWhere(
        (attribute) => attribute.name.local == 'scale',
      );
      _setAttribute(pageSetup, 'fitToWidth', '1');
      _setAttribute(pageSetup, 'fitToHeight', '$fitToHeight');
    }

    for (final breaks in [
      ...sheet.findAllElements('rowBreaks'),
      ...sheet.findAllElements('colBreaks'),
    ]) {
      breaks.parent?.children.remove(breaks);
    }
  }

  void _writeWorkbook(Archive archive, {required int photoPageCount}) {
    final workbook = _xmlFile(archive, 'xl/workbook.xml');
    final sheets = workbook.findAllElements('sheet').toList();
    for (final sheet in sheets) {
      if (!targetSheetNames.contains(sheet.getAttribute('name'))) {
        sheet.parent?.children.remove(sheet);
      }
    }

    for (final externalReferences
        in workbook.findAllElements('externalReferences').toList()) {
      externalReferences.parent?.children.remove(externalReferences);
    }

    const localSheetIdMap = {0: 0, 1: 1, 2: 2, 4: 3, 5: 4, 6: 5};
    for (final definedName
        in workbook.findAllElements('definedName').toList()) {
      final name = definedName.getAttribute('name') ?? '';
      final localSheetId = int.tryParse(
        definedName.getAttribute('localSheetId') ?? '',
      );
      final mappedId = localSheetId == null
          ? null
          : localSheetIdMap[localSheetId];
      if (!name.startsWith('_xlnm.Print_') || mappedId == null) {
        definedName.parent?.children.remove(definedName);
      } else {
        _setAttribute(definedName, 'localSheetId', '$mappedId');
        if (localSheetId == 6 && name == '_xlnm.Print_Area') {
          _replaceText(
            definedName,
            "'$_photoSheetName'!\$A\$1:\$I\$${photoPageCount * _photoRowsPerLocation}",
          );
        }
      }
    }
    _replaceXmlFile(archive, 'xl/workbook.xml', workbook);

    final relationships = _xmlFile(archive, 'xl/_rels/workbook.xml.rels');
    for (final relationship
        in relationships.findAllElements('Relationship').toList()) {
      final type = relationship.getAttribute('Type') ?? '';
      final id = relationship.getAttribute('Id') ?? '';
      final removeWorksheet =
          type.endsWith('/worksheet') && !_targetRelationshipIds.contains(id);
      if (removeWorksheet ||
          type.endsWith('/externalLink') ||
          type.endsWith('/calcChain')) {
        relationship.parent?.children.remove(relationship);
      }
    }
    _replaceXmlFile(archive, 'xl/_rels/workbook.xml.rels', relationships);
  }

  void _writeAppProperties(Archive archive) {
    final properties = _xmlFile(archive, 'docProps/app.xml');
    final counts = properties.findAllElements('i4').toList();
    if (counts.length >= 2) {
      _replaceText(counts[0], '${targetSheetNames.length}');
      _replaceText(counts[1], '7');
    }
    final titles = properties
        .findAllElements('TitlesOfParts')
        .firstOrNull
        ?.findElements('vector')
        .firstOrNull;
    if (titles != null) {
      const values = [
        ...targetSheetNames,
        'お客様提示用見積書表紙!Print_Area',
        'お客様提示用内訳書!Print_Area',
        '原価!Print_Area',
        '原価内訳書!Print_Area',
        '写真貼付台紙!Print_Area',
        'お客様提示用内訳書!Print_Titles',
        '原価内訳書!Print_Titles',
      ];
      _setAttribute(titles, 'size', '${values.length}');
      titles.children.clear();
      titles.children.addAll(
        values.map(
          (value) =>
              XmlElement(XmlName('lpstr', 'vt'), const [], [XmlText(value)]),
        ),
      );
    }
    _replaceXmlFile(archive, 'docProps/app.xml', properties);
  }

  int _createPhotoMemoStyle(Archive archive) {
    final styles = _xmlFile(archive, 'xl/styles.xml');
    final cellFormats = styles.findAllElements('cellXfs').first;
    final source = cellFormats.findElements('xf').elementAt(126);
    final attributes =
        source.attributes
            .where((attribute) => attribute.name.local != 'applyAlignment')
            .map(
              (attribute) => XmlAttribute(
                XmlName(attribute.name.local, attribute.name.prefix),
                attribute.value,
              ),
            )
            .toList()
          ..add(XmlAttribute(XmlName('applyAlignment'), '1'));
    final memoFormat = XmlElement(XmlName('xf'), attributes, [
      XmlElement(XmlName('alignment'), [
        XmlAttribute(XmlName('horizontal'), 'left'),
        XmlAttribute(XmlName('vertical'), 'top'),
        XmlAttribute(XmlName('wrapText'), '1'),
      ]),
    ]);
    final styleIndex = cellFormats.findElements('xf').length;
    cellFormats.children.add(memoFormat);
    _setAttribute(cellFormats, 'count', '${styleIndex + 1}');
    _replaceXmlFile(archive, 'xl/styles.xml', styles);
    return styleIndex;
  }

  void _ensureMergedRange(XmlDocument sheet, String reference) {
    final mergedCells = sheet.findAllElements('mergeCells').first;
    if (mergedCells
        .findElements('mergeCell')
        .any((cell) => cell.getAttribute('ref') == reference)) {
      return;
    }
    mergedCells.children.add(
      XmlElement(XmlName('mergeCell'), [
        XmlAttribute(XmlName('ref'), reference),
      ]),
    );
    _setAttribute(
      mergedCells,
      'count',
      '${mergedCells.findElements('mergeCell').length}',
    );
  }

  void _writePhotoDrawings(Archive archive, List<DocumentPhotoData> photos) {
    final pictures = <_PhotoPicture>[];
    for (var index = 0; index < photos.length; index++) {
      final rowOffset = index * _photoRowsPerLocation;
      for (final entry in [
        (
          photo: photos[index].beforePhoto,
          slot: 'before',
          fromRow: rowOffset + 8,
          toRow: rowOffset + 30,
        ),
        (
          photo: photos[index].afterPhoto,
          slot: 'after',
          fromRow: rowOffset + 31,
          toRow: rowOffset + 53,
        ),
      ]) {
        final photo = entry.photo;
        if (photo == null || photo.base64Data.isEmpty) continue;
        Uint8List sourceBytes;
        try {
          sourceBytes = base64Decode(photo.base64Data);
        } on FormatException {
          continue;
        }
        final bytes = _photoBytesForExcel(sourceBytes);
        if (bytes == null) continue;
        final relationshipId = 'rId${pictures.length + 1}';
        final mediaName = 'photo_${index + 1}_${entry.slot}.jpg';
        archive.addFile(ArchiveFile.bytes('xl/media/$mediaName', bytes));
        pictures.add(
          _PhotoPicture(
            relationshipId: relationshipId,
            mediaName: mediaName,
            name: '写真${index + 1}_${entry.slot}',
            fromRow: entry.fromRow,
            toRow: entry.toRow,
          ),
        );
      }
    }

    _replaceXmlFile(
      archive,
      'xl/drawings/drawing4.xml',
      _photoDrawingDocument(pictures),
    );
    _replaceXmlFile(
      archive,
      'xl/drawings/_rels/drawing4.xml.rels',
      _photoDrawingRelationships(pictures),
    );
    if (pictures.isNotEmpty) {
      _ensureContentType(archive, extension: 'jpg', contentType: 'image/jpeg');
    }
  }

  Uint8List? _photoBytesForExcel(Uint8List sourceBytes) {
    if (sourceBytes.isEmpty) return null;
    final source = image.decodeImage(sourceBytes);
    if (source == null) return null;
    const targetWidth = 1200;
    const targetHeight = 940;
    final scale = math.min(
      targetWidth / source.width,
      targetHeight / source.height,
    );
    final width = math.max(1, (source.width * scale).round());
    final height = math.max(1, (source.height * scale).round());
    final resized = image.copyResize(
      source,
      width: width,
      height: height,
      interpolation: image.Interpolation.average,
    );
    final canvas = image.Image(width: targetWidth, height: targetHeight);
    image.fill(canvas, color: image.ColorRgb8(255, 255, 255));
    image.compositeImage(
      canvas,
      resized,
      dstX: (targetWidth - width) ~/ 2,
      dstY: (targetHeight - height) ~/ 2,
    );
    return Uint8List.fromList(image.encodeJpg(canvas, quality: 88));
  }

  XmlDocument _photoDrawingDocument(List<_PhotoPicture> pictures) {
    final root = XmlElement(
      XmlName('wsDr', 'xdr'),
      [
        XmlAttribute(
          XmlName('xdr', 'xmlns'),
          'http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing',
        ),
        XmlAttribute(
          XmlName('a', 'xmlns'),
          'http://schemas.openxmlformats.org/drawingml/2006/main',
        ),
        XmlAttribute(
          XmlName('r', 'xmlns'),
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
        ),
      ],
      [
        for (var index = 0; index < pictures.length; index++)
          _photoPictureAnchor(pictures[index], id: index + 1),
      ],
    );
    return XmlDocument([
      XmlProcessing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"'),
      root,
    ]);
  }

  XmlElement _photoPictureAnchor(_PhotoPicture picture, {required int id}) {
    return XmlElement(
      XmlName('twoCellAnchor', 'xdr'),
      [XmlAttribute(XmlName('editAs'), 'oneCell')],
      [
        _drawingPosition('from', column: 2, row: picture.fromRow),
        _drawingPosition('to', column: 9, row: picture.toRow),
        XmlElement(XmlName('pic', 'xdr'), const [], [
          XmlElement(XmlName('nvPicPr', 'xdr'), const [], [
            XmlElement(XmlName('cNvPr', 'xdr'), [
              XmlAttribute(XmlName('id'), '$id'),
              XmlAttribute(XmlName('name'), picture.name),
            ]),
            XmlElement(XmlName('cNvPicPr', 'xdr'), const [], [
              XmlElement(XmlName('picLocks', 'a'), [
                XmlAttribute(XmlName('noChangeAspect'), '1'),
              ]),
            ]),
          ]),
          XmlElement(XmlName('blipFill', 'xdr'), const [], [
            XmlElement(XmlName('blip', 'a'), [
              XmlAttribute(XmlName('embed', 'r'), picture.relationshipId),
            ]),
            XmlElement(XmlName('stretch', 'a'), const [], [
              XmlElement(XmlName('fillRect', 'a')),
            ]),
          ]),
          XmlElement(XmlName('spPr', 'xdr'), const [], [
            XmlElement(
              XmlName('prstGeom', 'a'),
              [XmlAttribute(XmlName('prst'), 'rect')],
              [XmlElement(XmlName('avLst', 'a'))],
            ),
          ]),
        ]),
        XmlElement(XmlName('clientData', 'xdr')),
      ],
    );
  }

  XmlElement _drawingPosition(
    String name, {
    required int column,
    required int row,
  }) {
    XmlElement value(String name, int value) =>
        XmlElement(XmlName(name, 'xdr'), const [], [XmlText('$value')]);
    return XmlElement(XmlName(name, 'xdr'), const [], [
      value('col', column),
      value('colOff', 0),
      value('row', row),
      value('rowOff', 0),
    ]);
  }

  XmlDocument _photoDrawingRelationships(List<_PhotoPicture> pictures) {
    return XmlDocument([
      XmlProcessing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"'),
      XmlElement(
        XmlName('Relationships'),
        [
          XmlAttribute(
            XmlName('xmlns'),
            'http://schemas.openxmlformats.org/package/2006/relationships',
          ),
        ],
        [
          for (final picture in pictures)
            XmlElement(XmlName('Relationship'), [
              XmlAttribute(XmlName('Id'), picture.relationshipId),
              XmlAttribute(
                XmlName('Type'),
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image',
              ),
              XmlAttribute(XmlName('Target'), '../media/${picture.mediaName}'),
            ]),
        ],
      ),
    ]);
  }

  void _ensureContentType(
    Archive archive, {
    required String extension,
    required String contentType,
  }) {
    final types = _xmlFile(archive, '[Content_Types].xml');
    if (types
        .findAllElements('Default')
        .any((item) => item.getAttribute('Extension') == extension)) {
      return;
    }
    types.rootElement.children.insert(
      0,
      XmlElement(XmlName('Default'), [
        XmlAttribute(XmlName('Extension'), extension),
        XmlAttribute(XmlName('ContentType'), contentType),
      ]),
    );
    _replaceXmlFile(archive, '[Content_Types].xml', types);
  }

  XmlDocument _xmlFile(Archive archive, String path) {
    final file = archive.findFile(path);
    if (file == null) throw StateError('テンプレートに$pathがありません');
    return XmlDocument.parse(utf8.decode(file.content));
  }

  void _replaceXmlFile(Archive archive, String path, XmlDocument document) {
    final bytes = utf8.encode(document.toXmlString(pretty: false));
    archive.addFile(ArchiveFile.bytes(path, bytes));
  }

  void _removeFormulas(XmlDocument document) {
    for (final cell in document.findAllElements('c')) {
      if (cell.findElements('f').isNotEmpty) _clearCell(cell);
    }
  }

  void _clearRange(
    XmlDocument document,
    String startReference,
    String endReference,
  ) {
    final start = _cellPosition(startReference);
    final end = _cellPosition(endReference);
    for (final cell in document.findAllElements('c')) {
      final reference = cell.getAttribute('r');
      if (reference == null) continue;
      final position = _cellPosition(reference);
      if (position.column >= start.column &&
          position.column <= end.column &&
          position.row >= start.row &&
          position.row <= end.row) {
        _clearCell(cell);
      }
    }
  }

  void _setText(XmlDocument document, String reference, String value) {
    final cell = _cell(document, reference);
    _clearCell(cell);
    _setAttribute(cell, 't', 'inlineStr');
    final textAttributes = value.trim() == value
        ? const <XmlAttribute>[]
        : [XmlAttribute(XmlName('space', 'xml'), 'preserve')];
    cell.children.add(
      XmlElement(XmlName('is'), const [], [
        XmlElement(XmlName('t'), textAttributes, [XmlText(value)]),
      ]),
    );
  }

  void _setNumber(XmlDocument document, String reference, num value) {
    final cell = _cell(document, reference);
    _clearCell(cell);
    cell.children.add(XmlElement(XmlName('v'), const [], [XmlText('$value')]));
  }

  XmlElement _cell(XmlDocument document, String reference) {
    return document
            .findAllElements('c')
            .where((cell) => cell.getAttribute('r') == reference)
            .firstOrNull ??
        (throw StateError('テンプレートにセル$referenceがありません'));
  }

  void _clearCell(XmlElement cell) {
    cell.children.removeWhere(
      (child) =>
          child is XmlElement &&
          const {'f', 'v', 'is'}.contains(child.name.local),
    );
    cell.attributes.removeWhere((attribute) => attribute.name.local == 't');
  }

  void _setAttribute(XmlElement element, String name, String value) {
    element.attributes.removeWhere((attribute) => attribute.name.local == name);
    element.attributes.add(XmlAttribute(XmlName(name), value));
  }

  void _replaceText(XmlElement element, String value) {
    element.children
      ..clear()
      ..add(XmlText(value));
  }

  ({int column, int row}) _cellPosition(String reference) {
    final match = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(reference);
    if (match == null) throw FormatException('Invalid cell reference');
    var column = 0;
    for (final codeUnit in match.group(1)!.codeUnits) {
      column = column * 26 + codeUnit - 64;
    }
    return (column: column, row: int.parse(match.group(2)!));
  }

  String _displayDate(String value) {
    final date = _parseDate(value);
    return date == null ? value : _slashDate(date);
  }

  ({String era, String year, String month, String day}) _japaneseDate(
    String value,
  ) {
    final date = _parseDate(value);
    if (date == null) {
      return (era: '', year: value, month: '', day: '');
    }
    late final String era;
    late final int year;
    if (!date.isBefore(DateTime(2019, 5, 1))) {
      era = '令和';
      year = date.year - 2018;
    } else if (!date.isBefore(DateTime(1989, 1, 8))) {
      era = '平成';
      year = date.year - 1988;
    } else if (!date.isBefore(DateTime(1926, 12, 25))) {
      era = '昭和';
      year = date.year - 1925;
    } else {
      era = '西暦';
      year = date.year;
    }
    return (
      era: era,
      year: '$year',
      month: '${date.month}',
      day: '${date.day}',
    );
  }

  DateTime? _parseDate(String value) =>
      DateTime.tryParse(value.trim().replaceAll('/', '-'));

  String _japaneseExportDate(DateTime date) =>
      '${date.year}年${date.month}月${date.day}日';

  String _slashDate(DateTime date) => '${date.year}/${date.month}/${date.day}';
}

class _PhotoPicture {
  const _PhotoPicture({
    required this.relationshipId,
    required this.mediaName,
    required this.name,
    required this.fromRow,
    required this.toRow,
  });

  final String relationshipId;
  final String mediaName;
  final String name;
  final int fromRow;
  final int toRow;
}
