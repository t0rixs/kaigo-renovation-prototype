import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:kaigo_renovation_app/app_state.dart';
import 'package:kaigo_renovation_app/documents/document_export_data.dart';
import 'package:kaigo_renovation_app/documents/kaigo_estimate_template_writer.dart';
import 'package:kaigo_renovation_app/main.dart';
import 'package:kaigo_renovation_app/models.dart';
import 'package:kaigo_renovation_app/photo_capture_session.dart';
import 'package:kaigo_renovation_app/photos/photo_processor.dart';
import 'package:kaigo_renovation_app/screens/drawing_painters.dart';
import 'package:kaigo_renovation_app/screens/drawing_screen.dart';
import 'package:kaigo_renovation_app/screens/documents_screen.dart';
import 'package:kaigo_renovation_app/screens/estimate_screen.dart';
import 'package:kaigo_renovation_app/screens/photos_screen.dart';
import 'package:kaigo_renovation_app/screens/products_screen.dart';
import 'package:kaigo_renovation_app/screens/project_camera_screen.dart';
import 'package:kaigo_renovation_app/storage/app_data_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

part 'suites/app_data_documents_suite.dart';
part 'suites/drawing_interactions_suite.dart';
part 'suites/handrail_suite.dart';
part 'suites/equipment_door_suite.dart';
part 'suites/layout_rendering_suite.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  registerAppDataDocumentsTests();
  registerDrawingInteractionTests();
  registerHandrailTests();
  registerEquipmentDoorTests();
  registerLayoutRenderingTests();
}

Future<double> doorInkCenterX({required bool flipped}) async {
  const size = ui.Size(100, 100);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  DoorPainter(
    edge: WallEdge.top,
    selected: false,
    flipped: flipped,
  ).paint(canvas, size);
  final image = await recorder.endRecording().toImage(100, 100);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  image.dispose();

  var weightedX = 0;
  var darkPixelCount = 0;
  for (var y = 0; y < 100; y++) {
    for (var x = 0; x < 100; x++) {
      final offset = (y * 100 + x) * 4;
      final isDarkStroke =
          bytes[offset + 3] > 0 &&
          bytes[offset] < 100 &&
          bytes[offset + 1] < 100 &&
          bytes[offset + 2] < 100;
      if (!isDarkStroke) continue;
      weightedX += x;
      darkPixelCount++;
    }
  }
  return weightedX / darkPixelCount;
}

Future<ui.Rect> slidingDoorInkBounds(WallEdge edge) async {
  const dimension = 100;
  const size = ui.Size.square(100);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  DoorPainter(
    edge: edge,
    selected: false,
    flipped: false,
    doorType: DoorType.sliding,
  ).paint(canvas, size);
  final image = await recorder.endRecording().toImage(dimension, dimension);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  image.dispose();

  var minX = dimension;
  var minY = dimension;
  var maxX = 0;
  var maxY = 0;
  for (var y = 0; y < dimension; y++) {
    for (var x = 0; x < dimension; x++) {
      final offset = (y * dimension + x) * 4;
      final isDarkStroke =
          bytes[offset + 3] > 0 &&
          bytes[offset] < 100 &&
          bytes[offset + 1] < 120 &&
          bytes[offset + 2] < 130;
      if (!isDarkStroke) continue;
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }
  }
  return ui.Rect.fromLTRB(
    minX.toDouble(),
    minY.toDouble(),
    maxX.toDouble(),
    maxY.toDouble(),
  );
}

Future<ui.Offset> toiletInkCenter({
  required int width,
  required int height,
  required int rotationQuarterTurns,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  ToiletPainter(
    selected: false,
    rotationQuarterTurns: rotationQuarterTurns,
  ).paint(canvas, ui.Size(width.toDouble(), height.toDouble()));
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  image.dispose();

  var weightedX = 0;
  var weightedY = 0;
  var darkPixelCount = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final offset = (y * width + x) * 4;
      final isDarkStroke =
          bytes[offset + 3] > 0 &&
          bytes[offset] < 100 &&
          bytes[offset + 1] < 100 &&
          bytes[offset + 2] < 100;
      if (!isDarkStroke) continue;
      weightedX += x;
      weightedY += y;
      darkPixelCount++;
    }
  }
  return ui.Offset(
    weightedX / darkPixelCount / width,
    weightedY / darkPixelCount / height,
  );
}

XmlDocument _archiveXml(Archive archive, String path) {
  final file = archive.findFile(path);
  if (file == null) throw StateError('$path not found');
  return XmlDocument.parse(utf8.decode(file.content));
}

String _cellValue(XmlDocument sheet, String reference) {
  final cell = sheet
      .findAllElements('c')
      .where((element) => element.getAttribute('r') == reference)
      .single;
  final inlineText = cell.findAllElements('t').map((text) => text.innerText);
  if (inlineText.isNotEmpty) return inlineText.join();
  return cell.findElements('v').firstOrNull?.innerText ?? '';
}

bool _rowIsHidden(XmlDocument sheet, int rowNumber) {
  final row = sheet
      .findAllElements('row')
      .where((element) => element.getAttribute('r') == '$rowNumber')
      .single;
  return row.getAttribute('hidden') == '1';
}
