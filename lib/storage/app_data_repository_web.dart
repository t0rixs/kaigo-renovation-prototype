import 'package:idb_shim/idb_browser.dart';

import 'app_data_repository_base.dart';

class WebAppDataRepository implements AppDataRepository {
  WebAppDataRepository({this.databaseName = defaultDatabaseName});

  static const defaultDatabaseName = 'kaigo_renovation';
  static const _storeName = 'app_data';
  static const _recordKey = 'current';

  final String databaseName;

  @override
  Future<String?> read() async {
    final database = await _openDatabase();
    final transaction = database.transaction(_storeName, idbModeReadOnly);
    final stored = await transaction
        .objectStore(_storeName)
        .getObject(_recordKey);
    await transaction.completed;
    database.close();
    return stored is String ? stored : null;
  }

  @override
  Future<void> write(String jsonText) async {
    final database = await _openDatabase();
    final transaction = database.transaction(_storeName, idbModeReadWrite);
    await transaction.objectStore(_storeName).put(jsonText, _recordKey);
    await transaction.completed;
    database.close();
  }

  Future<Database> _openDatabase() {
    return idbFactoryBrowser.open(
      databaseName,
      version: 1,
      onUpgradeNeeded: (event) {
        final database = event.database;
        if (!database.objectStoreNames.contains(_storeName)) {
          database.createObjectStore(_storeName);
        }
      },
    );
  }
}

AppDataRepository createPlatformAppDataRepository() => WebAppDataRepository();
