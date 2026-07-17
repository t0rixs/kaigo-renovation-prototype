import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'document_export_data.dart';

class KaigoEstimateTemplateWriter {
  static const targetSheetNames = [
    '基本情報',
    '原価',
    '原価内訳書',
    'お客様提示用見積書表紙',
    'お客様提示用内訳書',
  ];

  static const _targetRelationshipIds = {
    'rId1',
    'rId2',
    'rId3',
    'rId5',
    'rId6',
  };

  Uint8List build(Uint8List templateBytes, DocumentExportData data) {
    if (data.lines.length > 38) {
      throw StateError('原価内訳書に出力できる手すりは38件までです');
    }

    final archive = ZipDecoder().decodeBytes(templateBytes);
    _writeWorkbook(archive);
    _writeAppProperties(archive);

    final basicInfo = _xmlFile(archive, 'xl/worksheets/sheet1.xml');
    final cost = _xmlFile(archive, 'xl/worksheets/sheet2.xml');
    final costDetails = _xmlFile(archive, 'xl/worksheets/sheet3.xml');
    final quoteCover = _xmlFile(archive, 'xl/worksheets/sheet5.xml');
    final quoteDetails = _xmlFile(archive, 'xl/worksheets/sheet6.xml');

    for (final document in [
      basicInfo,
      cost,
      costDetails,
      quoteCover,
      quoteDetails,
    ]) {
      _removeFormulas(document);
    }

    _populateBasicInfo(basicInfo, data);
    _populateCost(cost, data);
    _populateCostDetails(costDetails, data);
    _populateQuoteCover(quoteCover, data);
    _populateQuoteDetails(quoteDetails, data);

    _replaceXmlFile(archive, 'xl/worksheets/sheet1.xml', basicInfo);
    _replaceXmlFile(archive, 'xl/worksheets/sheet2.xml', cost);
    _replaceXmlFile(archive, 'xl/worksheets/sheet3.xml', costDetails);
    _replaceXmlFile(archive, 'xl/worksheets/sheet5.xml', quoteCover);
    _replaceXmlFile(archive, 'xl/worksheets/sheet6.xml', quoteDetails);

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

  void _writeWorkbook(Archive archive) {
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

    const localSheetIdMap = {0: 0, 1: 1, 2: 2, 4: 3, 5: 4};
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
      _replaceText(counts[0], '5');
      _replaceText(counts[1], '6');
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
