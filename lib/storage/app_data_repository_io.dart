import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_data_repository_base.dart';

class FileAppDataRepository implements AppDataRepository {
  static const fileName = 'kaigo_renovation_mvp_v1.json';

  Future<File> _dataFile() async {
    final directory = await getApplicationDocumentsDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<String?> read() async {
    final file = await _dataFile();
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String jsonText) async {
    final file = await _dataFile();
    await file.writeAsString(jsonText, flush: true);
  }
}

AppDataRepository createPlatformAppDataRepository() => FileAppDataRepository();
