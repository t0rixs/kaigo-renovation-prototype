import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class PendingPhotoCapture {
  const PendingPhotoCapture({
    required this.projectId,
    required this.locationId,
    required this.slot,
  });

  final String projectId;
  final String locationId;
  final ProjectPhotoSlot slot;
}

abstract final class PhotoCaptureSession {
  static const _projectKey = 'pendingPhotoProjectId';
  static const _locationKey = 'pendingPhotoLocationId';
  static const _slotKey = 'pendingPhotoSlot';

  static Future<void> begin({
    required String projectId,
    required String locationId,
    required ProjectPhotoSlot slot,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_projectKey, projectId);
    await preferences.setString(_locationKey, locationId);
    await preferences.setString(_slotKey, slot.name);
  }

  static Future<PendingPhotoCapture?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final projectId = preferences.getString(_projectKey);
    final locationId = preferences.getString(_locationKey);
    final slotName = preferences.getString(_slotKey);
    final slot = ProjectPhotoSlot.values
        .where((item) => item.name == slotName)
        .firstOrNull;
    if (projectId == null || locationId == null || slot == null) return null;
    return PendingPhotoCapture(
      projectId: projectId,
      locationId: locationId,
      slot: slot,
    );
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove(_projectKey),
      preferences.remove(_locationKey),
      preferences.remove(_slotKey),
    ]);
  }
}
