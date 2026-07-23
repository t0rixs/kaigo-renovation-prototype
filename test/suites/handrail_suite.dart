part of '../widget_test.dart';

void registerHandrailTests() {
  group('手すり', () {
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
      expect(
        state.handrailCompletelyOverlapsLayoutEdge(1750, 1500, 3000, 2250),
        isFalse,
      );
      state.dispose();
    });

    test('斜め手すりは両端を250mm単位に保って実長を計算する', () {
      final state = AppState();
      state.addHandrail(0, 0, 1100, 300);

      final line = state.lines.single;
      expect((line.x1Mm, line.y1Mm), (0, 0));
      expect((line.x2Mm, line.y2Mm), (1000, 250));
      expect(line.orientation, HandrailOrientation.diagonal);
      expect(line.lengthMm, 1031);
      state.dispose();
    });

    test('斜め手すりの中受ブラケットを実長に沿って等間隔配置する', () {
      final state = AppState();
      state.addHandrail(1000, 1000, 1750, 2000);
      final line = state.lines.single;

      expect(line.lengthMm, 1250);
      expect(
        state.jointPointsFor(line).map((point) => (point.xMm, point.yMm)),
        [(1000, 1000), (1375, 1500), (1750, 2000)],
      );
      final cost = state.costFor(line);
      expect(cost.railCost, 5500);
      expect(cost.endBracketCount, 2);
      expect(cost.intermediateBracketCount, 1);
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

      expect(
        state.jointPointsFor(line).map((point) => (point.xMm, point.yMm)),
        [(1000, 4000), (1750, 4000), (2500, 4000)],
      );
      final cost = state.costFor(line);
      expect(cost.endBracketCount, 2);
      expect(cost.intermediateBracketCount, 1);
      expect(cost.connectionJointCount, 0);
      expect(cost.endBracketCost, 2500);
      expect(cost.intermediateBracketCost, 1250);
      state.dispose();
    });

    test('部品マスタは端部・中受・接続の順で、各3商品を持つ', () {
      final state = AppState();
      final sorted = state.sortedJointProducts;

      expect(sorted, hasLength(9));
      expect(
        sorted
            .take(3)
            .every((item) => item.type == JointProductType.endBracket),
        isTrue,
      );
      expect(
        sorted
            .skip(3)
            .take(3)
            .every((item) => item.type == JointProductType.intermediateBracket),
        isTrue,
      );
      expect(sorted.skip(6).every((item) => item.type.isConnection), isTrue);
      state.dispose();
    });

    test('中受接続点の数を任意変更し、各点の部品を個別指定できる', () {
      final state = AppState();
      state.addHandrail(1000, 4000, 2500, 4000);
      final group = state.handrailEstimateGroups().single;

      expect(state.intermediatePointCountForGroup(group), 1);
      state.setIntermediatePointCountForGroup(group, 3);
      final points = state.connectionPointsForGroup(group);
      expect(points, hasLength(5));
      expect(points.map((point) => point.point.xMm), [
        1000,
        1375,
        1750,
        2125,
        2500,
      ]);
      expect(
        points.where(
          (point) => point.kind == HandrailConnectionKind.intermediateBracket,
        ),
        hasLength(3),
      );

      state.setConnectionPointProduct(group, points.first, 'EB-35-BR');
      state.setConnectionPointProduct(group, points[1], 'MB-35-BR');
      final updated = state.connectionPointsForGroup(group);
      expect(updated.first.jointProduct?.id, 'EB-35-BR');
      expect(updated[1].jointProduct?.id, 'MB-35-BR');
      expect(state.costForGroup(group).endBracketCost, 2700);
      expect(state.costForGroup(group).intermediateBracketCost, 3950);
      expect(state.lines.single.manualIntermediatePointCount, 3);
      expect(state.lines.single.connectionProductOverrides, {
        'start': 'EB-35-BR',
        'middle:0': 'MB-35-BR',
      });
      state.dispose();
    });

    test('接続点ごとに補強板を追加し、単価変更と保存復元ができる', () async {
      final repository = MemoryAppDataRepository();
      final state = AppState(dataRepository: repository);
      state.addHandrail(1000, 4000, 2500, 4000);
      final group = state.handrailEstimateGroups().single;
      final point = state.connectionPointsForGroup(group)[1];
      final baseCost = state.costForGroup(group).total;

      state.setConnectionPointReinforcementPlate(group, point, true);
      var updatedPoint = state.connectionPointsForGroup(group)[1];
      var cost = state.costForGroup(group);
      expect(updatedPoint.hasReinforcementPlate, isTrue);
      expect(updatedPoint.reinforcementPlatePrice, 5000);
      expect(cost.reinforcementPlateCount, 1);
      expect(cost.reinforcementPlateCost, 5000);
      expect(cost.total, baseCost + 5000);

      state.setConnectionPointReinforcementPlatePrice(
        group,
        updatedPoint,
        7200,
      );
      updatedPoint = state.connectionPointsForGroup(group)[1];
      cost = state.costForGroup(group);
      expect(updatedPoint.reinforcementPlatePrice, 7200);
      expect(cost.reinforcementPlateCost, 7200);
      expect(state.materialCostTotal, baseCost + 7200);
      await state.saveNow();

      final restored = AppState(dataRepository: repository);
      await restored.load();
      final restoredGroup = restored.handrailEstimateGroups().single;
      final restoredPoint = restored.connectionPointsForGroup(restoredGroup)[1];
      expect(restoredPoint.hasReinforcementPlate, isTrue);
      expect(restoredPoint.reinforcementPlatePrice, 7200);
      expect(restored.costForGroup(restoredGroup).total, baseCost + 7200);

      restored.setConnectionPointReinforcementPlate(
        restoredGroup,
        restoredPoint,
        false,
      );
      expect(
        restored
            .connectionPointsForGroup(restoredGroup)[1]
            .hasReinforcementPlate,
        isFalse,
      );
      expect(restored.costForGroup(restoredGroup).total, baseCost);
      state.dispose();
      restored.dispose();
    });

    test('L字接続点はL字・2次元・3次元ジョイントから選択し保存できる', () async {
      final repository = MemoryAppDataRepository();
      final state = AppState(dataRepository: repository);
      state.addHandrail(1250, 1250, 2750, 1250);
      state.addHandrail(2750, 1250, 2750, 2500);
      final group = state.handrailEstimateGroups().single;
      final connection = state
          .connectionPointsForGroup(group)
          .singleWhere(
            (point) => point.kind == HandrailConnectionKind.connectionJoint,
          );

      expect(
        state
            .jointProductsForKind(HandrailConnectionKind.connectionJoint)
            .map((product) => product.type),
        [
          JointProductType.lShapeConnection,
          JointProductType.twoDimensionalConnection,
          JointProductType.threeDimensionalConnection,
        ],
      );
      state.setConnectionPointProduct(group, connection, 'CJ-3D-35');
      expect(state.costForGroup(group).connectionJointCost, 2800);
      expect(
        group.lines.every(
          (line) => line.connectionProductOverrides.values.contains('CJ-3D-35'),
        ),
        isTrue,
      );
      expect(
        state.deleteJointProduct(state.jointProductById('CJ-3D-35')!),
        isFalse,
      );
      await state.saveNow();

      final restored = AppState(dataRepository: repository);
      await restored.load();
      final restoredGroup = restored.handrailEstimateGroups().single;
      final restoredConnection = restored
          .connectionPointsForGroup(restoredGroup)
          .singleWhere(
            (point) => point.kind == HandrailConnectionKind.connectionJoint,
          );
      expect(restoredConnection.jointProduct?.id, 'CJ-3D-35');
      expect(restored.costForGroup(restoredGroup).connectionJointCost, 2800);
      state.dispose();
      restored.dispose();
    });

    test('斜めに曲がる接続点は2次元ジョイントを初期選択する', () {
      final state = AppState();
      state.addHandrail(1000, 1000, 2000, 1000);
      state.addHandrail(2000, 1000, 2750, 1500);
      final group = state.handrailEstimateGroups().single;
      final connection = state
          .connectionPointsForGroup(group)
          .singleWhere(
            (point) => point.kind == HandrailConnectionKind.connectionJoint,
          );

      expect(group.shapeLabel, '角度付き');
      expect(
        connection.jointProduct?.type,
        JointProductType.twoDimensionalConnection,
      );
      state.dispose();
    });

    testWidgets('L字手すりの接続点編集は集合全体を選択し右パネルに番号表示する', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState();
      state.addHandrail(5000, 1000, 6000, 1000);
      state.addHandrail(1250, 1250, 2750, 1250);
      state.addHandrail(2750, 1250, 2750, 2500);
      final selectedGroup = state.estimateGroupFor(state.lines.last);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DrawingScreen(state: state)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('open-connection-editor-compact')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('connection-editor-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('connection-point-card-1')),
        findsOneWidget,
      );
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<PlanPainter>()
          .single;
      expect(
        painter.focusedHandrailIds,
        selectedGroup.lines.map((line) => line.id).toSet(),
      );
      expect(painter.showConnectionNumbers, isTrue);
      expect(painter.connectionPoints, hasLength(7));
      expect(painter.connectionPointNumbers.values, [1, 2, 3, 4, 5]);
      expect(
        painter.connectionPointNumbers.keys,
        state.connectionPointsForGroup(selectedGroup).map((point) => point.id),
      );

      final firstPoint = state.connectionPointsForGroup(selectedGroup).first;
      final reinforcementCheckbox = find.byKey(
        ValueKey('reinforcement-plate-${firstPoint.id}'),
      );
      expect(reinforcementCheckbox, findsOneWidget);
      tester
          .widget<CheckboxListTile>(reinforcementCheckbox)
          .onChanged
          ?.call(true);
      await tester.pumpAndSettle();
      expect(
        state
            .connectionPointsForGroup(selectedGroup)
            .first
            .hasReinforcementPlate,
        isTrue,
      );
      final reinforcementPrice = find.byKey(
        ValueKey('reinforcement-price-${firstPoint.id}'),
      );
      expect(reinforcementPrice, findsOneWidget);
      await tester.enterText(reinforcementPrice, '6500');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        state
            .connectionPointsForGroup(selectedGroup)
            .first
            .reinforcementPlatePrice,
        6500,
      );

      final increasePoints = find.byKey(
        const ValueKey('increase-connection-points'),
      );
      tester.widget<IconButton>(increasePoints).onPressed?.call();
      await tester.pumpAndSettle();
      expect(state.intermediatePointCountForGroup(selectedGroup), 3);
      final editorList = find.descendant(
        of: find.byKey(const ValueKey('connection-editor-panel')),
        matching: find.byType(ListView),
      );
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('connection-point-card-5')),
        editorList,
        const Offset(0, -180),
        maxIteration: 10,
      );
      expect(
        find.byKey(const ValueKey('connection-point-card-5')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
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

      expect(state.addDoor(1500, 2250), OpeningAddResult.added);
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
        (widget) =>
            widget is TextField && widget.decoration?.labelText == '場所名',
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

    testWidgets('設備やドアと重なった手すりの選択を最優先する', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState();
      state.addLayout(1000, 1000, 2000, 2000);
      state.addToilet(2000, 1500);
      final toilet = state.objects.last;
      expect(state.addDoor(1500, 1000), OpeningAddResult.added);
      final door = state.objects.last;
      state.addHandrail(1750, 1500, 2250, 1500);
      final toiletRail = state.lines.last;
      state.addHandrail(1250, 1000, 1750, 1000);
      final doorRail = state.lines.last;
      state.select(toilet.id);

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

      await tester.tap(find.byKey(ValueKey('line-body-${toiletRail.id}')));
      await tester.pump();
      expect(state.selectedId, toiletRail.id);

      state.select(door.id);
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('line-body-${doorRail.id}')));
      await tester.pump();
      expect(state.selectedId, doorRail.id);
      state.dispose();
    });

    testWidgets('前面の間取りと重なった設備をタップして選択できる', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState();
      state.addLayout(1000, 1000, 2000, 2000);
      state.addToilet(2000, 1000);
      final toilet = state.objects.firstWhere(
        (object) => object.kind == PlanObjectKind.fixture,
      );
      state.addLayout(1000, 1000, 2000, 2000);
      final frontRoom = state.objects.last;
      state.moveObjectBy(frontRoom, 250, 0);
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

      await tester.tap(find.byKey(ValueKey('object-${toilet.id}')));
      await tester.pump();

      expect(state.selectedId, toilet.id);
      expect(state.selectedId, isNot(frontRoom.id));
      state.dispose();
    });

    test('手すりの端点を任意グリッドへ動かして縦・斜めを切り替えられる', () {
      final state = AppState();
      state.addHandrail(1000, 1000, 2000, 1000);
      final line = state.lines.single;

      state.moveLineEnd(line, false, 1000, 2500);
      expect(line.isHorizontal, isFalse);
      expect(line.x1Mm, line.x2Mm);
      expect(line.orientation, HandrailOrientation.vertical);

      state.moveLineEnd(line, false, 2500, 2500);
      expect(line.isHorizontal, isFalse);
      expect(line.isVertical, isFalse);
      expect(line.orientation, HandrailOrientation.diagonal);
      expect(line.lengthMm, 2121);
      state.dispose();
    });

    testWidgets('横手すりの端ハンドルを斜めへドラッグして向きを変更できる', (tester) async {
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

      final endHandle = find.byKey(ValueKey('line-${line.id}-end'));
      final gesture = await tester.startGesture(tester.getCenter(endHandle));
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump();
      expect(line.isHorizontal, isFalse);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(line.isHorizontal, isFalse);
      expect(line.isVertical, isFalse);
      expect(line.x2Mm % AppState.gridMm, 0);
      expect(line.y2Mm % AppState.gridMm, 0);
      expect(line.orientation, HandrailOrientation.diagonal);
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

      final handle = find.byKey(ValueKey('resize-${toilet.id}'));
      final drawingState = tester.state(find.byType(DrawingScreen)) as dynamic;
      final visibleGrid = 40 * (drawingState.scale as double);
      final start = tester.getCenter(handle);
      final pointer = start + const Offset(70, 70);
      final gesture = await tester.startGesture(start);
      await gesture.moveTo(pointer);
      await tester.pump();

      final handleCenter = tester.getCenter(handle);
      expect(
        (handleCenter.dx - pointer.dx).abs(),
        lessThan(visibleGrid / 2 + 2),
      );
      expect(
        (handleCenter.dy - pointer.dy).abs(),
        lessThan(visibleGrid / 2 + 2),
      );
      expect(toilet.widthMm % AppState.gridMm, 0);
      expect(toilet.heightMm % AppState.gridMm, 0);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(toilet.widthMm % AppState.gridMm, 0);
      expect(toilet.heightMm % AppState.gridMm, 0);
      state.dispose();
    });
  });
}
