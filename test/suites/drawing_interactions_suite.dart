part of '../widget_test.dart';

void registerDrawingInteractionTests() {
  group('図面操作', () {
    testWidgets('タブレット幅では常設属性パネルを表示せず下部操作バーを使う', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState();
      state.addLayout(1000, 1000, 2000, 1500);
      state.select(state.objects.single.id);

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

      expect(find.text('属性'), findsNothing);
      expect(find.byTooltip('属性を編集'), findsOneWidget);
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

    testWidgets('図面設定では外周4辺のハンドルでサイズを変更できる', (tester) async {
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

      await tester.drag(
        find.byKey(const ValueKey('drawing-toolbar')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('drawing-settings')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('canvas-resize-top')), findsOneWidget);
      expect(find.byKey(const ValueKey('canvas-resize-right')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('canvas-resize-bottom')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('canvas-resize-left')), findsOneWidget);
      final originalWidth = state.canvasWidthMm;
      await tester.drag(
        find.byKey(const ValueKey('canvas-resize-right')),
        const Offset(40, 0),
      );
      await tester.pumpAndSettle();

      expect(state.canvasWidthMm, greaterThan(originalWidth));
      expect(state.canvasWidthMm % AppState.gridMm, 0);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('canvas-width-field')))
            .controller!
            .text,
        '${state.canvasWidthMm}',
      );
      expect(tester.takeException(), isNull);
      state.dispose();
    });

    testWidgets('設備は親ツールから6種を選択できる', (tester) async {
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

      final viewerRectBefore = tester.getRect(find.byType(InteractiveViewer));
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final transformBefore = List<double>.of(
        viewer.transformationController!.value.storage,
      );
      expect(find.byKey(const ValueKey('equipment-menu')), findsNothing);
      expect(find.byIcon(Icons.wc), findsNothing);
      await tester.tap(find.byKey(const ValueKey('tool-equipment')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('tool-equipment')),
          matching: find.byIcon(CupertinoIcons.square_grid_2x2),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('equipment-menu')), findsOneWidget);
      expect(find.byKey(const ValueKey('equipment-toilet')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('equipment-diningTable')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('equipment-kitchen')), findsOneWidget);
      expect(tester.getRect(find.byType(InteractiveViewer)), viewerRectBefore);
      expect(viewer.transformationController!.value.storage, transformBefore);
      await tester.drag(
        find.byKey(const ValueKey('equipment-menu')),
        const Offset(-260, 0),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('equipment-refrigerator')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('equipment-wardrobe')), findsOneWidget);
      expect(find.byKey(const ValueKey('equipment-bathtub')), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('equipment-menu')),
        const Offset(260, 0),
      );
      await tester.pumpAndSettle();
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

    testWidgets('縮小表示でも設備のリサイズ領域を指で操作できる', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState();
      state.addToilet(2000, 1500);
      final toilet = state.objects.single;
      state.select(toilet.id);
      final original = (
        xMm: toilet.xMm,
        yMm: toilet.yMm,
        widthMm: toilet.widthMm,
        heightMm: toilet.heightMm,
      );

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

      final hitTarget = find.byKey(ValueKey('resize-hit-${toilet.id}'));
      final box = tester.renderObject<RenderBox>(hitTarget);
      final topLeft = box.localToGlobal(Offset.zero);
      final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
      expect(bottomRight.dx - topLeft.dx, closeTo(48, 2));
      expect(bottomRight.dy - topLeft.dy, closeTo(48, 2));

      final center = Offset.lerp(topLeft, bottomRight, .5)!;
      final gesture = await tester.startGesture(center + const Offset(18, 0));
      await gesture.moveBy(const Offset(40, 40));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect((toilet.xMm, toilet.yMm), (original.xMm, original.yMm));
      expect(toilet.widthMm, greaterThan(original.widthMm));
      expect(toilet.heightMm, greaterThan(original.heightMm));
      expect(tester.takeException(), isNull);
      state.dispose();
    });

    testWidgets('間取りツール中も背面の選択間取りをハンドルからリサイズできる', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState();
      state.addLayout(1000, 1000, 2000, 2000);
      final backRoom = state.objects.single;
      state.addLayout(2500, 2500, 1500, 1500);
      final originalWidth = backRoom.widthMm;

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
      state.select(backRoom.id);
      await tester.pump();
      final handle = find.byKey(ValueKey('resize-${backRoom.id}'));
      expect(handle, findsOneWidget);

      await tester.drag(handle, const Offset(80, 80));
      await tester.pumpAndSettle();

      expect(backRoom.widthMm, greaterThan(originalWidth));
      expect(
        state.objects.where((item) => item.kind == PlanObjectKind.layout),
        hasLength(2),
      );
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

    testWidgets('間取りの場所名テキストをタップして選択できる', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState();
      state.addLayout(1000, 1000, 1500, 1500);
      final room = state.objects.single..place = 'トイレ';
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

      await tester.tap(find.byKey(const ValueKey('tool-equipment')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('equipment-toilet')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('layout-label-${room.id}')));
      await tester.pumpAndSettle();

      expect(state.selectedId, room.id);
      expect(state.objects, [room]);
      expect(tester.takeException(), isNull);
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

      final roomRect = tester.getRect(
        find.byKey(ValueKey('object-${room.id}')),
      );
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

    testWidgets('選択中の間取り内部へキッチン設備を配置できる', (tester) async {
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
      await tester.tap(find.byKey(const ValueKey('equipment-kitchen')));
      await tester.pump();
      await tester.tapAt(
        tester.getCenter(find.byKey(ValueKey('object-${room.id}'))),
      );
      await tester.pumpAndSettle();

      expect(state.objects, hasLength(2));
      final kitchen = state.objects.last;
      expect(kitchen.kind, PlanObjectKind.fixture);
      expect(kitchen.fixtureType, FixtureType.kitchen);
      expect(
        find.byKey(ValueKey('kitchen-symbol-${kitchen.id}')),
        findsOneWidget,
      );
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

      await tester.dragFrom(
        center - const Offset(40, 40),
        const Offset(80, 80),
      );
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

    testWidgets('拡大縮小ボタンは画面中央の図面座標を維持する', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState()..addSample(notify: false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DrawingScreen(state: state)),
        ),
      );
      await tester.pumpAndSettle();

      final viewerFinder = find.byType(InteractiveViewer);
      final viewer = tester.widget<InteractiveViewer>(viewerFinder);
      final controller = viewer.transformationController!;
      await tester.drag(viewerFinder, const Offset(-90, -60));
      await tester.pumpAndSettle();

      final viewportCenter = tester.getSize(viewerFinder).center(Offset.zero);
      final scaleBefore = controller.value.entry(0, 0);
      final beforeZoomIn = controller.toScene(viewportCenter);
      await tester.tap(find.byTooltip('拡大'));
      await tester.pump();
      final afterZoomIn = controller.toScene(viewportCenter);
      expect(controller.value.entry(0, 0), closeTo(scaleBefore + .18, .001));
      expect(afterZoomIn.dx, closeTo(beforeZoomIn.dx, .001));
      expect(afterZoomIn.dy, closeTo(beforeZoomIn.dy, .001));

      await tester.tap(find.byTooltip('縮小'));
      await tester.pump();
      final afterZoomOut = controller.toScene(viewportCenter);
      expect(controller.value.entry(0, 0), closeTo(scaleBefore, .001));
      expect(afterZoomOut.dx, closeTo(beforeZoomIn.dx, .001));
      expect(afterZoomOut.dy, closeTo(beforeZoomIn.dy, .001));
      expect(tester.takeException(), isNull);
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
      final roomRect = tester.getRect(
        find.byKey(ValueKey('object-${room.id}')),
      );
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

    testWidgets('手すりツールの斜めドラッグで斜め直線を配置できる', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
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

      await tester.tap(find.byKey(const ValueKey('tool-rail')));
      await tester.pump();
      final center = tester.getCenter(find.byType(InteractiveViewer));
      await tester.dragFrom(
        center - const Offset(80, 60),
        const Offset(160, 120),
      );
      await tester.pumpAndSettle();

      expect(state.lines, hasLength(1));
      final line = state.lines.single;
      expect(line.orientation, HandrailOrientation.diagonal);
      expect(line.x1Mm % AppState.gridMm, 0);
      expect(line.y1Mm % AppState.gridMm, 0);
      expect(line.x2Mm % AppState.gridMm, 0);
      expect(line.y2Mm % AppState.gridMm, 0);
      expect(tester.takeException(), isNull);
      state.dispose();
    });
  });
}
