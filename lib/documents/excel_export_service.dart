import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'document_export_data.dart';
import 'kaigo_estimate_template_writer.dart';

class ExcelExportService {
  static const templateAsset = 'assets/templates/kaigo_estimate_template.xlsx';

  Future<String?> export(DocumentExportData data) async {
    final template = await rootBundle.load(templateAsset);
    final bytes = KaigoEstimateTemplateWriter().build(
      template.buffer.asUint8List(
        template.offsetInBytes,
        template.lengthInBytes,
      ),
      data,
    );
    final name = _safeFileName(data.projectName);
    if (kIsWeb) {
      return FileSaver.instance.saveFile(
        name: name,
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    }
    return FileSaver.instance.saveAs(
      name: name,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  String _safeFileName(String projectName) {
    final normalized = projectName.trim().replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );
    return '${normalized.isEmpty ? '住宅改修' : normalized}_見積書';
  }
}
