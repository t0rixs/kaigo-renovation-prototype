part of '../widget_test.dart';

RenovationPhotoLocation _addPhotoHandrail(
  AppState state, {
  required int centerX,
  required int centerY,
}) {
  state.addHandrail(centerX - 250, centerY, centerX + 250, centerY);
  final line = state.lines.last;
  return state.photoLocations.singleWhere(
    (location) => location.handrailIds.contains(line.id),
  );
}

void registerAppDataDocumentsTests() {
  group('アプリ・データ・帳票', () {
    test('カメラ権限ダイアログのinactiveでは初期化を中断しない', () {
      expect(
        shouldReleaseCameraForLifecycle(AppLifecycleState.inactive),
        isFalse,
      );
      expect(shouldReleaseCameraForLifecycle(AppLifecycleState.paused), isTrue);
    });

    test('ブラウザでは未対応のフラッシュ操作を表示しない', () {
      expect(cameraFlashControlsAvailable(isWeb: true), isFalse);
      expect(cameraFlashControlsAvailable(isWeb: false), isTrue);
    });

    test('Webシェルもライト配色だけを宣言する', () {
      final html = File('web/index.html').readAsStringSync();

      expect(html, contains('name="color-scheme" content="light"'));
      expect(html, contains('name="supported-color-schemes" content="light"'));
      expect(html, contains('color-scheme: only light'));
    });

    testWidgets('トップから案件を選び5画面を表示できる', (tester) async {
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
      expect(
        find.byType(CupertinoSlidingSegmentedControl<int>),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CupertinoSlidingSegmentedControl<int>>(
              find.byType(CupertinoSlidingSegmentedControl<int>),
            )
            .groupValue,
        0,
      );
      expect(find.byType(CupertinoTabBar), findsNothing);
      expect(find.text('基本情報'), findsNothing);
      expect(find.text('山田 太郎様邸 住宅改修工事'), findsOneWidget);
      expect(find.text('山田 太郎'), findsOneWidget);
      expect(find.text('福岡市西区小戸1丁目'), findsOneWidget);
      expect(find.textContaining('最終更新'), findsOneWidget);

      await tester.tap(find.text('山田 太郎様邸 住宅改修工事'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoTabBar), findsOneWidget);
      expect(
        tester
            .widget<CupertinoTabBar>(find.byType(CupertinoTabBar))
            .currentIndex,
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
      await tester.tap(find.byKey(const ValueKey('project-back-button')));
      await tester.pumpAndSettle();
      expect(find.text('施工箇所図面'), findsOneWidget);

      await tester.tap(find.text('品番').last);
      await tester.pumpAndSettle();
      expect(find.text('デフォルト品番'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('施工箇所図面'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('写真').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('photos-screen')), findsOneWidget);
      expect(find.byKey(const ValueKey('move-photo-location')), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-side-menu')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('project-back-button')));
      await tester.pumpAndSettle();
      expect(find.text('施工箇所図面'), findsOneWidget);

      await tester.tap(find.text('書類').last);
      await tester.pumpAndSettle();
      expect(find.text('原価'), findsOneWidget);
      expect(find.text('見積書'), findsOneWidget);
      expect(find.textContaining('材料原価 1件'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('document-material-cost')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('document-cost-details')), findsNothing);
      expect(find.text('見積書表紙'), findsNothing);
      expect(find.text('見積書内容'), findsNothing);
      expect(find.byKey(const ValueKey('excel-export-button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('project-back-button')));
      await tester.pumpAndSettle();
      expect(find.text('施工箇所図面'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('project-back-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('top-navigation')), findsOneWidget);
      expect(find.text('山田 太郎様邸 住宅改修工事'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('システムがダークモードでもライトテーマを維持する', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(
        RenovationApp(
          appState: AppState(dataRepository: MemoryAppDataRepository()),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(
        find.byKey(const ValueKey('top-navigation')),
      );
      expect(Theme.of(context).brightness, Brightness.light);
      expect(CupertinoTheme.of(context).brightness, Brightness.light);
      expect(tester.takeException(), isNull);
    });

    testWidgets('文字を200パーセントに拡大しても主要ナビゲーションを操作できる', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        RenovationApp(
          appState: AppState(dataRepository: MemoryAppDataRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('top-navigation')), findsOneWidget);
      await tester.tap(find.text('山田 太郎様邸 住宅改修工事'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoTabBar), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('drawing-toolbar'))).height,
        greaterThan(68),
      );
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
          postPrice: 4000,
          maxJointIntervalMm: 1000,
          defaultEndBracketId: 'EB-35-WH',
          defaultIntermediateBracketId: 'MB-35-WH',
          defaultLJointId: 'CJ-L-35',
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
      expect(
        find.byKey(const ValueKey('document-material-cost')),
        findsNothing,
      );
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
      expect(state.materialCostTotal, 7000);
      expect(find.text('¥7,000'), findsWidgets);
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
      expect(
        find.byType(CupertinoSlidingSegmentedControl<int>),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CupertinoSlidingSegmentedControl<int>>(
              find.byType(CupertinoSlidingSegmentedControl<int>),
            )
            .groupValue,
        1,
      );
      expect(find.byType(CupertinoTabBar), findsNothing);
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
      expect(restored.objects, hasLength(3));
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
      expect(productMaster['jointProducts'], hasLength(9));
      expect(project['basicInfo'], isA<Map<String, dynamic>>());
      expect(project['documents'], isA<Map<String, dynamic>>());
      expect(project['photos'], isA<List<dynamic>>());
      expect(drawing['canvas'], {'widthMm': 10000, 'heightMm': 7500});
      expect(drawing['objects'], hasLength(3));
      expect(drawing['handrails'], hasLength(1));
      expect(estimate['handrails'], hasLength(1));
      final estimateRow = (estimate['handrails'] as List).single as Map;
      expect(estimateRow['endBracketCount'], 2);
      expect(estimateRow['intermediateBracketCount'], 0);
      expect(estimateRow['connectionJointCount'], 0);
      expect(estimate['materialCostTotal'], 5800);
      state.dispose();
    });

    testWidgets('手すり商品の標準部品3種を編集画面を開かず変更できる', (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState(dataRepository: MemoryAppDataRepository());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProductsScreen(state: state)),
        ),
      );
      await tester.pumpAndSettle();

      final product = state.products.first;
      expect(
        find.byKey(ValueKey('product-${product.id}-end-bracket')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('product-${product.id}-middle-bracket')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('product-${product.id}-l-joint')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('add-joint-product')), findsOneWidget);
      await tester.tap(
        find.byKey(ValueKey('product-${product.id}-end-bracket')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('EB-35-BR').last);
      await tester.pumpAndSettle();
      expect(product.defaultEndBracketId, 'EB-35-BR');
      expect(tester.takeException(), isNull);
      state.dispose();
    });

    test('改修場所と施工前後の写真を案件JSONへ保存できる', () async {
      final repository = MemoryAppDataRepository();
      final state = AppState(dataRepository: repository);
      final location = _addPhotoHandrail(state, centerX: 1250, centerY: 1750);
      final before = CapturedProjectPhoto(
        base64Data: 'YmVmb3Jl',
        mimeType: 'image/jpeg',
        fileName: 'before.jpg',
        capturedAt: DateTime(2026, 7, 22, 10, 30),
      );
      final after = CapturedProjectPhoto(
        base64Data: 'YWZ0ZXI=',
        mimeType: 'image/jpeg',
        fileName: 'after.jpg',
        capturedAt: DateTime(2026, 7, 22, 11, 30),
      );

      expect(
        state.setProjectPhoto(
          projectId: state.activeProject.id,
          locationId: location.id,
          slot: ProjectPhotoSlot.before,
          photo: before,
        ),
        isTrue,
      );
      expect(
        state.setProjectPhoto(
          projectId: state.activeProject.id,
          locationId: location.id,
          slot: ProjectPhotoSlot.after,
          photo: after,
        ),
        isTrue,
      );
      expect(
        state.setProjectPhotoMemo(
          projectId: state.activeProject.id,
          locationId: location.id,
          slot: ProjectPhotoSlot.before,
          value: '施工前は壁面に段差あり',
        ),
        isTrue,
      );
      expect(
        state.setProjectPhotoMemo(
          projectId: state.activeProject.id,
          locationId: location.id,
          slot: ProjectPhotoSlot.after,
          value: '手すり取付後',
        ),
        isTrue,
      );
      await state.saveNow();

      final restored = AppState(dataRepository: repository);
      await restored.load();
      expect(restored.photoLocations, hasLength(1));
      expect(restored.photoLocations.single.locationName, '場所未設定');
      expect(restored.photoLocations.single.xMm, 1250);
      expect(restored.photoLocations.single.yMm, 1750);
      expect(restored.photoLocations.single.handrailNumber, '1');
      expect(restored.photoLocations.single.handrailIds, hasLength(1));
      expect(
        restored.photoLocations.single.beforePhoto?.base64Data,
        'YmVmb3Jl',
      );
      expect(restored.photoLocations.single.afterPhoto?.base64Data, 'YWZ0ZXI=');
      expect(restored.photoLocations.single.beforeMemo, '施工前は壁面に段差あり');
      expect(restored.photoLocations.single.afterMemo, '手すり取付後');
      state.dispose();
      restored.dispose();
    });

    test('写真位置は屋内外や作成順に関係なく手すりNoの数値順に並ぶ', () {
      final state = AppState(dataRepository: MemoryAppDataRepository());
      for (var index = 0; index < 5; index++) {
        state.addHandrail(1000, 1000 + index * 500, 1500, 1000 + index * 500);
      }
      state.lines[3].constructionNumber = '5';
      state.lines[4]
        ..constructionNumber = '4'
        ..environment = HandrailEnvironment.outdoor
        ..installationType = HandrailInstallationType.freestanding
        ..productId = state.defaultProductIdFor(HandrailEnvironment.outdoor);
      state.changed();

      expect(state.photoLocations.map((location) => location.handrailNumber), [
        '1',
        '2',
        '3',
        '4',
        '5',
      ]);
      expect(
        DocumentExportData.fromState(state).photos.map((photo) => photo.number),
        ['1', '2', '3', '4', '5'],
      );
      state.dispose();
    });

    testWidgets('写真画面は手すりNoの写真位置を自動表示し写真を記録できる', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState(dataRepository: MemoryAppDataRepository());
      final location = _addPhotoHandrail(state, centerX: 1250, centerY: 1750);
      final photo = CapturedProjectPhoto(
        base64Data:
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        mimeType: 'image/png',
        fileName: 'camera.png',
        capturedAt: DateTime(2026, 7, 22),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotosScreen(state: state, capturePhoto: () async => photo),
          ),
        ),
      );

      final workspaceSize = tester.getSize(
        find.byKey(const ValueKey('photo-drawing-workspace')),
      );
      final planSize = tester.getSize(
        find.byKey(const ValueKey('photo-plan-canvas')),
      );
      expect(workspaceSize.width - planSize.width, 640);
      expect(workspaceSize.height - planSize.height, 640);

      expect(location.xMm % AppState.gridMm, 0);
      expect(location.yMm % AppState.gridMm, 0);
      expect(location.handrailNumber, '1');
      expect(find.byKey(const ValueKey('add-photo-location')), findsNothing);
      expect(find.byKey(const ValueKey('photo-side-menu')), findsOneWidget);
      expect(find.text('場所未設定'), findsOneWidget);
      expect(find.text('改修前'), findsOneWidget);
      expect(find.text('改修後'), findsOneWidget);
      expect(
        find.byKey(ValueKey('photo-before-${location.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('photo-after-${location.id}')),
        findsOneWidget,
      );
      final beforeMemo = find.byKey(
        ValueKey('photo-memo-before-${location.id}'),
      );
      final afterMemo = find.byKey(ValueKey('photo-memo-after-${location.id}'));
      expect(beforeMemo, findsOneWidget);
      expect(afterMemo, findsOneWidget);
      await tester.ensureVisible(beforeMemo);
      await tester.enterText(beforeMemo, '施工前メモ');
      await tester.ensureVisible(afterMemo);
      await tester.enterText(afterMemo, '施工後メモ');
      expect(location.beforeMemo, '施工前メモ');
      expect(location.afterMemo, '施工後メモ');

      await tester.tap(find.byKey(ValueKey('photo-before-${location.id}')));
      await tester.pumpAndSettle();
      expect(find.text('撮影'), findsOneWidget);
      expect(find.text('画像を選択'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('photo-source-camera')));
      await tester.pumpAndSettle();
      expect(state.photoLocations.single.beforePhoto?.fileName, 'camera.png');
      expect(
        find.byKey(ValueKey('photo-image-before-${location.id}')),
        findsOneWidget,
      );
      expect(state.photoLocations.single.afterPhoto, isNull);
      expect(tester.takeException(), isNull);
      state.dispose();
    });

    testWidgets('写真枠から端末の画像を選択して保存できる', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState(dataRepository: MemoryAppDataRepository());
      final location = _addPhotoHandrail(state, centerX: 1250, centerY: 1750);
      final selectedPhoto = CapturedProjectPhoto(
        base64Data:
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        mimeType: 'image/png',
        fileName: 'library.png',
        capturedAt: DateTime(2026, 7, 23),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotosScreen(
              state: state,
              selectPhoto: () async => selectedPhoto,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('photo-marker-${location.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('photo-before-${location.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('photo-source-library')));
      await tester.pumpAndSettle();

      expect(location.beforePhoto?.fileName, 'library.png');
      expect(
        find.byKey(ValueKey('photo-image-before-${location.id}')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Image>(
              find.byKey(ValueKey('photo-image-before-${location.id}')),
            )
            .fit,
        BoxFit.contain,
      );
      expect(
        tester
            .widget<Padding>(
              find.byKey(ValueKey('photo-image-padding-before-${location.id}')),
            )
            .padding,
        const EdgeInsets.all(8),
      );

      await tester.tap(find.byKey(ValueKey('photo-before-${location.id}')));
      await tester.pumpAndSettle();
      expect(find.text('写真を削除'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('delete-project-photo')));
      await tester.pumpAndSettle();
      expect(location.beforePhoto, isNull);
      expect(tester.takeException(), isNull);
      state.dispose();
    });

    testWidgets('写真の移動ツールを維持して丸番号の移動と写真表示ができる', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState(dataRepository: MemoryAppDataRepository());
      final location = _addPhotoHandrail(state, centerX: 1000, centerY: 1000);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PhotosScreen(state: state)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('photo-toolbar')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('move-photo-location')));
      await tester.pump();
      expect(find.textContaining('移動：丸番号をドラッグ'), findsOneWidget);

      await tester.drag(
        find.byKey(ValueKey('photo-marker-${location.id}')),
        const Offset(48, 24),
      );
      await tester.pumpAndSettle();

      expect((location.xMm, location.yMm), isNot((1000, 1000)));
      expect(location.xMm % AppState.gridMm, 0);
      expect(location.yMm % AppState.gridMm, 0);
      expect(find.textContaining('移動：丸番号をドラッグ'), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-side-menu')), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('photo-marker-${location.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('photo-side-menu')), findsOneWidget);
      expect(find.textContaining('移動：丸番号をドラッグ'), findsOneWidget);
      expect(
        find.byKey(ValueKey('active-photo-marker-${location.id}')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('move-photo-location')));
      await tester.pumpAndSettle();
      expect(find.textContaining('移動：丸番号をドラッグ'), findsNothing);
      expect(tester.takeException(), isNull);
      state.dispose();
    });

    testWidgets('写真メニューを常時表示しスクロール中の手すりNoを図面中央へ表示する', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState(dataRepository: MemoryAppDataRepository());
      final first = _addPhotoHandrail(state, centerX: 1000, centerY: 1000);
      final second = _addPhotoHandrail(state, centerX: 5000, centerY: 3500);
      _addPhotoHandrail(state, centerX: 8500, centerY: 6500);
      state.select(null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PhotosScreen(state: state)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('photo-marker-${first.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('photo-side-menu')), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-bottom-menu')), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-right-menu')), findsNothing);
      expect(
        find.byKey(ValueKey('active-photo-marker-${first.id}')),
        findsOneWidget,
      );
      const visibleCanvasCenterX = 390 / 2;
      expect(
        tester.getCenter(find.byKey(ValueKey('photo-marker-${first.id}'))).dx,
        closeTo(visibleCanvasCenterX, 4),
      );
      expect(
        tester.getCenter(find.byKey(ValueKey('photo-marker-${first.id}'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('photo-bottom-menu'))).dy,
        ),
      );

      final canvasRect = tester.getRect(
        find.byKey(const ValueKey('photo-drawing-canvas')),
      );
      await tester.dragFrom(
        Offset(canvasRect.right - 28, canvasRect.top + 72),
        const Offset(-54, 36),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('photo-side-menu')), findsOneWidget);

      final animationStart = tester.getCenter(
        find.byKey(ValueKey('photo-marker-${first.id}')),
      );
      await tester.tap(find.byKey(ValueKey('photo-marker-${first.id}')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final animationMiddle = tester.getCenter(
        find.byKey(ValueKey('photo-marker-${first.id}')),
      );
      await tester.pump(const Duration(milliseconds: 150));
      final animationEnd = tester.getCenter(
        find.byKey(ValueKey('photo-marker-${first.id}')),
      );
      expect(animationStart.dx, isNot(closeTo(animationEnd.dx, 1)));
      expect(
        animationMiddle.dx,
        inExclusiveRange(
          math.min(animationStart.dx, animationEnd.dx),
          math.max(animationStart.dx, animationEnd.dx),
        ),
      );
      expect(animationEnd.dx, closeTo(visibleCanvasCenterX, 4));

      await tester.tapAt(const Offset(24, 360));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('photo-side-menu')), findsOneWidget);
      expect(state.selectedId, isNull);

      await tester.tap(find.byKey(ValueKey('photo-marker-${first.id}')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('photo-location-list')),
        const Offset(0, -330),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('active-photo-marker-${second.id}')),
        findsOneWidget,
      );
      expect(
        tester.getCenter(find.byKey(ValueKey('photo-marker-${second.id}'))).dx,
        closeTo(visibleCanvasCenterX, 4),
      );
      expect(state.selectedId, isNull);
      expect(tester.takeException(), isNull);
      state.dispose();
    });

    test('撮影画像は別Isolateで1280px以内のJPEGへ変換する', () async {
      final source = image.Image(width: 2000, height: 1000);
      final sourceBytes = image.encodeJpg(source, quality: 95);

      final processedBytes = await processCapturedPhoto(sourceBytes);
      final processed = image.decodeJpg(processedBytes);

      expect(processed, isNotNull);
      expect(processed!.width, 1280);
      expect(processed.height, 640);
    });

    testWidgets('撮影後の画像処理中は写真枠に進捗を表示する', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState(dataRepository: MemoryAppDataRepository());
      final location = _addPhotoHandrail(state, centerX: 1250, centerY: 1750);
      final capture = Completer<CapturedProjectPhoto?>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotosScreen(
              state: state,
              capturePhoto: () => capture.future,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('photo-marker-${location.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('photo-before-${location.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('photo-source-camera')));
      await tester.pump();
      expect(find.text('写真を処理中'), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      capture.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('写真を処理中'), findsNothing);
      state.dispose();
    });

    testWidgets('撮影中にアプリが再起動しても対象案件の写真一覧へ戻る', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = MemoryAppDataRepository();
      final savedState = AppState(dataRepository: repository);
      final firstProjectId = savedState.activeProject.id;
      final secondProject = savedState.createProject();
      secondProject.customer.projectName = '撮影中の案件';
      final location = _addPhotoHandrail(
        savedState,
        centerX: 1250,
        centerY: 1750,
      );
      await savedState.saveNow();
      await PhotoCaptureSession.begin(
        projectId: secondProject.id,
        locationId: location.id,
        slot: ProjectPhotoSlot.before,
      );
      savedState.selectProject(firstProjectId);
      await savedState.saveNow();
      savedState.dispose();

      final resumedState = AppState(dataRepository: repository);
      await tester.pumpWidget(RenovationApp(appState: resumedState));
      await tester.pumpAndSettle();

      expect(resumedState.activeProject.id, secondProject.id);
      expect(find.byKey(const ValueKey('photos-screen')), findsOneWidget);
      expect(find.text('写真'), findsWidgets);
      expect(find.text('場所未設定'), findsOneWidget);
      expect(
        tester
            .widget<CupertinoTabBar>(find.byType(CupertinoTabBar))
            .currentIndex,
        3,
      );
      expect(find.byKey(const ValueKey('top-navigation')), findsNothing);
      expect(tester.takeException(), isNull);
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

    test('図面の左上をリサイズすると配置物の見た目を保つ座標へ補正する', () {
      final state = AppState(dataRepository: MemoryAppDataRepository());
      state.addLayout(1000, 750, 2000, 1500);
      state.addHandrail(1500, 2500, 3000, 2500);
      final room = state.objects.single;
      final line = state.lines.single;

      expect(state.resizeCanvasFromEdge(CanvasResizeEdge.left, 10500), isTrue);
      expect(state.canvasWidthMm, 10500);
      expect(room.xMm, 1500);
      expect(line.x1Mm, 2000);
      expect(line.x2Mm, 3500);

      expect(state.resizeCanvasFromEdge(CanvasResizeEdge.top, 8000), isTrue);
      expect(state.canvasHeightMm, 8000);
      expect(room.yMm, 1250);
      expect(line.y1Mm, 3000);
      expect(line.y2Mm, 3000);

      expect(state.resizeCanvasFromEdge(CanvasResizeEdge.left, 8750), isFalse);
      expect(state.canvasWidthMm, 10500);
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

    test('補強板は手すり原価と分離した書類明細になり見積総額へ反映される', () {
      final state = AppState(dataRepository: MemoryAppDataRepository())
        ..addSample(notify: false);
      final line = state.lines.single..place = '浴室';
      final group = state.handrailEstimateGroups().single;
      final point = state.connectionPointsForGroup(group).first;
      state.setConnectionPointReinforcementPlate(group, point, true);
      final reinforcedPoint = state.connectionPointsForGroup(group).first;
      state.setConnectionPointReinforcementPlatePrice(
        group,
        reinforcedPoint,
        6200,
      );
      state.documents.grossMarginPercent = 50;

      final data = DocumentExportData.fromState(state);

      expect(state.materialCostTotal, 12000);
      expect(data.lines, hasLength(2));
      expect(data.lines.first.handrailId, line.id);
      expect(data.lines.first.costAmount, 5800);
      expect(data.lines.last.workContent, '補強板取付');
      expect(data.lines.last.location, '浴室');
      expect(data.lines.last.productId, '補強板');
      expect(data.lines.last.specification, '接続点 1');
      expect(data.lines.last.unit, '枚');
      expect(data.lines.last.costAmount, 6200);
      expect(data.lines.last.customerAmount, 12400);
      expect(data.materialSubtotal, 12000);
      expect(data.quoteSubtotal, 24000);
      expect(data.quoteTax, 2400);
      expect(data.quoteTotal, 26400);
      state.dispose();
    });

    test('添付テンプレートから写真台紙を含む対象6シートのExcelを生成する', () async {
      final state = AppState(dataRepository: MemoryAppDataRepository())
        ..addSample(notify: false);
      final line = state.lines.single;
      line.place = '浴室';
      state.documents.grossMarginPercent = 50;
      state.documents.fieldsFor(line.id)
        ..workContent = '手すり取付'
        ..specification = '横手すり 750mm'
        ..remarks = '定価 8,000円';
      const photoBase64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
      final firstPhotoLocation = state.photoLocations.single;
      _addPhotoHandrail(state, centerX: 2250, centerY: 2500);
      state.setProjectPhoto(
        projectId: state.activeProject.id,
        locationId: firstPhotoLocation.id,
        slot: ProjectPhotoSlot.before,
        photo: CapturedProjectPhoto(
          base64Data: photoBase64,
          mimeType: 'image/png',
          fileName: 'before.png',
          capturedAt: DateTime(2026, 7, 14),
        ),
      );
      state.setProjectPhoto(
        projectId: state.activeProject.id,
        locationId: firstPhotoLocation.id,
        slot: ProjectPhotoSlot.after,
        photo: CapturedProjectPhoto(
          base64Data: photoBase64,
          mimeType: 'image/png',
          fileName: 'after.png',
          capturedAt: DateTime(2026, 7, 14),
        ),
      );
      state.setProjectPhotoMemo(
        projectId: state.activeProject.id,
        locationId: firstPhotoLocation.id,
        slot: ProjectPhotoSlot.before,
        value: '施工前メモ',
      );
      state.setProjectPhotoMemo(
        projectId: state.activeProject.id,
        locationId: firstPhotoLocation.id,
        slot: ProjectPhotoSlot.after,
        value: '施工後メモ',
      );
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
        'xl/worksheets/sheet7.xml',
      ]) {
        final sheet = _archiveXml(archive, path);
        expect(sheet.findAllElements('f'), isEmpty);
        expect(sheet.toXmlString(), isNot(contains('商品リスト')));
      }

      final costDetails = _archiveXml(archive, 'xl/worksheets/sheet3.xml');
      final quoteCover = _archiveXml(archive, 'xl/worksheets/sheet5.xml');
      final quoteDetails = _archiveXml(archive, 'xl/worksheets/sheet6.xml');
      final photos = _archiveXml(archive, 'xl/worksheets/sheet7.xml');
      expect(_cellValue(costDetails, 'A9'), '手すり取付');
      expect(_cellValue(costDetails, 'B9'), '浴室');
      expect(_cellValue(costDetails, 'H9'), '5800');
      expect(_cellValue(quoteCover, 'D14'), '${data.quoteTotal}');
      expect(_cellValue(quoteDetails, 'G9'), '11600');
      expect(_cellValue(quoteDetails, 'H50'), '${data.quoteTotal}');
      expect(_cellValue(photos, 'C3'), '山田 太郎');
      expect(_cellValue(photos, 'H3'), '0000123456');
      expect(_cellValue(photos, 'C4'), 'トイレ');
      expect(_cellValue(photos, 'H4'), '①');
      expect(_cellValue(photos, 'A9'), '施工前メモ');
      expect(_cellValue(photos, 'A32'), '施工後メモ');
      expect(_cellValue(photos, 'C58'), 'トイレ');
      expect(_cellValue(photos, 'H58'), '②');
      expect(
        photos
            .findAllElements('mergeCell')
            .map((cell) => cell.getAttribute('ref')),
        containsAll(['A9:B30', 'A32:B53']),
      );
      final photoDrawing = _archiveXml(archive, 'xl/drawings/drawing4.xml');
      final photoRelationships = _archiveXml(
        archive,
        'xl/drawings/_rels/drawing4.xml.rels',
      );
      expect(
        photoDrawing.descendants.whereType<XmlElement>().where(
          (element) => element.name.local == 'pic',
        ),
        hasLength(2),
      );
      expect(photoRelationships.findAllElements('Relationship'), hasLength(2));
      expect(archive.findFile('xl/media/photo_1_before.jpg'), isNotNull);
      expect(archive.findFile('xl/media/photo_1_after.jpg'), isNotNull);
      final photoPrintArea = workbook
          .findAllElements('definedName')
          .singleWhere(
            (name) =>
                name.getAttribute('name') == '_xlnm.Print_Area' &&
                name.getAttribute('localSheetId') == '5',
          )
          .innerText;
      expect(photoPrintArea, "'写真貼付台紙'!\$A\$1:\$I\$108");
      expect(_rowIsHidden(costDetails, 9), isFalse);
      expect(_rowIsHidden(costDetails, 10), isFalse);
      expect(_rowIsHidden(costDetails, 11), isTrue);
      expect(_rowIsHidden(costDetails, 84), isTrue);
      expect(_rowIsHidden(costDetails, 85), isFalse);
      expect(_rowIsHidden(quoteDetails, 9), isFalse);
      expect(_rowIsHidden(quoteDetails, 10), isFalse);
      expect(_rowIsHidden(quoteDetails, 11), isTrue);
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
      final photoPageSetup = photos.findAllElements('pageSetup').single;
      expect(photoPageSetup.getAttribute('scale'), '90');
      expect(photoPageSetup.getAttribute('fitToWidth'), isNull);
      expect(photoPageSetup.getAttribute('fitToHeight'), isNull);
      expect(
        photos.findAllElements('brk').map((item) => item.getAttribute('id')),
        ['54'],
      );
      state.dispose();
    });

    test('写真が11件以上でも台紙を複製して1件1ページで出力する', () async {
      final state = AppState(dataRepository: MemoryAppDataRepository())
        ..addSample(notify: false);
      for (final centerY in const [
        750,
        1000,
        1500,
        1750,
        2000,
        2250,
        2500,
        2750,
        3000,
        3250,
      ]) {
        _addPhotoHandrail(state, centerX: 1500, centerY: centerY);
      }
      expect(state.photoLocations, hasLength(11));
      for (final entry in state.photoLocations.indexed) {
        final (index, location) = entry;
        state.setProjectPhotoMemo(
          projectId: state.activeProject.id,
          locationId: location.id,
          slot: ProjectPhotoSlot.before,
          value: '施工前メモ${index + 1}',
        );
      }
      final data = DocumentExportData.fromState(state);
      final template = await File(
        'assets/templates/kaigo_estimate_template.xlsx',
      ).readAsBytes();

      final output = KaigoEstimateTemplateWriter().build(template, data);
      final archive = ZipDecoder().decodeBytes(output);
      final workbook = _archiveXml(archive, 'xl/workbook.xml');
      final photos = _archiveXml(archive, 'xl/worksheets/sheet7.xml');

      expect(_cellValue(photos, 'C543'), '山田 太郎');
      expect(_cellValue(photos, 'H543'), '0000123456');
      expect(_cellValue(photos, 'C544'), 'トイレ');
      expect(_cellValue(photos, 'H544'), '⑪');
      expect(_cellValue(photos, 'A549'), '施工前メモ11');
      expect(
        photos
            .findAllElements('mergeCell')
            .map((cell) => cell.getAttribute('ref')),
        containsAll(['A549:B570', 'A572:B593']),
      );
      final photoPrintArea = workbook
          .findAllElements('definedName')
          .singleWhere(
            (name) =>
                name.getAttribute('name') == '_xlnm.Print_Area' &&
                name.getAttribute('localSheetId') == '5',
          )
          .innerText;
      expect(photoPrintArea, "'写真貼付台紙'!\$A\$1:\$I\$594");
      expect(
        photos.findAllElements('brk').map((item) => item.getAttribute('id')),
        [for (var index = 1; index < 11; index++) '${index * 54}'],
      );
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
  });
}
