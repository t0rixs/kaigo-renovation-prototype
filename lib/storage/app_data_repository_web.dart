import 'package:idb_shim/idb_browser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_data_repository_base.dart';

class WebAppDataRepository implements AppDataRepository {
  WebAppDataRepository({
    this.databaseName = defaultDatabaseName,
    this.legacyStorageKey = defaultLegacyStorageKey,
  });

  static const defaultDatabaseName = 'kaigo_renovation';
  static const defaultLegacyStorageKey = 'kaigo_renovation_mvp_json_v1';
  static const _storeName = 'app_data';
  static const _recordKey = 'current';

  final String databaseName;
  final String legacyStorageKey;

  @override
  Future<String?> read() async {
    final database = await _openDatabase();
    final transaction = database.transaction(_storeName, idbModeReadOnly);
    final stored = await transaction
        .objectStore(_storeName)
        .getObject(_recordKey);
    await transaction.completed;
    database.close();
    if (stored is String) return stored;

    // Existing browser installs stored the JSON in localStorage. Move it once
    // so photos and later project growth are no longer constrained by its
    // small quota.
    final preferences = await SharedPreferences.getInstance();
    final legacyJson = preferences.getString(legacyStorageKey);
    if (legacyJson == null) return null;
    await write(legacyJson);
    await preferences.remove(legacyStorageKey);
    return legacyJson;
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
