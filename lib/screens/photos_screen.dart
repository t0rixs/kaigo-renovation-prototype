import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../models.dart';
import '../photo_capture_session.dart';

typedef ProjectPhotoCapture = Future<CapturedProjectPhoto?> Function();

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key, required this.state, this.capturePhoto});

  final AppState state;
  final ProjectPhotoCapture? capturePhoto;

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen>
    with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  final Set<String> _busySlots = {};
  Completer<void>? _resumeCompleter;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.capturePhoto == null) {
      unawaited(_recoverInterruptedCapture());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_resumeCompleter?.isCompleted == false) {
      _resumeCompleter?.complete();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed &&
        _resumeCompleter?.isCompleted == false) {
      _resumeCompleter?.complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = state.photoLocations;
    return ListView(
      key: const ValueKey('photos-screen'),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
      children: [
        FilledButton.icon(
          key: const ValueKey('add-photo-location'),
          onPressed: () {
            state.addPhotoLocation();
            setState(() {});
          },
          icon: const Icon(CupertinoIcons.add),
          label: const Text('改修場所を追加'),
        ),
        if (locations.isEmpty) ...[
          const SizedBox(height: 72),
          Icon(
            CupertinoIcons.camera,
            size: 44,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'まだ写真はありません',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '改修場所を追加して、施工前後の写真を記録できます',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        for (final location in locations) ...[
          const SizedBox(height: 14),
          _PhotoLocationCard(
            location: location,
            isBusy: (slot) => _busySlots.contains(_slotKey(location.id, slot)),
            onCapture: (slot) => _capture(location, slot),
          ),
        ],
      ],
    );
  }

  String _slotKey(String locationId, ProjectPhotoSlot slot) =>
      '$locationId-${slot.name}';

  Future<void> _capture(
    RenovationPhotoLocation location,
    ProjectPhotoSlot slot,
  ) async {
    final busyKey = _slotKey(location.id, slot);
    if (_busySlots.contains(busyKey)) return;
    setState(() => _busySlots.add(busyKey));

    try {
      final photo = widget.capturePhoto != null
          ? await widget.capturePhoto!()
          : await _captureWithCamera(location.id, slot);
      if (photo == null || !mounted) return;
      state.setProjectPhoto(
        projectId: state.activeProject.id,
        locationId: location.id,
        slot: slot,
        photo: photo,
      );
    } on PlatformException catch (error) {
      _showError(_cameraErrorMessage(error));
    } catch (_) {
      _showError('写真を読み込めませんでした。もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _busySlots.remove(busyKey));
    }
  }

  Future<CapturedProjectPhoto?> _captureWithCamera(
    String locationId,
    ProjectPhotoSlot slot,
  ) async {
    await PhotoCaptureSession.begin(
      projectId: state.activeProject.id,
      locationId: locationId,
      slot: slot,
    );

    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
      requestFullMetadata: false,
    );
    await PhotoCaptureSession.clear();
    return file == null ? null : _photoFromFile(file);
  }

  Future<void> _recoverInterruptedCapture() async {
    final pending = await PhotoCaptureSession.read();
    if (pending == null) return;
    await _waitUntilResumed();
    if (!mounted) return;

    try {
      final response = await _picker.retrieveLostData();
      final file = response.files?.firstOrNull;
      if (file != null) {
        final photo = await _photoFromFile(file);
        state.setProjectPhoto(
          projectId: pending.projectId,
          locationId: pending.locationId,
          slot: pending.slot,
          photo: photo,
        );
      } else if (response.exception != null) {
        _showError(_cameraErrorMessage(response.exception!));
      }
    } on PlatformException catch (error) {
      _showError(_cameraErrorMessage(error));
    } catch (_) {
      _showError('撮影した写真を復元できませんでした。');
    } finally {
      await PhotoCaptureSession.clear();
    }
  }

  Future<void> _waitUntilResumed() async {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    final completer = _resumeCompleter ??= Completer<void>();
    await completer.future;
    if (identical(_resumeCompleter, completer)) {
      _resumeCompleter = null;
    }
  }

  Future<CapturedProjectPhoto> _photoFromFile(XFile file) async {
    final bytes = await file.readAsBytes();
    return CapturedProjectPhoto(
      base64Data: base64Encode(bytes),
      mimeType: _mimeType(file),
      fileName: file.name,
      capturedAt: DateTime.now(),
    );
  }

  String _mimeType(XFile file) {
    if (file.mimeType?.isNotEmpty == true) return file.mimeType!;
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.heic') || name.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  String _cameraErrorMessage(PlatformException error) => switch (error.code) {
    'camera_access_denied' || 'camera_access_denied_without_prompt' =>
      'カメラの利用が許可されていません。端末の設定から許可してください。',
    'camera_access_restricted' => 'この端末ではカメラを利用できません。',
    _ => 'カメラを起動できませんでした。もう一度お試しください。',
  };

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PhotoLocationCard extends StatelessWidget {
  const _PhotoLocationCard({
    required this.location,
    required this.isBusy,
    required this.onCapture,
  });

  final RenovationPhotoLocation location;
  final bool Function(ProjectPhotoSlot slot) isBusy;
  final ValueChanged<ProjectPhotoSlot> onCapture;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('photo-location-${location.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              location.locationName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PhotoSlot(
                    locationId: location.id,
                    label: '改修前',
                    slot: ProjectPhotoSlot.before,
                    photo: location.beforePhoto,
                    busy: isBusy(ProjectPhotoSlot.before),
                    onTap: () => onCapture(ProjectPhotoSlot.before),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PhotoSlot(
                    locationId: location.id,
                    label: '改修後',
                    slot: ProjectPhotoSlot.after,
                    photo: location.afterPhoto,
                    busy: isBusy(ProjectPhotoSlot.after),
                    onTap: () => onCapture(ProjectPhotoSlot.after),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.locationId,
    required this.label,
    required this.slot,
    required this.photo,
    required this.busy,
    required this.onTap,
  });

  final String locationId;
  final String label;
  final ProjectPhotoSlot slot;
  final CapturedProjectPhoto? photo;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final imageBytes = _decode(photo?.base64Data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 7),
        Semantics(
          button: true,
          label: imageBytes == null ? '$labelの写真を撮影' : '$labelの写真を再撮影',
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Material(
              color: colors.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('photo-${slot.name}-$locationId'),
                onTap: busy ? null : onTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageBytes != null)
                      Image.memory(
                        imageBytes,
                        key: ValueKey('photo-image-${slot.name}-$locationId'),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    else
                      Center(
                        child: Icon(
                          CupertinoIcons.add_circled,
                          size: 38,
                          color: colors.primary,
                        ),
                      ),
                    if (imageBytes != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: .9),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              CupertinoIcons.camera_fill,
                              size: 20,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ),
                    if (busy)
                      ColoredBox(
                        color: colors.surface.withValues(alpha: .72),
                        child: const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Uint8List? _decode(String? data) {
    if (data == null || data.isEmpty) return null;
    try {
      return base64Decode(data);
    } on FormatException {
      return null;
    }
  }
}
