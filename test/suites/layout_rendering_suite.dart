part of '../widget_test.dart';

void registerLayoutRenderingTests() {
  group('間取り・描画', () {
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

    testWidgets('グリッド・間取り・設備・ドア・手すりの順に描画する', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState();
      state.addLayout(1000, 1000, 2000, 2000);
      final roomWithDoor = state.objects.single;
      expect(state.addDoor(1500, 1000), OpeningAddResult.added);
      state.addToilet(1750, 1250);
      state.addHandrail(1250, 1250, 2250, 1250);
      state.addLayout(1250, 750, 2000, 2000);
      state.moveObjectBy(roomWithDoor, 250, 0);

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

      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .toList();
      final lastLayoutIndex = painters.lastIndexWhere(
        (painter) => painter is LayoutPainter,
      );
      final gridIndex = painters.indexWhere(
        (painter) => painter is GridPainter,
      );
      final handrailIndex = painters.indexWhere(
        (painter) => painter is PlanPainter,
      );
      final fixtureIndex = painters.indexWhere(
        (painter) => painter is FixturePainter,
      );
      final doorIndex = painters.indexWhere(
        (painter) => painter is DoorPainter,
      );
      expect(gridIndex, lessThan(lastLayoutIndex));
      expect(lastLayoutIndex, lessThan(fixtureIndex));
      expect(fixtureIndex, lessThan(doorIndex));
      expect(doorIndex, lessThan(handrailIndex));
      expect(tester.takeException(), isNull);
      state.dispose();
    });

    test('グリッドと手すり層を合成しても間取り壁が見える', () async {
      const canvasSize = ui.Size.square(240);
      const roomSize = ui.Size.square(100);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      const GridPainter().paint(canvas, canvasSize);
      canvas.save();
      canvas.translate(50, 50);
      const LayoutPainter(
        selected: false,
        selectionColor: editorSelectionColor,
        cutouts: [],
        wallGaps: [],
      ).paint(canvas, roomSize);
      canvas.restore();
      PlanPainter(
        lines: const [],
        selectedId: null,
        mmToPixels: (value) => value.toDouble(),
        pathFor: (_) => throw StateError('No handrails in this test'),
        connectionPoints: const [],
        constructionNumberFor: (_) => '',
      ).paint(canvas, canvasSize);

      final image = await recorder.endRecording().toImage(240, 240);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      image.dispose();
      final offset = (75 * 240 + 50) * 4;

      expect(bytes[offset], lessThan(80));
      expect(bytes[offset + 1], lessThan(80));
      expect(bytes[offset + 2], lessThan(80));
      expect(bytes[offset + 3], greaterThan(200));
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

    testWidgets('左上を覆われた背面間取りの場所名を空いている位置へ移す', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState();
      state.addLayout(1000, 1000, 3000, 3000);
      final back = state.objects.single..place = '背面の間取り';
      state.addLayout(1000, 1000, 1000, 1000);
      final front = state.objects.last..place = '前面の間取り';

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

      final backLabel = find.byKey(ValueKey('layout-label-${back.id}'));
      final backLabelText = find.descendant(
        of: find.byKey(ValueKey('layout-label-visual-${back.id}')),
        matching: find.text('背面の間取り'),
      );
      final frontObject = find.byKey(ValueKey('object-${front.id}'));
      final backObject = find.byKey(ValueKey('object-${back.id}'));
      expect(backLabel, findsOneWidget);
      expect(
        tester.getRect(frontObject).overlaps(tester.getRect(backLabel)),
        isFalse,
      );
      expect(
        tester.getRect(backObject).contains(tester.getRect(backLabel).center),
        isTrue,
      );
      expect(tester.widget<Text>(backLabelText).textAlign, TextAlign.right);
      expect(tester.takeException(), isNull);
      state.dispose();
    });

    testWidgets('間取り名は枠の右端まで表示でき設備より前面で選択できる', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState();
      state.addLayout(1000, 1000, 1500, 1500);
      final room = state.objects.single..place = '浴室入口';
      state.addToilet(1250, 1500);
      final toilet = state.objects.last;
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

      final label = find.byKey(ValueKey('layout-label-${room.id}'));
      final labelVisual = find.byKey(
        ValueKey('layout-label-visual-${room.id}'),
      );
      final roomObject = find.byKey(ValueKey('object-${room.id}'));
      final toiletObject = find.byKey(ValueKey('object-${toilet.id}'));
      final labelRect = tester.getRect(labelVisual);
      final roomRect = tester.getRect(roomObject);

      expect(labelRect.width / roomRect.width, greaterThan(.85));
      expect(labelRect.right, lessThanOrEqualTo(roomRect.right));
      expect(
        tester.getRect(toiletObject).contains(tester.getRect(label).center),
        isTrue,
      );

      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(state.selectedId, room.id);
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
      expect(
        restored.sharedWallContactsFor(restoredLeft).single.visible,
        isTrue,
      );
      state.dispose();
      restored.dispose();
    });

    test('間取りを共有壁から離すと古い壁表示設定を破棄する', () {
      final state = AppState();
      state.addLayout(1000, 1000, 2000, 2000);
      final left = state.objects.single;
      state.addLayout(3000, 1000, 1000, 1000);
      final right = state.objects.last;
      state.setSharedWallVisible(
        state.sharedWallContactsFor(left).single,
        false,
      );

      state.moveObjectBy(right, 250, 0);

      expect(state.sharedWallContactsFor(left), isEmpty);
      expect(state.sharedWallOverrides, isEmpty);
      state.dispose();
    });

    test('図面を上または左へ拡張しても消した共有壁を維持する', () {
      final state = AppState();
      state.addLayout(1000, 1000, 2000, 2000);
      final first = state.objects.single;
      state.addLayout(3000, 1500, 1000, 1000);
      state.setSharedWallVisible(
        state.sharedWallContactsFor(first).single,
        false,
      );

      expect(
        state.resizeCanvasFromEdge(
          CanvasResizeEdge.top,
          state.canvasHeightMm + 500,
        ),
        isTrue,
      );
      expect(state.sharedWallContactsFor(first).single.visible, isFalse);

      expect(
        state.resizeCanvasFromEdge(
          CanvasResizeEdge.left,
          state.canvasWidthMm + 250,
        ),
        isTrue,
      );
      expect(state.sharedWallContactsFor(first).single.visible, isFalse);
      expect(state.sharedWallOverrides, hasLength(1));
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
      expect(
        painters.where((painter) => painter.cutouts.isEmpty),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
      state.dispose();
    });
  });
}
