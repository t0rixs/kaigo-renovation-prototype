@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:kaigo_renovation_app/storage/app_data_repository_web.dart';

void main() {
  final databaseNames = <String>[];

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
}
