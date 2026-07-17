import 'package:shared_preferences/shared_preferences.dart';

import 'app_data_repository_base.dart';

class WebAppDataRepository implements AppDataRepository {
  static const storageKey = 'kaigo_renovation_mvp_json_v1';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(storageKey);
  }

  @override
  Future<void> write(String jsonText) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(storageKey, jsonText);
  }
}

AppDataRepository createPlatformAppDataRepository() => WebAppDataRepository();
