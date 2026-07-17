import 'app_data_repository_base.dart';
import 'app_data_repository_stub.dart'
    if (dart.library.io) 'app_data_repository_io.dart'
    if (dart.library.js_interop) 'app_data_repository_web.dart';

export 'app_data_repository_base.dart';

AppDataRepository createAppDataRepository() =>
    createPlatformAppDataRepository();
