import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

const processedPhotoMaxDimension = 1280;
const processedPhotoJpegQuality = 70;

Future<Uint8List> processCapturedPhoto(Uint8List sourceBytes) => compute(
  processCapturedPhotoSynchronously,
  sourceBytes,
  debugLabel: 'process-captured-photo',
);

@visibleForTesting
Uint8List processCapturedPhotoSynchronously(Uint8List sourceBytes) {
  final decoded = image.decodeImage(sourceBytes);
  if (decoded == null) {
    throw const FormatException('Unsupported captured image');
  }

  final oriented = image.bakeOrientation(decoded);
  final longestSide = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;
  final resized = longestSide > processedPhotoMaxDimension
      ? image.copyResize(
          oriented,
          width: oriented.width >= oriented.height
              ? processedPhotoMaxDimension
              : null,
          height: oriented.height > oriented.width
              ? processedPhotoMaxDimension
              : null,
          interpolation: image.Interpolation.average,
        )
      : oriented;

  return image.encodeJpg(resized, quality: processedPhotoJpegQuality);
}
