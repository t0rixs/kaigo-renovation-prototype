import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaigo_renovation_app/app_state.dart';
import 'package:kaigo_renovation_app/documents/document_export_data.dart';
import 'package:kaigo_renovation_app/documents/kaigo_estimate_template_writer.dart';
import 'package:kaigo_renovation_app/main.dart';
import 'package:kaigo_renovation_app/models.dart';
import 'package:kaigo_renovation_app/screens/drawing_painters.dart';
import 'package:kaigo_renovation_app/screens/drawing_screen.dart';
import 'package:kaigo_renovation_app/screens/documents_screen.dart';
import 'package:kaigo_renovation_app/screens/estimate_screen.dart';
import 'package:kaigo_renovation_app/storage/app_data_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('トップから案件を選び4画面を表示できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      RenovationApp(
        appState: AppState(dataRepository: MemoryAppDataRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('案件'), findsOneWidget);
    expect(find.text('商品マスター'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(find.text('基本情報'), findsNothing);
    expect(find.text('山田 太郎様邸 住宅改修工事'), findsOneWidget);
    expect(find.text('山田 太郎'), findsOneWidget);
    expect(find.text('福岡市西区小戸1丁目'), findsOneWidget);
    expect(find.textContaining('最終更新'), findsOneWidget);

    await tester.tap(find.text('山田 太郎様邸 住宅改修工事'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(find.text('施工箇所図面'), findsOneWidget);
    expect(find.text('手すり'), findsOneWidget);
    expect(find.text('品番'), findsOneWidget);
    expect(tester.takeException(), isNull);

    expect(find.text('選択'), findsNothing);
    expect(find.text('間取り'), findsWidgets);
    expect(find.text('廊下'), findsNothing);

    await tester.tap(find.text('基本情報').last);
    await tester.pumpAndSettle();
    expect(find.text('お客様名'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('施工箇所図面'), findsOneWidget);

    await tester.tap(find.text('品番').last);
    await tester.pumpAndSettle();
    expect(find.text('デフォルト品番'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('施工箇所図面'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('書類').last);
    await tester.pumpAndSettle();
    expect(find.text('原価'), findsOneWidget);
    expect(find.text('見積書'), findsOneWidget);
    expect(find.textContaining('材料原価 1件'), findsOneWidget);
    expect(find.byKey(const ValueKey('document-material-cost')), findsNothing);
    expect(find.byKey(const ValueKey('document-cost-details')), findsNothing);
    expect(find.text('見積書表紙'), findsNothing);
    expect(find.text('見積書内容'), findsNothing);
    expect(find.byKey(const ValueKey('excel-export-button')), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('施工箇所図面'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('top-navigation')), findsOneWidget);
    expect(find.text('山田 太郎様邸 住宅改修工事'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('書類詳細から戻ると書類一覧を維持し粗利率から金額を自動計算する', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState(dataRepository: MemoryAppDataRepository())
      ..addSample(notify: false);
    var openedDrawing = false;
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentsScreen(
          state: state,
          onOpenDrawing: () => openedDrawing = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('gross-margin-field')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('document-quote')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('document-fullscreen-quote')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('gross-margin-field')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('quote-payment-terms-field')),
      findsOneWidget,
    );
    expect(find.text('見積金額（税込）'), findsOneWidget);
    expect(find.text('¥12,760'), findsWidgets);
    expect(find.text('見積書表紙'), findsNothing);
    expect(find.text('見積書内容'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('gross-margin-field')),
      '40',
    );
    await tester.pump();
    expect(state.documents.grossMarginPercent, 40);
    expect(find.text('¥10,633'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(openedDrawing, isFalse);
    expect(find.byKey(const ValueKey('document-quote')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('document-fullscreen-quote')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('document-cost')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('図面を開く'));
    await tester.pumpAndSettle();
    expect(openedDrawing, isTrue);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('統合した原価画面から帳票専用項目と手すりの場所・品番を編集できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState(dataRepository: MemoryAppDataRepository())
      ..addSample(notify: false);
    state.products.add(
      HandrailProduct(
        id: 'demo-indoor-alt',
        name: '室内用樹脂手すり φ32',
        environmentTags: {HandrailEnvironment.indoor},
        diameterMm: 32,
        railPricePerMeter: 6000,
        jointPrice: 2000,
        postPrice: 4000,
        maxJointIntervalMm: 1000,
      ),
    );
    final line = state.lines.single;

    await tester.pumpWidget(
      MaterialApp(
        home: DocumentsScreen(state: state, onOpenDrawing: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('document-cost')), findsOneWidget);
    expect(find.byKey(const ValueKey('document-material-cost')), findsNothing);
    expect(find.byKey(const ValueKey('document-cost-details')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('document-cost')));
    await tester.pumpAndSettle();

    final itemName = find.byKey(const ValueKey('cost-item-name-field'));
    final handrailCard = find.byKey(ValueKey('material-cost-${line.id}'));
    expect(itemName, findsOneWidget);
    expect(handrailCard, findsOneWidget);
    expect(
      tester.getTopLeft(itemName).dy,
      lessThan(tester.getTopLeft(handrailCard).dy),
    );
    expect(find.text('材料原価合計'), findsWidgets);
    expect(find.text('単価'), findsOneWidget);
    expect(find.text('消費税'), findsOneWidget);
    expect(find.text('合計'), findsOneWidget);
    expect(find.byKey(const ValueKey('cost-preview-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cost-details-preview-button')),
      findsOneWidget,
    );

    await tester.enterText(itemName, '山田様邸 原価一式');
    await tester.pump();
    expect(state.documents.costItemName, '山田様邸 原価一式');

    await tester.tap(handrailCard);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('document-handrail-editor')),
      findsOneWidget,
    );
    expect(find.text('設置方式'), findsNothing);
    expect(find.text('設置環境'), findsNothing);
    expect(find.text('長さ'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('document-handrail-place-field')),
      '浴室入口',
    );
    await tester.tap(
      find.byKey(const ValueKey('document-handrail-product-field')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('demo-indoor-alt  室内用樹脂手すり φ32').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('document-work-content-field')),
      '手すり設置・下地補強',
    );
    await tester.enterText(
      find.byKey(const ValueKey('document-specification-field')),
      '樹脂手すり 750mm',
    );
    await tester.enterText(
      find.byKey(const ValueKey('document-remarks-field')),
      '定価確認済み',
    );
    final save = find.byKey(const ValueKey('save-document-handrail'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(line.place, '浴室入口');
    expect(line.productId, 'demo-indoor-alt');
    expect(state.selectedId, isNull);
    final fields = state.documents.fieldsFor(line.id);
    expect(fields.workContent, '手すり設置・下地補強');
    expect(fields.specification, '樹脂手すり 750mm');
    expect(fields.remarks, '定価確認済み');
    final document = DocumentExportData.fromState(state);
    expect(document.lines.single.location, '浴室入口');
    expect(document.lines.single.productId, 'demo-indoor-alt');
    expect(state.materialCostTotal, 8500);
    expect(find.text('¥8,500'), findsWidgets);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('トップの商品マスターにはボトムメニューを表示しない', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      RenovationApp(
        appState: AppState(dataRepository: MemoryAppDataRepository()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('top-menu-products')));
    await tester.pumpAndSettle();

    expect(find.text('商品マスター'), findsOneWidget);
    expect(find.text('デフォルト品番'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(find.text('基本情報'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('案件ごとに基本情報と図面を分離する', () {
    final state = AppState()..addSample(notify: false);
    final firstProjectId = state.activeProject.id;
    final firstProjectName = state.customer.projectName;
    final firstObjectCount = state.objects.length;

    final secondProject = state.createProject();
    state.customer.projectName = '2件目の工事';
    state.addLayout(0, 0, 1000, 1000);

    expect(secondProject.customer.projectName, '2件目の工事');
    expect(state.objects, hasLength(1));

    state.selectProject(firstProjectId);
    expect(state.customer.projectName, firstProjectName);
    expect(state.objects, hasLength(firstObjectCount));
    state.dispose();
  });

  test('複数案件を保存して再読込できる', () async {
    final repository = MemoryAppDataRepository();
    final state = AppState(dataRepository: repository)
      ..addSample(notify: false);
    final firstProjectId = state.activeProject.id;
    state.customer.projectName = '保存対象1';

    final secondProject = state.createProject();
    state.customer.projectName = '保存対象2';
    state.addLayout(0, 0, 1000, 750);
    await state.saveNow();

    final restored = AppState(dataRepository: repository);
    await restored.load();

    expect(restored.projects, hasLength(2));
    expect(restored.activeProject.id, secondProject.id);
    expect(restored.customer.projectName, '保存対象2');
    expect(restored.objects, hasLength(1));

    restored.selectProject(firstProjectId);
    expect(restored.customer.projectName, '保存対象1');
    expect(restored.objects, hasLength(4));
    state.dispose();
    restored.dispose();
  });

  test('サーバー移行用JSONに商品・案件・基本情報・図面・見積を格納する', () {
    final state = AppState(dataRepository: MemoryAppDataRepository())
      ..addSample(notify: false);
    final json = jsonDecode(state.exportJson()) as Map<String, dynamic>;
    final productMaster = json['productMaster'] as Map<String, dynamic>;
    final projects = json['projects'] as List<dynamic>;
    final project = projects.single as Map<String, dynamic>;
    final drawing = project['drawing'] as Map<String, dynamic>;
    final estimate = project['estimate'] as Map<String, dynamic>;

    expect(json['schemaVersion'], 1);
    expect(productMaster['products'], hasLength(2));
    expect(project['basicInfo'], isA<Map<String, dynamic>>());
    expect(project['documents'], isA<Map<String, dynamic>>());
    expect(drawing['canvas'], {'widthMm': 10000, 'heightMm': 7500});
    expect(drawing['objects'], hasLength(4));
    expect(drawing['handrails'], hasLength(1));
    expect(estimate['handrails'], hasLength(1));
    expect(estimate['materialCostTotal'], 5800);
    state.dispose();
  });

  test('図面サイズは250mm単位で案件JSONへ保存する', () async {
    final repository = MemoryAppDataRepository();
    final state = AppState(dataRepository: repository);

    expect(state.setCanvasSize(12340, 8760), isTrue);
    expect(state.canvasWidthMm, 12250);
    expect(state.canvasHeightMm, 8750);
    await state.saveNow();

    final restored = AppState(dataRepository: repository);
    await restored.load();
    expect(restored.canvasWidthMm, 12250);
    expect(restored.canvasHeightMm, 8750);

    final drawing = (restored.activeProject.toJson()['drawing'] as Map);
    expect(drawing['canvas'], {'widthMm': 12250, 'heightMm': 8750});
    state.dispose();
    restored.dispose();
  });

  test('配置済み要素が図面外になる縮小は拒否する', () {
    final state = AppState();
    state.addLayout(8000, 6000, 1500, 1000);

    expect(state.minimumCanvasWidthMm, 9500);
    expect(state.minimumCanvasHeightMm, 7000);
    expect(state.setCanvasSize(9000, 7000), isFalse);
    expect(state.canvasWidthMm, 10000);
    expect(state.canvasHeightMm, 7500);
    expect(state.setCanvasSize(9500, 7000), isTrue);
    expect(state.canvasWidthMm, 9500);
    expect(state.canvasHeightMm, 7000);
    state.dispose();
  });

  test('書類データは手すり1本を1明細として粗利率から顧客単価を計算する', () {
    final state = AppState(dataRepository: MemoryAppDataRepository())
      ..addSample(notify: false);
    final line = state.lines.single;
    line.place = '浴室';
    final fields = state.documents.fieldsFor(line.id)
      ..workContent = '手すり取付'
      ..specification = '横手すり 750mm'
      ..remarks = '定価 8,000円';
    state.documents.grossMarginPercent = 50;

    final data = DocumentExportData.fromState(state);

    expect(data.lines, hasLength(1));
    expect(data.lines.single.handrailId, fields.handrailId);
    expect(data.lines.single.location, '浴室');
    expect(data.lines.single.costUnitPrice, 5800);
    expect(data.lines.single.costAmount, 5800);
    expect(data.lines.single.customerUnitPrice, 11600);
    expect(data.quoteSubtotal, 11600);
    expect(data.quoteTax, 1160);
    expect(data.quoteTotal, 12760);
    state.dispose();
  });

  test('添付テンプレートから対象5シートだけのExcelを生成する', () async {
    final state = AppState(dataRepository: MemoryAppDataRepository())
      ..addSample(notify: false);
    final line = state.lines.single;
    line.place = '浴室';
    state.documents.grossMarginPercent = 50;
    state.documents.fieldsFor(line.id)
      ..workContent = '手すり取付'
      ..specification = '横手すり 750mm'
      ..remarks = '定価 8,000円';
    final data = DocumentExportData.fromState(
      state,
      exportedAt: DateTime(2026, 7, 14),
    );
    final template = await File(
      'assets/templates/kaigo_estimate_template.xlsx',
    ).readAsBytes();

    final output = KaigoEstimateTemplateWriter().build(template, data);
    final archive = ZipDecoder().decodeBytes(output);
    final workbook = _archiveXml(archive, 'xl/workbook.xml');
    final sheetNames = workbook
        .findAllElements('sheet')
        .map((sheet) => sheet.getAttribute('name'))
        .toList();

    expect(sheetNames, KaigoEstimateTemplateWriter.targetSheetNames);
    for (final path in const [
      'xl/worksheets/sheet1.xml',
      'xl/worksheets/sheet2.xml',
      'xl/worksheets/sheet3.xml',
      'xl/worksheets/sheet5.xml',
      'xl/worksheets/sheet6.xml',
    ]) {
      final sheet = _archiveXml(archive, path);
      expect(sheet.findAllElements('f'), isEmpty);
      expect(sheet.toXmlString(), isNot(contains('商品リスト')));
    }

    final costDetails = _archiveXml(archive, 'xl/worksheets/sheet3.xml');
    final quoteCover = _archiveXml(archive, 'xl/worksheets/sheet5.xml');
    final quoteDetails = _archiveXml(archive, 'xl/worksheets/sheet6.xml');
    expect(_cellValue(costDetails, 'A9'), '手すり取付');
    expect(_cellValue(costDetails, 'B9'), '浴室');
    expect(_cellValue(costDetails, 'H9'), '5800');
    expect(_cellValue(quoteCover, 'D14'), '12760');
    expect(_cellValue(quoteDetails, 'G9'), '11600');
    expect(_cellValue(quoteDetails, 'H50'), '12760');
    expect(_rowIsHidden(costDetails, 9), isFalse);
    expect(_rowIsHidden(costDetails, 10), isTrue);
    expect(_rowIsHidden(costDetails, 84), isTrue);
    expect(_rowIsHidden(costDetails, 85), isFalse);
    expect(_rowIsHidden(quoteDetails, 9), isFalse);
    expect(_rowIsHidden(quoteDetails, 10), isTrue);
    expect(_rowIsHidden(quoteDetails, 46), isTrue);
    expect(_rowIsHidden(quoteDetails, 47), isFalse);
    for (final detailSheet in [costDetails, quoteDetails]) {
      final pageSetup = detailSheet.findAllElements('pageSetup').single;
      expect(pageSetup.getAttribute('fitToWidth'), '1');
      expect(pageSetup.getAttribute('fitToHeight'), '0');
      expect(pageSetup.getAttribute('scale'), isNull);
      expect(
        detailSheet
            .findAllElements('pageSetUpPr')
            .single
            .getAttribute('fitToPage'),
        '1',
      );
      expect(detailSheet.findAllElements('rowBreaks'), isEmpty);
      expect(detailSheet.findAllElements('colBreaks'), isEmpty);
    }
    for (final fixedSheet in [
      _archiveXml(archive, 'xl/worksheets/sheet2.xml'),
      quoteCover,
    ]) {
      final pageSetup = fixedSheet.findAllElements('pageSetup').single;
      expect(pageSetup.getAttribute('fitToWidth'), '1');
      expect(pageSetup.getAttribute('fitToHeight'), '1');
      expect(pageSetup.getAttribute('scale'), isNull);
      expect(fixedSheet.findAllElements('rowBreaks'), isEmpty);
      expect(fixedSheet.findAllElements('colBreaks'), isEmpty);
    }
    state.dispose();
  });

  test('サンプル図面から見積金額を計算する', () {
    final state = AppState()..addSample(notify: false);

    expect(state.lines, hasLength(1));
    expect(state.costFor(state.lines.single).railCost, 3300);
    expect(state.costFor(state.lines.single).jointCount, 2);
    expect(state.costFor(state.lines.single).jointCost, 2500);
    expect(state.materialCostTotal, 5800);

    state.dispose();
  });

  testWidgets('手すり編集シートを反映して閉じる間もController例外が出ない', (tester) async {
    final state = AppState()..addSample(notify: false);
    final line = state.lines.single;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showWorkLineEditor(context, state, line),
              child: const Text('編集を開く'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('編集を開く'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('反映する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('反映する'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('反映する'), findsNothing);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('図面設定から250mm単位で図面サイズを変更できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final settings = find.byKey(const ValueKey('drawing-settings'));
    await tester.drag(
      find.byKey(const ValueKey('drawing-toolbar')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(settings);
    await tester.pumpAndSettle();
    expect(find.text('図面設定'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('canvas-width-field')),
      '12010',
    );
    await tester.enterText(
      find.byKey(const ValueKey('canvas-height-field')),
      '8001',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('apply-canvas-settings')),
    );
    await tester.tap(find.byKey(const ValueKey('apply-canvas-settings')));
    await tester.pumpAndSettle();

    expect(state.canvasWidthMm, 12000);
    expect(state.canvasHeightMm, 8000);
    expect(find.byKey(const ValueKey('apply-canvas-settings')), findsNothing);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('設備は親ツールからトイレを選択する', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DrawingScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('equipment-menu')), findsNothing);
    expect(find.byIcon(Icons.wc), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tool-equipment')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tool-equipment')),
        matching: find.byIcon(Icons.widgets_outlined),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('equipment-menu')), findsOneWidget);
    expect(find.byKey(const ValueKey('equipment-toilet')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('equipment-toilet')));
    await tester.pump();
    expect(find.text('トイレ：配置する中心グリッドをタップ'), findsOneWidget);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('選択した間取りを丸ハンドルのスワイプで拡大できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState()..addSample(notify: false);
    final room = state.objects.first;
    state.select(room.id);
    final originalWidth = room.widthMm;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(ValueKey('resize-${room.id}')),
      const Offset(80, 0),
    );
    await tester.pumpAndSettle();

    expect(room.widthMm, greaterThan(originalWidth));
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('間取りモードのまま既存の間取りを選択できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addLayout(1000, 1000, 1500, 1500);
    final room = state.objects.single;
    state.select(null);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tool-layout')));
    await tester.pump();

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.scaleEnabled, isTrue);
    await tester.tap(find.byKey(ValueKey('layout-edge-${room.id}-top')));
    await tester.pumpAndSettle();

    expect(state.selectedId, room.id);
    expect(state.objects, hasLength(1));
    state.dispose();
  });

  testWidgets('未選択の間取りも縁の全方向250mm以内から選択できる', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addLayout(1500, 1500, 1500, 1500);
    final room = state.objects.single;
    state.select(null);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final roomRect = tester.getRect(find.byKey(ValueKey('object-${room.id}')));
    final expandedTopRect = tester.getRect(
      find.byKey(ValueKey('layout-expanded-hit-${room.id}-top')),
    );
    final displayedGrid = roomRect.width * AppState.gridMm / room.widthMm;
    expect(
      roomRect.top - expandedTopRect.top,
      moreOrLessEquals(displayedGrid, epsilon: 0.01),
    );

    final expandedOnlyPoint = Offset(
      roomRect.center.dx,
      (roomRect.top + expandedTopRect.top) / 2,
    );
    await tester.tapAt(expandedOnlyPoint);
    await tester.pump();
    expect(state.selectedId, room.id);

    await tester.tap(find.byKey(const ValueKey('tool-equipment')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('equipment-toilet')));
    await tester.pump();
    await tester.tapAt(expandedOnlyPoint);
    await tester.pump();

    expect(state.objects, hasLength(2));
    expect(state.objects.last.kind, PlanObjectKind.fixture);
    expect(state.selectedId, state.objects.last.id);
    state.dispose();
  });

  testWidgets('選択中の間取り内部へトイレ設備を配置できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    final room = state.objects.single;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tool-equipment')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('equipment-toilet')));
    await tester.pump();
    await tester.tapAt(
      tester.getCenter(find.byKey(ValueKey('object-${room.id}'))),
    );
    await tester.pumpAndSettle();

    expect(state.objects, hasLength(2));
    final toilet = state.objects.last;
    expect(toilet.kind, PlanObjectKind.fixture);
    expect(find.byKey(ValueKey('toilet-symbol-${toilet.id}')), findsOneWidget);
    state.dispose();
  });

  testWidgets('窓モードで間取りの縁をタップすると窓を配置できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    final room = state.objects.single;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('窓'));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('layout-edge-${room.id}-top')));
    await tester.pumpAndSettle();

    expect(state.objects, hasLength(2));
    final window = state.objects.last;
    expect(window.kind, PlanObjectKind.window);
    expect(window.wallId, room.id);

    state.select(null);
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('object-${window.id}')));
    await tester.pump();
    expect(state.selectedId, window.id);

    state.deleteSelected();
    await tester.pumpAndSettle();
    expect(state.objects, [room]);
    state.dispose();
  });

  testWidgets('間取りモードのピンチ操作では間取りを誤作成しない', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tool-layout')));
    await tester.pump();

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final controller = viewer.transformationController!;
    final scaleBefore = controller.value.getMaxScaleOnAxis();
    final center = tester.getCenter(find.byType(InteractiveViewer));
    final first = await tester.startGesture(center - const Offset(30, 0));
    await first.moveBy(const Offset(-35, -35));
    await tester.pump();
    final second = await tester.startGesture(center + const Offset(30, 0));
    await first.moveBy(const Offset(-30, 0));
    await second.moveBy(const Offset(30, 0));
    await tester.pump();
    await second.up();
    await first.moveBy(const Offset(50, 50));
    await tester.pump();
    await first.up();
    await tester.pumpAndSettle();

    expect(controller.value.getMaxScaleOnAxis(), greaterThan(scaleBefore));
    expect(state.objects, isEmpty);

    await tester.dragFrom(center - const Offset(40, 40), const Offset(80, 80));
    await tester.pumpAndSettle();
    expect(state.objects.single.kind, PlanObjectKind.layout);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('設備ツール選択中のピンチ操作では設備を誤配置しない', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tool-equipment')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('equipment-toilet')));
    await tester.pump();

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final controller = viewer.transformationController!;
    final scaleBefore = controller.value.getMaxScaleOnAxis();
    final center = tester.getCenter(find.byType(InteractiveViewer));
    final first = await tester.startGesture(center - const Offset(30, 0));
    final second = await tester.startGesture(center + const Offset(30, 0));
    await tester.pump();
    await first.moveBy(const Offset(-35, 0));
    await second.moveBy(const Offset(35, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    expect(controller.value.getMaxScaleOnAxis(), greaterThan(scaleBefore));
    expect(state.objects, isEmpty);

    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(state.objects, hasLength(1));
    expect(state.objects.single.kind, PlanObjectKind.fixture);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('選択中のツールを再タップすると解除されドラッグで画面移動できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.panEnabled, isTrue);
    expect(find.text('ツール未選択：ドラッグで画面移動'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tool-layout')));
    await tester.pump();
    viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(viewer.panEnabled, isFalse);

    await tester.tap(find.byKey(const ValueKey('tool-layout')));
    await tester.pump();
    viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(viewer.panEnabled, isTrue);

    final controller = viewer.transformationController!;
    final before = controller.value.getTranslation();
    await tester.drag(find.byType(InteractiveViewer), const Offset(60, 40));
    await tester.pumpAndSettle();
    final after = controller.value.getTranslation();

    expect(after.x, isNot(before.x));
    expect(after.y, isNot(before.y));
    expect(state.objects, isEmpty);
    state.dispose();
  });

  testWidgets('任意の図面要素は空白のワンタップで選択解除される', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState()..addSample(notify: false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tool-layout')));
    await tester.pump();

    final emptyPoint =
        tester.getTopLeft(find.byType(InteractiveViewer)) +
        const Offset(340, 300);
    final selectableIds = [
      ...state.objects.map((item) => item.id),
      ...state.lines.map((item) => item.id),
    ];
    for (final id in selectableIds) {
      state.select(id);
      await tester.pump();
      await tester.tapAt(emptyPoint);
      await tester.pump();
      expect(state.selectedId, isNull, reason: '$idの選択が解除される');
    }

    await tester.tap(find.byKey(const ValueKey('tool-equipment')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('equipment-toilet')));
    await tester.pump();
    state.select(state.objects.first.id);
    await tester.pump();
    final objectCount = state.objects.length;
    await tester.tapAt(emptyPoint);
    await tester.pump();
    expect(state.selectedId, isNull);
    expect(state.objects, hasLength(objectCount));

    state.dispose();
  });

  testWidgets('選択中の設備は外周250mmまで当たり判定が広がる', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState()..addToilet(2000, 2000);
    final toilet = state.objects.single;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final target = find.byKey(ValueKey('object-${toilet.id}'));
    final targetRect = tester.getRect(target);
    final expandedRect = tester.getRect(
      find.byKey(ValueKey('selected-hit-${toilet.id}')),
    );
    final displayedGrid = targetRect.width * AppState.gridMm / toilet.widthMm;
    expect(
      targetRect.left - expandedRect.left,
      moreOrLessEquals(displayedGrid, epsilon: 0.01),
    );

    await tester.tapAt(
      Offset((targetRect.left + expandedRect.left) / 2, targetRect.center.dy),
    );
    await tester.pump();
    expect(state.selectedId, toilet.id);

    await tester.tapAt(
      Offset(expandedRect.left - displayedGrid / 2, targetRect.center.dy),
    );
    await tester.pump();
    expect(state.selectedId, isNull);
    state.dispose();
  });

  testWidgets('選択中の手すりは線の周囲250mmまで当たり判定が広がる', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState()..addHandrail(1500, 1500, 3000, 1500);
    final line = state.lines.single;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final body = find.byKey(ValueKey('line-body-${line.id}'));
    final bodyRect = tester.getRect(body);
    final expandedRect = tester.getRect(
      find.byKey(ValueKey('selected-hit-${line.id}-segment-0')),
    );
    expect(
      expandedRect.bottom - bodyRect.bottom,
      moreOrLessEquals(bodyRect.height, epsilon: 0.01),
    );

    await tester.tapAt(
      Offset(bodyRect.center.dx, (bodyRect.bottom + expandedRect.bottom) / 2),
    );
    await tester.pump();
    expect(state.selectedId, line.id);

    await tester.tapAt(
      Offset(bodyRect.center.dx, expandedRect.bottom + bodyRect.height / 2),
    );
    await tester.pump();
    expect(state.selectedId, isNull);
    state.dispose();
  });

  testWidgets('設備はタップで選択してから通常ドラッグで移動する', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addToilet(1500, 1500);
    final toilet = state.objects.single;
    final originalX = toilet.xMm;
    state.select(null);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final target = find.byKey(ValueKey('object-${toilet.id}'));
    await tester.drag(target, const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(toilet.xMm, originalX);

    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(state.selectedId, toilet.id);

    await tester.drag(target, const Offset(80, 0));
    await tester.pumpAndSettle();

    expect(toilet.xMm, greaterThan(originalX));
    state.dispose();
  });

  testWidgets('キャンバスのドラッグ範囲から間取りを作成できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tool-layout')));
    await tester.pump();
    final canvasCenter = tester.getCenter(find.byType(InteractiveViewer));
    await tester.dragFrom(
      canvasCenter - const Offset(60, 60),
      const Offset(120, 120),
    );
    await tester.pumpAndSettle();

    expect(state.objects, hasLength(1));
    expect(state.objects.single.kind, PlanObjectKind.layout);
    expect(state.objects.single.widthMm, greaterThanOrEqualTo(250));
    expect(state.objects.single.heightMm, greaterThanOrEqualTo(250));
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('手すり作成ドラッグは未選択の間取り判定より優先される', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addLayout(1500, 1500, 2000, 2000);
    final room = state.objects.single;
    state.select(null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tool-rail')));
    await tester.pump();
    final roomRect = tester.getRect(find.byKey(ValueKey('object-${room.id}')));
    final displayedGrid = roomRect.width * AppState.gridMm / room.widthMm;
    final start = Offset(
      roomRect.left + displayedGrid * 2,
      roomRect.top + displayedGrid * .7,
    );
    await tester.dragFrom(start, Offset(displayedGrid * 3, 0));
    await tester.pumpAndSettle();

    expect(state.lines, hasLength(1));
    expect(state.lines.single.y1Mm, room.yMm + AppState.gridMm);
    expect(state.lines.single.y2Mm, room.yMm + AppState.gridMm);
    expect(state.selectedId, state.lines.single.id);

    state.deleteSelected();
    await tester.pump();
    await tester.dragFrom(
      Offset(roomRect.left + displayedGrid * 2, roomRect.top),
      Offset(displayedGrid * 3, 0),
    );
    await tester.pump();
    expect(state.lines, isEmpty);
    expect(find.textContaining('間取りの縁と完全に重ならない'), findsOneWidget);
    state.dispose();
  });

  test('手すりが間取りの縁に全区間重なる場合だけ検出する', () {
    final state = AppState();
    state.addLayout(1500, 1500, 2000, 2000);

    expect(
      state.handrailCompletelyOverlapsLayoutEdge(1750, 1500, 3000, 1500),
      isTrue,
    );
    expect(
      state.handrailCompletelyOverlapsLayoutEdge(1750, 1750, 3000, 1750),
      isFalse,
    );
    expect(
      state.handrailCompletelyOverlapsLayoutEdge(1000, 1500, 3000, 1500),
      isFalse,
    );
    state.dispose();
  });

  test('手すりは近い軸へ固定され250mm単位になる', () {
    final state = AppState();
    state.addHandrail(0, 0, 1100, 300);

    final line = state.lines.single;
    expect(line.y1Mm, line.y2Mm);
    expect(line.lengthMm % AppState.gridMm, 0);
    expect(line.lengthMm, greaterThanOrEqualTo(AppState.gridMm));
    state.dispose();
  });

  test('手すりの両端と1000mm間隔にジョイントを自動生成して見積へ反映する', () {
    final state = AppState();
    state.addHandrail(1000, 1000, 2000, 1000);
    final line = state.lines.single;

    expect(state.costFor(line).jointCount, 2);

    state.setLineLength(line, 2250);
    expect(line.lengthMm, 2250);
    final cost = state.costFor(line);
    expect(cost.jointCount, 4);
    expect(cost.postCount, 0);
    expect(cost.railCost, 9900);
    expect(cost.jointCost, 5000);
    expect(cost.postCost, 0);
    expect(cost.total, 14900);
    expect(state.materialCostTotal, 14900);
    state.dispose();
  });

  test('最大間隔を超えない範囲でジョイント間隔を均等にする', () {
    final state = AppState();
    state.addHandrail(1000, 4000, 2500, 4000);
    final line = state.lines.single;

    expect(state.jointPointsFor(line).map((point) => (point.xMm, point.yMm)), [
      (1000, 4000),
      (1750, 4000),
      (2500, 4000),
    ]);
    state.dispose();
  });

  test('屋外の独立型は対応商品を使いジョイント数と同数の柱を計上する', () {
    final state = AppState();
    state.addHandrail(1000, 1000, 2000, 1000);
    final line = state.lines.single;

    state.applyHandrailSettings(
      line,
      environment: HandrailEnvironment.outdoor,
      installationType: HandrailInstallationType.freestanding,
      productId: state.defaultProductIdFor(HandrailEnvironment.outdoor),
    );

    final cost = state.costFor(line);
    expect(line.productId, 'demo-outdoor-34');
    expect(cost.jointCount, 2);
    expect(cost.postCount, 2);
    expect(cost.railCost, 7200);
    expect(cost.jointCost, 3600);
    expect(cost.postCost, 13000);
    expect(cost.total, 23800);
    state.dispose();
  });

  test('商品選択は設置環境タグで絞り込みデフォルトを変更できる', () {
    final state = AppState();
    final shared = HandrailProduct(
      id: 'BOTH-01',
      name: '屋内外兼用手すり',
      environmentTags: {
        HandrailEnvironment.indoor,
        HandrailEnvironment.outdoor,
      },
      diameterMm: 34,
      railPricePerMeter: 6000,
      jointPrice: 1500,
      postPrice: 5000,
      maxJointIntervalMm: 750,
    );

    expect(state.addProduct(shared), isTrue);
    expect(state.productsFor(HandrailEnvironment.indoor), contains(shared));
    expect(state.productsFor(HandrailEnvironment.outdoor), contains(shared));
    state.setDefaultProduct(HandrailEnvironment.outdoor, shared.id);
    expect(state.defaultProductIdFor(HandrailEnvironment.outdoor), shared.id);
    state.dispose();
  });

  test('間取り内の手すりと設備は場所名を初期値にする', () {
    final state = AppState();
    state.addLayout(1000, 1000, 3000, 3000);
    final outer = state.objects.single..place = '廊下';
    state.addLayout(1500, 1500, 1000, 1500);
    final inner = state.objects.last..place = 'トイレ';

    state.addHandrail(1750, 2000, 2250, 2000);
    expect(state.lines.single.place, 'トイレ');

    state.addToilet(2000, 2250);
    expect(state.objects.last.place, 'トイレ');

    expect(
      state.addOpening(PlanObjectKind.door, 1500, 2250),
      OpeningAddResult.added,
    );
    expect(state.objects.last.place, 'トイレ');
    expect(outer.toJson(), isNot(contains('label')));
    expect(inner.toJson()['place'], 'トイレ');
    state.dispose();
  });

  testWidgets('間取り編集は表示名をなくして場所名だけを編集する', (tester) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    final room = state.objects.single;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('属性を編集'));
    await tester.pumpAndSettle();

    expect(find.text('表示名'), findsNothing);
    expect(find.text('場所名'), findsOneWidget);
    final placeField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '場所名',
    );
    await tester.enterText(placeField, '浴室');
    await tester.tap(find.text('反映する'));
    await tester.pumpAndSettle();

    expect(room.place, '浴室');
    state.dispose();
  });

  test('手すりは壁の近くでも座標と直線形状を維持する', () {
    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    state.addHandrail(1250, 1000, 3250, 1000);
    final line = state.lines.single;

    expect(line.y1Mm, 1000);
    expect(line.y2Mm, 1000);
    expect(
      state.handrailPath(line).points.map((point) => (point.xMm, point.yMm)),
      [(1250, 1000), (3250, 1000)],
    );
    state.dispose();
  });

  testWidgets('図面ツールバーに壁吸着機能を表示しない', (tester) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    state.addHandrail(1250, 1250, 2000, 1250);
    state.select(state.lines.single.id);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    PlanPainter planPainter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<PlanPainter>()
        .single;

    expect(planPainter().selectionColor, editorSelectionColor);
    expect(find.byKey(const ValueKey('wall-snap-toggle')), findsNothing);
    expect(find.textContaining('壁吸着'), findsNothing);
    expect(state.selectedId, state.lines.single.id);
    state.dispose();
  });

  test('単体の手すりは間取りの角を越えても直線のままになる', () {
    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    state.addHandrail(1250, 1250, 3250, 1250);
    final line = state.lines.single;

    final path = state.handrailPath(line);
    expect(path.points.map((point) => (point.xMm, point.yMm)), [
      (1250, 1250),
      (3250, 1250),
    ]);
    expect(line.lengthMm, 2000);

    final joints = state.jointPointsFor(line);
    expect(joints.map((point) => (point.xMm, point.yMm)), [
      (1250, 1250),
      (2250, 1250),
      (3250, 1250),
    ]);
    expect(state.costFor(line).jointCount, 3);
    state.dispose();
  });

  testWidgets('直線手すりは選択後の通常ドラッグで任意位置へ移動できる', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    state.addHandrail(2000, 1250, 3000, 1250);
    final line = state.lines.single;
    final originalY = line.y1Mm;
    state.select(null);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final body = find.byKey(ValueKey('line-body-${line.id}'));
    await tester.tap(body);
    await tester.pumpAndSettle();
    expect(state.selectedId, line.id);

    await tester.drag(body, const Offset(0, 80));
    await tester.pumpAndSettle();

    expect(line.y1Mm, greaterThan(originalY));
    expect(line.y1Mm, line.y2Mm);
    expect(state.handrailPath(line).points, hasLength(2));
    state.dispose();
  });

  testWidgets('間取りの縁と重なった手すりをタップして選択できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    final room = state.objects.single;
    state.addHandrail(1000, 1000, 2000, 1000);
    final rail = state.lines.single;
    state.select(null);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('line-body-${rail.id}')));
    await tester.pump();

    expect(state.selectedId, rail.id);
    expect(state.selectedId, isNot(room.id));
    state.dispose();
  });

  test('手すりの端点を別の軸へ動かすと横向きと縦向きが切り替わる', () {
    final state = AppState();
    state.addHandrail(1000, 1000, 2000, 1000);
    final line = state.lines.single;

    state.moveLineEnd(line, false, 1000, 2500);
    expect(line.isHorizontal, isFalse);
    expect(line.x1Mm, line.x2Mm);
    expect(line.orientation, HandrailOrientation.vertical);

    state.moveLineEnd(line, false, 2500, 2500);
    expect(line.isHorizontal, isTrue);
    expect(line.y1Mm, line.y2Mm);
    expect(line.orientation, HandrailOrientation.horizontal);
    state.dispose();
  });

  testWidgets('横手すりの端ハンドルを縦へドラッグして向きを変更できる', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addHandrail(1000, 1000, 2000, 1000);
    final line = state.lines.single;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 12; i++) {
      await tester.tap(find.byTooltip('拡大'));
      await tester.pump();
    }

    final endHandle = find.byKey(ValueKey('line-${line.id}-end'));
    final gesture = await tester.startGesture(tester.getCenter(endHandle));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    expect(line.isHorizontal, isFalse);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(line.isHorizontal, isFalse);
    expect(line.x1Mm, line.x2Mm);
    expect(line.lengthMm % AppState.gridMm, 0);
    expect(line.orientation, HandrailOrientation.vertical);
    state.dispose();
  });

  testWidgets('リサイズハンドルは指位置に最も近いグリッドへ追従する', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addToilet(750, 500);
    final toilet = state.objects.single;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 12; i++) {
      await tester.tap(find.byTooltip('拡大'));
      await tester.pump();
    }

    final handle = find.byKey(ValueKey('resize-${toilet.id}'));
    final drawingState = tester.state(find.byType(DrawingScreen)) as dynamic;
    final visibleGrid = 40 * (drawingState.scale as double);
    final start = tester.getCenter(handle);
    final pointer = start + const Offset(70, 70);
    final gesture = await tester.startGesture(start);
    await gesture.moveTo(pointer);
    await tester.pump();

    final handleCenter = tester.getCenter(handle);
    expect((handleCenter.dx - pointer.dx).abs(), lessThan(visibleGrid / 2 + 2));
    expect((handleCenter.dy - pointer.dy).abs(), lessThan(visibleGrid / 2 + 2));
    expect(toilet.widthMm % AppState.gridMm, 0);
    expect(toilet.heightMm % AppState.gridMm, 0);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(toilet.widthMm % AppState.gridMm, 0);
    expect(toilet.heightMm % AppState.gridMm, 0);
    state.dispose();
  });

  test('ドアは最寄りの間取り辺に所属する', () {
    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);

    expect(
      state.addOpening(PlanObjectKind.door, 3000, 1500),
      OpeningAddResult.added,
    );
    final door = state.objects.last;
    expect(door.wallId, state.objects.first.id);
    expect(door.wallEdge, WallEdge.right);
    state.dispose();
  });

  testWidgets('ドアツールから開き戸とスライド戸を選んで配置できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addLayout(1000, 1000, 2500, 2000);
    final room = state.objects.single;
    state.select(null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tool-door')));
    await tester.pump();
    expect(find.byKey(const ValueKey('door-menu')), findsOneWidget);
    expect(find.text('開き戸'), findsOneWidget);
    expect(find.text('スライド戸'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('door-sliding')));
    await tester.pump();
    expect(find.textContaining('スライド戸：'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('layout-edge-${room.id}-top')));
    await tester.pumpAndSettle();

    final door = state.objects.last;
    expect(door.kind, PlanObjectKind.door);
    expect(door.doorType, DoorType.sliding);
    expect(door.wallId, room.id);
    expect(door.opensOutward, isFalse);
    state.dispose();
  });

  test('スライド戸の戸種と引き方向はJSONで復元できる', () {
    final state = AppState();
    state.addLayout(1000, 1000, 2500, 2000);
    expect(
      state.addOpening(
        PlanObjectKind.door,
        2000,
        1000,
        doorType: DoorType.sliding,
      ),
      OpeningAddResult.added,
    );
    final door = state.objects.last;
    state.flipDoor(door);

    final restored = PlanObject.fromJson(door.toJson());
    expect(restored.doorType, DoorType.sliding);
    expect(restored.flipped, isTrue);
    expect(restored.opensOutward, isFalse);
    state.dispose();
  });

  test('スライド戸記号は上下左右の壁と開口端へ揃う', () async {
    for (final edge in WallEdge.values) {
      final bounds = await slidingDoorInkBounds(edge);
      final horizontal = edge == WallEdge.top || edge == WallEdge.bottom;

      if (horizontal) {
        expect(bounds.left, lessThanOrEqualTo(1), reason: '$edge の左枠');
        expect(bounds.right, greaterThanOrEqualTo(98), reason: '$edge の右枠');
      } else {
        expect(bounds.top, lessThanOrEqualTo(1), reason: '$edge の上枠');
        expect(bounds.bottom, greaterThanOrEqualTo(98), reason: '$edge の下枠');
      }

      switch (edge) {
        case WallEdge.top:
          expect(bounds.top, lessThanOrEqualTo(5), reason: '上壁との間隔');
        case WallEdge.right:
          expect(bounds.right, greaterThanOrEqualTo(98), reason: '右壁との間隔');
        case WallEdge.bottom:
          expect(bounds.bottom, greaterThanOrEqualTo(98), reason: '下壁との間隔');
        case WallEdge.left:
          expect(bounds.left, lessThanOrEqualTo(1), reason: '左壁との間隔');
      }
    }
  });

  test('間取りの移動とサイズ変更に所属するドアが追従する', () {
    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    final room = state.objects.first;
    state.addOpening(PlanObjectKind.door, 3000, 1500);
    final door = state.objects.last;
    final originalDoorX = door.xMm;
    final originalDoorY = door.yMm;

    state.moveObjectBy(room, 500, 250);
    expect(door.xMm, originalDoorX + 500);
    expect(door.yMm, originalDoorY + 250);

    state.resizeObjectBy(room, 500, 0);
    expect(door.xMm, room.xMm + room.widthMm);
    expect(door.wallEdge, WallEdge.right);
    state.dispose();
  });

  test('同じ壁区間へドアや窓を重複配置できない', () {
    final state = AppState();
    state.addLayout(1000, 1000, 3000, 2000);

    expect(
      state.addOpening(PlanObjectKind.door, 1500, 1000),
      OpeningAddResult.added,
    );
    expect(
      state.addOpening(PlanObjectKind.window, 1500, 1000),
      OpeningAddResult.overlaps,
    );
    expect(state.objects, hasLength(2));

    expect(
      state.addOpening(PlanObjectKind.window, 2000, 1000),
      OpeningAddResult.added,
    );
    expect(state.objects, hasLength(3));
    state.dispose();
  });

  test('ドアや窓の移動と拡大でも他の開口へ重ねられない', () {
    final state = AppState();
    state.addLayout(1000, 1000, 3000, 2000);
    state.addOpening(PlanObjectKind.door, 1500, 1000);
    final first = state.objects.last;
    state.addOpening(PlanObjectKind.window, 2500, 1000);
    final second = state.objects.last;
    final secondX = second.xMm;

    state.moveObjectBy(second, -750, 0);
    expect(second.xMm, secondX);

    state.resizeObjectBy(first, 1000, 0);
    expect(first.widthMm, 500);
    state.dispose();
  });

  test('窓を開口幅を保ったまま別の間取りの壁へ移動できる', () {
    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    final firstRoom = state.objects.first;
    state.addLayout(4000, 1000, 2000, 2000);
    final secondRoom = state.objects.last;
    state.addOpening(PlanObjectKind.window, 2000, 1000);
    final window = state.objects.last;
    final originalLength = window.widthMm;

    expect(state.moveOpeningTo(window, 4000, 2000), isTrue);
    expect(window.wallId, secondRoom.id);
    expect(window.wallId, isNot(firstRoom.id));
    expect(window.wallEdge, WallEdge.left);
    expect(window.heightMm, originalLength);
    state.dispose();
  });

  test('ドアを反転状態と開口幅を保ったまま別の向きの壁へ移動できる', () {
    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    state.addLayout(4000, 1000, 2000, 2000);
    final secondRoom = state.objects.last;
    state.addOpening(PlanObjectKind.door, 2000, 1000);
    final door = state.objects.last;
    final originalLength = door.widthMm;
    state.flipDoor(door);
    expect(state.moveOpeningTo(door, 2000, 750), isTrue);
    expect(door.opensOutward, isTrue);

    expect(state.moveOpeningTo(door, 4000, 2000), isTrue);
    expect(door.wallId, secondRoom.id);
    expect(door.wallEdge, WallEdge.left);
    expect(door.widthMm, originalLength);
    expect(door.heightMm, originalLength);
    expect(door.flipped, isTrue);
    expect(door.opensOutward, isTrue);
    state.dispose();
  });

  test('ドアを同じ壁の内外へ移動すると内開きと外開きが切り替わる', () {
    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    state.addOpening(PlanObjectKind.door, 2000, 1000);
    final door = state.objects.last;

    expect(door.opensOutward, isFalse);
    expect(state.moveOpeningTo(door, 2000, 750), isTrue);
    expect(door.wallEdge, WallEdge.top);
    expect(door.opensOutward, isTrue);

    expect(state.moveOpeningTo(door, 2000, 1250), isTrue);
    expect(door.wallEdge, WallEdge.top);
    expect(door.opensOutward, isFalse);
    state.dispose();
  });

  testWidgets('ドアを選択後の通常ドラッグで壁の反対側へまたぐと外開きになる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    state.addOpening(PlanObjectKind.door, 2000, 1000);
    final door = state.objects.last;
    state.select(null);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final doorTarget = find.byKey(ValueKey('object-${door.id}'));
    final inwardTop = tester.getTopLeft(doorTarget).dy;
    await tester.tap(doorTarget);
    await tester.pumpAndSettle();
    expect(state.selectedId, door.id);

    await tester.drag(doorTarget, const Offset(0, -20));
    await tester.pumpAndSettle();

    expect(door.opensOutward, isTrue);
    expect(tester.getTopLeft(doorTarget).dy, lessThan(inwardTop));

    state.undo();
    await tester.pumpAndSettle();
    expect(
      state.objects.firstWhere((item) => item.id == door.id).opensOutward,
      isFalse,
    );
    state.dispose();
  });

  testWidgets('窓を選択後の通常ドラッグで別の間取りの壁へ移動できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    state.addLayout(4000, 1000, 2000, 2000);
    final secondRoom = state.objects.last;
    state.addOpening(PlanObjectKind.window, 2000, 1000);
    final window = state.objects.last;
    state.select(null);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final windowTarget = find.byKey(ValueKey('object-${window.id}'));
    final wallTarget = find.byKey(
      ValueKey('layout-edge-${secondRoom.id}-left'),
    );
    final originalWallId = window.wallId;
    final originalX = window.xMm;
    final originalY = window.yMm;

    await tester.drag(windowTarget, const Offset(80, 60));
    await tester.pumpAndSettle();
    expect(window.wallId, originalWallId);
    expect(window.xMm, originalX);
    expect(window.yMm, originalY);

    await tester.tap(windowTarget);
    await tester.pumpAndSettle();
    expect(state.selectedId, window.id);

    final gesture = await tester.startGesture(tester.getCenter(windowTarget));
    await gesture.moveTo(tester.getCenter(wallTarget));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(window.wallId, secondRoom.id);
    expect(window.wallEdge, WallEdge.left);
    state.dispose();
  });

  test('ドアの左右反転で描画位置も反転する', () async {
    final normalCenter = await doorInkCenterX(flipped: false);
    final flippedCenter = await doorInkCenterX(flipped: true);

    expect(normalCenter, lessThan(50));
    expect(flippedCenter, greaterThan(50));
  });

  test('ドアを左右反転して元に戻せる', () {
    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    state.addOpening(PlanObjectKind.door, 3000, 2000);
    final door = state.objects.last;

    expect(door.flipped, isFalse);
    state.flipDoor(door);
    expect(door.flipped, isTrue);
    state.undo();
    expect(
      state.objects.firstWhere((item) => item.id == door.id).flipped,
      isFalse,
    );
    state.dispose();
  });

  testWidgets('選択したドアを下部バーから左右反転できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    state.addOpening(PlanObjectKind.door, 3000, 2000);
    final door = state.objects.last;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('ドアを左右反転'));
    await tester.pumpAndSettle();
    expect(door.flipped, isTrue);
    state.dispose();
  });

  testWidgets('選択した開き戸を下部バーから内開き外開き切替できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    state.addOpening(PlanObjectKind.door, 2000, 1000);
    final door = state.objects.last;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(door.opensOutward, isFalse);
    await tester.tap(find.byTooltip('外開きに変更'));
    await tester.pumpAndSettle();
    expect(door.opensOutward, isTrue);
    expect(find.byTooltip('内開きに変更'), findsOneWidget);
    state.dispose();
  });

  testWidgets('選択したスライド戸は下部バーから引き方向を反転できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    state.addOpening(
      PlanObjectKind.door,
      2000,
      1000,
      doorType: DoorType.sliding,
    );
    final door = state.objects.last;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('外開きに変更'), findsNothing);
    await tester.tap(find.byTooltip('引き方向を反転'));
    await tester.pumpAndSettle();
    expect(door.flipped, isTrue);
    expect(door.opensOutward, isFalse);
    state.dispose();
  });

  test('間取りの縮小でドアと窓が重なる場合はサイズを変更しない', () {
    final state = AppState();
    state.addLayout(1000, 1000, 3000, 2000);
    final room = state.objects.first;
    state.addOpening(PlanObjectKind.door, 1500, 1000);
    state.addOpening(PlanObjectKind.window, 3500, 1000);
    final originalWidth = room.widthMm;
    final openingPositions = state.objects
        .where((item) => item.isWallAttached)
        .map((item) => item.xMm)
        .toList();

    state.resizeObjectBy(room, -2000, 0);

    expect(room.widthMm, originalWidth);
    expect(
      state.objects
          .where((item) => item.isWallAttached)
          .map((item) => item.xMm),
      openingPositions,
    );
    state.dispose();
  });

  test('トイレは500mm x 1000mmで中心グリッドへ配置される', () {
    final state = AppState();
    state.addToilet(1000, 1000);

    final toilet = state.objects.single;
    expect(toilet.kind, PlanObjectKind.fixture);
    expect(toilet.widthMm, 500);
    expect(toilet.heightMm, 1000);
    expect(toilet.xMm % AppState.gridMm, 0);
    expect(toilet.yMm % AppState.gridMm, 0);
    state.dispose();
  });

  test('トイレを90度単位で回転し中心・角度・保存値を維持する', () {
    final state = AppState();
    state.addToilet(2000, 2000);
    final toilet = state.objects.single;
    final centerX = toilet.xMm + toilet.widthMm / 2;
    final centerY = toilet.yMm + toilet.heightMm / 2;

    state.rotateToilet(toilet);
    expect(toilet.rotationQuarterTurns, 1);
    expect(toilet.rotationDegrees, 90);
    expect(toilet.widthMm, 1000);
    expect(toilet.heightMm, 500);
    expect(toilet.xMm + toilet.widthMm / 2, centerX);
    expect(toilet.yMm + toilet.heightMm / 2, centerY);

    state.rotateToilet(toilet);
    expect(toilet.rotationDegrees, 180);
    expect(toilet.widthMm, 500);
    expect(toilet.heightMm, 1000);

    final restored = PlanObject.fromJson(toilet.toJson());
    expect(restored.rotationDegrees, 180);
    state.undo();
    expect(state.objects.single.rotationDegrees, 90);
    state.dispose();
  });

  test('トイレ記号の描画も90度回転する', () async {
    final vertical = await toiletInkCenter(
      width: 100,
      height: 200,
      rotationQuarterTurns: 0,
    );
    final horizontal = await toiletInkCenter(
      width: 200,
      height: 100,
      rotationQuarterTurns: 1,
    );

    expect(horizontal.dx, closeTo(1 - vertical.dy, .04));
    expect(horizontal.dy, closeTo(vertical.dx, .04));
  });

  testWidgets('選択したトイレを下部バーから90度回転できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addToilet(2000, 2000);
    final toilet = state.objects.single;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('トイレを90度回転'));
    await tester.pumpAndSettle();

    expect(toilet.rotationDegrees, 90);
    expect(toilet.widthMm, 1000);
    expect(toilet.heightMm, 500);
    expect(find.textContaining('90°'), findsOneWidget);
    state.dispose();
  });

  test('間取りの作成を元に戻してやり直せる', () {
    final state = AppState();
    state.addLayout(0, 0, 1000, 1000);
    expect(state.objects, hasLength(1));

    state.undo();
    expect(state.objects, isEmpty);
    state.redo();
    expect(state.objects, hasLength(1));
    state.dispose();
  });

  test('窓だけを削除しても間取りと設備は残る', () {
    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    final room = state.objects.first;
    state.addToilet(2000, 2000);
    final toilet = state.objects.last;
    state.addOpening(PlanObjectKind.window, 2000, 1000);
    final window = state.objects.last;

    state.select(window.id);
    state.deleteSelected();

    expect(
      state.objects.map((item) => item.id),
      containsAll([room.id, toilet.id]),
    );
    expect(state.objects.map((item) => item.id), isNot(contains(window.id)));
    expect(state.objects, hasLength(2));
    state.dispose();
  });

  test('ドアだけを削除して元に戻せる', () {
    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    final room = state.objects.first;
    state.addOpening(PlanObjectKind.door, 3000, 2000);
    final door = state.objects.last;

    state.select(door.id);
    state.deleteSelected();
    expect(state.objects, [room]);

    state.undo();
    expect(
      state.objects.map((item) => item.id),
      containsAll([room.id, door.id]),
    );
    state.dispose();
  });

  test('間取りを削除した場合だけ所属するドアと窓も削除する', () {
    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    final room = state.objects.first;
    state.addToilet(2000, 2000);
    final toilet = state.objects.last;
    state.addOpening(PlanObjectKind.door, 3000, 2000);
    state.addOpening(PlanObjectKind.window, 2000, 1000);

    state.select(room.id);
    state.deleteSelected();

    expect(state.objects, hasLength(1));
    expect(state.objects.single.id, toilet.id);
    expect(state.objects.single.kind, PlanObjectKind.fixture);
    state.dispose();
  });

  test('トイレ設備だけを削除しても間取りと窓は残る', () {
    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    final room = state.objects.first;
    state.addToilet(2000, 2000);
    final toilet = state.objects.last;
    state.addOpening(PlanObjectKind.window, 2000, 1000);
    final window = state.objects.last;

    state.select(toilet.id);
    state.deleteSelected();

    expect(
      state.objects.map((item) => item.id),
      containsAll([room.id, window.id]),
    );
    expect(state.objects.map((item) => item.id), isNot(contains(toilet.id)));
    expect(state.objects, hasLength(2));
    state.dispose();
  });

  test('手すりだけを削除しても図面オブジェクトは残る', () {
    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    final room = state.objects.single;
    state.addHandrail(1250, 1250, 2000, 1250);
    final rail = state.lines.single;

    state.select(rail.id);
    state.deleteSelected();

    expect(state.objects, [room]);
    expect(state.lines, isEmpty);
    state.dispose();
  });

  test('手すりは近くの壁やドアに影響されず指定した長さで配置される', () {
    final state = AppState();
    state.addLayout(1000, 1000, 3000, 3000);
    expect(
      state.addOpening(PlanObjectKind.door, 2500, 1000),
      OpeningAddResult.added,
    );
    state.addHandrail(1250, 1250, 3750, 1250);

    final line = state.lines.single;
    expect(state.handrailPath(line).points.last.xMm, 3750);
    expect(line.lengthMm, 2500);
    state.dispose();
  });

  test('手すりの近くにもドアを配置できる', () {
    final state = AppState();
    state.addLayout(1000, 1000, 3000, 3000);
    state.addHandrail(1250, 1250, 2750, 1250);

    expect(
      state.addOpening(PlanObjectKind.door, 2000, 1000),
      OpeningAddResult.added,
    );
    expect(
      state.objects.where((object) => object.kind == PlanObjectKind.door),
      hasLength(1),
    );
    state.dispose();
  });

  test('端点接続した手すりは編集単位を保ち見積とNoでは1件になる', () {
    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    state.addHandrail(1250, 1250, 2750, 1250);
    state.addHandrail(2750, 1250, 2750, 2500);

    expect(state.lines, hasLength(2));
    final groups = state.handrailEstimateGroups();
    expect(groups, hasLength(1));
    expect(groups.single.lines, hasLength(2));
    expect(groups.single.lengthMm, 2750);
    expect(
      state.constructionNumberFor(state.lines.last),
      state.lines.first.constructionNumber,
    );

    final cost = state.costForGroup(groups.single);
    expect(cost.jointCount, 5);
    expect(cost.railCost, 12100);
    expect(cost.jointCost, 6250);
    expect(cost.total, 18350);
    expect(state.materialCostTotal, 18350);

    final document = DocumentExportData.fromState(state);
    expect(document.lines, hasLength(1));
    expect(document.lines.single.costAmount, 18350);
    expect(document.lines.single.specification, contains('L字'));

    final json = state.toJson();
    final project = (json['projects'] as List).single as Map<String, dynamic>;
    final estimate = project['estimate'] as Map<String, dynamic>;
    final rows = estimate['handrails'] as List;
    expect(rows, hasLength(1));
    expect(
      (rows.single as Map<String, dynamic>)['componentHandrailIds'],
      hasLength(2),
    );
    expect(estimate['materialCostTotal'], 18350);

    state.addHandrail(1000, 4000, 2000, 4000);
    expect(state.handrailEstimateGroups(), hasLength(2));
    expect(state.constructionNumberFor(state.lines.last), '2');
    state.dispose();
  });

  test('間取りは作成と移動で前面になりサイズ変更では順序を変えない', () {
    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    final first = state.objects.single;
    state.addLayout(2000, 500, 2000, 2000);
    final second = state.objects.last;

    expect(
      state.objects
          .where((object) => object.kind == PlanObjectKind.layout)
          .map((object) => object.id),
      [first.id, second.id],
    );

    state.moveObjectBy(first, -250, 0);
    expect(
      state.objects
          .where((object) => object.kind == PlanObjectKind.layout)
          .map((object) => object.id),
      [second.id, first.id],
    );

    state.resizeObjectBy(second, 250, 250);
    expect(
      state.objects
          .where((object) => object.kind == PlanObjectKind.layout)
          .map((object) => object.id),
      [second.id, first.id],
    );
    state.dispose();
  });

  test('部分重複では前面の間取りが覆う背面の縁を検出する', () {
    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    final back = state.objects.single;
    state.addLayout(2000, 500, 2000, 2000);
    final front = state.objects.last;

    final occlusions = state.layoutWallOcclusionsFor(back);
    expect(occlusions.map((gap) => gap.edge).toSet(), {
      WallEdge.top,
      WallEdge.right,
    });
    expect(state.layoutWallOcclusionsFor(front), isEmpty);
    state.dispose();
  });

  test('描画順が変わっても既存の間取り所属判定は変更しない', () {
    final state = AppState();
    state.addLayout(1000, 1000, 1000, 1000);
    final smaller = state.objects.single..place = '小さい間取り';
    state.addLayout(1500, 500, 2000, 2000);

    expect(state.layoutAt(1750, 1500), same(smaller));
    state.dispose();
  });

  testWidgets('部分重複した背面間取りの縁を描画から除外する', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    final back = state.objects.single;
    state.addLayout(2000, 500, 2000, 2000);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<LayoutPainter>()
        .toList();
    expect(painters, hasLength(2));
    expect(painters.first.wallGaps.map((gap) => gap.edge).toSet(), {
      WallEdge.top,
      WallEdge.right,
    });
    expect(painters.last.wallGaps, isEmpty);

    state.moveObjectBy(back, -250, 0);
    state.changed();
    await tester.pump();
    painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<LayoutPainter>()
        .toList();
    expect(painters.first.wallGaps.map((gap) => gap.edge).toSet(), {
      WallEdge.bottom,
      WallEdge.left,
    });
    expect(painters.last.wallGaps, isEmpty);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  test('完全に内包された間取りを外側間取りの領域から除外する', () {
    final state = AppState();
    state.addLayout(1000, 1000, 3000, 3000);
    final outer = state.objects.single;
    state.addLayout(1500, 1500, 1000, 1000);
    final inner = state.objects.last;
    expect(state.layoutWallOcclusionsFor(outer), isEmpty);
    expect(state.layoutWallOcclusionsFor(inner), isEmpty);
    state.addLayout(3750, 3750, 1000, 1000);
    final partial = state.objects.last;

    expect(state.containedLayouts(outer), [inner]);
    expect(state.containedLayouts(inner), isEmpty);
    expect(state.containedLayouts(outer), isNot(contains(partial)));
    expect(state.layoutContainsPoint(outer, 2000, 2000), isFalse);
    expect(state.layoutContainsPoint(inner, 2000, 2000), isTrue);
    expect(state.layoutContainsPoint(outer, 1250, 1250), isTrue);
    outer.place = '間取りA';
    inner.place = '間取りB';
    state.addHandrail(1750, 2000, 2250, 2000);
    expect(DocumentExportData.fromState(state).lines.single.location, '間取りB');
    state.dispose();
  });

  test('接触する間取りの共有壁区間を検出して表示状態を保存復元する', () async {
    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    final left = state.objects.single;
    state.addLayout(3000, 1500, 1000, 1000);
    final right = state.objects.last;

    final contact = state.sharedWallContactsFor(left).single;
    expect(contact.otherRoom, right);
    expect(contact.roomEdge, WallEdge.right);
    expect(contact.otherEdge, WallEdge.left);
    expect(contact.segment.horizontal, isFalse);
    expect(contact.segment.coordinateMm, 3000);
    expect(contact.segment.startMm, 1500);
    expect(contact.segment.endMm, 2500);
    expect(contact.visible, isTrue);

    state.setSharedWallVisible(contact, false);
    expect(state.sharedWallContactsFor(left).single.visible, isFalse);
    expect(state.sharedWallContactsFor(right).single.visible, isFalse);

    final restored = AppState(dataRepository: MemoryAppDataRepository());
    await restored.importJson(state.exportJson());
    final restoredLeft = restored.objects.first;
    expect(
      restored.sharedWallContactsFor(restoredLeft).single.visible,
      isFalse,
    );

    restored.setSharedWallVisible(
      restored.sharedWallContactsFor(restoredLeft).single,
      true,
    );
    expect(restored.sharedWallOverrides, isEmpty);
    expect(restored.sharedWallContactsFor(restoredLeft).single.visible, isTrue);
    state.dispose();
    restored.dispose();
  });

  test('間取りを共有壁から離すと古い壁表示設定を破棄する', () {
    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    final left = state.objects.single;
    state.addLayout(3000, 1000, 1000, 1000);
    final right = state.objects.last;
    state.setSharedWallVisible(state.sharedWallContactsFor(left).single, false);

    state.moveObjectBy(right, 250, 0);

    expect(state.sharedWallContactsFor(left), isEmpty);
    expect(state.sharedWallOverrides, isEmpty);
    state.dispose();
  });

  testWidgets('選択した間取りの共有壁ボタンから壁を消して再表示できる', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addLayout(1000, 1000, 2000, 2000);
    final left = state.objects.single;
    state.addLayout(3000, 1000, 1000, 1000);
    state.select(left.id);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) => DrawingScreen(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('共有壁を編集'), findsOneWidget);
    final outerPainter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<LayoutPainter>()
        .where((painter) => painter.selected)
        .single;
    expect(outerPainter.wallGaps, isEmpty);

    await tester.tap(find.byTooltip('共有壁を編集'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shared-wall-hide')));
    await tester.pumpAndSettle();
    expect(state.sharedWallContactsFor(left).single.visible, isFalse);

    await tester.tap(find.byTooltip('共有壁を編集'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shared-wall-show')));
    await tester.pumpAndSettle();
    expect(state.sharedWallContactsFor(left).single.visible, isTrue);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('内包された間取りを外側の描画からくり抜く', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    state.addLayout(1000, 1000, 3000, 3000);
    state.addLayout(1500, 1500, 1000, 1000);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DrawingScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();

    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<LayoutPainter>()
        .toList();
    expect(
      painters.where((painter) => painter.cutouts.length == 1),
      hasLength(1),
    );
    expect(painters.where((painter) => painter.cutouts.isEmpty), hasLength(1));
    expect(tester.takeException(), isNull);
    state.dispose();
  });
}

Future<double> doorInkCenterX({required bool flipped}) async {
  const size = ui.Size(100, 100);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  DoorPainter(
    edge: WallEdge.top,
    selected: false,
    flipped: flipped,
  ).paint(canvas, size);
  final image = await recorder.endRecording().toImage(100, 100);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  image.dispose();

  var weightedX = 0;
  var darkPixelCount = 0;
  for (var y = 0; y < 100; y++) {
    for (var x = 0; x < 100; x++) {
      final offset = (y * 100 + x) * 4;
      final isDarkStroke =
          bytes[offset + 3] > 0 &&
          bytes[offset] < 100 &&
          bytes[offset + 1] < 100 &&
          bytes[offset + 2] < 100;
      if (!isDarkStroke) continue;
      weightedX += x;
      darkPixelCount++;
    }
  }
  return weightedX / darkPixelCount;
}

Future<ui.Rect> slidingDoorInkBounds(WallEdge edge) async {
  const dimension = 100;
  const size = ui.Size.square(100);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  DoorPainter(
    edge: edge,
    selected: false,
    flipped: false,
    doorType: DoorType.sliding,
  ).paint(canvas, size);
  final image = await recorder.endRecording().toImage(dimension, dimension);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  image.dispose();

  var minX = dimension;
  var minY = dimension;
  var maxX = 0;
  var maxY = 0;
  for (var y = 0; y < dimension; y++) {
    for (var x = 0; x < dimension; x++) {
      final offset = (y * dimension + x) * 4;
      final isDarkStroke =
          bytes[offset + 3] > 0 &&
          bytes[offset] < 100 &&
          bytes[offset + 1] < 120 &&
          bytes[offset + 2] < 130;
      if (!isDarkStroke) continue;
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }
  }
  return ui.Rect.fromLTRB(
    minX.toDouble(),
    minY.toDouble(),
    maxX.toDouble(),
    maxY.toDouble(),
  );
}

Future<ui.Offset> toiletInkCenter({
  required int width,
  required int height,
  required int rotationQuarterTurns,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  ToiletPainter(
    selected: false,
    rotationQuarterTurns: rotationQuarterTurns,
  ).paint(canvas, ui.Size(width.toDouble(), height.toDouble()));
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  image.dispose();

  var weightedX = 0;
  var weightedY = 0;
  var darkPixelCount = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final offset = (y * width + x) * 4;
      final isDarkStroke =
          bytes[offset + 3] > 0 &&
          bytes[offset] < 100 &&
          bytes[offset + 1] < 100 &&
          bytes[offset + 2] < 100;
      if (!isDarkStroke) continue;
      weightedX += x;
      weightedY += y;
      darkPixelCount++;
    }
  }
  return ui.Offset(
    weightedX / darkPixelCount / width,
    weightedY / darkPixelCount / height,
  );
}

XmlDocument _archiveXml(Archive archive, String path) {
  final file = archive.findFile(path);
  if (file == null) throw StateError('$path not found');
  return XmlDocument.parse(utf8.decode(file.content));
}

String _cellValue(XmlDocument sheet, String reference) {
  final cell = sheet
      .findAllElements('c')
      .where((element) => element.getAttribute('r') == reference)
      .single;
  final inlineText = cell.findAllElements('t').map((text) => text.innerText);
  if (inlineText.isNotEmpty) return inlineText.join();
  return cell.findElements('v').firstOrNull?.innerText ?? '';
}

bool _rowIsHidden(XmlDocument sheet, int rowNumber) {
  final row = sheet
      .findAllElements('row')
      .where((element) => element.getAttribute('r') == '$rowNumber')
      .single;
  return row.getAttribute('hidden') == '1';
}
