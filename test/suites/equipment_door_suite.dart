part of '../widget_test.dart';

void registerEquipmentDoorTests() {
  group('設備・ドア', () {
    test('ドアは最寄りの間取り辺に所属する', () {
      final state = AppState();
      state.addLayout(1000, 1000, 2000, 2000);

      expect(state.addDoor(3000, 1500), OpeningAddResult.added);
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
        state.addDoor(2000, 1000, doorType: DoorType.sliding),
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
      state.addDoor(3000, 1500);
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

    test('同じ壁区間へドアを重複配置できない', () {
      final state = AppState();
      state.addLayout(1000, 1000, 3000, 2000);

      expect(state.addDoor(1500, 1000), OpeningAddResult.added);
      expect(state.addDoor(1500, 1000), OpeningAddResult.overlaps);
      expect(state.objects, hasLength(2));

      expect(state.addDoor(2000, 1000), OpeningAddResult.added);
      expect(state.objects, hasLength(3));
      state.dispose();
    });

    test('ドアの移動と拡大でも他のドアへ重ねられない', () {
      final state = AppState();
      state.addLayout(1000, 1000, 3000, 2000);
      state.addDoor(1500, 1000);
      final first = state.objects.last;
      state.addDoor(2500, 1000);
      final second = state.objects.last;
      final secondX = second.xMm;

      state.moveObjectBy(second, -750, 0);
      expect(second.xMm, secondX);

      state.resizeObjectBy(first, 1000, 0);
      expect(first.widthMm, 500);
      state.dispose();
    });

    test('ドアを反転状態と開口幅を保ったまま別の向きの壁へ移動できる', () {
      final state = AppState();
      state.addLayout(1000, 1000, 2000, 2000);
      state.addLayout(4000, 1000, 2000, 2000);
      final secondRoom = state.objects.last;
      state.addDoor(2000, 1000);
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
      state.addDoor(2000, 1000);
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
      state.addDoor(2000, 1000);
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

    test('ドアの左右反転で描画位置も反転する', () async {
      final normalCenter = await doorInkCenterX(flipped: false);
      final flippedCenter = await doorInkCenterX(flipped: true);

      expect(normalCenter, lessThan(50));
      expect(flippedCenter, greaterThan(50));
    });

    test('ドアを左右反転して元に戻せる', () {
      final state = AppState();
      state.addLayout(1000, 1000, 2000, 2000);
      state.addDoor(3000, 2000);
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
      state.addDoor(3000, 2000);
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

    testWidgets('開き戸の詳細画面には吊元編集を表示しない', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState();
      state.addLayout(1000, 1000, 2000, 2000);
      state.addDoor(3000, 2000);
      final door = state.objects.last;
      state.flipDoor(door);

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

      expect(find.text('ドアを編集'), findsOneWidget);
      expect(find.text('戸種'), findsOneWidget);
      expect(find.text('開き方向'), findsOneWidget);
      expect(find.text('吊元'), findsNothing);
      expect(find.text('標準'), findsNothing);
      expect(find.text('左右反転'), findsNothing);

      await tester.tap(find.text('反映する'));
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
      state.addDoor(2000, 1000);
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
      state.addDoor(2000, 1000, doorType: DoorType.sliding);
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

    test('間取りの縮小でドア同士が重なる場合はサイズを変更しない', () {
      final state = AppState();
      state.addLayout(1000, 1000, 3000, 2000);
      final room = state.objects.first;
      state.addDoor(1500, 1000);
      state.addDoor(3500, 1000);
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

    test('設備6種は適切な初期寸法で配置され自由にリサイズ・保存できる', () {
      final state = AppState();
      final expectedSizes = <FixtureType, (int, int)>{
        FixtureType.toilet: (500, 1000),
        FixtureType.diningTable: (1500, 1250),
        FixtureType.kitchen: (2500, 750),
        FixtureType.refrigerator: (750, 1000),
        FixtureType.wardrobe: (2000, 1000),
        FixtureType.bathtub: (1500, 750),
      };

      for (final MapEntry(key: type, value: size) in expectedSizes.entries) {
        state.addFixture(type, 3500, 2500);
        final fixture = state.objects.last;
        expect(fixture.fixtureType, type);
        expect((fixture.widthMm, fixture.heightMm), size);
        expect(fixture.xMm % AppState.gridMm, 0);
        expect(fixture.yMm % AppState.gridMm, 0);
        expect(PlanObject.fromJson(fixture.toJson()).fixtureType, type);
      }

      final kitchen = state.objects.firstWhere(
        (item) => item.fixtureType == FixtureType.kitchen,
      );
      state.resizeObjectBy(kitchen, 250, 500);
      expect((kitchen.widthMm, kitchen.heightMm), (2750, 1250));
      state.dispose();
    });

    test('設備6種を90度単位で回転し角度と寸法を保存できる', () {
      for (final type in FixtureType.values) {
        final state = AppState();
        state.addFixture(type, 3000, 2500);
        final fixture = state.objects.single;
        final originalWidth = fixture.widthMm;
        final originalHeight = fixture.heightMm;
        final centerX = fixture.xMm + fixture.widthMm / 2;
        final centerY = fixture.yMm + fixture.heightMm / 2;

        state.rotateFixture(fixture);
        expect(fixture.rotationQuarterTurns, 1, reason: type.name);
        expect(fixture.rotationDegrees, 90, reason: type.name);
        expect(fixture.widthMm, originalHeight, reason: type.name);
        expect(fixture.heightMm, originalWidth, reason: type.name);
        expect(
          (fixture.xMm + fixture.widthMm / 2 - centerX).abs(),
          lessThanOrEqualTo(AppState.gridMm / 2),
          reason: type.name,
        );
        expect(
          (fixture.yMm + fixture.heightMm / 2 - centerY).abs(),
          lessThanOrEqualTo(AppState.gridMm / 2),
          reason: type.name,
        );

        state.rotateFixture(fixture);
        expect(fixture.rotationDegrees, 180, reason: type.name);
        expect(fixture.widthMm, originalWidth, reason: type.name);
        expect(fixture.heightMm, originalHeight, reason: type.name);
        expect(
          PlanObject.fromJson(fixture.toJson()).rotationDegrees,
          180,
          reason: type.name,
        );
        state.undo();
        expect(state.objects.single.rotationDegrees, 90, reason: type.name);
        state.dispose();
      }
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

    testWidgets('選択した設備を下部バーから90度回転できる', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState();
      state.addFixture(FixtureType.kitchen, 2000, 2000);
      final fixture = state.objects.single;

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

      await tester.tap(find.byTooltip('設備を90度回転'));
      await tester.pumpAndSettle();

      expect(fixture.rotationDegrees, 90);
      expect(fixture.widthMm, 750);
      expect(fixture.heightMm, 2500);
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

    test('ドアだけを削除して元に戻せる', () {
      final state = AppState();
      state.addLayout(1000, 1000, 2000, 2000);
      final room = state.objects.first;
      state.addDoor(3000, 2000);
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

    test('間取りを削除した場合だけ所属するドアも削除する', () {
      final state = AppState();
      state.addLayout(1000, 1000, 2000, 2000);
      final room = state.objects.first;
      state.addToilet(2000, 2000);
      final toilet = state.objects.last;
      state.addDoor(3000, 2000);

      state.select(room.id);
      state.deleteSelected();

      expect(state.objects, hasLength(1));
      expect(state.objects.single.id, toilet.id);
      expect(state.objects.single.kind, PlanObjectKind.fixture);
      state.dispose();
    });

    test('トイレ設備だけを削除しても間取りとドアは残る', () {
      final state = AppState();
      state.addLayout(1000, 1000, 2000, 2000);
      final room = state.objects.first;
      state.addToilet(2000, 2000);
      final toilet = state.objects.last;
      state.addDoor(2000, 1000);
      final door = state.objects.last;

      state.select(toilet.id);
      state.deleteSelected();

      expect(
        state.objects.map((item) => item.id),
        containsAll([room.id, door.id]),
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
      expect(state.addDoor(2500, 1000), OpeningAddResult.added);
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

      expect(state.addDoor(2000, 1000), OpeningAddResult.added);
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
      expect(cost.endBracketCount, 2);
      expect(cost.intermediateBracketCount, 2);
      expect(cost.connectionJointCount, 1);
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

    test('接続していた手すりを切り離すとNoと写真位置を別々に再生成する', () {
      final state = AppState();
      state.addHandrail(1000, 1000, 2000, 1000);
      state.addHandrail(2000, 1000, 2000, 2000);

      expect(state.handrailEstimateGroups(), hasLength(1));
      expect(state.photoLocations, hasLength(1));
      expect(state.photoLocations.single.handrailIds, hasLength(2));
      expect(state.photoLocations.single.handrailNumber, '1');

      final second = state.lines.last;
      state.moveLineEnd(second, true, 2500, 1000);
      state.changed();

      final groups = state.handrailEstimateGroups();
      final numbers = groups
          .map((group) => state.constructionNumberFor(group.primary))
          .toList();
      expect(groups, hasLength(2));
      expect(numbers, ['1', '2']);
      expect(numbers.toSet(), hasLength(2));
      expect(state.photoLocations, hasLength(2));
      expect(state.photoLocations.map((location) => location.handrailNumber), [
        '1',
        '2',
      ]);
      expect(
        state.photoLocations.every(
          (location) => location.handrailIds.length == 1,
        ),
        isTrue,
      );
      state.dispose();
    });
  });
}
