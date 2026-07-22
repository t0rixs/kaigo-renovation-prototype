@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:kaigo_renovation_app/storage/app_data_repository_web.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final databaseNames = <String>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    for (final name in databaseNames) {
      await idbFactoryBrowser.deleteDatabase(name);
    }
    databaseNames.clear();
  });

  test('IndexedDBへ書き込んだ案件JSONを読み戻せる', () async {
    final databaseName =
        'kaigo_renovation_test_${DateTime.now().microsecondsSinceEpoch}';
    databaseNames.add(databaseName);
    final repository = WebAppDataRepository(databaseName: databaseName);

    await repository.write('{"projects":[{"id":"project-1"}]}');

    expect(await repository.read(), '{"projects":[{"id":"project-1"}]}');
  });

  test('旧localStorageのJSONをIndexedDBへ一度だけ移行する', () async {
    final databaseName =
        'kaigo_renovation_test_${DateTime.now().microsecondsSinceEpoch}';
    final legacyKey = 'legacy_${DateTime.now().microsecondsSinceEpoch}';
    databaseNames.add(databaseName);
    SharedPreferences.setMockInitialValues({legacyKey: '{"version":1}'});
    final repository = WebAppDataRepository(
      databaseName: databaseName,
      legacyStorageKey: legacyKey,
    );

    expect(await repository.read(), '{"version":1}');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey(legacyKey), isFalse);
    expect(await repository.read(), '{"version":1}');
  });
}
